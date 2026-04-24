# RP Agent Runtime Execution Strategy Specification

Version: 0.1  
Status: Draft  
Audience: Backend / Runtime / Agent Orchestration / Cost Optimization / Performance Engineering

---

## 1. Document Scope

This document defines how the RP Agent system should work in actual runtime execution under the following engineering goals:

1. use deterministic program logic whenever possible,
2. minimize large-model calls,
3. preserve the conceptual architecture already defined in the framework and runtime protocol,
4. keep the system testable, cacheable, and cost-controllable.

This document is a companion to:
- `rp_agent_framework_spec.md`
- `rp_agent_runtime_protocol_spec.md`
- `rp_agent_prompt_skill_spec.md`
- `rp_agent_skill_system_spec.md`
- `rp_agent_multi_character_arbitration_spec.md`

This document focuses on **execution strategy**, not narrative philosophy.

---

## 2. Key Implementation Principle

The conceptual modules defined in the framework are **not** equal to one model call each.

The architecture should preserve conceptual separation while implementing a runtime that is mostly program-driven.

### Conceptual separation remains useful for:
- clean boundaries,
- testing,
- modularity,
- replacement,
- debugging.

### Runtime execution should be optimized for:
- fewer model calls,
- lower latency,
- lower token cost,
- better reproducibility.

Therefore:

**Conceptual modules may remain separate in protocol design, while runtime execution may fuse some of them into fewer actual calls.**

---

## 3. Runtime Layer Split

The recommended implementation uses three runtime layers.

```text
[Simulation Core]   -> program-first
[Cognitive Layer]   -> model only when needed
[Presentation Layer] -> model only when output rendering is needed
```

---

## 4. Simulation Core

The Simulation Core should be program-driven as much as possible.

It is responsible for:
- scene state maintenance,
- entity position and visibility,
- environment state,
- body state and resource updates,
- skill runtime generation,
- action candidate construction,
- feasibility validation,
- multi-character arbitration,
- reaction windows,
- clash and counterplay resolution,
- damage/status/resource/state changes,
- persistence and trace generation.

### Strong Recommendation
All of the above should be deterministic or semi-deterministic code whenever possible.

---

## 5. Cognitive Layer

The Cognitive Layer is where large models are actually useful.

It should be used for:
- subjective interpretation,
- bias-sensitive perception,
- belief change under ambiguity,
- intention generation,
- subtle social reasoning.

However, this layer should not be called continuously for every character.

### Core Optimization
Instead of separate calls for:
- PerceptionDistributor,
- BeliefUpdater,
- IntentAgent,

the runtime should fuse them into a single model call per active character when possible.

This fused call is referred to in this spec as:

**`CharacterCognitivePass`**

---

## 6. Presentation Layer

The Presentation Layer should generate:
- dialogue,
- visible motion description,
- narrated outcome packaging,
- stylistic rendering of already-resolved events.

This layer should not determine what actually happened.
It should verbalize what the runtime has already resolved.

A recommended fused output call is:

**`SurfaceRealizer`**

---

## 7. Recommended Model Calls

Under this strategy, the system should ideally expose only two model-facing runtime call types.

## 7.1 `CharacterCognitivePass`
Input:
- filtered scene view,
- embodiment state,
- current body/resources/statuses,
- current beliefs,
- relation models,
- goals,
- recent event delta.

Output:
- perception delta,
- belief update,
- intent plan.

## 7.2 `SurfaceRealizer`
Input:
- arbitration result,
- visible effects,
- current speakers/actors,
- style/tone constraints.

Output:
- rendered dialogue,
- narrated action text,
- visible scene update prose.

### Important
Everything else should remain programmatic unless there is a very strong reason not to.

---

## 8. Mapping Conceptual Modules to Runtime Calls

### Conceptual Modules
- SceneStateExtractor
- EmbodimentResolver
- PerceptionDistributor
- BeliefUpdater
- IntentAgent
- ActionSelector / Arbitration
- SurfaceRealizer
- StateCommitter

### Runtime Execution Mapping

| Conceptual Module | Runtime Strategy |
|---|---|
| SceneStateExtractor | programmatic if input world is already structured; model-assisted only when ingesting raw text |
| EmbodimentResolver | programmatic |
| PerceptionDistributor | fused into CharacterCognitivePass |
| BeliefUpdater | fused into CharacterCognitivePass |
| IntentAgent | fused into CharacterCognitivePass |
| Arbitration / Conflict Resolution | programmatic |
| SurfaceRealizer | model-assisted |
| StateCommitter | programmatic |

This is the recommended execution strategy for low-call, high-control operation.

---

## 9. Input Modes

The execution strategy should support two main operating modes.

## 9.1 Structured World Mode
Used when the application itself owns the world state.

Examples:
- game-like runtime,
- editor-driven narrative simulation,
- internal structured event system,
- deterministic position/state handling.

In this mode:
- scene extraction should be almost entirely programmatic,
- the model is used mostly for cognition and presentation.

## 9.2 Text Ingestion Mode
Used when the system receives free-form narrative text or free-form user scene updates.

In this mode:
- a model-assisted SceneStateExtractor or text-to-delta parser may be needed,
- the resulting structured state should still be normalized and stored programmatically afterward.

---

## 10. Event-Driven Runtime, Not Constant Full Recompute

The runtime should be event-driven.

Do not recompute every layer for every character on every micro-step.

Instead:
- update deterministic world state,
- compute changed event delta,
- mark which characters are affected,
- call the cognitive layer only for characters who actually need re-evaluation.

---

## 11. Active Set and Dirty Flags

A large-model cognitive pass should only run for characters who are both:
- active in the current local scene window,
- dirty enough to require new cognition.

## 11.1 Active Set
A character should be in the active set when at least one of the following is true:
- directly addressed,
- physically threatened,
- in a reaction window,
- intent needs to be expressed now,
- gained or lost relevant information,
- scene changes materially near them,
- their prior intent became invalid.

## 11.2 Dirty Flags
Recommended per-character dirty flags:

```yaml
dirty_flags:
  scene_changed: false
  body_changed: false
  relation_changed: false
  belief_invalidated: false
  intent_invalidated: false
  directly_addressed: false
  under_threat: false
  reaction_window_open: false
  received_new_salient_signal: false
```

A cognitive pass should only run when the character is in the active set and at least one relevant dirty flag is true.

---

## 12. Intent Persistence and Reuse

A character should not need a new intent every micro-step.

If the previous intent remains valid, executable, and not meaningfully contradicted by new information, the system may keep it active.

Examples:
- continuing retreat,
- continuing a held barrier,
- continuing observation,
- continuing to answer the current speaker,
- continuing pursuit.

This reduces calls significantly.

---

## 13. Programmatic Default Policies

Not every character should use model cognition at all times.

The runtime should support policy tiers.

## 13.1 Tier A: Full Cognitive Characters
Use full `CharacterCognitivePass`.

Examples:
- protagonist,
- major companions,
- main antagonist,
- socially or psychologically complex figures.

## 13.2 Tier B: Simplified Rule-Based Characters
Use deterministic or template-based behavior unless scene complexity forces escalation.

Examples:
- guards,
- assistants,
- minor named NPCs.

## 13.3 Tier C: Crowd / Background Characters
Use purely programmatic policy.

Examples:
- bystanders,
- background servants,
- crowd panic behaviors,
- low-importance combatants.

---

## 14. CharacterCognitivePass Specification

## 14.1 Purpose
A fused model call that performs the work of:
- subjective perception update,
- belief assimilation,
- intent generation.

## 14.2 Input

```yaml
character_cognitive_pass_input:
  character_id: ""
  filtered_scene_view: {}
  embodiment_state: {}
  body_state: {}
  resources: {}
  active_status_effects: []
  prior_belief_state: {}
  relation_models: {}
  emotion_state: {}
  current_goals: {}
  recent_event_delta: []
  memory_refs: []
```

## 14.3 Output

```yaml
character_cognitive_pass_output:
  character_id: ""
  perception_delta: {}
  belief_update: {}
  intent_plan: {}
```

## 14.4 Rule
This call may internally preserve conceptual separation in the prompt/output, but it should still be executed as one runtime model call whenever possible.

---

## 15. SurfaceRealizer Specification

## 15.1 Purpose
Converts resolved outcomes into player/user-visible output.

## 15.2 Input

```yaml
surface_realizer_input:
  scene_turn_id: ""
  arbitration_result: {}
  visible_scene_changes: []
  speaker_order: []
  tone_profile: {}
  style_constraints: {}
```

## 15.3 Output

```yaml
surface_realizer_output:
  rendered_text: ""
  dialogue_blocks: []
  visible_action_descriptions: []
```

## 15.4 Rule
SurfaceRealizer should not invent hidden motivations or unresolved outcomes.
It must render already-resolved state.

---

## 16. Recommended Main Loop

The runtime loop should be built around deterministic ticks or scene windows.

## 16.1 Main Loop Outline

```text
1. Apply world and user input delta
2. Update structured scene state
3. Update body/resources/status effects/cooldowns
4. Generate event delta
5. Compute active set + dirty flags
6. Run CharacterCognitivePass only for active & dirty characters
7. Build action candidates
8. Generate runtime skill instances if needed
9. Run feasibility validation
10. Run arbitration / reaction / clash / effect resolution
11. Commit updated state
12. Call SurfaceRealizer if visible output is needed
```

---

## 17. Where Program Logic Should Dominate

The following subsystems should be code-first.

## 17.1 Scene State
- position,
- line of sight,
- obstacle presence,
- lighting,
- smell source propagation,
- sound propagation,
- item ownership,
- area state.

## 17.2 Body and Resources
- vitality/mana/spirit/soul_stability,
- wounds,
- fatigue,
- cooldowns,
- sensory impairment,
- status effects.

## 17.3 Skill Runtime Generation
- template + binding + status + resources + environment → runtime skill instance.

## 17.4 Arbitration
- conflict clustering,
- reaction windows,
- timing comparison,
- delivery validity,
- hit/resist/counter/clash logic,
- effect outcome.

## 17.5 State Commit
- persistence,
- turn trace,
- belief/emotion deltas,
- scene consequences.

---

## 18. Where Models Are Actually Valuable

The model should be used where deterministic code is weak or expensive to author by hand.

## 18.1 Subjective Interpretation
Examples:
- what a hesitant tone means to a proud character,
- whether a suspicious character treats a pause as concealment,
- how an emotionally hurt character reinterprets an ambiguous gesture.

## 18.2 Intent Selection Under Ambiguity
Examples:
- whether to probe, hide, lie, retreat, attack, stall, or seek reassurance.

## 18.3 Linguistic Rendering
Examples:
- dialogue wording,
- emotional action narration,
- style-constrained prose.

---

## 19. Caching and Reuse Strategy

To reduce calls, the runtime should support caching.

## 19.1 Cognitive Cache Conditions
A recent cognitive output may be reused if:
- filtered scene view did not materially change,
- no relevant dirty flag fired,
- body state is stable,
- relation model did not change,
- prior intent remains valid,
- no new salient event arrived.

## 19.2 Presentation Cache Conditions
Rendered output fragments or style-conditioned wording may be cached for repeated templates or low-complexity minor NPC output.

---

## 20. Event Batching

Small event fragments should be batched before model invocation.

Bad pattern:
- model call for every single micro-event.

Recommended pattern:
- accumulate local event delta for the scene window,
- trigger one cognitive pass per affected character for the batch.

This significantly reduces call count without losing most of the causal chain.

---

## 21. Model Escalation Policy

Not every situation needs the same depth of model reasoning.

Recommended escalation:

### Level 0: No Model
Use deterministic policy only.

### Level 1: Lightweight Cognitive Pass
Use when one character needs ordinary social or tactical update.

### Level 2: Full Cognitive Pass
Use when ambiguity, emotional contradiction, or high-stakes conflict is significant.

### Level 3: Enhanced Rendering
Use only when a user-visible dramatic or stylistic output is required.

---

## 22. Example Execution: Simple Social Scene

Scene:
- two characters in low tension conversation,
- no major body state changes,
- no overt skills,
- no object conflict.

Recommended runtime:
- program updates scene and floor state,
- only the directly addressed character gets a cognitive pass if needed,
- response may even be template-driven if low importance,
- single SurfaceRealizer call if output is shown.

Possible model calls:
- 0 or 1 cognitive pass,
- 1 surface realization.

---

## 23. Example Execution: Wind Blade Attack

Scene:
- Character A decides to cast wind blade,
- Character B may dodge,
- Character C may raise barrier.

Recommended runtime:
- A's intent generation may require one cognitive pass,
- runtime skill instance generated programmatically,
- notice timing calculated programmatically,
- B and C only get cognitive calls if actually active and dirty,
- arbitration, dodge, barrier, hit, damage, and statuses are programmatic,
- surface realization is model-assisted only for final narration.

Possible model calls:
- 1 to 3 cognitive passes depending on scene complexity,
- 1 surface realization.

Not recommended:
- a separate model call for hit check,
- a separate model call for shield interaction,
- a separate model call for damage outcome.

---

## 24. Example Execution: Charm Gaze

Scene:
- Character A attempts charm gaze,
- Character B may notice the channel,
- B's belief and intent may shift if affected.

Recommended runtime:
- A's intent may require one cognitive pass,
- channel establishment and detectability are programmatic from runtime skill instance,
- B only gets a cognitive pass if the effect or attempted effect becomes salient,
- the success tier is programmatic,
- B's changed interpretation and intent after the effect may require one cognitive pass,
- final visible text is rendered once.

Important distinction:
- charm success tier is programmatic,
- subjective reinterpretation after charm is cognitive.

---

## 25. Minimal Call Budget Strategy

For cost-sensitive deployment, the recommended baseline per scene window is:

- 0 to 2 cognitive passes for important active characters,
- 0 cognitive passes for most minor/background entities,
- 1 surface realization only when user-visible output is required.

Everything else should remain code-first.

---

## 26. Logging and Trace Requirements

To keep the hybrid runtime debuggable, the following should be logged:
- active set composition,
- dirty flag state,
- whether a cognitive call was triggered and why,
- runtime skill instance generation summary,
- arbitration summary,
- state delta,
- final presentation payload.

This is important for both debugging and call-cost analysis.

---

## 27. Validation Rules for This Execution Strategy

## 27.1 Over-Calling Rule
Flag if the runtime repeatedly invokes the model for characters without relevant dirty flags.

## 27.2 Under-Calling Rule
Flag if a character's belief/intent clearly should update but the runtime suppresses the cognitive pass incorrectly.

## 27.3 Program/Model Boundary Rule
Flag if deterministic subsystems such as hit checks, timing resolution, or resource application drift into uncontrolled model inference.

## 27.4 Render-Only Rule
Flag if SurfaceRealizer invents unresolved outcomes.

## 27.5 Cache Safety Rule
Flag if cached cognition is reused after material scene or state change.

---

## 28. Implementation Recommendations

## 28.1 Maintain Structured State as the Source of Truth
Never treat model prose as the authoritative state.

## 28.2 Keep Runtime Skill Generation Programmatic
This improves reproducibility and keeps combat/counterplay predictable.

## 28.3 Use Dirty-Flag Gating Aggressively
This is one of the highest-leverage call reduction methods.

## 28.4 Separate Major and Minor NPC Policies
Do not spend equal cognitive budget on all entities.

## 28.5 Prefer Event Batching
Avoid per-micro-event model calls.

## 28.6 Let Models Interpret, Not Simulate Physics
Physical, timing, and resource logic should remain in code.

---

## 29. Non-Goals of This Document

This document does not define:
- exact database tables,
- exact model prompt wording,
- exact numeric formulas for every skill,
- UI/editor workflow,
- benchmarking methodology.

Those should live in companion documents.

---

## 30. Implementation Reference

### 30.1 Dart Implementation

The execution strategy is implemented in `lib/core/services/agent/`:

```
services/agent/
├── scene_state_extractor.dart      # Programmatic scene extraction
├── embodiment_resolver.dart        # Programmatic embodiment resolution
├── scene_filtering_protocol.dart   # Programmatic scene filtering
├── memory_access_protocol.dart     # Programmatic memory access
├── character_input_assembly.dart   # Programmatic input assembly
├── character_cognitive_pass.dart   # Fused cognitive pass (model call)
├── cognitive_pass_executor.dart    # Orchestrates belief + intent updates
├── action_arbitration.dart         # Programmatic arbitration
├── surface_realizer.dart           # Presentation layer (model call)
├── agent_runtime.dart              # Main loop orchestrator
└── validation/                     # Programmatic validation
    ├── agent_validator.dart
    ├── omniscience_leakage_rule.dart
    ├── embodiment_ignored_rule.dart
    ├── memory_leakage_rule.dart
    └── mana_sense_validation_rule.dart
```

### 30.2 AgentRuntime Main Loop

```dart
class AgentRuntime {
  Future<AgentTurnResult> processTurn(AgentTurnRequest request) async {
    // 1. Extract scene state (programmatic)
    final scene = await _sceneExtractor.extract(...);

    // 2. Compute active set and dirty flags (programmatic)
    final activeIds = _resolveActiveCharacterIds(request);

    // 3. For each active & dirty character:
    for (final characterId in activeIds) {
      if (!_isDirty(characterId)) continue;

      // 3a. Assemble input (programmatic)
      final input = await _inputAssembly.assemble(...);

      // 3b. Execute cognitive pass (model call)
      final output = await _cognitivePassExecutor.execute(...);

      // 3c. Validate output (programmatic)
      final validationResults = _validator.validate(...);
    }

    // 4. Arbitrate actions (programmatic)
    final arbitration = _actionArbitration.arbitrate(...);

    // 5. Render output (model call)
    final rendered = _surfaceRealizer.render(...);

    return AgentTurnResult(...);
  }
}
```

### 30.3 Dirty Flags Implementation

```dart
class DirtyFlags {
  bool sceneChanged = false;
  bool bodyChanged = false;
  bool relationChanged = false;
  bool beliefInvalidated = false;
  bool intentInvalidated = false;
  bool directlyAddressed = false;
  bool underThreat = false;
  bool reactionWindowOpen = false;
  bool receivedNewSalientSignal = false;

  bool get isDirty =>
      sceneChanged ||
      bodyChanged ||
      relationChanged ||
      beliefInvalidated ||
      intentInvalidated ||
      directlyAddressed ||
      underThreat ||
      reactionWindowOpen ||
      receivedNewSalientSignal;
}
```

### 30.4 Character Tier Policy

```dart
enum CharacterTier {
  tierA,  // Full cognitive pass
  tierB,  // Simplified rule-based
  tierC,  // Programmatic only
}

class CognitivePassExecutor {
  Future<ExecutionResult> execute(
    CognitivePassExecutionRequest request, {
    required CharacterTier tier,
  }) async {
    return switch (tier) {
      CharacterTier.tierA => await _executeFullCognitivePass(request),
      CharacterTier.tierB => await _executeSimplifiedPass(request),
      CharacterTier.tierC => _executeProgrammaticPass(request),
    };
  }
}
```

### 30.5 Rust Persistence Layer

The persistence layer in `rust/src/agent/` provides efficient state storage:

```rust
// Scene snapshots
let snapshot = SceneSnapshot::new("scene1", "turn1", scene_model_json);
storage.save_scene_snapshot(&snapshot)?;

// Character state
let char_snapshot = CharacterRuntimeSnapshot::new(
    "char1", "turn1",
    relationship_models, belief_state, emotion_state,
    body_state, goals,
);
storage.save_character_snapshot(&char_snapshot)?;

// Turn traces for debugging
let trace = TurnTrace::new("turn1")
    .with_perception(perception_json)
    .with_belief_update(belief_json)
    .with_intent_plan(intent_json)
    .with_validation(validation_record);
storage.save_turn_trace(&trace)?;
```

### 30.6 Call Budget Monitoring

```dart
class CallBudgetMonitor {
  int cognitivePassCount = 0;
  int surfaceRealizerCount = 0;
  int validationWarningCount = 0;

  void recordCognitivePass(String characterId, String reason) {
    cognitivePassCount++;
    log.info('Cognitive pass for $characterId: $reason');
  }

  void recordSurfaceRealizer(String sceneTurnId) {
    surfaceRealizerCount++;
  }

  BudgetReport generateReport() {
    return BudgetReport(
      cognitivePasses: cognitivePassCount,
      surfaceRealizations: surfaceRealizerCount,
      warnings: validationWarningCount,
    );
  }
}
```

---

## 31. Summary

This execution strategy keeps the RP Agent system practical for real deployment.

The core rule is:

- the world runs in code,
- bodies, resources, skills, and conflict resolve in code,
- the model is called only when subjective cognition or user-facing expression is needed,
- multiple conceptual modules may be fused into one runtime model call,
- only active and dirty characters should receive cognitive inference.

This allows the system to preserve the architecture's psychological depth while staying cost-aware, testable, and deliverable.

