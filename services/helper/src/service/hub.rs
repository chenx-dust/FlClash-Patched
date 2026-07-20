use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::fs::File;
use std::io::{BufRead, Error, Read};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::{io, thread};
use warp::{Filter, Reply};

const LISTEN_PORT: u16 = 47890;
const CORE_EXECUTABLE_NAME: &str = match option_env!("CORE_EXECUTABLE_NAME") {
    Some(name) => name,
    None => "FlClashCore.exe",
};

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct StartParams {
    pub arg: String,
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

static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
    Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(100))));
static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

fn start(start_params: StartParams) -> impl Reply {
    let core_path = match core_path() {
        Ok(path) => path,
        Err(error) => return error.to_string(),
    };
    if !cfg!(debug_assertions) {
        let sha256 = sha256_file(&core_path).unwrap_or_default();
        if sha256 != env!("TOKEN") {
            return format!("The SHA256 hash of the program requesting execution is: {}. The helper program only allows execution of applications with the SHA256 hash: {}.", sha256,  env!("TOKEN"),);
        }
    }
    stop();
    let mut process = PROCESS.lock().unwrap();
    match Command::new(&core_path)
        .stderr(Stdio::piped())
        .arg(&start_params.arg)
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

pub async fn run_service() -> anyhow::Result<()> {
    let api_ping = warp::get().and(warp::path("ping")).map(|| env!("TOKEN"));

    let api_start = warp::post()
        .and(warp::path("start"))
        .and(warp::body::json())
        .map(|start_params: StartParams| start(start_params));

    let api_stop = warp::post().and(warp::path("stop")).map(stop);

    let api_logs = warp::get().and(warp::path("logs")).map(get_logs);

    warp::serve(api_ping.or(api_start).or(api_stop).or(api_logs))
        .run(([127, 0, 0, 1], LISTEN_PORT))
        .await;

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
    fn start_params_reject_path_field() {
        let params = r#"{"path":"C:\\attacker.exe","arg":"pipe"}"#;

        assert!(serde_json::from_str::<StartParams>(params).is_err());
    }
}
