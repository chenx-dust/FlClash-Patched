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
use std::time::Duration;

#[cfg(unix)]
use std::path::Path;

macro_rules! ipc_debug {
    ($($arg:tt)*) => {
        #[cfg(debug_assertions)]
        eprintln!($($arg)*);
    };
}

static RUNNING: AtomicBool = AtomicBool::new(false);
static CONNECTED: AtomicBool = AtomicBool::new(false);
static GENERATION: AtomicU64 = AtomicU64::new(0);
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

fn make_frame(ty: u8, payload: &[u8]) -> Vec<u8> {
    let mut frame = Vec::with_capacity(1 + payload.len());
    frame.push(ty);
    frame.extend_from_slice(payload);
    frame
}

fn cleanup_socket(path: &str) -> io::Result<()> {
    #[cfg(unix)]
    {
        if Path::new(path).exists() {
            std::fs::remove_file(path)?;
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
    join_server(take_server_handle()?)
}

#[frb]
pub fn restart_ipc_server(name: String, sink: StreamSink<Vec<u8>, SseCodec>) -> Result<(), String> {
    let _lifecycle = LIFECYCLE
        .lock()
        .map_err(|e| format!("Lifecycle lock poisoned: {e}"))?;
    let generation = GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    ipc_debug!("[IPC] restart_ipc_server: gen={generation}, name={name}");

    stop_server_thread()?;
    cleanup_socket(&name).map_err(|e| format!("Failed to remove stale socket: {e}"))?;

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
                    Err(e) if e.kind() == io::ErrorKind::WouldBlock => return Ok(None),
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
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => return Ok(None),
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

        let (mut receiver, mut sender) = stream.split();
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
mod tests {
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
mod tests {
    use super::*;

    #[test]
    fn stopping_an_already_stopped_server_succeeds() {
        RUNNING.store(false, Ordering::SeqCst);
        CONNECTED.store(true, Ordering::SeqCst);

        assert_eq!(stop_ipc_server(), Ok(()));
        assert!(!CONNECTED.load(Ordering::SeqCst));
    }
}
