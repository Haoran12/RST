//! Agent storage layer for persisting runtime state.

use std::path::PathBuf;
use std::fs;
use std::io;

use crate::agent::models::*;
use crate::models::AppError;

/// Storage for agent runtime state.
pub struct AgentStorage {
    root: PathBuf,
}

impl AgentStorage {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// Ensure storage directories exist.
    pub fn ensure_ready(&self) -> Result<(), AppError> {
        let dirs = [
            self.root.join("scenes"),
            self.root.join("characters"),
            self.root.join("memories"),
            self.root.join("traces"),
        ];

        for dir in &dirs {
            fs::create_dir_all(dir)
                .map_err(|e| AppError::Storage(format!("failed to create directory: {}", e)))?;
        }

        Ok(())
    }

    /// Save a scene snapshot.
    pub fn save_scene_snapshot(&self, snapshot: &SceneSnapshot) -> Result<(), AppError> {
        self.ensure_ready()?;

        let path = self.root
            .join("scenes")
            .join(format!("{}.json", snapshot.snapshot_id));

        let content = serde_json::to_string_pretty(snapshot)
            .map_err(|e| AppError::Storage(format!("failed to serialize scene: {}", e)))?;

        fs::write(&path, content)
            .map_err(|e| AppError::Storage(format!("failed to write scene: {}", e)))?;

        Ok(())
    }

    /// Load a scene snapshot by ID.
    pub fn load_scene_snapshot(&self, snapshot_id: &str) -> Result<Option<SceneSnapshot>, AppError> {
        let path = self.root
            .join("scenes")
            .join(format!("{}.json", snapshot_id));

        if !path.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(&path)
            .map_err(|e| AppError::Storage(format!("failed to read scene: {}", e)))?;

        let snapshot: SceneSnapshot = serde_json::from_str(&content)
            .map_err(|e| AppError::Storage(format!("failed to parse scene: {}", e)))?;

        Ok(Some(snapshot))
    }

    /// Save a character runtime snapshot.
    pub fn save_character_snapshot(&self, snapshot: &CharacterRuntimeSnapshot) -> Result<(), AppError> {
        self.ensure_ready()?;

        let path = self.root
            .join("characters")
            .join(format!("{}.json", snapshot.snapshot_id));

        let content = serde_json::to_string_pretty(snapshot)
            .map_err(|e| AppError::Storage(format!("failed to serialize character: {}", e)))?;

        fs::write(&path, content)
            .map_err(|e| AppError::Storage(format!("failed to write character: {}", e)))?;

        Ok(())
    }

    /// Load a character runtime snapshot by ID.
    pub fn load_character_snapshot(&self, snapshot_id: &str) -> Result<Option<CharacterRuntimeSnapshot>, AppError> {
        let path = self.root
            .join("characters")
            .join(format!("{}.json", snapshot_id));

        if !path.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(&path)
            .map_err(|e| AppError::Storage(format!("failed to read character: {}", e)))?;

        let snapshot: CharacterRuntimeSnapshot = serde_json::from_str(&content)
            .map_err(|e| AppError::Storage(format!("failed to parse character: {}", e)))?;

        Ok(Some(snapshot))
    }

    /// Save a turn trace.
    pub fn save_turn_trace(&self, trace: &TurnTrace) -> Result<(), AppError> {
        self.ensure_ready()?;

        let path = self.root
            .join("traces")
            .join(format!("{}.json", trace.trace_id));

        let content = serde_json::to_string_pretty(trace)
            .map_err(|e| AppError::Storage(format!("failed to serialize trace: {}", e)))?;

        fs::write(&path, content)
            .map_err(|e| AppError::Storage(format!("failed to write trace: {}", e)))?;

        Ok(())
    }

    /// Load a turn trace by ID.
    pub fn load_turn_trace(&self, trace_id: &str) -> Result<Option<TurnTrace>, AppError> {
        let path = self.root
            .join("traces")
            .join(format!("{}.json", trace_id));

        if !path.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(&path)
            .map_err(|e| AppError::Storage(format!("failed to read trace: {}", e)))?;

        let trace: TurnTrace = serde_json::from_str(&content)
            .map_err(|e| AppError::Storage(format!("failed to parse trace: {}", e)))?;

        Ok(Some(trace))
    }

    /// Save a memory record.
    pub fn save_memory(&self, memory: &MemoryRecord) -> Result<(), AppError> {
        self.ensure_ready()?;

        let path = self.root
            .join("memories")
            .join(format!("{}.json", memory.memory_id));

        let content = serde_json::to_string_pretty(memory)
            .map_err(|e| AppError::Storage(format!("failed to serialize memory: {}", e)))?;

        fs::write(&path, content)
            .map_err(|e| AppError::Storage(format!("failed to write memory: {}", e)))?;

        Ok(())
    }

    /// Load a memory record by ID.
    pub fn load_memory(&self, memory_id: &str) -> Result<Option<MemoryRecord>, AppError> {
        let path = self.root
            .join("memories")
            .join(format!("{}.json", memory_id));

        if !path.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(&path)
            .map_err(|e| AppError::Storage(format!("failed to read memory: {}", e)))?;

        let memory: MemoryRecord = serde_json::from_str(&content)
            .map_err(|e| AppError::Storage(format!("failed to parse memory: {}", e)))?;

        Ok(Some(memory))
    }

    /// List all memories accessible to a character.
    pub fn list_memories_for_character(&self, character_id: &str) -> Result<Vec<MemoryRecord>, AppError> {
        let memories_dir = self.root.join("memories");

        if !memories_dir.exists() {
            return Ok(Vec::new());
        }

        let mut memories = Vec::new();

        for entry in fs::read_dir(&memories_dir)
            .map_err(|e| AppError::Storage(format!("failed to read memories directory: {}", e)))?
        {
            let entry = entry.map_err(|e| AppError::Storage(format!("failed to read entry: {}", e)))?;
            let path = entry.path();

            if path.extension().map_or(false, |ext| ext == "json") {
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(memory) = serde_json::from_str::<MemoryRecord>(&content) {
                        if memory.is_accessible_to(character_id) {
                            memories.push(memory);
                        }
                    }
                }
            }
        }

        // Sort by creation time, most recent first
        memories.sort_by(|a, b| b.created_at.cmp(&a.created_at));

        Ok(memories)
    }

    /// Delete a memory record.
    pub fn delete_memory(&self, memory_id: &str) -> Result<bool, AppError> {
        let path = self.root
            .join("memories")
            .join(format!("{}.json", memory_id));

        if !path.exists() {
            return Ok(false);
        }

        fs::remove_file(&path)
            .map_err(|e| AppError::Storage(format!("failed to delete memory: {}", e)))?;

        Ok(true)
    }

    /// List all scene snapshots for a scene.
    pub fn list_scene_snapshots(&self, scene_id: &str) -> Result<Vec<SceneSnapshot>, AppError> {
        let scenes_dir = self.root.join("scenes");

        if !scenes_dir.exists() {
            return Ok(Vec::new());
        }

        let mut snapshots = Vec::new();

        for entry in fs::read_dir(&scenes_dir)
            .map_err(|e| AppError::Storage(format!("failed to read scenes directory: {}", e)))?
        {
            let entry = entry.map_err(|e| AppError::Storage(format!("failed to read entry: {}", e)))?;
            let path = entry.path();

            if path.extension().map_or(false, |ext| ext == "json") {
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(snapshot) = serde_json::from_str::<SceneSnapshot>(&content) {
                        if snapshot.scene_id == scene_id {
                            snapshots.push(snapshot);
                        }
                    }
                }
            }
        }

        // Sort by creation time, most recent first
        snapshots.sort_by(|a, b| b.created_at.cmp(&a.created_at));

        Ok(snapshots)
    }

    /// Get the latest scene snapshot for a scene.
    pub fn get_latest_scene_snapshot(&self, scene_id: &str) -> Result<Option<SceneSnapshot>, AppError> {
        let snapshots = self.list_scene_snapshots(scene_id)?;
        Ok(snapshots.into_iter().next())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_storage_initialization() {
        let temp_dir = TempDir::new().unwrap();
        let storage = AgentStorage::new(temp_dir.path());

        storage.ensure_ready().unwrap();

        assert!(temp_dir.path().join("scenes").exists());
        assert!(temp_dir.path().join("characters").exists());
        assert!(temp_dir.path().join("memories").exists());
        assert!(temp_dir.path().join("traces").exists());
    }

    #[test]
    fn test_scene_snapshot_roundtrip() {
        let temp_dir = TempDir::new().unwrap();
        let storage = AgentStorage::new(temp_dir.path());

        let snapshot = SceneSnapshot::new(
            "scene1",
            "turn1",
            serde_json::json!({"lighting": "dim"}),
        );

        storage.save_scene_snapshot(&snapshot).unwrap();

        let loaded = storage.load_scene_snapshot(&snapshot.snapshot_id).unwrap();
        assert!(loaded.is_some());

        let loaded = loaded.unwrap();
        assert_eq!(loaded.scene_id, "scene1");
        assert_eq!(loaded.scene_turn_id, "turn1");
    }

    #[test]
    fn test_character_snapshot_roundtrip() {
        let temp_dir = TempDir::new().unwrap();
        let storage = AgentStorage::new(temp_dir.path());

        let snapshot = CharacterRuntimeSnapshot::new(
            "char1",
            "turn1",
            serde_json::json!({}),
            serde_json::json!({"suspicion": 0.8}),
            serde_json::json!({"fear": 0.3}),
            serde_json::json!({}),
            serde_json::json!({"shortTerm": ["escape"]}),
        );

        storage.save_character_snapshot(&snapshot).unwrap();

        let loaded = storage.load_character_snapshot(&snapshot.snapshot_id).unwrap();
        assert!(loaded.is_some());

        let loaded = loaded.unwrap();
        assert_eq!(loaded.character_id, "char1");
    }

    #[test]
    fn test_memory_access_control() {
        let temp_dir = TempDir::new().unwrap();
        let storage = AgentStorage::new(temp_dir.path());

        // Create private memory for alice
        let memory = MemoryRecord::new(
            "mem1",
            "Alice's secret",
            "alice",
            MemoryVisibilityRecord::Private,
        );
        storage.save_memory(&memory).unwrap();

        // Alice can access
        let alice_memories = storage.list_memories_for_character("alice").unwrap();
        assert_eq!(alice_memories.len(), 1);

        // Bob cannot access
        let bob_memories = storage.list_memories_for_character("bob").unwrap();
        assert_eq!(bob_memories.len(), 0);
    }

    #[test]
    fn test_turn_trace_roundtrip() {
        let temp_dir = TempDir::new().unwrap();
        let storage = AgentStorage::new(temp_dir.path());

        let trace = TurnTrace::new("turn1")
            .with_perception(serde_json::json!({"noticed": ["fact1"]}))
            .with_validation(ValidationResultRecord::new(
                "test_rule",
                ValidationSeverityRecord::Warning,
                "Test warning",
            ));

        storage.save_turn_trace(&trace).unwrap();

        let loaded = storage.load_turn_trace(&trace.trace_id).unwrap();
        assert!(loaded.is_some());

        let loaded = loaded.unwrap();
        assert_eq!(loaded.perception_packets.len(), 1);
        assert_eq!(loaded.validation_results.len(), 1);
    }
}
