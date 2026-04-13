use anyhow::{Context, Result, anyhow};
use chrono::{SecondsFormat, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SessionMode {
    St,
    Rst,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum StreamingStatus {
    Idle,
    Receiving,
    Error,
}

impl Default for StreamingStatus {
    fn default() -> Self {
        Self::Idle
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum MessageRole {
    System,
    User,
    Assistant,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum MessageStatus {
    Pending,
    Streaming,
    Completed,
    Error,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum RequestLogStatus {
    Success,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSummary {
    pub session_id: String,
    pub session_name: String,
    pub mode: SessionMode,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateSessionRequest {
    pub session_name: String,
    pub mode: SessionMode,
    pub main_api_config_id: String,
    pub preset_id: String,
    pub st_world_book_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionConfig {
    pub session_id: String,
    pub session_name: String,
    pub mode: SessionMode,
    pub main_api_config_id: String,
    pub preset_id: String,
    pub st_world_book_id: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionRuntimeState {
    pub session_id: String,
    #[serde(default)]
    pub active_message_id: Option<String>,
    #[serde(default)]
    pub streaming_status: StreamingStatus,
    #[serde(default)]
    pub last_error: Option<String>,
    #[serde(default)]
    pub last_prompt_token_estimate: Option<i64>,
    #[serde(default)]
    pub last_completion_token_estimate: Option<i64>,
    #[serde(default)]
    pub last_used_model: Option<String>,
    #[serde(default)]
    pub last_request_started_at: Option<String>,
    #[serde(default)]
    pub last_request_finished_at: Option<String>,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoadSessionResult {
    pub config: SessionConfig,
    pub runtime: SessionRuntimeState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteResult {
    pub deleted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MessageRecord {
    pub message_id: String,
    pub session_id: String,
    pub role: MessageRole,
    #[serde(default)]
    pub floor_no: Option<i64>,
    pub content: String,
    pub visible: bool,
    pub status: MessageStatus,
    pub error_message: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateMessageRequest {
    pub session_id: String,
    pub role: MessageRole,
    pub content: String,
    pub visible: bool,
    pub status: MessageStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteMessagesResult {
    pub deleted_message_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RequestLog {
    pub log_id: String,
    pub session_id: String,
    pub provider: String,
    pub model: String,
    pub status: RequestLogStatus,
    pub request_time: String,
    #[serde(default)]
    pub response_time: Option<String>,
    #[serde(default)]
    pub duration_ms: Option<i64>,
    #[serde(default)]
    pub prompt_tokens: Option<i64>,
    #[serde(default)]
    pub completion_tokens: Option<i64>,
    #[serde(default)]
    pub total_tokens: Option<i64>,
    #[serde(default)]
    pub stop_reason: Option<String>,
    pub redacted: bool,
    pub payload_truncated: bool,
    #[serde(default)]
    pub request_preview_json: Option<String>,
    #[serde(default)]
    pub response_preview_json: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RequestLogSummary {
    pub log_id: String,
    pub session_id: String,
    pub provider: String,
    pub model: String,
    pub status: RequestLogStatus,
    pub request_time: String,
    #[serde(default)]
    pub duration_ms: Option<i64>,
    pub redacted: bool,
    pub payload_truncated: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateRequestLogRequest {
    pub session_id: String,
    pub provider: String,
    pub model: String,
    pub status: RequestLogStatus,
    pub request_time: String,
    #[serde(default)]
    pub response_time: Option<String>,
    #[serde(default)]
    pub duration_ms: Option<i64>,
    #[serde(default)]
    pub prompt_tokens: Option<i64>,
    #[serde(default)]
    pub completion_tokens: Option<i64>,
    #[serde(default)]
    pub total_tokens: Option<i64>,
    #[serde(default)]
    pub stop_reason: Option<String>,
    pub redacted: bool,
    pub payload_truncated: bool,
    #[serde(default)]
    pub request_preview_json: Option<String>,
    #[serde(default)]
    pub response_preview_json: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SessionFile {
    config: SessionConfig,
    runtime: SessionRuntimeState,
    #[serde(default)]
    messages: Vec<MessageRecord>,
}

pub fn list_sessions() -> Result<Vec<SessionSummary>> {
    let mut sessions = Vec::new();
    for path in session_paths()? {
        let file = read_session_file(&path)?;
        sessions.push(SessionSummary {
            session_id: file.config.session_id.clone(),
            session_name: file.config.session_name.clone(),
            mode: file.config.mode,
            updated_at: file.config.updated_at.clone(),
        });
    }

    sessions.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
    Ok(sessions)
}

pub fn create_session(seed: CreateSessionRequest) -> Result<SessionConfig> {
    validate_session_name(&seed.session_name)?;
    validate_mode_binding(seed.mode, seed.st_world_book_id.as_deref())?;

    let now = now_rfc3339();
    let config = SessionConfig {
        session_id: Uuid::new_v4().to_string(),
        session_name: seed.session_name.trim().to_string(),
        mode: seed.mode,
        main_api_config_id: seed.main_api_config_id,
        preset_id: seed.preset_id,
        st_world_book_id: seed.st_world_book_id,
        created_at: now.clone(),
        updated_at: now,
    };

    save_session(config)
}

pub fn save_session(mut config: SessionConfig) -> Result<SessionConfig> {
    if config.session_id.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }
    validate_session_name(&config.session_name)?;
    validate_mode_binding(config.mode, config.st_world_book_id.as_deref())?;

    let path = session_file_path(&config.session_id)?;
    let now = now_rfc3339();

    if path.exists() {
        let mut file = read_session_file(&path)?;
        config.session_name = config.session_name.trim().to_string();
        config.created_at = file.config.created_at.clone();
        config.updated_at = now.clone();

        file.config = config.clone();
        file.runtime.session_id = file.config.session_id.clone();
        file.runtime.updated_at = now;
        write_session_file(&path, &file)?;
        return Ok(file.config);
    }

    config.session_name = config.session_name.trim().to_string();
    if config.created_at.trim().is_empty() {
        config.created_at = now.clone();
    }
    config.updated_at = now.clone();

    let file = SessionFile {
        config: config.clone(),
        runtime: SessionRuntimeState {
            session_id: config.session_id.clone(),
            active_message_id: None,
            streaming_status: StreamingStatus::Idle,
            last_error: None,
            last_prompt_token_estimate: None,
            last_completion_token_estimate: None,
            last_used_model: None,
            last_request_started_at: None,
            last_request_finished_at: None,
            updated_at: now,
        },
        messages: Vec::new(),
    };
    write_session_file(&path, &file)?;
    Ok(config)
}

pub fn rename_session(session_id: String, session_name: String) -> Result<SessionConfig> {
    if session_id.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }
    validate_session_name(&session_name)?;

    let path = session_file_path(&session_id)?;
    if !path.exists() {
        return Err(anyhow!("not_found: session {} does not exist", session_id));
    }

    let mut file = read_session_file(&path)?;
    let now = now_rfc3339();
    file.config.session_name = session_name.trim().to_string();
    file.config.updated_at = now.clone();
    file.runtime.updated_at = now;
    write_session_file(&path, &file)?;
    Ok(file.config)
}

pub fn delete_session(session_id: String) -> Result<DeleteResult> {
    if session_id.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }

    let path = session_file_path(&session_id)?;
    if !path.exists() {
        return Ok(DeleteResult { deleted: false });
    }

    fs::remove_file(&path).with_context(|| format!("failed to delete {}", path.display()))?;
    Ok(DeleteResult { deleted: true })
}

pub fn load_session(session_id: String) -> Result<LoadSessionResult> {
    if session_id.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }

    let path = session_file_path(&session_id)?;
    if !path.exists() {
        return Err(anyhow!("not_found: session {} does not exist", session_id));
    }

    let mut file = read_session_file(&path)?;

    let mut changed = false;
    if reconcile_inflight_state(&mut file) {
        changed = true;
    }
    if reconcile_message_floors(&mut file.messages) {
        changed = true;
    }
    if changed {
        write_session_file(&path, &file)?;
    }

    Ok(LoadSessionResult {
        config: file.config,
        runtime: file.runtime,
    })
}

pub fn create_message(message: CreateMessageRequest) -> Result<MessageRecord> {
    if message.session_id.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }

    let path = session_file_path(&message.session_id)?;
    if !path.exists() {
        return Err(anyhow!(
            "not_found: session {} does not exist",
            message.session_id
        ));
    }

    let mut file = read_session_file(&path)?;
    let _ = reconcile_message_floors(&mut file.messages);
    let now = now_rfc3339();
    let record = MessageRecord {
        message_id: Uuid::new_v4().to_string(),
        session_id: message.session_id,
        role: message.role,
        floor_no: next_floor_no(&file.messages, message.role),
        content: message.content,
        visible: message.visible,
        status: message.status,
        error_message: None,
        created_at: now.clone(),
        updated_at: now.clone(),
    };

    file.messages.push(record.clone());
    apply_status_side_effects(
        &mut file.runtime,
        &record.message_id,
        record.status,
        None,
        &now,
    );
    touch_session(&mut file, &now);
    write_session_file(&path, &file)?;
    Ok(record)
}

pub fn update_message_content(message_id: String, content: String) -> Result<MessageRecord> {
    if message_id.trim().is_empty() {
        return Err(anyhow!("validation_error: messageId cannot be empty"));
    }

    let now = now_rfc3339();
    mutate_message(&message_id, |file, message| {
        message.content = content.clone();
        message.updated_at = now.clone();
        touch_session(file, &now);
        Ok(message.clone())
    })
}

pub fn set_message_status(
    message_id: String,
    status: MessageStatus,
    error_message: Option<String>,
) -> Result<MessageRecord> {
    if message_id.trim().is_empty() {
        return Err(anyhow!("validation_error: messageId cannot be empty"));
    }

    let now = now_rfc3339();
    let normalized_error = error_message
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());

    mutate_message(&message_id, |file, message| {
        message.status = status;
        message.error_message = if status == MessageStatus::Error {
            normalized_error
                .clone()
                .or_else(|| Some("unknown_error".to_string()))
        } else {
            None
        };
        message.updated_at = now.clone();

        apply_status_side_effects(
            &mut file.runtime,
            &message.message_id,
            message.status,
            message.error_message.as_deref(),
            &now,
        );
        touch_session(file, &now);
        Ok(message.clone())
    })
}

pub fn set_message_visibility(message_id: String, visible: bool) -> Result<MessageRecord> {
    if message_id.trim().is_empty() {
        return Err(anyhow!("validation_error: messageId cannot be empty"));
    }

    let now = now_rfc3339();
    mutate_message(&message_id, |file, message| {
        message.visible = visible;
        message.updated_at = now.clone();
        touch_session(file, &now);
        Ok(message.clone())
    })
}

pub fn delete_messages(
    session_id: String,
    message_ids: Vec<String>,
) -> Result<DeleteMessagesResult> {
    if session_id.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }

    let path = session_file_path(&session_id)?;
    if !path.exists() {
        return Err(anyhow!("not_found: session {} does not exist", session_id));
    }

    let id_set: HashSet<String> = message_ids
        .into_iter()
        .map(|id| id.trim().to_string())
        .filter(|id| !id.is_empty())
        .collect();

    if id_set.is_empty() {
        return Ok(DeleteMessagesResult {
            deleted_message_ids: Vec::new(),
        });
    }

    let mut file = read_session_file(&path)?;
    let mut deleted = Vec::new();
    file.messages.retain(|message| {
        if id_set.contains(&message.message_id) {
            deleted.push(message.message_id.clone());
            return false;
        }
        true
    });

    if deleted.is_empty() {
        return Ok(DeleteMessagesResult {
            deleted_message_ids: deleted,
        });
    }
    let _ = reconcile_message_floors(&mut file.messages);

    let now = now_rfc3339();
    if let Some(active_id) = file.runtime.active_message_id.as_ref() {
        if deleted.contains(active_id) {
            file.runtime.active_message_id = None;
            file.runtime.streaming_status = StreamingStatus::Idle;
            file.runtime.last_request_finished_at = Some(now.clone());
        }
    }

    touch_session(&mut file, &now);
    write_session_file(&path, &file)?;

    Ok(DeleteMessagesResult {
        deleted_message_ids: deleted,
    })
}

pub fn list_messages(session_id: String, limit: Option<u32>) -> Result<Vec<MessageRecord>> {
    if session_id.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }

    let path = session_file_path(&session_id)?;
    if !path.exists() {
        return Err(anyhow!("not_found: session {} does not exist", session_id));
    }

    let mut file = read_session_file(&path)?;
    if reconcile_message_floors(&mut file.messages) {
        write_session_file(&path, &file)?;
    }
    let mut messages = file.messages;

    if let Some(limit) = limit {
        if limit == 0 {
            return Ok(Vec::new());
        }
        let limit = limit as usize;
        if messages.len() > limit {
            messages = messages[messages.len() - limit..].to_vec();
        }
    }

    Ok(messages)
}

pub fn create_request_log(seed: CreateRequestLogRequest) -> Result<RequestLog> {
    let session_id = seed.session_id.trim().to_string();
    if session_id.is_empty() {
        return Err(anyhow!("validation_error: sessionId cannot be empty"));
    }

    let provider = seed.provider.trim().to_string();
    if provider.is_empty() {
        return Err(anyhow!("validation_error: provider cannot be empty"));
    }

    let model = seed.model.trim().to_string();
    if model.is_empty() {
        return Err(anyhow!("validation_error: model cannot be empty"));
    }

    let request_time = seed.request_time.trim().to_string();
    if request_time.is_empty() {
        return Err(anyhow!("validation_error: requestTime cannot be empty"));
    }

    let log = RequestLog {
        log_id: Uuid::new_v4().to_string(),
        session_id,
        provider,
        model,
        status: seed.status,
        request_time,
        response_time: normalize_optional(seed.response_time),
        duration_ms: seed.duration_ms,
        prompt_tokens: seed.prompt_tokens,
        completion_tokens: seed.completion_tokens,
        total_tokens: seed.total_tokens,
        stop_reason: normalize_optional(seed.stop_reason),
        redacted: seed.redacted,
        payload_truncated: seed.payload_truncated,
        request_preview_json: normalize_optional(seed.request_preview_json),
        response_preview_json: normalize_optional(seed.response_preview_json),
    };

    let path = request_log_file_path(&log.log_id)?;
    write_request_log_file(&path, &log)?;
    Ok(log)
}

pub fn list_request_logs(
    session_id: Option<String>,
    status: Option<RequestLogStatus>,
    limit: Option<u32>,
) -> Result<Vec<RequestLogSummary>> {
    let session_filter = session_id
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty());

    let mut logs = Vec::new();
    for path in request_log_paths()? {
        let log = read_request_log_file(&path)?;
        if let Some(filter) = session_filter.as_ref() {
            if &log.session_id != filter {
                continue;
            }
        }

        if let Some(expected_status) = status {
            if log.status != expected_status {
                continue;
            }
        }

        logs.push(RequestLogSummary {
            log_id: log.log_id,
            session_id: log.session_id,
            provider: log.provider,
            model: log.model,
            status: log.status,
            request_time: log.request_time,
            duration_ms: log.duration_ms,
            redacted: log.redacted,
            payload_truncated: log.payload_truncated,
        });
    }

    logs.sort_by(|a, b| b.request_time.cmp(&a.request_time));
    if let Some(limit) = limit {
        if limit == 0 {
            return Ok(Vec::new());
        }
        logs.truncate(limit as usize);
    }
    Ok(logs)
}

pub fn get_request_log(log_id: String) -> Result<RequestLog> {
    let normalized = log_id.trim();
    if normalized.is_empty() {
        return Err(anyhow!("validation_error: logId cannot be empty"));
    }

    let path = request_log_file_path(normalized)?;
    if !path.exists() {
        return Err(anyhow!(
            "not_found: request log {} does not exist",
            normalized
        ));
    }

    read_request_log_file(&path)
}

pub fn set_workspace_dir(path: String) -> Result<String> {
    let trimmed = path.trim();
    if trimmed.is_empty() {
        return Err(anyhow!("validation_error: workspaceDir cannot be empty"));
    }

    let target = PathBuf::from(trimmed);
    fs::create_dir_all(&target)
        .with_context(|| format!("failed to create workspace dir {}", target.display()))?;

    let current = workspace_root();
    let legacy = legacy_workspace_root();
    migrate_workspace_if_needed(&current, &target)?;
    migrate_workspace_if_needed(&legacy, &target)?;

    unsafe {
        std::env::set_var("RST_WORKSPACE_DIR", &target);
    }

    Ok(target.to_string_lossy().to_string())
}

fn workspace_root() -> PathBuf {
    std::env::var("RST_WORKSPACE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| legacy_workspace_root())
}

fn legacy_workspace_root() -> PathBuf {
    PathBuf::from("./rust/data")
}

fn sessions_dir() -> Result<PathBuf> {
    let dir = workspace_root().join("sessions");
    fs::create_dir_all(&dir).with_context(|| format!("failed to create {}", dir.display()))?;
    Ok(dir)
}

fn request_logs_dir() -> Result<PathBuf> {
    let dir = workspace_root().join("request_logs");
    fs::create_dir_all(&dir).with_context(|| format!("failed to create {}", dir.display()))?;
    Ok(dir)
}

fn session_file_path(session_id: &str) -> Result<PathBuf> {
    Ok(sessions_dir()?.join(format!("{session_id}.json")))
}

fn session_paths() -> Result<Vec<PathBuf>> {
    let sessions_dir = sessions_dir()?;
    let entries = fs::read_dir(&sessions_dir)
        .with_context(|| format!("failed to read {}", sessions_dir.display()))?;

    let mut paths = Vec::new();
    for entry in entries {
        let entry = entry.with_context(|| "failed to iterate sessions directory")?;
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) == Some("json") {
            paths.push(path);
        }
    }
    Ok(paths)
}

fn request_log_file_path(log_id: &str) -> Result<PathBuf> {
    Ok(request_logs_dir()?.join(format!("{log_id}.json")))
}

fn request_log_paths() -> Result<Vec<PathBuf>> {
    let logs_dir = request_logs_dir()?;
    let entries = fs::read_dir(&logs_dir)
        .with_context(|| format!("failed to read {}", logs_dir.display()))?;

    let mut paths = Vec::new();
    for entry in entries {
        let entry = entry.with_context(|| "failed to iterate request_logs directory")?;
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) == Some("json") {
            paths.push(path);
        }
    }
    Ok(paths)
}

fn read_session_file(path: &Path) -> Result<SessionFile> {
    let raw =
        fs::read_to_string(path).with_context(|| format!("failed to read {}", path.display()))?;
    serde_json::from_str(&raw).with_context(|| format!("failed to parse {}", path.display()))
}

fn write_session_file(path: &Path, file: &SessionFile) -> Result<()> {
    let raw =
        serde_json::to_string_pretty(file).with_context(|| "failed to serialize session data")?;
    fs::write(path, raw).with_context(|| format!("failed to write {}", path.display()))?;
    Ok(())
}

fn read_request_log_file(path: &Path) -> Result<RequestLog> {
    let raw =
        fs::read_to_string(path).with_context(|| format!("failed to read {}", path.display()))?;
    serde_json::from_str(&raw).with_context(|| format!("failed to parse {}", path.display()))
}

fn write_request_log_file(path: &Path, log: &RequestLog) -> Result<()> {
    let raw = serde_json::to_string_pretty(log)
        .with_context(|| "failed to serialize request log data")?;
    fs::write(path, raw).with_context(|| format!("failed to write {}", path.display()))?;
    Ok(())
}

fn touch_session(file: &mut SessionFile, now: &str) {
    file.config.updated_at = now.to_string();
    file.runtime.updated_at = now.to_string();
}

fn validate_session_name(session_name: &str) -> Result<()> {
    if session_name.trim().is_empty() {
        return Err(anyhow!("validation_error: sessionName cannot be empty"));
    }
    Ok(())
}

fn validate_mode_binding(mode: SessionMode, st_world_book_id: Option<&str>) -> Result<()> {
    if mode == SessionMode::St && st_world_book_id.is_none() {
        return Err(anyhow!(
            "validation_error: stWorldBookId is required when mode is ST"
        ));
    }

    if mode == SessionMode::Rst && st_world_book_id.is_some() {
        return Err(anyhow!(
            "validation_error: stWorldBookId must be null when mode is RST"
        ));
    }

    Ok(())
}

fn apply_status_side_effects(
    runtime: &mut SessionRuntimeState,
    message_id: &str,
    status: MessageStatus,
    error_message: Option<&str>,
    now: &str,
) {
    match status {
        MessageStatus::Pending => {
            runtime.updated_at = now.to_string();
        }
        MessageStatus::Streaming => {
            runtime.active_message_id = Some(message_id.to_string());
            runtime.streaming_status = StreamingStatus::Receiving;
            runtime.last_error = None;
            runtime.last_request_started_at = Some(now.to_string());
            runtime.updated_at = now.to_string();
        }
        MessageStatus::Completed => {
            runtime.active_message_id = None;
            runtime.streaming_status = StreamingStatus::Idle;
            runtime.last_error = None;
            runtime.last_request_finished_at = Some(now.to_string());
            runtime.updated_at = now.to_string();
        }
        MessageStatus::Error => {
            if runtime.active_message_id.as_deref() == Some(message_id) {
                runtime.active_message_id = None;
                runtime.last_request_finished_at = Some(now.to_string());
            }
            runtime.streaming_status = StreamingStatus::Error;
            runtime.last_error = error_message.map(ToString::to_string);
            runtime.updated_at = now.to_string();
        }
    }
}

fn role_has_floor(role: MessageRole) -> bool {
    matches!(role, MessageRole::User | MessageRole::Assistant)
}

fn next_floor_no(messages: &[MessageRecord], role: MessageRole) -> Option<i64> {
    if !role_has_floor(role) {
        return None;
    }

    let mut floor = 0_i64;
    for message in messages {
        if role_has_floor(message.role) {
            floor += 1;
        }
    }
    Some(floor)
}

fn reconcile_message_floors(messages: &mut [MessageRecord]) -> bool {
    let mut changed = false;
    let mut floor = 0_i64;

    for message in messages {
        let next_floor = if role_has_floor(message.role) {
            let current = floor;
            floor += 1;
            Some(current)
        } else {
            None
        };

        if message.floor_no != next_floor {
            message.floor_no = next_floor;
            changed = true;
        }
    }

    changed
}

fn mutate_message<F>(message_id: &str, mutator: F) -> Result<MessageRecord>
where
    F: Fn(&mut SessionFile, &mut MessageRecord) -> Result<MessageRecord>,
{
    for path in session_paths()? {
        let mut file = read_session_file(&path)?;

        if let Some(index) = file
            .messages
            .iter()
            .position(|message| message.message_id == message_id)
        {
            let mut cloned = file.messages[index].clone();
            let result = mutator(&mut file, &mut cloned)?;
            file.messages[index] = cloned;
            write_session_file(&path, &file)?;
            return Ok(result);
        }
    }

    Err(anyhow!("not_found: message {} does not exist", message_id))
}

fn reconcile_inflight_state(file: &mut SessionFile) -> bool {
    if file.runtime.streaming_status != StreamingStatus::Receiving {
        return false;
    }

    let now = now_rfc3339();
    let mut changed = false;

    let active_id = file.runtime.active_message_id.clone();
    for message in &mut file.messages {
        let is_target = if let Some(active_id) = active_id.as_deref() {
            message.message_id == active_id
        } else {
            message.status == MessageStatus::Streaming
        };

        if is_target && message.status == MessageStatus::Streaming {
            message.status = MessageStatus::Error;
            if message.error_message.is_none() {
                message.error_message = Some("interrupted_stream_recovered".to_string());
            }
            message.updated_at = now.clone();
            changed = true;
        }
    }

    file.runtime.streaming_status = StreamingStatus::Error;
    file.runtime.active_message_id = None;
    if file.runtime.last_error.is_none() {
        file.runtime.last_error = Some("interrupted_stream_recovered".to_string());
    }
    file.runtime.last_request_finished_at = Some(now.clone());
    touch_session(file, &now);

    let _ = changed;
    true
}

fn now_rfc3339() -> String {
    Utc::now().to_rfc3339_opts(SecondsFormat::Secs, true)
}

fn normalize_optional(value: Option<String>) -> Option<String> {
    value
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
}

fn migrate_workspace_if_needed(from: &Path, to: &Path) -> Result<()> {
    if from == to || !from.exists() {
        return Ok(());
    }

    let target_sessions = to.join("sessions");
    if target_sessions.exists() {
        return Ok(());
    }

    copy_dir_recursive(from, to)
}

fn copy_dir_recursive(from: &Path, to: &Path) -> Result<()> {
    fs::create_dir_all(to).with_context(|| format!("failed to create {}", to.display()))?;

    for entry in fs::read_dir(from).with_context(|| format!("failed to read {}", from.display()))? {
        let entry = entry.with_context(|| "failed to iterate directory for migration")?;
        let source_path = entry.path();
        let target_path = to.join(entry.file_name());
        let source_type = entry
            .file_type()
            .with_context(|| format!("failed to inspect {}", source_path.display()))?;

        if source_type.is_dir() {
            copy_dir_recursive(&source_path, &target_path)?;
            continue;
        }

        if source_type.is_file() {
            if !target_path.exists() {
                fs::copy(&source_path, &target_path).with_context(|| {
                    format!(
                        "failed to migrate file {} -> {}",
                        source_path.display(),
                        target_path.display()
                    )
                })?;
            }
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;
    use std::sync::{Mutex, MutexGuard, OnceLock};

    fn test_lock() -> MutexGuard<'static, ()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|error| error.into_inner())
    }

    #[test]
    fn session_crud_roundtrip() {
        let _guard = test_lock();
        let workspace_dir = std::env::temp_dir().join(format!("rst-frb-{}", Uuid::new_v4()));
        unsafe {
            std::env::set_var("RST_WORKSPACE_DIR", &workspace_dir);
        }

        let created = create_session(CreateSessionRequest {
            session_name: "Smoke Session".to_string(),
            mode: SessionMode::Rst,
            main_api_config_id: "api-default".to_string(),
            preset_id: "preset-default".to_string(),
            st_world_book_id: None,
        })
        .expect("create_session should succeed");

        let renamed = rename_session(created.session_id.clone(), "Renamed".to_string())
            .expect("rename_session should succeed");
        assert_eq!(renamed.session_name, "Renamed");

        let listed = list_sessions().expect("list_sessions should succeed");
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].session_id, created.session_id);

        let loaded = load_session(created.session_id.clone()).expect("load_session should succeed");
        assert_eq!(loaded.config.session_id, created.session_id);
        assert_eq!(loaded.config.mode, SessionMode::Rst);

        let deleted =
            delete_session(created.session_id.clone()).expect("delete_session should succeed");
        assert!(deleted.deleted);

        let listed_after_delete = list_sessions().expect("list_sessions should succeed");
        assert!(listed_after_delete.is_empty());

        let _ = std::fs::remove_dir_all(workspace_dir);
    }

    #[test]
    fn message_state_machine_and_recovery() {
        let _guard = test_lock();
        let workspace_dir = std::env::temp_dir().join(format!("rst-frb-{}", Uuid::new_v4()));
        unsafe {
            std::env::set_var("RST_WORKSPACE_DIR", &workspace_dir);
        }

        let created = create_session(CreateSessionRequest {
            session_name: "Chat Session".to_string(),
            mode: SessionMode::Rst,
            main_api_config_id: "api-default".to_string(),
            preset_id: "preset-default".to_string(),
            st_world_book_id: None,
        })
        .expect("create_session should succeed");

        let _user = create_message(CreateMessageRequest {
            session_id: created.session_id.clone(),
            role: MessageRole::User,
            content: "hello".to_string(),
            visible: true,
            status: MessageStatus::Completed,
        })
        .expect("create user message should succeed");

        let assistant = create_message(CreateMessageRequest {
            session_id: created.session_id.clone(),
            role: MessageRole::Assistant,
            content: "".to_string(),
            visible: true,
            status: MessageStatus::Pending,
        })
        .expect("create assistant message should succeed");

        set_message_status(assistant.message_id.clone(), MessageStatus::Streaming, None)
            .expect("set streaming should succeed");

        update_message_content(assistant.message_id.clone(), "partial".to_string())
            .expect("update content should succeed");

        let loaded =
            load_session(created.session_id.clone()).expect("load_session should reconcile");
        assert_eq!(loaded.runtime.streaming_status, StreamingStatus::Error);
        assert!(loaded.runtime.active_message_id.is_none());

        let messages =
            list_messages(created.session_id.clone(), None).expect("list messages works");
        let recovered = messages
            .iter()
            .find(|m| m.message_id == assistant.message_id)
            .expect("assistant message should exist");
        assert_eq!(recovered.status, MessageStatus::Error);
        assert_eq!(recovered.content, "partial");

        set_message_status(assistant.message_id.clone(), MessageStatus::Completed, None)
            .expect("set completed should succeed");

        let loaded_after_complete =
            load_session(created.session_id.clone()).expect("load_session should succeed");
        assert_eq!(
            loaded_after_complete.runtime.streaming_status,
            StreamingStatus::Idle
        );

        let _ = std::fs::remove_dir_all(workspace_dir);
    }

    #[test]
    fn message_mutations_persist_to_session_file() {
        let _guard = test_lock();
        let workspace_dir = std::env::temp_dir().join(format!("rst-frb-{}", Uuid::new_v4()));
        unsafe {
            std::env::set_var("RST_WORKSPACE_DIR", &workspace_dir);
        }

        let created = create_session(CreateSessionRequest {
            session_name: "Persist Session".to_string(),
            mode: SessionMode::Rst,
            main_api_config_id: "api-default".to_string(),
            preset_id: "preset-default".to_string(),
            st_world_book_id: None,
        })
        .expect("create_session should succeed");

        let user = create_message(CreateMessageRequest {
            session_id: created.session_id.clone(),
            role: MessageRole::User,
            content: "user-content".to_string(),
            visible: true,
            status: MessageStatus::Completed,
        })
        .expect("create user message should succeed");

        let assistant = create_message(CreateMessageRequest {
            session_id: created.session_id.clone(),
            role: MessageRole::Assistant,
            content: "assistant-content".to_string(),
            visible: true,
            status: MessageStatus::Completed,
        })
        .expect("create assistant message should succeed");

        update_message_content(
            assistant.message_id.clone(),
            "assistant-updated".to_string(),
        )
        .expect("update_message_content should succeed");
        set_message_visibility(assistant.message_id.clone(), false)
            .expect("set_message_visibility should succeed");
        delete_messages(created.session_id.clone(), vec![user.message_id.clone()])
            .expect("delete_messages should succeed");

        let path = session_file_path(&created.session_id).expect("session_file_path should work");
        let file = read_session_file(&path).expect("session file should be readable");
        assert_eq!(file.messages.len(), 1);

        let persisted = &file.messages[0];
        assert_eq!(persisted.message_id, assistant.message_id);
        assert_eq!(persisted.content, "assistant-updated");
        assert!(!persisted.visible);
        assert_eq!(persisted.floor_no, Some(0));

        let listed = list_messages(created.session_id.clone(), None).expect("list_messages works");
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].message_id, assistant.message_id);
        assert!(!listed[0].visible);
        assert_eq!(listed[0].content, "assistant-updated");

        let _ = std::fs::remove_dir_all(workspace_dir);
    }

    #[test]
    fn set_workspace_dir_migrates_legacy_data_once() {
        let _guard = test_lock();
        let legacy_root = std::env::temp_dir().join(format!("rst-legacy-{}", Uuid::new_v4()));
        let target_root = std::env::temp_dir().join(format!("rst-target-{}", Uuid::new_v4()));

        fs::create_dir_all(legacy_root.join("sessions")).expect("legacy sessions dir");
        fs::write(
            legacy_root.join("sessions").join("legacy.json"),
            "{\"ok\":true}",
        )
        .expect("legacy session file");

        unsafe {
            std::env::set_var("RST_WORKSPACE_DIR", &legacy_root);
        }

        let applied = set_workspace_dir(target_root.to_string_lossy().to_string())
            .expect("set_workspace_dir should succeed");
        assert_eq!(PathBuf::from(applied), target_root);
        assert!(target_root.join("sessions").join("legacy.json").exists());

        let _ = std::fs::remove_dir_all(legacy_root);
        let _ = std::fs::remove_dir_all(target_root);
    }

    #[test]
    fn request_log_create_list_and_get() {
        let _guard = test_lock();
        let workspace_dir = std::env::temp_dir().join(format!("rst-logs-{}", Uuid::new_v4()));
        unsafe {
            std::env::set_var("RST_WORKSPACE_DIR", &workspace_dir);
        }

        let _created = create_request_log(CreateRequestLogRequest {
            session_id: "session-a".to_string(),
            provider: "openai_compatible".to_string(),
            model: "gpt-5.4-mini".to_string(),
            status: RequestLogStatus::Success,
            request_time: "2026-04-10T10:00:00Z".to_string(),
            response_time: Some("2026-04-10T10:00:01Z".to_string()),
            duration_ms: Some(1000),
            prompt_tokens: Some(12),
            completion_tokens: Some(8),
            total_tokens: Some(20),
            stop_reason: Some("stop".to_string()),
            redacted: true,
            payload_truncated: false,
            request_preview_json: Some("{\"ok\":true}".to_string()),
            response_preview_json: Some("{\"ok\":true}".to_string()),
        })
        .expect("create_request_log should succeed");

        let listed = list_request_logs(
            Some("session-a".to_string()),
            Some(RequestLogStatus::Success),
            None,
        )
        .expect("list_request_logs should succeed");
        assert_eq!(listed.len(), 1);

        let loaded = get_request_log(listed[0].log_id.clone()).expect("get_request_log works");
        assert_eq!(loaded.session_id, "session-a");
        assert_eq!(loaded.status, RequestLogStatus::Success);
        assert_eq!(loaded.model, "gpt-5.4-mini");

        let _ = std::fs::remove_dir_all(workspace_dir);
    }
}
