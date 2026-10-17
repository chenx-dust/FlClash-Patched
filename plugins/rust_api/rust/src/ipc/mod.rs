#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod access;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod frame;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod outbox;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod server;
#[cfg(any(target_os = "android", target_os = "ios"))]
mod unsupported;

#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub use server::Server;
#[cfg(any(target_os = "android", target_os = "ios"))]
pub use unsupported::Server;

#[cfg_attr(any(target_os = "android", target_os = "ios"), allow(dead_code))]
#[derive(Debug, PartialEq, Eq)]
pub enum Event {
    Connected { pid: Option<u32> },
    Message(Vec<u8>),
    Disconnected { error: Option<String> },
    Failed(String),
}

/// Returns false once nobody listens any more, which ends the server.
pub type EventSink = Box<dyn Fn(Event) -> bool + Send>;
