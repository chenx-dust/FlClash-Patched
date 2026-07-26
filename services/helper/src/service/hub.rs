use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::fs::{File, OpenOptions};
#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
use std::future::pending;
use std::future::Future;
use std::io::{BufRead, Error, Read};
#[cfg(windows)]
use std::os::windows::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::{io, thread};
use warp::http::StatusCode;
use warp::reject::Reject;
use warp::{Filter, Rejection, Reply};
#[cfg(windows)]
use windows_sys::Win32::Storage::FileSystem::FILE_SHARE_READ;

const LISTEN_PORT: u16 = 47890;
const CORE_PIPE_PREFIX: &str = r"\\.\pipe\FlClashCore_";
const ACCESS_TOKEN_HEADER: &str = "x-flclash-token";
const DEBUG_ACCESS_TOKEN: &str = "flclash-debug";
const PROTOCOL_VERSION_HEADER: &str = "x-flclash-helper-protocol";
const PROTOCOL_VERSION: &str = "3";

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct StartParams {
    pub address: String,
}

fn access_token() -> &'static str {
    if cfg!(debug_assertions) {
        DEBUG_ACCESS_TOKEN
    } else {
        env!("TOKEN")
    }
}

#[derive(Debug)]
struct Unauthorized;

impl Reject for Unauthorized {}

fn core_path() -> Result<PathBuf, Error> {
    let helper_path = std::env::current_exe()?;
    let directory = helper_path
        .parent()
        .ok_or_else(|| Error::other("helper executable has no parent directory"))?;
    Ok(directory.join(env!("CORE_NAME")))
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

fn is_allowed_core_pipe(address: &str) -> bool {
    let Some(suffix) = address.strip_prefix(CORE_PIPE_PREFIX) else {
        return false;
    };
    suffix.len() == 32 && suffix.bytes().all(|value| value.is_ascii_hexdigit())
}

static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
    Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(100))));
static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

fn start(start_params: StartParams) -> impl Reply {
    if cfg!(debug_assertions) {
        return "privileged Core startup is disabled in debug builds".to_string();
    }
    if !is_allowed_core_pipe(&start_params.address) {
        return "invalid Core pipe address".to_string();
    }

    let core_path = match core_path() {
        Ok(path) => path,
        Err(error) => return error.to_string(),
    };
    let mut core_file = match open_core(&core_path) {
        Ok(file) => file,
        Err(error) => return error.to_string(),
    };
    let sha256 = match sha256_file(&mut core_file) {
        Ok(sha256) => sha256,
        Err(error) => return error.to_string(),
    };
    if sha256 != access_token() {
        return "Core executable SHA256 mismatch".to_string();
    }

    stop_core();
    let mut process = PROCESS.lock().unwrap();
    match Command::new(&core_path)
        .current_dir(core_path.parent().unwrap())
        .stderr(Stdio::piped())
        .arg(&start_params.address)
        .spawn()
    {
        Ok(child) => {
            let process_id = child.id();
            *process = Some(child);
            if let Some(ref mut child) = *process {
                let stderr = child.stderr.take().unwrap();
                let reader = io::BufReader::new(stderr);
                thread::spawn(move || {
                    for line in reader.lines() {
                        match line {
                            Ok(output) => {
                                log_message(output);
                            }
                            Err(_) => {
                                break;
                            }
                        }
                    }
                });
            }
            process_id.to_string()
        }
        Err(e) => {
            log_message(e.to_string());
            e.to_string()
        }
    }
}

fn stop_core() -> String {
    let mut process = PROCESS.lock().unwrap();
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    *process = None;
    String::new()
}

fn log_message(message: String) {
    let mut log_buffer = LOGS.lock().unwrap();
    if log_buffer.len() == 100 {
        log_buffer.pop_front();
    }
    log_buffer.push_back(format!("{}\n", message));
}

fn get_logs() -> impl Reply {
    let log_buffer = LOGS.lock().unwrap();
    let value = log_buffer
        .iter()
        .cloned()
        .collect::<Vec<String>>()
        .join("\n");
    warp::reply::with_header(
        warp::reply::with_header(value, "Content-Type", "text/plain; charset=utf-8"),
        "Cache-Control",
        "no-store",
    )
}

fn authenticated() -> impl Filter<Extract = ((),), Error = Rejection> + Clone {
    warp::header::optional::<String>(ACCESS_TOKEN_HEADER).and_then(
        |token: Option<String>| async move {
            if token.as_deref() == Some(access_token()) {
                Ok(())
            } else {
                Err(warp::reject::custom(Unauthorized))
            }
        },
    )
}

async fn handle_rejection(rejection: Rejection) -> Result<impl Reply, Rejection> {
    if rejection.find::<Unauthorized>().is_none() {
        return Err(rejection);
    }
    Ok(warp::reply::with_status("", StatusCode::UNAUTHORIZED))
}

fn routes() -> impl Filter<Extract = (impl Reply,), Error = Rejection> + Clone {
    let api_ping = warp::get()
        .and(warp::path("ping"))
        .and(warp::path::end())
        .and(authenticated())
        .map(|()| {
            let path = std::env::current_exe()
                .map(|path| path.to_string_lossy().into_owned())
                .unwrap_or_default();
            warp::reply::with_header(path, PROTOCOL_VERSION_HEADER, PROTOCOL_VERSION)
        });

    let api_start = warp::post()
        .and(warp::path("start"))
        .and(warp::path::end())
        .and(warp::body::json())
        .map(start);

    let api_stop = warp::post()
        .and(warp::path("stop"))
        .and(warp::path::end())
        .map(stop_core);

    let api_logs = warp::get()
        .and(warp::path("logs"))
        .and(warp::path::end())
        .map(get_logs);

    api_ping
        .or(api_start)
        .or(api_stop)
        .or(api_logs)
        .recover(handle_rejection)
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
pub async fn run_service() -> anyhow::Result<()> {
    run_service_until(pending(), || Ok(())).await
}

pub(super) async fn run_service_until<F, S>(shutdown: F, on_started: S) -> anyhow::Result<()>
where
    F: Future<Output = ()> + Send + 'static,
    S: FnOnce() -> anyhow::Result<()>,
{
    if !cfg!(debug_assertions) && access_token().is_empty() {
        anyhow::bail!("helper access token is empty");
    }

    let (_, server) = warp::serve(routes())
        .try_bind_with_graceful_shutdown(([127, 0, 0, 1], LISTEN_PORT), shutdown)
        .map_err(|error| anyhow::anyhow!("bind helper server: {error}"))?;
    on_started()?;
    server.await;
    stop_core();

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn ping_requires_access_token() {
        let response = warp::test::request()
            .method("GET")
            .path("/ping")
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn logs_are_available_without_access_token() {
        let response = warp::test::request()
            .method("GET")
            .path("/logs")
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response.headers().get("content-type").unwrap(),
            "text/plain; charset=utf-8"
        );
        assert_eq!(response.headers().get("cache-control").unwrap(), "no-store");
    }

    #[tokio::test]
    async fn ping_returns_the_running_helper_path() {
        let response = warp::test::request()
            .method("GET")
            .path("/ping")
            .header(ACCESS_TOKEN_HEADER, access_token())
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response.headers().get(PROTOCOL_VERSION_HEADER).unwrap(),
            PROTOCOL_VERSION
        );
        assert_eq!(
            response.body(),
            std::env::current_exe()
                .unwrap()
                .to_string_lossy()
                .as_bytes()
        );
    }

    #[tokio::test]
    async fn start_rejects_a_caller_supplied_core_argument() {
        let response = warp::test::request()
            .method("POST")
            .path("/start")
            .header("content-type", "application/json")
            .body(
                r#"{"address":"\\\\.\\pipe\\FlClashCore_0123456789abcdef0123456789abcdef","path":"attacker.exe"}"#,
            )
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn debug_build_refuses_privileged_core_startup() {
        let response = warp::test::request()
            .method("POST")
            .path("/start")
            .header("content-type", "application/json")
            .body(r#"{"address":"\\\\.\\pipe\\FlClashCore_0123456789abcdef0123456789abcdef"}"#)
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response.body(),
            "privileged Core startup is disabled in debug builds"
        );
    }

    #[tokio::test]
    async fn stop_is_available_without_access_token() {
        let response = warp::test::request()
            .method("POST")
            .path("/stop")
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::OK);
    }

    #[test]
    fn core_path_is_fixed_beside_the_helper() {
        assert_eq!(
            core_path().unwrap().file_name().unwrap(),
            std::ffi::OsStr::new(env!("CORE_NAME"))
        );
    }

    #[test]
    fn only_accepts_random_core_pipe_namespace() {
        assert!(is_allowed_core_pipe(
            r"\\.\pipe\FlClashCore_0123456789abcdef0123456789abcdef"
        ));
        assert!(!is_allowed_core_pipe(r"\\.\pipe\FlClashCore"));
        assert!(!is_allowed_core_pipe(
            r"\\.\pipe\Other_0123456789abcdef0123456789abcdef"
        ));
        assert!(!is_allowed_core_pipe(
            r"\\.\pipe\FlClashCore_0123456789abcdef"
        ));
        assert!(!is_allowed_core_pipe(
            r"\\.\pipe\FlClashCore_0123456789abcdef0123456789abcdeg"
        ));
    }
}
