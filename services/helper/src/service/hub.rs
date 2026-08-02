use interprocess::local_socket::prelude::*;
use interprocess::local_socket::{GenericFilePath, ListenerNonblockingMode, ListenerOptions};
#[cfg(windows)]
use interprocess::os::windows::{
    local_socket::ListenerOptionsExt, security_descriptor::SecurityDescriptor,
};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs::{File, OpenOptions};
use std::future::Future;
use std::io::{self, Error, Read, Write};
#[cfg(windows)]
use std::os::windows::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
#[cfg(windows)]
use widestring::U16CString;
#[cfg(windows)]
use windows_sys::Win32::{
    Foundation::CloseHandle,
    Storage::FileSystem::FILE_SHARE_READ,
    System::Threading::{
        OpenProcess, QueryFullProcessImageNameW, PROCESS_QUERY_LIMITED_INFORMATION,
    },
};

const HELPER_PIPE_NAME: &str = r"\\.\pipe\FlClashHelper-v1";
const CORE_PIPE_PREFIX: &str = r"\\.\pipe\FlClashCore_";
const MAX_HELPER_REQUEST_SIZE: usize = 4 * 1024;
const MAX_HELPER_RESPONSE_SIZE: usize = 64 * 1024;
const IPC_TOKEN_BASE64_URL_LENGTH: usize = 22;
const SESSION_ID_HEX_LENGTH: usize = 32;
const EXPECTED_CORE_SHA256: &str = env!("CORE_SHA256");
const APP_EXECUTABLE_NAME: &str = "FlClash.exe";

#[derive(Debug, Deserialize)]
#[serde(tag = "method", rename_all = "snake_case", deny_unknown_fields)]
enum HelperRequest {
    Ping,
    Start {
        address: String,
        #[serde(rename = "sessionId")]
        session_id: String,
    },
    Stop {
        #[serde(rename = "sessionId")]
        session_id: String,
    },
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct HelperResponse {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    session_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    core_pid: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    stopped: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    code: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    message: Option<String>,
}

impl HelperResponse {
    fn success() -> Self {
        Self {
            ok: true,
            session_id: None,
            core_pid: None,
            stopped: None,
            reason: None,
            code: None,
            message: None,
        }
    }

    fn failure(code: &'static str, message: impl ToString) -> Self {
        Self {
            ok: false,
            code: Some(code),
            message: Some(message.to_string()),
            ..Self::success()
        }
    }
}

struct ManagedCore {
    child: Child,
    session_id: String,
    address: String,
}

static PROCESS: Lazy<Mutex<Option<ManagedCore>>> = Lazy::new(|| Mutex::new(None));

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum StopDecision {
    Stop,
    NotRunning,
    SessionMismatch,
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
    Ok(helper_dir.join(env!("CORE_NAME")))
}

fn core_path() -> Result<PathBuf, Error> {
    core_path_from_helper_path(&std::env::current_exe()?)
}

fn app_path_from_helper_path(helper_path: &Path) -> Result<PathBuf, Error> {
    let helper_dir = helper_path
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .ok_or_else(|| {
            Error::new(
                io::ErrorKind::InvalidData,
                "helper executable has no parent directory",
            )
        })?;
    Ok(helper_dir.join(APP_EXECUTABLE_NAME))
}

fn app_path() -> Result<PathBuf, Error> {
    app_path_from_helper_path(&std::env::current_exe()?)
}

fn open_core(path: &Path) -> Result<File, Error> {
    let mut options = OpenOptions::new();
    options.read(true);
    #[cfg(windows)]
    options.share_mode(FILE_SHARE_READ);
    options.open(path)
}

fn sha256_file(file: &mut File) -> Result<String, Error> {
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

fn open_verified_core(path: &Path, expected_sha256: &str) -> Result<File, Error> {
    if expected_sha256.is_empty() {
        return Err(Error::other("expected Core SHA256 is empty"));
    }
    let mut core_file = open_core(path)?;
    if sha256_file(&mut core_file)? != expected_sha256 {
        return Err(Error::other("Core executable SHA256 mismatch"));
    }
    Ok(core_file)
}

fn open_fixed_verified_core() -> Result<(PathBuf, File), Error> {
    let path = core_path()?;
    let file = open_verified_core(&path, EXPECTED_CORE_SHA256)?;
    Ok((path, file))
}

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

fn is_valid_core_pipe_name(address: &str) -> bool {
    address
        .strip_prefix(CORE_PIPE_PREFIX)
        .is_some_and(has_secure_token)
}

fn is_valid_session_id(value: &str) -> bool {
    value.len() == SESSION_ID_HEX_LENGTH
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || matches!(byte, b'a'..=b'f'))
}

fn stop_decision(current_session: Option<&str>, requested_session: &str) -> StopDecision {
    match current_session {
        None => StopDecision::NotRunning,
        Some(current) if current == requested_session => StopDecision::Stop,
        Some(_) => StopDecision::SessionMismatch,
    }
}

fn start_core(address: String, session_id: String) -> HelperResponse {
    if !is_valid_session_id(&session_id) {
        return HelperResponse::failure("invalidSessionId", "invalid Core session ID");
    }
    if !is_valid_core_pipe_name(&address) {
        return HelperResponse::failure("invalidAddress", "invalid Core pipe name");
    }
    let (core_path, _core_file) = match open_fixed_verified_core() {
        Ok(core) => core,
        Err(error) => return HelperResponse::failure("coreVerificationFailed", error),
    };
    let mut process = match PROCESS.lock() {
        Ok(process) => process,
        Err(error) => return HelperResponse::failure("processStateError", error),
    };
    if let Some(current) = process.as_mut() {
        match current.child.try_wait() {
            Ok(Some(_)) => *process = None,
            Ok(None) if current.session_id == session_id && current.address == address => {
                return HelperResponse {
                    session_id: Some(session_id),
                    core_pid: Some(current.child.id()),
                    ..HelperResponse::success()
                };
            }
            Ok(None) => {
                return HelperResponse::failure(
                    "sessionMismatch",
                    "another Core session is already running",
                );
            }
            Err(error) => return HelperResponse::failure("processStateError", error),
        }
    }
    match Command::new(&core_path)
        .current_dir(core_path.parent().unwrap_or_else(|| Path::new(".")))
        .stderr(Stdio::null())
        .arg(&address)
        .spawn()
    {
        Ok(child) => {
            let core_pid = child.id();
            *process = Some(ManagedCore {
                child,
                session_id: session_id.clone(),
                address,
            });
            HelperResponse {
                session_id: Some(session_id),
                core_pid: Some(core_pid),
                ..HelperResponse::success()
            }
        }
        Err(error) => HelperResponse::failure("startFailed", error),
    }
}

fn stop_core(session_id: String) -> HelperResponse {
    if !is_valid_session_id(&session_id) {
        return HelperResponse::failure("invalidSessionId", "invalid Core session ID");
    }
    let mut process = match PROCESS.lock() {
        Ok(process) => process,
        Err(error) => return HelperResponse::failure("processStateError", error),
    };
    match stop_decision(
        process.as_ref().map(|managed| managed.session_id.as_str()),
        &session_id,
    ) {
        StopDecision::NotRunning => HelperResponse {
            session_id: Some(session_id),
            stopped: Some(false),
            reason: Some("notRunning"),
            ..HelperResponse::success()
        },
        StopDecision::SessionMismatch => HelperResponse::failure(
            "sessionMismatch",
            "the running Core belongs to another session",
        ),
        StopDecision::Stop => {
            if let Some(mut managed) = process.take() {
                let _ = managed.child.kill();
                let _ = managed.child.wait();
            }
            HelperResponse {
                session_id: Some(session_id),
                stopped: Some(true),
                ..HelperResponse::success()
            }
        }
    }
}

fn stop_core_unconditional() {
    let Ok(mut process) = PROCESS.lock() else {
        return;
    };
    if let Some(mut managed) = process.take() {
        let _ = managed.child.kill();
        let _ = managed.child.wait();
    }
}

fn handle_request(request: HelperRequest) -> HelperResponse {
    match request {
        HelperRequest::Ping => match open_fixed_verified_core() {
            Ok(_) => HelperResponse::success(),
            Err(error) => HelperResponse::failure("coreVerificationFailed", error),
        },
        HelperRequest::Start {
            address,
            session_id,
        } => start_core(address, session_id),
        HelperRequest::Stop { session_id } => stop_core(session_id),
    }
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
    let length = u32::try_from(data.len())
        .map_err(|_| Error::new(io::ErrorKind::InvalidData, "helper IPC frame overflow"))?;
    writer.write_all(&length.to_le_bytes())?;
    writer.write_all(data)
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
    let error = (result == 0).then(Error::last_os_error);
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
        .ok_or_else(|| Error::new(io::ErrorKind::PermissionDenied, "client PID unavailable"))?;
    let actual_path = std::fs::canonicalize(process_image_path(pid)?)?;
    let expected_path = std::fs::canonicalize(app_path()?)?;
    if !actual_path
        .to_string_lossy()
        .eq_ignore_ascii_case(&expected_path.to_string_lossy())
    {
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
fn run_named_pipe_service(
    running: &AtomicBool,
    on_started: impl FnOnce() -> anyhow::Result<()>,
) -> anyhow::Result<()> {
    let pipe_name = HELPER_PIPE_NAME.to_fs_name::<GenericFilePath>()?;
    let sddl = U16CString::from_str("D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;AU)")?;
    let security_descriptor = SecurityDescriptor::deserialize(&sddl)?;
    let listener = ListenerOptions::new()
        .name(pipe_name)
        .security_descriptor(security_descriptor)
        .create_sync()?;
    listener.set_nonblocking(ListenerNonblockingMode::Accept)?;
    on_started()?;

    while running.load(Ordering::SeqCst) {
        let mut stream = match listener.accept() {
            Ok(stream) => stream,
            Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                std::thread::sleep(Duration::from_millis(50));
                continue;
            }
            Err(error) => return Err(error.into()),
        };
        if authenticate_client(&stream).is_err() {
            continue;
        }
        let response = match read_frame(&mut stream, MAX_HELPER_REQUEST_SIZE).and_then(|data| {
            serde_json::from_slice::<HelperRequest>(&data)
                .map_err(|error| Error::new(io::ErrorKind::InvalidData, error))
        }) {
            Ok(request) => handle_request(request),
            Err(error) => HelperResponse::failure("invalidRequest", error),
        };
        let started_session = response
            .core_pid
            .is_some()
            .then(|| response.session_id.clone())
            .flatten();
        let write_result = serde_json::to_vec(&response)
            .map_err(Error::other)
            .and_then(|data| write_frame(&mut stream, &data, MAX_HELPER_RESPONSE_SIZE));
        if write_result.is_err() {
            if let Some(session_id) = started_session {
                let _ = stop_core(session_id);
            }
        }
    }
    Ok(())
}

#[cfg(not(windows))]
fn run_named_pipe_service(
    _running: &AtomicBool,
    _on_started: impl FnOnce() -> anyhow::Result<()>,
) -> anyhow::Result<()> {
    anyhow::bail!("the FlClash helper service is only supported on Windows")
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
pub async fn run_service() -> anyhow::Result<()> {
    run_service_until(std::future::pending(), || Ok(())).await
}

pub(super) async fn run_service_until<F, S>(shutdown: F, on_started: S) -> anyhow::Result<()>
where
    F: Future<Output = ()> + Send + 'static,
    S: FnOnce() -> anyhow::Result<()> + Send + 'static,
{
    if EXPECTED_CORE_SHA256.is_empty() {
        anyhow::bail!("expected Core SHA256 is empty");
    }
    let running = Arc::new(AtomicBool::new(true));
    let service_running = Arc::clone(&running);
    let mut service =
        tokio::task::spawn_blocking(move || run_named_pipe_service(&service_running, on_started));
    let result = tokio::select! {
        result = &mut service => result.map_err(|error| anyhow::anyhow!("join helper service: {error}"))?,
        _ = shutdown => {
            running.store(false, Ordering::SeqCst);
            service.await.map_err(|error| anyhow::anyhow!("join helper service: {error}"))?
        }
    };
    running.store(false, Ordering::SeqCst);
    stop_core_unconditional();
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn validates_session_ownership() {
        let session = "0123456789abcdef0123456789abcdef";
        let other = "fedcba9876543210fedcba9876543210";
        assert!(is_valid_session_id(session));
        assert!(!is_valid_session_id("ABCDEF0123456789abcdef0123456789"));
        assert_eq!(stop_decision(None, session), StopDecision::NotRunning);
        assert_eq!(stop_decision(Some(session), session), StopDecision::Stop);
        assert_eq!(
            stop_decision(Some(other), session),
            StopDecision::SessionMismatch
        );
    }

    #[test]
    fn accepts_only_canonical_random_core_pipe_names() {
        assert!(is_valid_core_pipe_name(
            r"\\.\pipe\FlClashCore_AAAAAAAAAAAAAAAAAAAAAA"
        ));
        assert!(!is_valid_core_pipe_name(
            r"\\.\pipe\FlClashCore_AAAAAAAAAAAAAAAAAAAAAB"
        ));
        assert!(!is_valid_core_pipe_name(r"\\.\pipe\attacker"));
    }

    #[test]
    fn request_rejects_unknown_fields() {
        let request = r#"{"method":"start","address":"pipe","sessionId":"0123456789abcdef0123456789abcdef","path":"attacker.exe"}"#;
        assert!(serde_json::from_str::<HelperRequest>(request).is_err());
    }

    #[test]
    fn request_frame_enforces_size_limit_before_allocation() {
        let frame = ((MAX_HELPER_REQUEST_SIZE + 1) as u32).to_le_bytes();
        assert_eq!(
            read_frame(&mut frame.as_slice(), MAX_HELPER_REQUEST_SIZE)
                .unwrap_err()
                .kind(),
            io::ErrorKind::InvalidData,
        );
    }

    #[test]
    fn verifies_core_sha256_in_all_build_modes() {
        let path =
            std::env::temp_dir().join(format!("flclash-helper-core-sha256-{}", std::process::id()));
        let mut file = File::create(&path).unwrap();
        file.write_all(b"test").unwrap();
        drop(file);
        assert!(open_verified_core(
            &path,
            "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
        .is_ok());
        assert_eq!(
            open_verified_core(&path, "invalid")
                .unwrap_err()
                .to_string(),
            "Core executable SHA256 mismatch"
        );
        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn executable_paths_are_fixed_beside_helper() {
        let helper = PathBuf::from("install").join("FlClashHelperService.exe");
        assert_eq!(
            core_path_from_helper_path(&helper).unwrap(),
            PathBuf::from("install").join(env!("CORE_NAME")),
        );
        assert_eq!(
            app_path_from_helper_path(&helper).unwrap(),
            PathBuf::from("install").join(APP_EXECUTABLE_NAME),
        );
    }
}
