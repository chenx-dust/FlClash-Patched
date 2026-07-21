use crate::frb_generated::StreamSink;
use flutter_rust_bridge::for_generated::SseCodec;
use flutter_rust_bridge::frb;
use interprocess::local_socket::prelude::*;
use interprocess::local_socket::{GenericFilePath, ListenerNonblockingMode, ListenerOptions};
use std::io::{self, Read, Write};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{self, SyncSender, TrySendError};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

#[cfg(unix)]
use std::fs::{DirBuilder, Permissions};
#[cfg(unix)]
use std::os::unix::fs::{DirBuilderExt, FileTypeExt, MetadataExt, PermissionsExt};
#[cfg(unix)]
use std::path::{Path, PathBuf};

#[cfg(target_os = "macos")]
use std::os::fd::AsRawFd;

#[cfg(windows)]
use std::os::windows::io::{AsHandle, AsRawHandle};
#[cfg(windows)]
use windows_sys::Win32::System::Pipes::PeekNamedPipe;

macro_rules! ipc_debug {
    ($($arg:tt)*) => {
        #[cfg(debug_assertions)]
        eprintln!($($arg)*);
    };
}

static RUNNING: AtomicBool = AtomicBool::new(false);
static CONNECTED: AtomicBool = AtomicBool::new(false);
static GENERATION: AtomicU64 = AtomicU64::new(0);
static EXPECTED_CORE_PID: AtomicU64 = AtomicU64::new(0);
static LIFECYCLE: Mutex<()> = Mutex::new(());

struct ServerState {
    tx: Option<SyncSender<Vec<u8>>>,
    handle: Option<thread::JoinHandle<()>>,
}

static STATE: Mutex<ServerState> = Mutex::new(ServerState {
    tx: None,
    handle: None,
});

const TYPE_READY: u8 = 0x00;
const TYPE_CONNECTED: u8 = 0x01;
const TYPE_DISCONNECTED: u8 = 0x02;
const TYPE_DATA: u8 = 0x03;
const TYPE_ERROR: u8 = 0x04;

const MAX_FRAME_SIZE: usize = 64 * 1024 * 1024;
const MAX_PENDING_MESSAGES: usize = 8;
const IO_POLL_INTERVAL: Duration = Duration::from_millis(20);
const ACCEPT_POLL_INTERVAL: Duration = Duration::from_millis(50);
const PEER_AUTH_TIMEOUT: Duration = Duration::from_secs(10);

#[cfg(unix)]
const UNIX_FALLBACK_RUNTIME_ROOT: &str = "/tmp";
#[cfg(unix)]
const UNIX_APP_RUNTIME_DIR: &str = "flclash";
#[cfg(unix)]
const UNIX_RUNTIME_PREFIX: &str = "flclash-";
#[cfg(unix)]
const UNIX_SOCKET_PREFIX: &str = "ipc-";
#[cfg(unix)]
const UNIX_SOCKET_SUFFIX: &str = ".sock";
#[cfg(unix)]
const IPC_TOKEN_BASE64_URL_LENGTH: usize = 22;

fn make_frame(ty: u8, payload: &[u8]) -> Vec<u8> {
    let mut frame = Vec::with_capacity(1 + payload.len());
    frame.push(ty);
    frame.extend_from_slice(payload);
    frame
}

fn wait_for_expected_core_pid(generation: u64) -> io::Result<u64> {
    let deadline = Instant::now() + PEER_AUTH_TIMEOUT;
    loop {
        let expected_pid = EXPECTED_CORE_PID.load(Ordering::SeqCst);
        if expected_pid != 0 {
            return Ok(expected_pid);
        }
        if !server_active(generation) {
            return Err(io::Error::new(
                io::ErrorKind::Interrupted,
                "IPC server stopped before peer authorization",
            ));
        }
        if Instant::now() >= deadline {
            return Err(io::Error::new(
                io::ErrorKind::TimedOut,
                "timed out awaiting the expected core PID",
            ));
        }
        thread::sleep(IO_POLL_INTERVAL);
    }
}

fn validate_peer_pid(actual_pid: u64, expected_pid: u64) -> io::Result<()> {
    (actual_pid == expected_pid).then_some(()).ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!("IPC peer PID mismatch: actual={actual_pid}, expected={expected_pid}"),
        )
    })
}

#[derive(Debug, PartialEq, Eq)]
struct PeerIdentity {
    pid: u64,
    euid: u32,
}

#[cfg(target_os = "macos")]
fn macos_peer_pid(stream: &LocalSocketStream) -> io::Result<u64> {
    let LocalSocketStream::UdSocket(stream) = stream;
    let mut pid: libc::pid_t = 0;
    let mut length = std::mem::size_of_val(&pid) as libc::socklen_t;
    let result = unsafe {
        libc::getsockopt(
            stream.inner().as_raw_fd(),
            libc::SOL_LOCAL,
            libc::LOCAL_PEERPID,
            std::ptr::from_mut(&mut pid).cast(),
            &mut length,
        )
    };
    if result != 0 {
        return Err(io::Error::last_os_error());
    }
    if length as usize != std::mem::size_of_val(&pid) || pid <= 0 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "Unix IPC peer returned an invalid process ID",
        ));
    }
    Ok(pid as u64)
}

#[cfg(unix)]
fn peer_identity(stream: &LocalSocketStream) -> io::Result<PeerIdentity> {
    let credentials = stream.peer_creds()?;
    let euid = credentials.euid().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::Unsupported,
            "Unix IPC peer user ID is unavailable",
        )
    })?;
    #[cfg(target_os = "macos")]
    let pid = macos_peer_pid(stream)?;
    #[cfg(not(target_os = "macos"))]
    let pid = credentials.pid().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::Unsupported,
            "Unix IPC peer process ID is unavailable",
        )
    })? as u64;
    Ok(PeerIdentity { pid, euid })
}

fn validate_peer_identity(
    identity: &PeerIdentity,
    expected_pid: u64,
    expected_euid: u32,
) -> io::Result<()> {
    validate_peer_pid(identity.pid, expected_pid)?;
    // The desktop core normally inherits the app user's EUID. TUN mode uses a
    // setuid-root core on Unix, so the same process may legitimately connect
    // with EUID 0. The exact spawned PID is still required above.
    if identity.euid != expected_euid && identity.euid != 0 {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!(
                "IPC peer user mismatch: actual={}, expected={expected_euid} or root",
                identity.euid,
            ),
        ));
    }
    Ok(())
}

#[cfg(unix)]
fn wait_for_authorized_peer(stream: &LocalSocketStream, generation: u64) -> io::Result<()> {
    let identity = peer_identity(stream)?;
    let expected_pid = wait_for_expected_core_pid(generation)?;
    validate_peer_identity(&identity, expected_pid, unsafe { libc::geteuid() })
}

#[cfg(windows)]
fn wait_for_authorized_peer(stream: &LocalSocketStream, generation: u64) -> io::Result<()> {
    let actual_pid = stream
        .peer_creds()?
        .pid()
        .ok_or_else(|| io::Error::new(io::ErrorKind::Unsupported, "IPC peer PID is unavailable"))?;
    let expected_pid = wait_for_expected_core_pid(generation)?;
    validate_peer_pid(u64::from(actual_pid), expected_pid)
}

#[cfg(unix)]
fn has_secure_token_name(value: &str, prefix: &str, suffix: &str) -> bool {
    let Some(token) = value
        .strip_prefix(prefix)
        .and_then(|value| value.strip_suffix(suffix))
    else {
        return false;
    };
    let bytes = token.as_bytes();
    if bytes.len() != IPC_TOKEN_BASE64_URL_LENGTH {
        return false;
    }
    bytes[..IPC_TOKEN_BASE64_URL_LENGTH - 1]
        .iter()
        .all(|byte| byte.is_ascii_alphanumeric() || matches!(*byte, b'-' | b'_'))
        && matches!(
            bytes[IPC_TOKEN_BASE64_URL_LENGTH - 1],
            b'A' | b'Q' | b'g' | b'w'
        )
}

#[cfg(unix)]
fn preferred_unix_runtime_root() -> Option<PathBuf> {
    match std::env::consts::OS {
        "linux" => {
            let root = PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR")?);
            if !is_usable_preferred_runtime_root(&root) {
                return None;
            }
            Some(root)
        }
        "macos" => {
            let root = std::env::temp_dir();
            is_usable_preferred_runtime_root(&root).then_some(root)
        }
        _ => None,
    }
}

#[cfg(unix)]
fn is_usable_preferred_runtime_root(runtime_root: &Path) -> bool {
    runtime_root.is_absolute()
        && runtime_root != Path::new("/")
        && runtime_root != Path::new(UNIX_FALLBACK_RUNTIME_ROOT)
}

#[cfg(unix)]
fn ensure_private_preferred_runtime_root(runtime_root: &Path) -> io::Result<()> {
    let metadata = std::fs::symlink_metadata(runtime_root)?;
    if !metadata.file_type().is_dir()
        || metadata.file_type().is_symlink()
        || metadata.uid() != unsafe { libc::geteuid() }
        || metadata.mode() & 0o777 != 0o700
    {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "Preferred Unix runtime root must be owned by the current user with mode 0700",
        ));
    }
    Ok(())
}

#[cfg(unix)]
fn is_preferred_runtime_dir(runtime_dir: &Path, runtime_name: &str) -> io::Result<bool> {
    let Some(runtime_root) = preferred_unix_runtime_root() else {
        return Ok(false);
    };
    if runtime_dir.parent() != Some(runtime_root.as_path()) {
        return Ok(false);
    }

    if runtime_name != UNIX_APP_RUNTIME_DIR {
        return Ok(false);
    }
    ensure_private_preferred_runtime_root(&runtime_root)?;
    Ok(true)
}

#[cfg(unix)]
fn unix_runtime_dir(socket_path: &Path) -> io::Result<&Path> {
    if !socket_path.is_absolute() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Unix IPC path must be absolute",
        ));
    }
    let runtime_dir = socket_path.parent().ok_or_else(|| {
        io::Error::new(io::ErrorKind::InvalidInput, "Unix IPC path has no parent")
    })?;
    let runtime_name = runtime_dir
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::InvalidInput,
                "Unix IPC runtime directory name is invalid",
            )
        })?;
    let socket_name = socket_path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::InvalidInput,
                "Unix IPC socket name is invalid",
            )
        })?;
    if !has_secure_token_name(socket_name, UNIX_SOCKET_PREFIX, UNIX_SOCKET_SUFFIX) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Unix IPC socket name must contain a 128-bit unpadded Base64URL token",
        ));
    }

    let uses_random_tmp_directory = runtime_dir.parent()
        == Some(Path::new(UNIX_FALLBACK_RUNTIME_ROOT))
        && has_secure_token_name(runtime_name, UNIX_RUNTIME_PREFIX, "");
    if !uses_random_tmp_directory && !is_preferred_runtime_dir(runtime_dir, runtime_name)? {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Unix IPC runtime directory is outside the allowed platform runtime root",
        ));
    }
    Ok(runtime_dir)
}

#[cfg(unix)]
fn ensure_private_runtime_dir(socket_path: &Path) -> io::Result<&Path> {
    let runtime_dir = unix_runtime_dir(socket_path)?;
    let mut builder = DirBuilder::new();
    builder.mode(0o700);
    match builder.create(runtime_dir) {
        Ok(()) => {}
        Err(error) if error.kind() == io::ErrorKind::AlreadyExists => {}
        Err(error) => return Err(error),
    }

    let metadata = std::fs::symlink_metadata(runtime_dir)?;
    if !metadata.file_type().is_dir()
        || metadata.file_type().is_symlink()
        || metadata.uid() != unsafe { libc::geteuid() }
        || metadata.mode() & 0o777 != 0o700
    {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "Unix IPC runtime directory must be owned by the current user with mode 0700",
        ));
    }
    Ok(runtime_dir)
}

fn prepare_socket(path: &str) -> io::Result<()> {
    #[cfg(unix)]
    {
        let socket_path = Path::new(path);
        ensure_private_runtime_dir(socket_path)?;
        match std::fs::symlink_metadata(socket_path) {
            Ok(metadata)
                if metadata.file_type().is_socket() || metadata.file_type().is_symlink() =>
            {
                std::fs::remove_file(socket_path)?;
            }
            Ok(_) => {
                return Err(io::Error::new(
                    io::ErrorKind::AlreadyExists,
                    "Unix IPC path exists and is not a socket",
                ));
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => return Err(error),
        }
    }
    #[cfg(windows)]
    {
        let _ = path;
    }
    Ok(())
}

fn secure_socket_permissions(path: &str) -> io::Result<()> {
    #[cfg(unix)]
    {
        let socket_path = Path::new(path);
        unix_runtime_dir(socket_path)?;
        std::fs::set_permissions(socket_path, Permissions::from_mode(0o600))?;
        let metadata = std::fs::symlink_metadata(socket_path)?;
        if !metadata.file_type().is_socket()
            || metadata.uid() != unsafe { libc::geteuid() }
            || metadata.mode() & 0o777 != 0o600
        {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "Unix IPC socket must be owned by the current user with mode 0600",
            ));
        }
    }
    #[cfg(windows)]
    {
        let _ = path;
    }
    Ok(())
}

fn cleanup_socket(path: &str) -> io::Result<()> {
    #[cfg(unix)]
    {
        let socket_path = Path::new(path);
        let runtime_dir = unix_runtime_dir(socket_path)?;
        match std::fs::remove_file(socket_path) {
            Ok(()) => {}
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => return Err(error),
        }
        match std::fs::remove_dir(runtime_dir) {
            Ok(()) => {}
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => return Err(error),
        }
    }
    #[cfg(windows)]
    {
        let _ = path;
    }
    Ok(())
}

fn is_current_gen(generation: u64) -> bool {
    GENERATION.load(Ordering::SeqCst) == generation
}

fn server_active(generation: u64) -> bool {
    RUNNING.load(Ordering::SeqCst) && is_current_gen(generation)
}

fn take_server_handle() -> Result<Option<thread::JoinHandle<()>>, String> {
    let mut state = STATE.lock().map_err(|e| format!("Lock poisoned: {e}"))?;
    state.tx = None;
    Ok(state.handle.take())
}

fn join_server(handle: Option<thread::JoinHandle<()>>) -> Result<(), String> {
    if let Some(handle) = handle {
        ipc_debug!("[IPC] joining server thread...");
        handle
            .join()
            .map_err(|_| "IPC server thread panicked".to_owned())?;
        ipc_debug!("[IPC] server thread joined");
    }
    Ok(())
}

fn stop_server_thread() -> Result<(), String> {
    RUNNING.store(false, Ordering::SeqCst);
    CONNECTED.store(false, Ordering::SeqCst);
    EXPECTED_CORE_PID.store(0, Ordering::SeqCst);
    join_server(take_server_handle()?)
}

#[frb]
pub fn set_expected_core_pid(pid: u32) -> Result<(), String> {
    if pid == 0 {
        return Err("Expected core process ID must be positive".into());
    }
    EXPECTED_CORE_PID.store(u64::from(pid), Ordering::SeqCst);
    Ok(())
}

#[frb]
pub fn clear_expected_core_pid() {
    EXPECTED_CORE_PID.store(0, Ordering::SeqCst);
}

#[frb]
pub fn restart_ipc_server(name: String, sink: StreamSink<Vec<u8>, SseCodec>) -> Result<(), String> {
    let _lifecycle = LIFECYCLE
        .lock()
        .map_err(|e| format!("Lifecycle lock poisoned: {e}"))?;
    let generation = GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    ipc_debug!("[IPC] restart_ipc_server: gen={generation}, name={name}");

    stop_server_thread()?;
    prepare_socket(&name).map_err(|e| format!("Failed to prepare IPC socket: {e}"))?;

    RUNNING.store(true, Ordering::SeqCst);
    let handle = thread::Builder::new()
        .name("ipc-server".into())
        .spawn(move || io_loop(name, sink, generation))
        .map_err(|e| {
            RUNNING.store(false, Ordering::SeqCst);
            format!("Failed to spawn IPC server thread: {e}")
        })?;

    let mut state = STATE.lock().map_err(|e| format!("Lock poisoned: {e}"))?;
    state.handle = Some(handle);
    Ok(())
}

#[frb]
pub fn stop_ipc_server() -> Result<(), String> {
    let _lifecycle = LIFECYCLE
        .lock()
        .map_err(|e| format!("Lifecycle lock poisoned: {e}"))?;
    ipc_debug!(
        "[IPC] stop_ipc_server: RUNNING={}",
        RUNNING.load(Ordering::SeqCst)
    );
    stop_server_thread()
}

#[frb]
pub fn ipc_server_status() -> bool {
    RUNNING.load(Ordering::SeqCst)
}

#[frb]
pub fn is_ipc_connected() -> bool {
    CONNECTED.load(Ordering::SeqCst)
}

#[frb]
pub fn send_ipc_message(data: Vec<u8>) -> Result<(), String> {
    validate_frame_len(data.len()).map_err(|e| e.to_string())?;
    if !CONNECTED.load(Ordering::SeqCst) {
        return Err("IPC client is not connected".into());
    }

    let tx = STATE
        .lock()
        .map_err(|e| format!("Lock poisoned: {e}"))?
        .tx
        .clone()
        .ok_or("IPC server is not running")?;

    match tx.try_send(data) {
        Ok(()) => Ok(()),
        Err(TrySendError::Full(_)) => Err("IPC send queue is full".into()),
        Err(TrySendError::Disconnected(_)) => Err("IPC client is disconnected".into()),
    }
}

fn validate_frame_len(len: usize) -> io::Result<u32> {
    if len > MAX_FRAME_SIZE {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("IPC frame exceeds {MAX_FRAME_SIZE} bytes"),
        ));
    }
    u32::try_from(len)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "IPC frame is too large"))
}

fn is_nonblocking_idle(error: &io::Error) -> bool {
    error.kind() == io::ErrorKind::WouldBlock
}

#[cfg(windows)]
fn windows_pipe_available_bytes(pipe: &impl AsHandle) -> io::Result<usize> {
    let mut available = 0;
    let result = unsafe {
        PeekNamedPipe(
            pipe.as_handle().as_raw_handle(),
            std::ptr::null_mut(),
            0,
            std::ptr::null_mut(),
            &mut available,
            std::ptr::null_mut(),
        )
    };
    if result != 0 {
        return Ok(available as usize);
    }
    Err(io::Error::last_os_error())
}

#[cfg(any(windows, test))]
fn available_read_len(buffer_len: usize, available: usize) -> io::Result<usize> {
    if buffer_len == 0 {
        return Ok(0);
    }
    if available == 0 {
        return Err(io::ErrorKind::WouldBlock.into());
    }
    Ok(available.min(buffer_len))
}

#[cfg(windows)]
struct WindowsPipeReader<R>(R);

#[cfg(windows)]
impl<R: Read + AsHandle> Read for WindowsPipeReader<R> {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if buffer.is_empty() {
            return Ok(0);
        }
        let available = windows_pipe_available_bytes(&self.0)?;
        let read_len = available_read_len(buffer.len(), available)?;
        self.0.read(&mut buffer[..read_len])
    }
}

fn write_all_interruptible(
    writer: &mut impl Write,
    mut data: &[u8],
    connection_running: &AtomicBool,
    generation: u64,
) -> io::Result<()> {
    while !data.is_empty() {
        if !connection_running.load(Ordering::SeqCst) || !server_active(generation) {
            return Err(io::Error::new(
                io::ErrorKind::Interrupted,
                "IPC connection stopped",
            ));
        }
        match writer.write(data) {
            Ok(0) => return Err(io::ErrorKind::WriteZero.into()),
            Ok(written) => data = &data[written..],
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                thread::sleep(IO_POLL_INTERVAL);
            }
            Err(e) => return Err(e),
        }
    }
    Ok(())
}

fn write_frame(
    writer: &mut impl Write,
    data: &[u8],
    connection_running: &AtomicBool,
    generation: u64,
) -> io::Result<()> {
    let len = validate_frame_len(data.len())?;
    write_all_interruptible(writer, &len.to_le_bytes(), connection_running, generation)?;
    write_all_interruptible(writer, data, connection_running, generation)
}

#[frb(ignore)]
#[derive(Default)]
struct FrameReader {
    header: [u8; 4],
    header_read: usize,
    payload: Vec<u8>,
    payload_read: usize,
}

impl FrameReader {
    fn poll(&mut self, reader: &mut impl Read) -> io::Result<Option<Vec<u8>>> {
        loop {
            if self.header_read < self.header.len() {
                match reader.read(&mut self.header[self.header_read..]) {
                    Ok(0) => return Err(io::ErrorKind::UnexpectedEof.into()),
                    Ok(read) => self.header_read += read,
                    Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
                    Err(e) if is_nonblocking_idle(&e) => return Ok(None),
                    Err(e) => return Err(e),
                }
                if self.header_read < self.header.len() {
                    continue;
                }

                let len = u32::from_le_bytes(self.header) as usize;
                validate_frame_len(len)?;
                if len == 0 {
                    self.reset();
                    return Ok(Some(Vec::new()));
                }
                self.payload = vec![0; len];
            }

            match reader.read(&mut self.payload[self.payload_read..]) {
                Ok(0) => return Err(io::ErrorKind::UnexpectedEof.into()),
                Ok(read) => self.payload_read += read,
                Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
                Err(e) if is_nonblocking_idle(&e) => return Ok(None),
                Err(e) => return Err(e),
            }
            if self.payload_read == self.payload.len() {
                let payload = std::mem::take(&mut self.payload);
                self.reset();
                return Ok(Some(payload));
            }
        }
    }

    fn reset(&mut self) {
        self.header = [0; 4];
        self.header_read = 0;
        self.payload.clear();
        self.payload_read = 0;
    }
}

fn report_error(sink: &StreamSink<Vec<u8>, SseCodec>, message: impl AsRef<str>) {
    let _ = sink.add(make_frame(TYPE_ERROR, message.as_ref().as_bytes()));
}

fn finish_server(name: &str, generation: u64) {
    if !is_current_gen(generation) {
        return;
    }
    RUNNING.store(false, Ordering::SeqCst);
    CONNECTED.store(false, Ordering::SeqCst);
    if let Ok(mut state) = STATE.lock() {
        state.tx = None;
    }
    if let Err(e) = cleanup_socket(name) {
        ipc_debug!("[IPC] cleanup socket failed: {e}");
    }
}

fn io_loop(name: String, sink: StreamSink<Vec<u8>, SseCodec>, generation: u64) {
    ipc_debug!("[IPC] io_loop[{generation}]: started");

    let fs_name = match name.clone().to_fs_name::<GenericFilePath>() {
        Ok(name) => name,
        Err(e) => {
            report_error(&sink, format!("name error: {e}"));
            finish_server(&name, generation);
            return;
        }
    };

    let listener = match ListenerOptions::new().name(fs_name).create_sync() {
        Ok(listener) => listener,
        Err(e) => {
            report_error(&sink, format!("bind error: {e}"));
            finish_server(&name, generation);
            return;
        }
    };

    if let Err(e) = secure_socket_permissions(&name) {
        report_error(&sink, format!("listener permissions error: {e}"));
        finish_server(&name, generation);
        return;
    }

    if let Err(e) = listener.set_nonblocking(ListenerNonblockingMode::Accept) {
        report_error(&sink, format!("listener nonblocking error: {e}"));
        finish_server(&name, generation);
        return;
    }

    if sink.add(make_frame(TYPE_READY, &[])).is_err() {
        finish_server(&name, generation);
        return;
    }

    while server_active(generation) {
        let stream = match listener.accept() {
            Ok(stream) => stream,
            Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                thread::sleep(ACCEPT_POLL_INTERVAL);
                continue;
            }
            Err(e) => {
                if server_active(generation) {
                    report_error(&sink, format!("accept error: {e}"));
                }
                break;
            }
        };

        if let Err(e) = wait_for_authorized_peer(&stream, generation) {
            if e.kind() != io::ErrorKind::Interrupted && server_active(generation) {
                ipc_debug!("[IPC] rejected unauthorized peer: {e}");
            }
            continue;
        }

        // Unix streams use nonblocking reads directly. On Windows, `Accept` mode
        // deliberately restores an accepted named pipe to blocking mode. Keep it
        // that way and poll with PeekNamedPipe before reading: mixing PIPE_NOWAIT
        // with interprocess' overlapped synchronous I/O turns an idle connection
        // into ERROR_NO_DATA/zero-byte reads and can prevent the connection from
        // ever reaching the connected state.
        #[cfg(not(windows))]
        if let Err(e) = stream.set_nonblocking(true) {
            report_error(&sink, format!("stream nonblocking error: {e}"));
            continue;
        }

        let (tx, rx) = mpsc::sync_channel::<Vec<u8>>(MAX_PENDING_MESSAGES);
        match STATE.lock() {
            Ok(mut state) if server_active(generation) => state.tx = Some(tx),
            Ok(_) => break,
            Err(e) => {
                report_error(&sink, format!("state lock error: {e}"));
                break;
            }
        }

        CONNECTED.store(true, Ordering::SeqCst);
        if sink.add(make_frame(TYPE_CONNECTED, &[])).is_err() {
            CONNECTED.store(false, Ordering::SeqCst);
            break;
        }

        let (receiver, sender) = stream.split();
        #[cfg(windows)]
        let mut receiver = match receiver {
            interprocess::local_socket::RecvHalf::NamedPipe(receiver) => {
                WindowsPipeReader(receiver)
            }
        };
        #[cfg(not(windows))]
        let mut receiver = receiver;
        let mut sender = sender;
        let connection_running = Arc::new(AtomicBool::new(true));
        let writer_running = Arc::clone(&connection_running);
        let (error_tx, error_rx) = mpsc::channel::<String>();

        let writer = thread::spawn(move || {
            while writer_running.load(Ordering::SeqCst) && server_active(generation) {
                match rx.recv_timeout(IO_POLL_INTERVAL) {
                    Ok(data) => {
                        if let Err(e) = write_frame(&mut sender, &data, &writer_running, generation)
                        {
                            if e.kind() != io::ErrorKind::Interrupted {
                                let _ = error_tx.send(format!("write error: {e}"));
                            }
                            break;
                        }
                    }
                    Err(mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(mpsc::RecvTimeoutError::Disconnected) => break,
                }
            }
            writer_running.store(false, Ordering::SeqCst);
            CONNECTED.store(false, Ordering::SeqCst);
        });

        let mut frame_reader = FrameReader::default();
        while connection_running.load(Ordering::SeqCst) && server_active(generation) {
            match frame_reader.poll(&mut receiver) {
                Ok(Some(data)) => {
                    if sink.add(make_frame(TYPE_DATA, &data)).is_err() {
                        break;
                    }
                }
                Ok(None) => thread::sleep(IO_POLL_INTERVAL),
                Err(e) => {
                    ipc_debug!(
                        "[IPC] read error: kind={:?}, raw={:?}, error={e}",
                        e.kind(),
                        e.raw_os_error()
                    );
                    if !matches!(
                        e.kind(),
                        io::ErrorKind::UnexpectedEof
                            | io::ErrorKind::ConnectionReset
                            | io::ErrorKind::BrokenPipe
                    ) && server_active(generation)
                    {
                        report_error(&sink, format!("read error: {e}"));
                    }
                    break;
                }
            }
        }

        connection_running.store(false, Ordering::SeqCst);
        CONNECTED.store(false, Ordering::SeqCst);
        if let Ok(mut state) = STATE.lock() {
            state.tx = None;
        }
        let _ = writer.join();

        if let Ok(message) = error_rx.try_recv() {
            report_error(&sink, message);
        }
        if server_active(generation) && sink.add(make_frame(TYPE_DISCONNECTED, &[])).is_err() {
            break;
        }
    }

    finish_server(&name, generation);
    ipc_debug!("[IPC] io_loop[{generation}]: stopped");
}

#[cfg(test)]
mod frame_tests {
    use super::*;
    use std::collections::VecDeque;
    use std::io::Cursor;

    enum ReadStep {
        Data(Vec<u8>),
        WouldBlock,
    }

    struct StepReader {
        steps: VecDeque<ReadStep>,
    }

    impl Read for StepReader {
        fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
            match self.steps.pop_front() {
                Some(ReadStep::Data(mut data)) => {
                    let read = data.len().min(buffer.len());
                    buffer[..read].copy_from_slice(&data[..read]);
                    if read < data.len() {
                        data.drain(..read);
                        self.steps.push_front(ReadStep::Data(data));
                    }
                    Ok(read)
                }
                Some(ReadStep::WouldBlock) => Err(io::ErrorKind::WouldBlock.into()),
                None => Ok(0),
            }
        }
    }

    #[test]
    fn frame_reader_reads_complete_frame() {
        let payload = b"hello";
        let mut bytes = (payload.len() as u32).to_le_bytes().to_vec();
        bytes.extend_from_slice(payload);
        let mut reader = Cursor::new(bytes);
        let mut frame_reader = FrameReader::default();

        assert_eq!(
            frame_reader.poll(&mut reader).unwrap(),
            Some(payload.to_vec())
        );
    }

    #[test]
    fn frame_reader_preserves_partial_nonblocking_reads() {
        let mut reader = StepReader {
            steps: VecDeque::from([
                ReadStep::Data(vec![5, 0]),
                ReadStep::WouldBlock,
                ReadStep::Data(vec![0, 0]),
                ReadStep::Data(b"he".to_vec()),
                ReadStep::WouldBlock,
                ReadStep::Data(b"llo".to_vec()),
            ]),
        };
        let mut frame_reader = FrameReader::default();

        assert_eq!(frame_reader.poll(&mut reader).unwrap(), None);
        assert_eq!(frame_reader.poll(&mut reader).unwrap(), None);
        assert_eq!(
            frame_reader.poll(&mut reader).unwrap(),
            Some(b"hello".to_vec())
        );
    }

    #[test]
    fn available_read_len_reports_idle_without_reading() {
        let error = available_read_len(1024, 0).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::WouldBlock);
    }

    #[test]
    fn available_read_len_limits_blocking_read_to_available_bytes() {
        assert_eq!(available_read_len(1024, 7).unwrap(), 7);
        assert_eq!(available_read_len(4, 7).unwrap(), 4);
        assert_eq!(available_read_len(0, 0).unwrap(), 0);
    }

    #[test]
    fn frame_reader_rejects_oversized_frame_before_allocation() {
        let len = (MAX_FRAME_SIZE as u32 + 1).to_le_bytes();
        let mut reader = Cursor::new(len);
        let mut frame_reader = FrameReader::default();

        assert_eq!(
            frame_reader.poll(&mut reader).unwrap_err().kind(),
            io::ErrorKind::InvalidData
        );
        assert!(frame_reader.payload.is_empty());
    }
}

#[cfg(test)]
mod lifecycle_tests {
    use super::*;

    #[test]
    fn stopping_an_already_stopped_server_succeeds() {
        RUNNING.store(false, Ordering::SeqCst);
        CONNECTED.store(true, Ordering::SeqCst);

        assert_eq!(stop_ipc_server(), Ok(()));
        assert!(!CONNECTED.load(Ordering::SeqCst));
    }

    #[test]
    fn peer_identity_requires_expected_process_and_authorized_user() {
        let identity = PeerIdentity {
            pid: 1234,
            euid: 501,
        };

        assert!(validate_peer_identity(&identity, 1234, 501).is_ok());
        assert_eq!(
            validate_peer_identity(&identity, 4321, 501)
                .unwrap_err()
                .kind(),
            io::ErrorKind::PermissionDenied,
        );
        assert_eq!(
            validate_peer_identity(&identity, 1234, 502)
                .unwrap_err()
                .kind(),
            io::ErrorKind::PermissionDenied,
        );
    }

    #[test]
    fn peer_identity_allows_spawned_setuid_root_core() {
        let identity = PeerIdentity { pid: 1234, euid: 0 };

        assert!(validate_peer_identity(&identity, 1234, 501).is_ok());
        assert_eq!(
            validate_peer_identity(&identity, 4321, 501)
                .unwrap_err()
                .kind(),
            io::ErrorKind::PermissionDenied,
        );
    }

    #[test]
    fn peer_pid_must_match_the_spawned_core() {
        assert!(validate_peer_pid(42, 42).is_ok());
        assert_eq!(
            validate_peer_pid(7, 42).unwrap_err().kind(),
            io::ErrorKind::PermissionDenied,
        );
    }
}

#[cfg(all(test, unix))]
mod unix_security_tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn test_socket_path() -> String {
        let token = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
            ^ u128::from(std::process::id());
        let token_hex = format!("{token:032x}");
        let runtime_token = format!("{}A", &token_hex[..21]);
        format!("/tmp/flclash-{runtime_token}/ipc-AAAAAAAAAAAAAAAAAAAAAA.sock")
    }

    #[test]
    fn private_runtime_directory_has_expected_permissions() {
        let socket_path = test_socket_path();
        prepare_socket(&socket_path).unwrap();
        let runtime_dir = unix_runtime_dir(Path::new(&socket_path)).unwrap();
        let runtime_metadata = std::fs::symlink_metadata(runtime_dir).unwrap();

        assert!(runtime_metadata.file_type().is_dir());
        assert_eq!(runtime_metadata.uid(), unsafe { libc::geteuid() });
        assert_eq!(runtime_metadata.mode() & 0o777, 0o700);

        let fs_name = socket_path.clone().to_fs_name::<GenericFilePath>().unwrap();
        let listener = ListenerOptions::new().name(fs_name).create_sync().unwrap();
        secure_socket_permissions(&socket_path).unwrap();
        let socket_metadata = std::fs::symlink_metadata(&socket_path).unwrap();

        assert!(socket_metadata.file_type().is_socket());
        assert_eq!(socket_metadata.uid(), unsafe { libc::geteuid() });
        assert_eq!(socket_metadata.mode() & 0o777, 0o600);

        drop(listener);
        cleanup_socket(&socket_path).unwrap();
    }

    #[test]
    fn kernel_reports_current_process_as_unix_peer() {
        let socket_path = test_socket_path();
        prepare_socket(&socket_path).unwrap();
        let fs_name = socket_path.clone().to_fs_name::<GenericFilePath>().unwrap();
        let listener = ListenerOptions::new()
            .name(fs_name.clone())
            .create_sync()
            .unwrap();
        secure_socket_permissions(&socket_path).unwrap();

        let client = LocalSocketStream::connect(fs_name).unwrap();
        let server = listener.accept().unwrap();
        let identity = peer_identity(&server).unwrap();

        assert_eq!(identity.pid, u64::from(std::process::id()));
        assert_eq!(identity.euid, unsafe { libc::geteuid() });

        drop(client);
        drop(server);
        drop(listener);
        cleanup_socket(&socket_path).unwrap();
    }

    #[test]
    fn rejects_unmanaged_socket_path() {
        assert!(prepare_socket("/tmp/flclash.sock").is_err());
    }

    #[test]
    fn validates_canonical_128_bit_base64_url_tokens() {
        assert!(has_secure_token_name(
            "ipc-AAAAAAAAAAAAAAAAAAAAAA.sock",
            UNIX_SOCKET_PREFIX,
            UNIX_SOCKET_SUFFIX,
        ));
        assert!(!has_secure_token_name(
            "ipc-00000000000000000000000000000000.sock",
            UNIX_SOCKET_PREFIX,
            UNIX_SOCKET_SUFFIX,
        ));
        assert!(!has_secure_token_name(
            "ipc-AAAAAAAAAAAAAAAAAAAAAB.sock",
            UNIX_SOCKET_PREFIX,
            UNIX_SOCKET_SUFFIX,
        ));
    }
}
