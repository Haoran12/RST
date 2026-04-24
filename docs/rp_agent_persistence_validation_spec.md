# RP Agent Persistence and Validation Specification

Version: 0.1  
Status: Draft  
Audience: Backend / Storage / Runtime / QA / Evaluation

---

## 1. Document Scope

This document defines how RP Agent runtime state should be persisted, committed, validated, and monitored.

It is the implementation companion to:
- `rp_agent_framework_spec.md`
- `rp_agent_runtime_protocol_spec.md`
- `rp_agent_prompt_skill_spec.md`

This document covers:
- persistent state categories,
- commit flow,
- versioning and migration guidance,
- validation rules,
- regression and failure cases,
- acceptance criteria.

This document does **not** redefine runtime schemas. Runtime object definitions belong to `rp_agent_runtime_protocol_spec.md`.

---

## 2. Why Persistence and Validation Need Their Own Document

A character-centered RP system will drift unless it has reliable persistence and validation.

Without a dedicated persistence / validation layer, common failures include:
- belief state reset or flattening,
- relation drift without cause,
- body state being forgotten after one turn,
- hidden information accidentally leaking between turns,
- prompt changes silently breaking character consistency,
- non-human sensory traits becoming decorative over time.

Therefore persistence and validation must be treated as first-class system design concerns.

---

## 3. Persistence Goals

The persistence layer must support:

1. state continuity across turns,
2. separation of stable vs transient state,
3. incremental state updates,
4. reproducibility and debugging,
5. rollback and traceability,
6. evaluation against consistency rules.

---

## 4. Persistent State Categories

The system should persist at least the following categories.

## 4.1 Character Static State
Rarely changes.

Examples:
- identity,
- species,
- long-term traits,
- values,
- baseline sensory profile,
- stable worldview,
- self-image,
- defense patterns.

## 4.2 Character Semi-Stable State
Changes occasionally.

Examples:
- relation model,
- long-term beliefs,
- loyalties,
- recurring fears,
- known secrets,
- learned habits,
- long-term wounds or conditions.

## 4.3 Character Transient Runtime State
Changes frequently.

Examples:
- current emotions,
- current goals,
- temporary body state,
- temporary injuries,
- fatigue,
- current hypotheses,
- present suspicion level,
- immediate intent history.

## 4.4 Scene State
Turn-local or scene-local.

Examples:
- current location layout,
- lighting state,
- object positions,
- active environmental signals,
- event stream.

## 4.5 Turn History State
Useful for replay, debugging, and memory extraction.

Examples:
- perception packets,
- belief updates,
- intent plans,
- rendered outputs,
- commit deltas.

---

## 5. Recommended Persistence Model

Recommended separation:

### Static Layer
Store in durable structured form:
- YAML / JSON source files for authored defaults,
- mirrored DB representation for runtime access.

### Runtime Layer
Store in database / structured state store:
- current character runtime state,
- scene state,
- turn-level outputs,
- delta history.

### Trace Layer
Store append-only or snapshot history for debugging:
- per-turn scene snapshot,
- per-turn embodiment state,
- per-turn perception packet,
- per-turn belief update,
- per-turn intent plan,
- validation results.

---

## 6. Suggested Persistent Objects

## 6.1 Character Record

```yaml
character_record:
  character_id: ""
  static_profile: {}
  baseline_body_profile: {}
  mind_model_card: {}
  authored_metadata: {}
```

## 6.2 Character Runtime Snapshot

```yaml
character_runtime_snapshot:
  snapshot_id: ""
  character_id: ""
  scene_turn_id: ""
  relationship_models: {}
  belief_state: {}
  emotion_state: {}
  temporary_body_state: {}
  embodiment_state: {}
  current_goals: {}
```

## 6.3 Scene Snapshot

```yaml
scene_snapshot:
  snapshot_id: ""
  scene_id: ""
  scene_turn_id: ""
  scene_model: {}
```

## 6.4 Turn Trace

```yaml
turn_trace:
  trace_id: ""
  scene_turn_id: ""
  perception_packets: []
  belief_updates: []
  intent_plans: []
  rendered_output: {}
  commit_delta: {}
  validation_results: []
```

---

## 7. Commit Flow

Recommended commit order after each turn:

```text
rendered turn output produced
→ compute world consequence delta
→ compute character state deltas
→ validate deltas
→ persist turn trace
→ persist new runtime snapshots
→ update current active state pointers
```

---

## 8. What Must Be Committed Every Turn

At minimum, the following should be committed:

1. updated emotion state,
2. updated belief state,
3. updated temporary body state,
4. updated relation deltas if any,
5. scene consequences,
6. rendered output summary,
7. validation report.

Optional but strongly recommended:
- full perception packet,
- full belief update packet,
- selected and rejected intents,
- signal salience traces,
- memory write candidates.

---

## 9. State Delta Strategy

Do not rewrite the entire world state every time unless necessary.

Recommended strategy:
- keep current active snapshot,
- write per-turn delta,
- periodically produce compacted snapshots.

Useful benefits:
- lower storage overhead,
- easier replay,
- better debugging,
- cleaner rollback.

---

## 10. Memory Persistence Guidance

Not every turn-level detail should become long-term memory.

Suggested memory categories:

### Episodic Memory Candidates
Scene-specific remembered events.

### Relation Memory Candidates
Events that should change trust, resentment, gratitude, fear, or obligation.

### Belief Memory Candidates
Repeatedly reinforced beliefs or strong new conclusions.

### Body/Trauma Memory Candidates
Events that create lasting fear triggers or physical caution patterns.

Suggested rule:
- transient inference should not automatically become stable long-term memory,
- repeated or high-impact events should be eligible for consolidation.

---

## 11. Versioning and Migration Guidance

All major persisted objects should include:
- schema version,
- creation timestamp,
- last updated timestamp.

Recommended fields:

```yaml
meta:
  schema_version: "0.1"
  created_at: ""
  updated_at: ""
```

When schema changes:
- runtime code should know how to migrate old snapshots,
- validation should detect incompatible legacy objects,
- document set version should be updated.

---

## 12. Validation Layers

Validation should exist at multiple layers.

## 12.1 Shape Validation
Check whether output matches schema.

Examples:
- missing required keys,
- invalid enum values,
- confidence outside 0.0–1.0,
- malformed arrays.

## 12.2 Access Validation
Check for knowledge leakage.

Examples:
- character references hidden truth,
- belief update uses inaccessible cues,
- intent depends on unseen facts.

## 12.3 Embodiment Validation
Check whether body state materially influences output.

Examples:
- blindfolded character relying on eye contact,
- injured character unaffected in action feasibility,
- hypersensitive smell trait never appearing.

## 12.4 Consistency Validation
Check continuity across turns.

Examples:
- belief reversal without trigger,
- sudden relation jump without cause,
- body injury disappearing without treatment,
- stable self-image breaking without narrative cause.

## 12.5 Prompt Drift Validation
Check whether current model behavior still honors module scope.

Examples:
- PerceptionDistributor producing action plans,
- BeliefUpdater resolving objective truth too often,
- IntentAgent becoming globally optimal rather than character-consistent.

---

## 13. Core Validation Rules

## 13.1 Omniscience Leakage Rule
Flag if any character-facing output contains unsupported hidden information.

## 13.2 Cue/Interpretation Collapse Rule
Flag if perception output turns subjective impression into unqualified fact.

## 13.3 Embodiment Ignored Rule
Flag if body constraints do not materially affect access, reasoning, or intent.

## 13.4 Ambiguity Flattening Rule
Flag if uncertain evidence is repeatedly resolved as certainty without enough support.

## 13.5 Character Consistency Rule
Flag if selected intent contradicts stable self-image, values, or relation strategy without sufficient trigger.

## 13.6 Persistence Continuity Rule
Flag if stable state shifts occur without corresponding causal events.

---

## 14. Example Validation Scenarios

## 14.1 Blindfolded Character Failure
Input:
- vision blocked,
- no alternative visual aid.

Failure output:
- "He notices the other person's expression tighten."

Expected validation:
- fail embodiment validation,
- fail access validation.

## 14.2 Fox Spirit Smell Failure
Input:
- strong smell acuity,
- fresh blood smell present.

Failure output:
- no smell-related perception across several relevant turns.

Expected validation:
- warning or failure for species trait underuse.

## 14.3 Injury Persistence Failure
Input:
- previous turn: severe leg injury.

Failure output:
- next turn: normal mobility, no explanation.

Expected validation:
- fail continuity validation.

## 14.4 Plot-Optimal Intent Failure
Input:
- suspicious, proud, emotionally hurt character.

Failure output:
- immediately chooses perfectly balanced diplomatic truth-seeking move every time.

Expected validation:
- warning for character-flattening or prompt drift.

---

## 15. Acceptance Criteria for Implementation

The system should be considered minimally acceptable only if it demonstrates the following in repeated tests:

1. distinct characters in the same scene form distinct perception packets,
2. body state changes perception and action feasibility,
3. hidden information does not leak into character-facing reasoning,
4. belief ambiguity persists when evidence is incomplete,
5. non-human sensory traits materially matter,
6. state continuity survives across multiple turns,
7. validation can detect obvious drift and leakage failures.

---

## 16. Recommended Test Categories

1. sensory limitation tests,
2. non-human sensory advantage tests,
3. fatigue / pain cognitive narrowing tests,
4. relation-bias interpretation tests,
5. contradiction preservation tests,
6. multi-character asymmetric knowledge tests,
7. continuity across long scenes,
8. persistence migration tests.

---

## 17. Operational Monitoring Suggestions

In production-like runtime, record at least:
- validation pass/fail counts,
- omniscience leakage incidents,
- embodiment ignored incidents,
- belief consistency anomalies,
- missing persistence fields,
- schema mismatch rates.

This helps detect gradual prompt drift or runtime regression.

---

## 18. Scene Filtering Validation Rules

### 18.1 Vision Blocking Validation
**Rule**: If `embodiment_state.sensory_capabilities.vision.availability < 0.1`
**Check**: `filtered_scene_view.visible_entities` must be empty
**Failure**: Flag as `embodiment_ignored`

### 18.2 Hearing Blocking Validation
**Rule**: If `embodiment_state.sensory_capabilities.hearing.availability < 0.1`
**Check**: `filtered_scene_view.audible_signals` must be empty
**Failure**: Flag as `embodiment_ignored`

### 18.3 Smell Blocking Validation
**Rule**: If `embodiment_state.sensory_capabilities.smell.availability < 0.1`
**Check**: `filtered_scene_view.olfactory_signals` must be empty
**Failure**: Flag as `embodiment_ignored`

### 18.4 Entity Visibility Validation
**Rule**: All entities in `filtered_scene_view.visible_entities`
**Check**: Must satisfy line-of-sight from `character_position`
**Failure**: Flag as `access_boundary_violation`

---

## 19. Memory Access Validation Rules

### 19.1 Known_By Validation
**Rule**: For any memory in `accessible_memories`
**Check**: `character_id` must be in `memory.known_by` OR `memory.visibility = public`
**Failure**: Flag as `memory_leakage`

### 19.2 Private Memory Validation
**Rule**: If `memory.visibility = private`
**Check**: `memory.known_by` must equal `[memory.owner_character_id]`
**Failure**: Flag as `visibility_inconsistency`

### 19.3 Cognitive Pass Leakage Validation
**Rule**: Character cognitive pass output
**Check**: Must not reference:
  - Memories not in `accessible_memories`
  - Entities not in `filtered_scene_view`
  - World truth not derivable from filtered inputs
**Failure**: Flag as `omniscience_leakage`

---

## 20. Non-Goals of This Document

This document does not define:
- exact DB table SQL,
- full observability dashboard design,
- evaluation UI,
- worldbook compatibility conversion,
- prompt wording itself.

Those should be separate documents if needed.

---

## 21. Implementation Reference

### 21.1 Dart Validation Module

The validation layer is implemented in `lib/core/services/agent/validation/`:

```
validation/
├── validation.dart              # Module exports
├── validation_rule.dart         # Base class for all rules
├── agent_validator.dart         # Aggregator and runner
├── omniscience_leakage_rule.dart
├── embodiment_ignored_rule.dart
├── memory_leakage_rule.dart
└── mana_sense_validation_rule.dart
```

#### AgentValidator Usage

```dart
final validator = AgentValidator.withDefaultRules();
final results = validator.validate(
  filteredView: filteredView,
  embodimentState: embodimentState,
  output: cognitiveOutput,
  accessibleMemories: memories,
);

if (validator.hasErrors(results)) {
  // Handle validation failures
  final report = validator.generateReport(results);
  log.warning(report);
}
```

#### Custom Validation Rules

```dart
class CustomRule extends ValidationRule {
  @override
  String get ruleId => 'custom_rule';

  @override
  String get description => 'Description of what this rule checks';

  @override
  List<ValidationResult> validate({
    required FilteredSceneView filteredView,
    required EmbodimentState embodimentState,
    required CharacterCognitivePassOutput? output,
    required List<MemoryEntry> accessibleMemories,
  }) {
    final results = <ValidationResult>[];
    // Validation logic here
    return results;
  }
}

// Add to validator
final validator = AgentValidator.withDefaultRules()
    .withRule(CustomRule());
```

### 21.2 Rust Persistence Layer

The persistence layer is implemented in `rust/src/agent/`:

```
agent/
├── mod.rs        # Module exports
├── models.rs     # Data models
└── storage.rs    # Storage implementation
```

#### Storage Usage

```rust
use rst_core::agent::{AgentStorage, SceneSnapshot, CharacterRuntimeSnapshot, MemoryRecord};

let storage = AgentStorage::new("./data/agent");

// Save scene snapshot
let snapshot = SceneSnapshot::new("scene1", "turn1", scene_model_json);
storage.save_scene_snapshot(&snapshot)?;

// Save character state
let char_snapshot = CharacterRuntimeSnapshot::new(
    "char1", "turn1",
    relationship_models, belief_state, emotion_state,
    body_state, goals,
);
storage.save_character_snapshot(&char_snapshot)?;

// Query memories
let memories = storage.list_memories_for_character("alice")?;
```

#### Memory Access Control

```rust
let memory = MemoryRecord::new(
    "mem1",
    "Secret information",
    "alice",
    MemoryVisibilityRecord::Private,
);

// Check access
assert!(memory.is_accessible_to("alice"));
assert!(!memory.is_accessible_to("bob"));
```

### 21.3 Data File Structure

```
data/agent/
├── scenes/
│   ├── snapshot_scene1_turn1.json
│   └── snapshot_scene1_turn2.json
├── characters/
│   ├── char_alice_turn1.json
│   └── char_bob_turn1.json
├── memories/
│   ├── mem1.json
│   └── mem2.json
└── traces/
    ├── trace_turn1.json
    └── trace_turn2.json
```

---

## 22. Summary

This document defines how RP Agent state is stored, committed, and checked.

Its purpose is to ensure that the framework remains stable over time:
- characters remember coherently,
- bodies remain meaningful,
- beliefs remain traceable,
- hidden information stays contained,
- regressions become detectable.

Without this layer, the architecture may look correct on paper while drifting in actual runtime behavior.

