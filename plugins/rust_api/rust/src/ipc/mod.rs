#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod frame;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod platform;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod queue;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod server;
#[cfg(any(target_os = "android", target_os = "ios"))]
mod unsupported;

#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub use server::{restart_server, send_message, stop_server};
#[cfg(any(target_os = "android", target_os = "ios"))]
pub use unsupported::{restart_server, send_message, stop_server};
