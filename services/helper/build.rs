fn main() {
    let token = std::env::var("TOKEN").unwrap_or_default();
    let core_name = std::env::var("CORE_NAME").unwrap_or_else(|_| "FlClashCore.exe".to_string());
    println!("cargo:rustc-env=TOKEN={}", token);
    println!("cargo:rustc-env=CORE_NAME={}", core_name);
    println!("cargo:rerun-if-env-changed=TOKEN");
    println!("cargo:rerun-if-env-changed=CORE_NAME");
}
