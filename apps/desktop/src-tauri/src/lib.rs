//! Tauri desktop backend and command boundary.

pub mod backend;
pub mod bootstrap;
pub mod commands;
pub mod keychain;
pub mod protocol;
pub mod ssh;
pub mod state;
pub mod tunnel;

pub use backend::{Backend, BackendError};
pub use commands::{
    bootstrap_plan, connect_remote_workspace, parse_protocol_frame, safe_default_config,
    tunnel_plan,
};
pub use state::BackendState;

#[tauri::command]
fn safe_default_config_json(config_dir: String) -> Result<String, String> {
    let config = safe_default_config(config_dir.into())?;
    serde_json::to_string(&config).map_err(|err| err.to_string())
}

#[tauri::command]
fn parse_protocol_frame_json(json: String) -> Result<String, String> {
    let frame = parse_protocol_frame(&json)?;
    serde_json::to_string(&frame).map_err(|err| err.to_string())
}

#[tauri::command]
fn app_health() -> &'static str {
    "ok"
}

#[tauri::command]
fn connect_remote_workspace_json(payload: String) -> Result<String, String> {
    commands::connect_remote_workspace_json(&payload)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            app_health,
            connect_remote_workspace_json,
            parse_protocol_frame_json,
            safe_default_config_json
        ])
        .run(tauri::generate_context!())
        .expect("failed to run sterm Tauri application");
}
