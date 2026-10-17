#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod keys;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod owner;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod service;
#[cfg(any(target_os = "android", target_os = "ios"))]
mod unsupported;

#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub use service::{listen, set_hot_keys};
#[cfg(any(target_os = "android", target_os = "ios"))]
pub use unsupported::{listen, set_hot_keys};
