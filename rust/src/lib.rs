pub mod api;
pub mod frb_api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod models;
pub mod prompt;
pub mod retrieval;
pub mod security;
pub mod storage;

use api::ApiFacade;
use storage::Storage;

/// Workspace is the Rust-side entrypoint for MVP scaffolding.
pub struct Workspace {
    storage: Storage,
    api: ApiFacade,
}

impl Workspace {
    pub fn new(root: impl Into<String>) -> Self {
        let root_path = root.into();
        Self {
            storage: Storage::new(root_path.clone()),
            api: ApiFacade::new(root_path),
        }
    }

    pub fn ping(&self) -> &'static str {
        let _ = (&self.storage, &self.api);
        "rst-core-ready"
    }
}

#[cfg(test)]
mod tests {
    use super::Workspace;

    #[test]
    fn workspace_ping() {
        let workspace = Workspace::new("./");
        assert_eq!(workspace.ping(), "rst-core-ready");
    }
}
