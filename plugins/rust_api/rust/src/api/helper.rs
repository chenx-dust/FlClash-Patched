use interprocess::local_socket::prelude::*;
use interprocess::local_socket::{ConnectOptions, GenericFilePath};
use interprocess::ConnectWaitMode;
use serde::{Deserialize, Serialize};
use std::io::{self, Read, Write};
#[cfg(windows)]
use std::mem::{size_of, MaybeUninit};
#[cfg(windows)]
use std::os::windows::ffi::OsStringExt;
use std::path::{Path, PathBuf};
#[cfg(windows)]
use std::ptr::null;
use std::time::Duration;

#[cfg(windows)]
use windows_sys::Win32::Foundation::ERROR_INSUFFICIENT_BUFFER;
#[cfg(windows)]
use windows_sys::Win32::System::Services::{
    CloseServiceHandle, OpenSCManagerW, OpenServiceW, QueryServiceConfigW, QueryServiceStatusEx,
    QUERY_SERVICE_CONFIGW, SC_HANDLE, SC_MANAGER_CONNECT, SC_STATUS_PROCESS_INFO,
    SERVICE_QUERY_CONFIG, SERVICE_QUERY_STATUS, SERVICE_RUNNING, SERVICE_STATUS_PROCESS,
};

const HELPER_PIPE_NAME: &str = r"\\.\pipe\FlClashHelper-v1";
const HELPER_EXECUTABLE_NAME: &str = "FlClashHelperService.exe";
const MAX_HELPER_REQUEST_SIZE: usize = 4 * 1024;
const MAX_HELPER_RESPONSE_SIZE: usize = 64 * 1024;
const SESSION_ID_HEX_LENGTH: usize = 32;

#[derive(Serialize)]
#[serde(tag = "method", rename_all = "snake_case")]
enum HelperRequest<'a> {
    Ping,
    Start {
        address: &'a str,
        #[serde(rename = "sessionId")]
        session_id: &'a str,
    },
    Stop {
        #[serde(rename = "sessionId")]
        session_id: &'a str,
    },
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HelperRpcResponse {
    pub ok: bool,
    pub session_id: Option<String>,
    pub core_pid: Option<u32>,
    pub stopped: Option<bool>,
    pub reason: Option<String>,
    pub code: Option<String>,
    pub message: Option<String>,
}

fn is_valid_session_id(value: &str) -> bool {
    value.len() == SESSION_ID_HEX_LENGTH
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || matches!(byte, b'a'..=b'f'))
}

fn read_frame(reader: &mut impl Read, limit: usize) -> io::Result<Vec<u8>> {
    let mut length = [0_u8; 4];
    reader.read_exact(&mut length)?;
    let length = u32::from_le_bytes(length) as usize;
    if length > limit {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "helper IPC frame is too large",
        ));
    }
    let mut data = vec![0_u8; length];
    reader.read_exact(&mut data)?;
    Ok(data)
}

fn write_frame(writer: &mut impl Write, data: &[u8], limit: usize) -> io::Result<()> {
    if data.len() > limit {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "helper IPC frame is too large",
        ));
    }
    let length = u32::try_from(data.len()).map_err(|_| {
        io::Error::new(
            io::ErrorKind::InvalidData,
            "helper IPC frame length overflow",
        )
    })?;
    writer.write_all(&length.to_le_bytes())?;
    writer.write_all(data)
}

fn helper_path_from_app_path(app_path: &Path) -> io::Result<PathBuf> {
    let app_dir = app_path
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                "application executable has no parent directory",
            )
        })?;
    Ok(app_dir.join(HELPER_EXECUTABLE_NAME))
}

#[cfg(windows)]
struct OwnedServiceHandle(SC_HANDLE);

#[cfg(windows)]
impl Drop for OwnedServiceHandle {
    fn drop(&mut self) {
        unsafe {
            CloseServiceHandle(self.0);
        }
    }
}

#[cfg(windows)]
fn helper_service_identity() -> io::Result<(u32, PathBuf)> {
    // An unelevated app cannot reliably open the LocalSystem service process.
    // SCM exposes both identity fields with ordinary query permissions.
    let manager = unsafe { OpenSCManagerW(null(), null(), SC_MANAGER_CONNECT) };
    if manager.is_null() {
        return Err(io::Error::last_os_error());
    }
    let manager = OwnedServiceHandle(manager);
    let service_name: Vec<u16> = "FlClashHelperService"
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();
    let service = unsafe {
        OpenServiceW(
            manager.0,
            service_name.as_ptr(),
            SERVICE_QUERY_CONFIG | SERVICE_QUERY_STATUS,
        )
    };
    if service.is_null() {
        return Err(io::Error::last_os_error());
    }
    let service = OwnedServiceHandle(service);
    let mut status = MaybeUninit::<SERVICE_STATUS_PROCESS>::zeroed();
    let mut bytes_needed = 0_u32;
    let result = unsafe {
        QueryServiceStatusEx(
            service.0,
            SC_STATUS_PROCESS_INFO,
            status.as_mut_ptr().cast(),
            u32::try_from(size_of::<SERVICE_STATUS_PROCESS>()).unwrap(),
            &mut bytes_needed,
        )
    };
    if result == 0 {
        return Err(io::Error::last_os_error());
    }
    let status = unsafe { status.assume_init() };
    if status.dwCurrentState != SERVICE_RUNNING || status.dwProcessId == 0 {
        return Err(io::Error::new(
            io::ErrorKind::NotConnected,
            "FlClash helper service is not running",
        ));
    }
    let executable_path = query_service_executable_path(service.0)?;
    Ok((status.dwProcessId, executable_path))
}

#[cfg(windows)]
fn query_service_executable_path(service: SC_HANDLE) -> io::Result<PathBuf> {
    let mut bytes_needed = 0_u32;
    let result =
        unsafe { QueryServiceConfigW(service, std::ptr::null_mut(), 0, &mut bytes_needed) };
    if result != 0 || bytes_needed == 0 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "service configuration size is unavailable",
        ));
    }
    let error = io::Error::last_os_error();
    if error.raw_os_error() != Some(ERROR_INSUFFICIENT_BUFFER as i32) {
        return Err(error);
    }

    loop {
        let byte_count = usize::try_from(bytes_needed).map_err(|_| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                "service configuration is too large",
            )
        })?;
        let word_count = byte_count.div_ceil(size_of::<usize>());
        // QUERY_SERVICE_CONFIGW requires pointer alignment that Vec<u8> does not guarantee.
        let mut config_buffer = vec![0_usize; word_count];
        let buffer_size = config_buffer
            .len()
            .checked_mul(size_of::<usize>())
            .and_then(|size| u32::try_from(size).ok())
            .ok_or_else(|| {
                io::Error::new(
                    io::ErrorKind::InvalidData,
                    "service configuration is too large",
                )
            })?;
        let mut next_bytes_needed = 0_u32;
        let result = unsafe {
            QueryServiceConfigW(
                service,
                config_buffer.as_mut_ptr().cast(),
                buffer_size,
                &mut next_bytes_needed,
            )
        };
        if result != 0 {
            let config = unsafe { &*config_buffer.as_ptr().cast::<QUERY_SERVICE_CONFIGW>() };
            let command = unsafe { wide_string(config.lpBinaryPathName)? };
            return registered_service_executable_path(&command);
        }

        let error = io::Error::last_os_error();
        if error.raw_os_error() != Some(ERROR_INSUFFICIENT_BUFFER as i32)
            || next_bytes_needed <= buffer_size
        {
            return Err(error);
        }
        bytes_needed = next_bytes_needed;
    }
}

#[cfg(windows)]
unsafe fn wide_string(value: *const u16) -> io::Result<std::ffi::OsString> {
    if value.is_null() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "service executable path is unavailable",
        ));
    }
    let mut length = 0_usize;
    while unsafe { *value.add(length) } != 0 {
        length += 1;
        if length > 32_768 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "service executable path is too long",
            ));
        }
    }
    Ok(std::ffi::OsString::from_wide(unsafe {
        std::slice::from_raw_parts(value, length)
    }))
}

#[cfg(windows)]
fn registered_service_executable_path(command: &std::ffi::OsStr) -> io::Result<PathBuf> {
    let command = command.to_string_lossy();
    let command = command.trim();
    let path = if let Some(command) = command.strip_prefix('"') {
        command.strip_suffix('"').filter(|path| !path.contains('"'))
    } else if command.chars().all(|character| !character.is_whitespace()) {
        Some(command)
    } else {
        None
    };
    match path {
        Some(path) if !path.is_empty() => Ok(PathBuf::from(path)),
        _ => Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "helper service command must contain only its executable path",
        )),
    }
}

#[cfg(windows)]
fn authenticate_server(stream: &interprocess::local_socket::Stream) -> io::Result<()> {
    let pid = stream
        .peer_creds()
        .map_err(|error| io::Error::new(error.kind(), format!("query helper PID: {error}")))?
        .pid()
        .ok_or_else(|| io::Error::new(io::ErrorKind::PermissionDenied, "server PID unavailable"))?;
    let (service_pid, service_path) = helper_service_identity().map_err(|error| {
        io::Error::new(
            error.kind(),
            format!("query FlClash helper service identity: {error}"),
        )
    })?;
    if pid != service_pid {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!("helper server PID mismatch: actual={pid}, service={service_pid}"),
        ));
    }
    let actual_path = std::fs::canonicalize(service_path)?;
    let expected_path =
        std::fs::canonicalize(helper_path_from_app_path(&std::env::current_exe()?)?)?;
    if !actual_path
        .to_string_lossy()
        .eq_ignore_ascii_case(&expected_path.to_string_lossy())
    {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!(
                "helper server executable mismatch: actual={}, expected={}",
                actual_path.display(),
                expected_path.display(),
            ),
        ));
    }
    Ok(())
}

#[cfg(windows)]
fn call_helper(request: HelperRequest<'_>) -> Result<HelperRpcResponse, String> {
    let name = HELPER_PIPE_NAME
        .to_fs_name::<GenericFilePath>()
        .map_err(|error| error.to_string())?;
    let mut stream = ConnectOptions::new()
        .name(name)
        .wait_mode(ConnectWaitMode::Timeout(Duration::from_secs(2)))
        .connect_sync()
        .map_err(|error| format!("connect helper pipe: {error}"))?;
    authenticate_server(&stream).map_err(|error| format!("authenticate helper server: {error}"))?;
    let data = serde_json::to_vec(&request).map_err(|error| error.to_string())?;
    write_frame(&mut stream, &data, MAX_HELPER_REQUEST_SIZE).map_err(|error| error.to_string())?;
    let data =
        read_frame(&mut stream, MAX_HELPER_RESPONSE_SIZE).map_err(|error| error.to_string())?;
    serde_json::from_slice(&data).map_err(|error| error.to_string())
}

#[cfg(not(windows))]
fn call_helper(_request: HelperRequest<'_>) -> Result<HelperRpcResponse, String> {
    Err("the FlClash helper service is only supported on Windows".to_string())
}

pub fn helper_ping() -> Result<HelperRpcResponse, String> {
    call_helper(HelperRequest::Ping)
}

pub fn helper_start_core(address: String, session_id: String) -> Result<HelperRpcResponse, String> {
    if !is_valid_session_id(&session_id) {
        return Err("Core session ID must be 128-bit lowercase hexadecimal".to_string());
    }
    call_helper(HelperRequest::Start {
        address: &address,
        session_id: &session_id,
    })
}

pub fn helper_stop_core(session_id: String) -> Result<HelperRpcResponse, String> {
    if !is_valid_session_id(&session_id) {
        return Err("Core session ID must be 128-bit lowercase hexadecimal".to_string());
    }
    call_helper(HelperRequest::Stop {
        session_id: &session_id,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn response_frame_rejects_oversized_length() {
        let frame = ((MAX_HELPER_RESPONSE_SIZE + 1) as u32).to_le_bytes();

        assert_eq!(
            read_frame(&mut frame.as_slice(), MAX_HELPER_RESPONSE_SIZE)
                .unwrap_err()
                .kind(),
            io::ErrorKind::InvalidData,
        );
    }

    #[test]
    fn requests_include_session_ownership() {
        let session = "0123456789abcdef0123456789abcdef";
        let request = HelperRequest::Start {
            address: r"\\.\pipe\FlClashCore_AAAAAAAAAAAAAAAAAAAAAA",
            session_id: session,
        };
        let value = serde_json::to_value(request).unwrap();
        assert_eq!(value["sessionId"], session);
        assert!(is_valid_session_id(session));
        assert!(!is_valid_session_id("ABCDEF0123456789abcdef0123456789"));
    }

    #[test]
    fn helper_path_is_fixed_beside_app() {
        let app = PathBuf::from("install").join("FlClash.exe");
        assert_eq!(
            helper_path_from_app_path(&app).unwrap(),
            PathBuf::from("install").join(HELPER_EXECUTABLE_NAME),
        );
    }

    #[cfg(windows)]
    #[test]
    fn service_command_must_only_name_the_helper_executable() {
        assert_eq!(
            registered_service_executable_path(std::ffi::OsStr::new(
                r#""C:\Program Files\FlClash\FlClashHelperService.exe""#,
            ))
            .unwrap(),
            PathBuf::from(r"C:\Program Files\FlClash\FlClashHelperService.exe"),
        );
        assert_eq!(
            registered_service_executable_path(std::ffi::OsStr::new(
                r"C:\FlClash\FlClashHelperService.exe",
            ))
            .unwrap(),
            PathBuf::from(r"C:\FlClash\FlClashHelperService.exe"),
        );
        assert!(registered_service_executable_path(std::ffi::OsStr::new(
            r#""C:\Program Files\FlClash\FlClashHelperService.exe" attacker"#,
        ))
        .is_err(),);
    }
}
