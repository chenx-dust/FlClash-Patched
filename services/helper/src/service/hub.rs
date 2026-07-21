use interprocess::local_socket::prelude::*;
use interprocess::local_socket::{GenericFilePath, ListenerOptions};
#[cfg(windows)]
use interprocess::os::windows::{
    local_socket::ListenerOptionsExt, security_descriptor::SecurityDescriptor,
};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{self, Error, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
#[cfg(windows)]
use widestring::U16CString;
#[cfg(windows)]
use windows_sys::Win32::{
    Foundation::CloseHandle,
    System::Threading::{
        OpenProcess, QueryFullProcessImageNameW, PROCESS_QUERY_LIMITED_INFORMATION,
    },
};

const HELPER_PIPE_NAME: &str = r"\\.\pipe\FlClashHelper-v1";
const MAX_HELPER_REQUEST_SIZE: usize = 4 * 1024;
const MAX_HELPER_RESPONSE_SIZE: usize = 64 * 1024;
const IPC_TOKEN_BASE64_URL_LENGTH: usize = 22;
const CORE_EXECUTABLE_NAME: &str = match option_env!("CORE_EXECUTABLE_NAME") {
    Some(name) => name,
    None => "FlClashCore.exe",
};
const APP_EXECUTABLE_NAME: &str = "FlClash.exe";

#[derive(Debug, Deserialize)]
#[serde(tag = "method", rename_all = "snake_case", deny_unknown_fields)]
enum HelperRequest {
    Ping,
    Start { arg: String },
    Stop,
}

#[derive(Debug, Serialize)]
struct HelperResponse {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    token: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    core_pid: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

impl HelperResponse {
    fn success() -> Self {
        Self {
            ok: true,
            token: None,
            core_pid: None,
            error: None,
        }
    }

    fn failure(error: impl ToString) -> Self {
        Self {
            ok: false,
            token: None,
            core_pid: None,
            error: Some(error.to_string()),
        }
    }
}

fn core_path_from_helper_path(helper_path: &Path) -> Result<PathBuf, Error> {
    let helper_dir = helper_path
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .ok_or_else(|| {
            Error::new(
                io::ErrorKind::InvalidData,
                "helper executable has no parent directory",
            )
        })?;
    Ok(helper_dir.join(CORE_EXECUTABLE_NAME))
}

fn core_path() -> Result<PathBuf, Error> {
    core_path_from_helper_path(&std::env::current_exe()?)
}

fn app_path() -> Result<PathBuf, Error> {
    let helper_path = std::env::current_exe()?;
    let helper_dir = helper_path.parent().ok_or_else(|| {
        Error::new(
            io::ErrorKind::InvalidData,
            "helper executable has no parent directory",
        )
    })?;
    Ok(helper_dir.join(APP_EXECUTABLE_NAME))
}

fn sha256_file(path: &Path) -> Result<String, Error> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0; 4096];

    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

fn has_secure_token(token: &str) -> bool {
    let bytes = token.as_bytes();
    bytes.len() == IPC_TOKEN_BASE64_URL_LENGTH
        && bytes[..IPC_TOKEN_BASE64_URL_LENGTH - 1]
            .iter()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(*byte, b'-' | b'_'))
        && matches!(
            bytes[IPC_TOKEN_BASE64_URL_LENGTH - 1],
            b'A' | b'Q' | b'g' | b'w'
        )
}

fn is_valid_core_pipe_name(arg: &str) -> bool {
    const PREFIX: &str = r"\\.\pipe\FlClashCore_";
    arg.strip_prefix(PREFIX).is_some_and(has_secure_token)
}

fn start(arg: &str) -> Result<u32, String> {
    if !is_valid_core_pipe_name(arg) {
        return Err("invalid core pipe name".to_string());
    }
    let core_path = match core_path() {
        Ok(path) => path,
        Err(error) => return Err(error.to_string()),
    };
    if !cfg!(debug_assertions) {
        let sha256 = sha256_file(&core_path).unwrap_or_default();
        if sha256 != env!("TOKEN") {
            return Err(format!(
                "Core SHA256 mismatch: actual={sha256}, expected={}",
                env!("TOKEN"),
            ));
        }
    }
    stop();
    let mut process = PROCESS.lock().unwrap();
    match Command::new(&core_path)
        .stderr(Stdio::null())
        .arg(arg)
        .spawn()
    {
        Ok(child) => {
            let core_pid = child.id();
            *process = Some(child);
            Ok(core_pid)
        }
        Err(e) => Err(e.to_string()),
    }
}

fn stop() {
    let mut process = PROCESS.lock().unwrap();
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    *process = None;
}

fn read_frame(reader: &mut impl Read, limit: usize) -> io::Result<Vec<u8>> {
    let mut length = [0_u8; 4];
    reader.read_exact(&mut length)?;
    let length = u32::from_le_bytes(length) as usize;
    if length > limit {
        return Err(Error::new(
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
        return Err(Error::new(
            io::ErrorKind::InvalidData,
            "helper IPC frame is too large",
        ));
    }
    let length = u32::try_from(data.len()).map_err(|_| {
        Error::new(
            io::ErrorKind::InvalidData,
            "helper IPC frame length overflow",
        )
    })?;
    writer.write_all(&length.to_le_bytes())?;
    writer.write_all(data)
}

fn handle_request(request: HelperRequest) -> HelperResponse {
    match request {
        HelperRequest::Ping => HelperResponse {
            token: Some(env!("TOKEN")),
            ..HelperResponse::success()
        },
        HelperRequest::Start { arg } => match start(&arg) {
            Ok(core_pid) => HelperResponse {
                core_pid: Some(core_pid),
                ..HelperResponse::success()
            },
            Err(error) => HelperResponse::failure(error),
        },
        HelperRequest::Stop => {
            stop();
            HelperResponse::success()
        }
    }
}

#[cfg(windows)]
fn process_image_path(pid: u32) -> io::Result<PathBuf> {
    let process = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid) };
    if process.is_null() {
        return Err(Error::last_os_error());
    }
    let mut buffer = vec![0_u16; 32_768];
    let mut length = u32::try_from(buffer.len()).unwrap();
    let result =
        unsafe { QueryFullProcessImageNameW(process, 0, buffer.as_mut_ptr(), &mut length) };
    let error = if result == 0 {
        Some(Error::last_os_error())
    } else {
        None
    };
    unsafe {
        CloseHandle(process);
    }
    if let Some(error) = error {
        return Err(error);
    }
    buffer.truncate(length as usize);
    Ok(PathBuf::from(String::from_utf16_lossy(&buffer)))
}

#[cfg(windows)]
fn authenticate_client(stream: &interprocess::local_socket::Stream) -> io::Result<()> {
    let pid = stream
        .peer_creds()?
        .pid()
        .ok_or_else(|| Error::new(io::ErrorKind::PermissionDenied, "client PID is unavailable"))?;
    let actual_path = std::fs::canonicalize(process_image_path(pid)?)?;
    let expected_path = std::fs::canonicalize(app_path()?)?;
    if actual_path != expected_path {
        return Err(Error::new(
            io::ErrorKind::PermissionDenied,
            format!(
                "helper client executable mismatch: actual={}, expected={}",
                actual_path.display(),
                expected_path.display(),
            ),
        ));
    }
    Ok(())
}

#[cfg(windows)]
fn run_named_pipe_service() -> anyhow::Result<()> {
    let pipe_name = HELPER_PIPE_NAME.to_fs_name::<GenericFilePath>()?;
    let sddl = U16CString::from_str("D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;AU)")?;
    let security_descriptor = SecurityDescriptor::deserialize(&sddl)?;
    let listener = ListenerOptions::new()
        .name(pipe_name)
        .security_descriptor(security_descriptor)
        .create_sync()?;

    loop {
        let mut stream = listener.accept()?;
        if authenticate_client(&stream).is_err() {
            continue;
        }
        let response = match read_frame(&mut stream, MAX_HELPER_REQUEST_SIZE).and_then(|data| {
            serde_json::from_slice::<HelperRequest>(&data)
                .map_err(|error| Error::new(io::ErrorKind::InvalidData, error))
        }) {
            Ok(request) => handle_request(request),
            Err(error) => HelperResponse::failure(error),
        };
        let started_core = response.core_pid.is_some();
        let write_result = serde_json::to_vec(&response)
            .map_err(Error::other)
            .and_then(|data| write_frame(&mut stream, &data, MAX_HELPER_RESPONSE_SIZE));
        if write_result.is_err() && started_core {
            stop();
        }
    }
}

#[cfg(not(windows))]
fn run_named_pipe_service() -> anyhow::Result<()> {
    anyhow::bail!("the FlClash helper service is only supported on Windows")
}

pub async fn run_service() -> anyhow::Result<()> {
    tokio::task::spawn_blocking(run_named_pipe_service).await??;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn core_path_is_sibling_of_helper() {
        let helper_path = PathBuf::from("install").join("FlClashHelperService.exe");

        assert_eq!(
            core_path_from_helper_path(&helper_path).unwrap(),
            PathBuf::from("install").join(CORE_EXECUTABLE_NAME),
        );
    }

    #[test]
    fn core_path_rejects_missing_parent() {
        assert!(core_path_from_helper_path(Path::new("FlClashHelperService.exe")).is_err());
    }

    #[test]
    fn accepts_only_canonical_random_core_pipe_names() {
        assert!(is_valid_core_pipe_name(
            r"\\.\pipe\FlClashCore_AAAAAAAAAAAAAAAAAAAAAA",
        ));
        assert!(!is_valid_core_pipe_name(
            r"\\.\pipe\FlClashCore_AAAAAAAAAAAAAAAAAAAAAB",
        ));
        assert!(!is_valid_core_pipe_name(r"\\.\pipe\attacker"));
    }

    #[test]
    fn request_rejects_unknown_fields() {
        let request = r#"{"method":"start","arg":"pipe","path":"attacker.exe"}"#;

        assert!(serde_json::from_str::<HelperRequest>(request).is_err());
    }

    #[test]
    fn request_frame_enforces_size_limit_before_allocation() {
        let mut frame = ((MAX_HELPER_REQUEST_SIZE + 1) as u32)
            .to_le_bytes()
            .to_vec();
        frame.extend_from_slice(b"ignored");

        assert_eq!(
            read_frame(&mut frame.as_slice(), MAX_HELPER_REQUEST_SIZE)
                .unwrap_err()
                .kind(),
            io::ErrorKind::InvalidData,
        );
    }
}
