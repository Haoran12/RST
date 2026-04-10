use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoreRetrievalQuery {
    pub session_id: String,
    pub recent_text: String,
    pub scan_depth: usize,
    pub max_results: usize,
    pub max_entry_tokens: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoreRetrievalHit {
    pub id: String,
    pub title: String,
    pub content: String,
    pub score: f32,
}

pub fn search_lore(_query: LoreRetrievalQuery) -> Vec<LoreRetrievalHit> {
    vec![]
}
