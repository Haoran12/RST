use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SessionMode {
    St,
    Rst,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSummary {
    pub session_id: String,
    pub session_name: String,
    pub mode: SessionMode,
    pub updated_at: DateTime<Utc>,
}

impl SessionSummary {
    pub fn new(
        session_id: impl Into<String>,
        session_name: impl Into<String>,
        mode: SessionMode,
    ) -> Self {
        Self {
            session_id: session_id.into(),
            session_name: session_name.into(),
            mode,
            updated_at: Utc::now(),
        }
    }
}

#[derive(Debug, Error)]
pub enum AppError {
    #[error("validation error: {0}")]
    Validation(String),
    #[error("storage error: {0}")]
    Storage(String),
}
