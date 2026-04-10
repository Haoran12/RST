use crate::models::SessionMode;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PromptBuildRequest {
    pub session_id: String,
    pub mode: SessionMode,
    pub user_input: String,
    pub include_message_ids: Vec<String>,
    pub max_context_tokens: usize,
    pub reserved_completion_tokens: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PromptBuildResult {
    pub messages: Vec<PromptMessage>,
    pub used_lore_ids: Vec<String>,
    pub omitted_lore_ids: Vec<String>,
    pub prompt_token_estimate: usize,
    pub truncated: bool,
    pub truncation_notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PromptMessage {
    pub role: String,
    pub content: String,
}

pub fn build_prompt(request: PromptBuildRequest) -> PromptBuildResult {
    let system = PromptMessage {
        role: "system".to_string(),
        content: format!("mode={:?}; session={}", request.mode, request.session_id),
    };
    let user = PromptMessage {
        role: "user".to_string(),
        content: request.user_input,
    };

    PromptBuildResult {
        messages: vec![system, user],
        used_lore_ids: vec![],
        omitted_lore_ids: vec![],
        prompt_token_estimate: 0,
        truncated: false,
        truncation_notes: vec![],
    }
}
