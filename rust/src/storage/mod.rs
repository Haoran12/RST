use crate::models::AppError;

pub struct Storage {
    root: String,
}

impl Storage {
    pub fn new(root: String) -> Self {
        Self { root }
    }

    pub fn ensure_ready(&self) -> Result<(), AppError> {
        if self.root.is_empty() {
            return Err(AppError::Validation("workspace root is empty".to_string()));
        }
        Ok(())
    }
}
