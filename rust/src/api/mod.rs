use crate::models::{AppError, SessionMode, SessionSummary};

pub struct ApiFacade {
    root: String,
}

impl ApiFacade {
    pub fn new(root: String) -> Self {
        Self { root }
    }

    pub fn list_sessions(&self) -> Result<Vec<SessionSummary>, AppError> {
        let _ = &self.root;
        Ok(vec![SessionSummary::new(
            "bootstrap",
            "Bootstrap Session",
            SessionMode::Rst,
        )])
    }
}
