use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::fs::File;
use std::io::{BufRead, Error, Read};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::{io, thread};
use warp::http::StatusCode;
use warp::reject::Reject;
use warp::{Filter, Rejection, Reply};

const LISTEN_PORT: u16 = 47890;
const CORE_PIPE_NAME: &str = r"\\.\pipe\FlClashCore";
const ACCESS_TOKEN_HEADER: &str = "x-flclash-token";
const DEBUG_ACCESS_TOKEN: &str = "flclash-debug";

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct StartParams {
    pub path: String,
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

fn sha256_file(path: &str) -> Result<String, Error> {
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

static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
    Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(100))));
static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

fn start(start_params: StartParams) -> impl Reply {
    if !cfg!(debug_assertions) {
        let sha256 = sha256_file(start_params.path.as_str()).unwrap_or("".to_string());
        if sha256 != env!("TOKEN") {
            return format!("The SHA256 hash of the program requesting execution is: {}. The helper program only allows execution of applications with the SHA256 hash: {}.", sha256,  env!("TOKEN"),);
        }
    }
    stop();
    let mut process = PROCESS.lock().unwrap();
    match Command::new(&start_params.path)
        .stderr(Stdio::piped())
        .arg(CORE_PIPE_NAME)
        .spawn()
    {
        Ok(child) => {
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
            "".to_string()
        }
        Err(e) => {
            log_message(e.to_string());
            e.to_string()
        }
    }
}

fn stop() -> impl Reply {
    let mut process = PROCESS.lock().unwrap();
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    *process = None;
    "".to_string()
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
    warp::reply::with_header(value, "Content-Type", "text/plain")
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
    let auth = authenticated();

    let api_ping = warp::get()
        .and(warp::path("ping"))
        .and(warp::path::end())
        .and(auth.clone())
        .map(|()| "");

    let api_start = warp::post()
        .and(warp::path("start"))
        .and(warp::path::end())
        .and(auth.clone())
        .and(warp::body::json())
        .map(|(), start_params: StartParams| start(start_params));

    let api_stop = warp::post()
        .and(warp::path("stop"))
        .and(warp::path::end())
        .and(auth.clone())
        .map(|()| stop());

    let api_logs = warp::get()
        .and(warp::path("logs"))
        .and(warp::path::end())
        .and(auth)
        .map(|()| get_logs());

    api_ping
        .or(api_start)
        .or(api_stop)
        .or(api_logs)
        .recover(handle_rejection)
}

pub async fn run_service() -> anyhow::Result<()> {
    if !cfg!(debug_assertions) && access_token().is_empty() {
        anyhow::bail!("helper access token is empty");
    }

    warp::serve(routes())
        .run(([127, 0, 0, 1], LISTEN_PORT))
        .await;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn helper_routes_require_access_token() {
        let response = warp::test::request()
            .method("GET")
            .path("/ping")
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn ping_accepts_access_token_without_exposing_it() {
        let response = warp::test::request()
            .method("GET")
            .path("/ping")
            .header(ACCESS_TOKEN_HEADER, access_token())
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::OK);
        assert!(response.body().is_empty());
    }

    #[tokio::test]
    async fn start_rejects_a_caller_supplied_core_argument() {
        let response = warp::test::request()
            .method("POST")
            .path("/start")
            .header(ACCESS_TOKEN_HEADER, access_token())
            .header("content-type", "application/json")
            .body(r#"{"path":"FlClashCore.exe","arg":"attacker-pipe"}"#)
            .reply(&routes())
            .await;

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[test]
    fn core_pipe_name_is_fixed() {
        assert_eq!(CORE_PIPE_NAME, r"\\.\pipe\FlClashCore");
    }
}
