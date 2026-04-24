//! Agent data models for persistence and state management.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Snapshot of a scene at a specific turn.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SceneSnapshot {
    pub snapshot_id: String,
    pub scene_id: String,
    pub scene_turn_id: String,
    pub scene_model: serde_json::Value,
    pub created_at: DateTime<Utc>,
}

impl SceneSnapshot {
    pub fn new(
        scene_id: impl Into<String>,
        scene_turn_id: impl Into<String>,
        scene_model: serde_json::Value,
    ) -> Self {
        let scene_id = scene_id.into();
        let scene_turn_id = scene_turn_id.into();
        let snapshot_id = format!("snapshot_{}_{}", scene_id, scene_turn_id);

        Self {
            snapshot_id,
            scene_id,
            scene_turn_id,
            scene_model,
            created_at: Utc::now(),
        }
    }
}

/// Runtime state snapshot for a character.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CharacterRuntimeSnapshot {
    pub snapshot_id: String,
    pub character_id: String,
    pub scene_turn_id: String,
    pub relationship_models: serde_json::Value,
    pub belief_state: serde_json::Value,
    pub emotion_state: serde_json::Value,
    pub temporary_body_state: serde_json::Value,
    pub current_goals: serde_json::Value,
    pub created_at: DateTime<Utc>,
}

impl CharacterRuntimeSnapshot {
    pub fn new(
        character_id: impl Into<String>,
        scene_turn_id: impl Into<String>,
        relationship_models: serde_json::Value,
        belief_state: serde_json::Value,
        emotion_state: serde_json::Value,
        temporary_body_state: serde_json::Value,
        current_goals: serde_json::Value,
    ) -> Self {
        let character_id = character_id.into();
        let scene_turn_id = scene_turn_id.into();
        let snapshot_id = format!("char_{}_{}", character_id, scene_turn_id);

        Self {
            snapshot_id,
            character_id,
            scene_turn_id,
            relationship_models,
            belief_state,
            emotion_state,
            temporary_body_state,
            current_goals,
            created_at: Utc::now(),
        }
    }
}

/// Trace of a single turn's cognitive processing.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TurnTrace {
    pub trace_id: String,
    pub scene_turn_id: String,
    pub perception_packets: Vec<serde_json::Value>,
    pub belief_updates: Vec<serde_json::Value>,
    pub intent_plans: Vec<serde_json::Value>,
    pub rendered_output: serde_json::Value,
    pub validation_results: Vec<ValidationResultRecord>,
    pub created_at: DateTime<Utc>,
}

impl TurnTrace {
    pub fn new(scene_turn_id: impl Into<String>) -> Self {
        let scene_turn_id = scene_turn_id.into();
        let trace_id = format!("trace_{}", scene_turn_id);

        Self {
            trace_id,
            scene_turn_id,
            perception_packets: Vec::new(),
            belief_updates: Vec::new(),
            intent_plans: Vec::new(),
            rendered_output: serde_json::Value::Null,
            validation_results: Vec::new(),
            created_at: Utc::now(),
        }
    }

    pub fn with_perception(mut self, perception: serde_json::Value) -> Self {
        self.perception_packets.push(perception);
        self
    }

    pub fn with_belief_update(mut self, belief: serde_json::Value) -> Self {
        self.belief_updates.push(belief);
        self
    }

    pub fn with_intent_plan(mut self, intent: serde_json::Value) -> Self {
        self.intent_plans.push(intent);
        self
    }

    pub fn with_rendered_output(mut self, output: serde_json::Value) -> Self {
        self.rendered_output = output;
        self
    }

    pub fn with_validation(mut self, validation: ValidationResultRecord) -> Self {
        self.validation_results.push(validation);
        self
    }
}

/// Record of a validation result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ValidationResultRecord {
    pub rule_id: String,
    pub severity: ValidationSeverityRecord,
    pub message: String,
    pub details: Option<String>,
    pub context: Option<serde_json::Value>,
}

impl ValidationResultRecord {
    pub fn new(
        rule_id: impl Into<String>,
        severity: ValidationSeverityRecord,
        message: impl Into<String>,
    ) -> Self {
        Self {
            rule_id: rule_id.into(),
            severity,
            message: message.into(),
            details: None,
            context: None,
        }
    }

    pub fn with_details(mut self, details: impl Into<String>) -> Self {
        self.details = Some(details.into());
        self
    }

    pub fn with_context(mut self, context: serde_json::Value) -> Self {
        self.context = Some(context);
        self
    }
}

/// Severity level for validation results.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ValidationSeverityRecord {
    Info,
    Warning,
    Error,
}

/// Memory record for persistent storage.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemoryRecord {
    pub memory_id: String,
    pub content: String,
    pub owner_character_id: String,
    pub known_by: Vec<String>,
    pub visibility: MemoryVisibilityRecord,
    pub emotional_weight: f64,
    pub created_at: DateTime<Utc>,
    pub last_accessed_at: Option<DateTime<Utc>>,
}

impl MemoryRecord {
    pub fn new(
        memory_id: impl Into<String>,
        content: impl Into<String>,
        owner_character_id: impl Into<String>,
        visibility: MemoryVisibilityRecord,
    ) -> Self {
        let owner = owner_character_id.into();
        Self {
            memory_id: memory_id.into(),
            content: content.into(),
            owner_character_id: owner.clone(),
            known_by: vec![owner],
            visibility,
            emotional_weight: 0.0,
            created_at: Utc::now(),
            last_accessed_at: None,
        }
    }

    pub fn with_known_by(mut self, known_by: Vec<String>) -> Self {
        self.known_by = known_by;
        self
    }

    pub fn with_emotional_weight(mut self, weight: f64) -> Self {
        self.emotional_weight = weight;
        self
    }

    pub fn touch(&mut self) {
        self.last_accessed_at = Some(Utc::now());
    }

    pub fn is_accessible_to(&self, character_id: &str) -> bool {
        match self.visibility {
            MemoryVisibilityRecord::Public => true,
            MemoryVisibilityRecord::Private => self.owner_character_id == character_id,
            MemoryVisibilityRecord::Shared => self.known_by.contains(&character_id.to_string()),
        }
    }
}

/// Visibility level for memories.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MemoryVisibilityRecord {
    Public,
    Private,
    Shared,
}

/// Dirty flags for tracking state changes.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DirtyFlagsRecord {
    pub scene_changed: bool,
    pub body_changed: bool,
    pub relation_changed: bool,
    pub belief_invalidated: bool,
    pub intent_invalidated: bool,
    pub directly_addressed: bool,
    pub under_threat: bool,
    pub reaction_window_open: bool,
    pub received_new_salient_signal: bool,
}

impl DirtyFlagsRecord {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn is_dirty(&self) -> bool {
        self.scene_changed
            || self.body_changed
            || self.relation_changed
            || self.belief_invalidated
            || self.intent_invalidated
            || self.directly_addressed
            || self.under_threat
            || self.reaction_window_open
            || self.received_new_salient_signal
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scene_snapshot_creation() {
        let snapshot = SceneSnapshot::new(
            "scene1",
            "turn1",
            serde_json::json!({"test": "data"}),
        );

        assert_eq!(snapshot.scene_id, "scene1");
        assert_eq!(snapshot.scene_turn_id, "turn1");
        assert!(snapshot.snapshot_id.contains("scene1"));
        assert!(snapshot.snapshot_id.contains("turn1"));
    }

    #[test]
    fn test_character_runtime_snapshot_creation() {
        let snapshot = CharacterRuntimeSnapshot::new(
            "char1",
            "turn1",
            serde_json::json!({}),
            serde_json::json!({"suspicion": 0.8}),
            serde_json::json!({"fear": 0.3}),
            serde_json::json!({}),
            serde_json::json!({"shortTerm": ["escape"]}),
        );

        assert_eq!(snapshot.character_id, "char1");
        assert_eq!(snapshot.scene_turn_id, "turn1");
    }

    #[test]
    fn test_turn_trace_builder() {
        let trace = TurnTrace::new("turn1")
            .with_perception(serde_json::json!({"noticed": ["fact1"]}))
            .with_belief_update(serde_json::json!({"new": "hypothesis"}))
            .with_intent_plan(serde_json::json!({"intent": "flee"}))
            .with_rendered_output(serde_json::json!({"dialogue": "I must go."}));

        assert_eq!(trace.scene_turn_id, "turn1");
        assert_eq!(trace.perception_packets.len(), 1);
        assert_eq!(trace.belief_updates.len(), 1);
        assert_eq!(trace.intent_plans.len(), 1);
    }

    #[test]
    fn test_memory_accessibility() {
        let mut memory = MemoryRecord::new(
            "mem1",
            "Secret information",
            "alice",
            MemoryVisibilityRecord::Private,
        );

        // Private memory only accessible to owner
        assert!(memory.is_accessible_to("alice"));
        assert!(!memory.is_accessible_to("bob"));

        // Make it shared
        memory.visibility = MemoryVisibilityRecord::Shared;
        memory.known_by = vec!["alice".to_string(), "bob".to_string()];

        assert!(memory.is_accessible_to("alice"));
        assert!(memory.is_accessible_to("bob"));
        assert!(!memory.is_accessible_to("charlie"));

        // Make it public
        memory.visibility = MemoryVisibilityRecord::Public;

        assert!(memory.is_accessible_to("anyone"));
    }

    #[test]
    fn test_dirty_flags() {
        let mut flags = DirtyFlagsRecord::new();

        assert!(!flags.is_dirty());

        flags.scene_changed = true;
        assert!(flags.is_dirty());

        flags.scene_changed = false;
        flags.under_threat = true;
        assert!(flags.is_dirty());
    }
}
