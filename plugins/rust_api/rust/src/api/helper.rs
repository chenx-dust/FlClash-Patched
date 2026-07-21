use interprocess::local_socket::prelude::*;
use interprocess::local_socket::{ConnectOptions, GenericFilePath};
use interprocess::ConnectWaitMode;
use serde::{Deserialize, Serialize};
use std::io::{self, Read, Write};
#[cfg(windows)]
use std::mem::{size_of, MaybeUninit};
#[cfg(windows)]
use std::ptr::null;
use std::time::Duration;

#[cfg(windows)]
use windows_sys::Win32::System::Services::{
    CloseServiceHandle, OpenSCManagerW, OpenServiceW, QueryServiceStatusEx, SC_HANDLE,
    SC_MANAGER_CONNECT, SC_STATUS_PROCESS_INFO, SERVICE_QUERY_STATUS, SERVICE_RUNNING,
    SERVICE_STATUS_PROCESS,
};

const HELPER_PIPE_NAME: &str = r"\\.\pipe\FlClashHelper-v1";
const MAX_HELPER_REQUEST_SIZE: usize = 4 * 1024;
const MAX_HELPER_RESPONSE_SIZE: usize = 64 * 1024;

#[derive(Serialize)]
#[serde(tag = "method", rename_all = "snake_case")]
enum HelperRequest<'a> {
    Ping,
    Start { arg: &'a str },
    Stop,
}

#[derive(Deserialize)]
struct HelperResponse {
    ok: bool,
    token: Option<String>,
    core_pid: Option<u32>,
    error: Option<String>,
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
fn helper_service_pid() -> io::Result<u32> {
    let manager = unsafe { OpenSCManagerW(null(), null(), SC_MANAGER_CONNECT) };
    if manager.is_null() {
        return Err(io::Error::last_os_error());
    }
    let manager = OwnedServiceHandle(manager);
    let service_name: Vec<u16> = "FlClashHelperService"
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();
    let service = unsafe { OpenServiceW(manager.0, service_name.as_ptr(), SERVICE_QUERY_STATUS) };
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
    Ok(status.dwProcessId)
}

#[cfg(windows)]
fn authenticate_server(stream: &interprocess::local_socket::Stream) -> io::Result<()> {
    let pid = stream
        .peer_creds()
        .map_err(|error| io::Error::new(error.kind(), format!("query helper PID: {error}")))?
        .pid()
        .ok_or_else(|| io::Error::new(io::ErrorKind::PermissionDenied, "server PID unavailable"))?;
    let service_pid = helper_service_pid().map_err(|error| {
        io::Error::new(
            error.kind(),
            format!("query FlClash helper service PID: {error}"),
        )
    })?;
    if pid != service_pid {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!("helper server PID mismatch: actual={pid}, service={service_pid}"),
        ));
    }
    Ok(())
}

#[cfg(windows)]
fn call_helper(request: HelperRequest<'_>) -> Result<HelperResponse, String> {
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
    let response: HelperResponse =
        serde_json::from_slice(&data).map_err(|error| error.to_string())?;
    if response.ok {
        Ok(response)
    } else {
        Err(response
            .error
            .unwrap_or_else(|| "helper request failed".to_string()))
    }
}

#[cfg(not(windows))]
fn call_helper(_request: HelperRequest<'_>) -> Result<HelperResponse, String> {
    Err("the FlClash helper service is only supported on Windows".to_string())
}

pub fn helper_ping() -> Result<String, String> {
    call_helper(HelperRequest::Ping)?
        .token
        .ok_or_else(|| "helper ping response has no token".to_string())
}

pub fn helper_start_core(arg: String) -> Result<u32, String> {
    call_helper(HelperRequest::Start { arg: &arg })?
        .core_pid
        .ok_or_else(|| "helper start response has no core PID".to_string())
}

pub fn helper_stop_core() -> Result<(), String> {
    call_helper(HelperRequest::Stop)?;
    Ok(())
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
}
