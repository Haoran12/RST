# RP Agent Runtime Protocol Specification

Version: 0.1  
Status: Draft  
Audience: Backend / Runtime / Orchestration / Data Modeling

---

## 1. Document Scope

This document defines the runtime contracts and handoff protocols for the RP Agent framework.

It is the implementation companion to `rp_agent_framework_spec.md`.

This document defines:
- runtime object schemas,
- module input/output contracts,
- orchestration order,
- data access boundaries,
- handoff rules between modules.

This document does **not** define exact prompt wording. Prompt implementation belongs to `rp_agent_prompt_skill_spec.md`.

---

## 2. Runtime Pipeline

```text
Narrative Input / World State / Event Log
  ↓
[SceneStateExtractor]
  ↓
scene_model
  ↓
[EmbodimentResolver] (per character)
  ↓
embodiment_state
  ↓
[PerceptionDistributor] (per character)
  ↓
character_perception_packet
  ↓
[BeliefUpdater] (per character)
  ↓
character_belief_update
  ↓
[IntentAgent] (per character)
  ↓
character_intent_plan
  ↓
[ActionSelector / SurfaceRealizer]
  ↓
rendered_output
  ↓
[StateCommitter]
```

---

## 3. Shared Conventions

## 3.1 IDs
Every major runtime object should be versionable and traceable by IDs.

Recommended fields:
- `scene_id`
- `scene_turn_id`
- `character_id`
- `signal_id`
- `event_id`

## 3.2 Confidence Range
All probabilistic or graded fields should use normalized numeric values:
- minimum: `0.0`
- maximum: `1.0`

Examples:
- visibility,
- accessibility,
- confidence,
- salience,
- urgency,
- pain load,
- fatigue,
- trust.

## 3.3 Unknown Handling
If information is missing or ambiguous:
- prefer `unknown`, `null`, or explicit uncertainty notes,
- do not fabricate unsupported certainty.

---

## 4. Character Runtime State

This object contains the persistent and semi-persistent runtime state needed across turns.

```yaml
character_runtime_state:
  character_id: ""

  profile:
    traits: []
    values: []
    cognitive_style: {}
    social_style: {}

  mind_model_card:
    self_image: ""
    worldview: []
    social_logic: []
    fear_triggers: []
    defense_patterns: []
    desire_patterns: []

  relationship_models: {}
  belief_state: {}
  emotion_state: {}

  baseline_body_profile: {}
  temporary_body_state: {}
  embodiment_state: {}

  current_goals: {}
  memory_index_refs: []
```

---

## 5. SceneStateExtractor Protocol

## 5.1 Responsibility
Convert narrative/world input into a structured scene model suitable for sensory access analysis.

## 5.2 Input

```yaml
scene_extractor_input:
  world_state_delta: {}
  narrative_input: ""
  event_log_delta: []
  prior_scene_state: {}
```

## 5.3 Output: `scene_model`

```yaml
scene_model:
  scene_id: ""
  scene_turn_id: ""

  time_context:
    time_of_day: ""
    weather: ""
    visibility_condition: ""
    ambient_context_notes: []

  spatial_layout:
    scene_type: room|street|forest|courtyard|cave|hallway|unknown
    dimensions_estimate: ""
    subareas:
      - id: ""
        name: ""
        description: ""
    obstacles:
      - id: ""
        type: wall|screen|table|curtain|tree|crowd|furniture|terrain
        location: ""
        blocks_vision: true
        blocks_sound: false
        blocks_smell: false
        blocks_movement: false
    entry_points:
      - id: ""
        type: door|window|path|corridor|gate
        state: open|closed|ajar|blocked|unknown
        location: ""

  lighting:
    overall_level: bright|normal|dim|very_dim|dark
    source_points:
      - id: ""
        type: candle|torch|window_light|moonlight|electric|fire|unknown
        intensity: 0.0
        location: ""
    shadow_zones:
      - area_id: ""
        severity: 0.0
    backlight_zones:
      - area_id: ""
        severity: 0.0
    flicker: 0.0
    visual_noise: []

  acoustics:
    ambient_noise_level: 0.0
    ambient_sources:
      - type: rain|wind|crowd|machine|insects|water|fire|unknown
        intensity: 0.0
    reflective_quality: open|muffled|echoing|enclosed|mixed

  olfactory_field:
    overall_density: 0.0
    airflow: still|weak|flowing|gusty|variable
    odor_sources:
      - id: ""
        type: blood|medicine|incense|rot|soil|alcohol|sweat|flower|smoke|metal|unknown
        intensity: 0.0
        freshness: fresh|recent|old|unknown
        spread_range: 0.0
        source_position: ""
    interfering_odors: []

  physical_atmosphere:
    temperature: cold|cool|neutral|warm|hot|unknown
    humidity: 0.0
    airflow:
      strength: 0.0
      direction: ""
    surface_conditions:
      - area: ""
        condition: wet|dusty|slippery|rough|unstable|soft|hard

  entities:
    characters:
      - id: ""
        location: ""
        posture: standing|sitting|leaning|kneeling|lying|moving|unknown
        orientation: ""
        visibility_profile:
          silhouette_clear: true
          face_clear: false
          hands_clear: false
    objects:
      - id: ""
        type: ""
        location: ""
        notable_properties: []

  observable_signals:
    visual_signals:
      - signal_id: ""
        content: ""
        location: ""
        size_or_visibility: 0.0
        persistence: transient|stable
        ambiguity: 0.0
    auditory_signals:
      - signal_id: ""
        content: ""
        source: ""
        loudness: 0.0
        repetition: 0.0
        ambiguity: 0.0
    olfactory_signals:
      - signal_id: ""
        content: ""
        source: ""
        intensity: 0.0
        ambiguity: 0.0
    tactile_signals:
      - signal_id: ""
        content: ""
        source: ""
        immediacy: 0.0

  event_stream:
    - event_id: ""
      timestamp_order: 1
      actor: ""
      event_type: motion|speech|micro_expression|sound|odor_change|contact|object_change
      content: ""
      duration: ""
      subtlety: 0.0
      observability:
        vision: 0.0
        hearing: 0.0
        smell: 0.0
        touch: 0.0

  observability_constraints:
    - signal_id: ""
      required_conditions: []
      degraded_by: []
      enhanced_by: []

  uncertainty_notes: []
```

## 5.4 Output Rules
- Must remain environment-grounded.
- Must avoid actor psychology as fact.
- Must preserve uncertainty.
- Must encode signals at a level useful for downstream differentiation.

---

## 6. EmbodimentResolver Protocol

## 6.1 Responsibility
Resolve the interaction between:
- body,
- species,
- temporary physical condition,
- scene conditions.

## 6.2 Input

```yaml
embodiment_input:
  character_id: ""
  baseline_body_profile:
    species: human|fox_spirit|fairy|ghost|immortal|other
    sensory_baseline:
      vision: 1.0
      hearing: 1.0
      smell: 1.0
      touch: 1.0
      proprioception: 1.0
    special_traits: []
    vulnerabilities: []
    motor_baseline:
      mobility: 1.0
      balance: 1.0
      stamina: 1.0
    cognition_baseline:
      stress_tolerance: 1.0
      sensory_overload_tolerance: 1.0

  temporary_body_state:
    sensory_blocks:
      vision_blocked: false
      hearing_blocked: false
      smell_blocked: false
    lighting_penalty_modifier: 0.0
    injuries:
      - part: ""
        severity: 0.0
        pain: 0.0
        functional_penalty: 0.0
    blood_loss: 0.0
    fatigue: 0.0
    pain_level: 0.0
    dizziness: 0.0
    illness: []
    drug_effects: []
    hunger: 0.0
    thirst: 0.0
    emotional_arousal_body_effect: 0.0

  scene_model: {}
```

## 6.3 Output: `embodiment_state`

```yaml
embodiment_state:
  character_id: ""
  scene_turn_id: ""

  sensory_capabilities:
    vision:
      availability: 0.0
      acuity: 0.0
      stability: 0.0
      notes: ""
    hearing:
      availability: 0.0
      acuity: 0.0
      stability: 0.0
      notes: ""
    smell:
      availability: 0.0
      acuity: 0.0
      stability: 0.0
      notes: ""
    touch:
      availability: 0.0
      acuity: 0.0
      stability: 0.0
      notes: ""
    proprioception:
      availability: 0.0
      acuity: 0.0
      stability: 0.0
      notes: ""

  body_constraints:
    mobility: 0.0
    balance: 0.0
    pain_load: 0.0
    fatigue: 0.0
    cognitive_clarity: 0.0

  salience_modifiers:
    attention_pull:
      - stimulus_type: ""
        modifier: 0.0
        reason: ""
    aversion_triggers:
      - stimulus_type: ""
        modifier: 0.0
        reason: ""
    overload_risks: []

  reasoning_modifiers:
    cognitive_clarity: 0.0
    pain_bias: 0.0
    threat_bias: 0.0
    overload_bias: 0.0

  action_feasibility:
    physical_execution_capacity: 0.0
    social_patience: 0.0
    fine_control: 0.0
    sustained_attention: 0.0
```

## 6.4 Handoff Rule
`embodiment_state` must be consumed by both:
- `PerceptionDistributor`
- `BeliefUpdater`
- `IntentAgent`

It is not perception-only data.

---

## 7. PerceptionDistributor Protocol

## 7.1 Responsibility
Generate the character-specific perception of the current turn.

## 7.2 Input

```yaml
perception_input:
  character_profile:
    traits: []
    values: []
    cognitive_style: {}
    social_style: {}
  mind_model_card: {}
  current_state:
    current_goals: {}
    emotion_state: {}
  relationship_models: {}
  scene_model: {}
  embodiment_state: {}
  memory_index_refs: []
```

## 7.3 Output: `character_perception_packet`

```yaml
character_perception_packet:
  character_id: ""
  scene_turn_id: ""

  noticed_facts:
    - fact_id: ""
      content: ""
      sensory_mode: visual|auditory|smell|touch|proprioception|memory_trigger
      confidence: 0.0
      salience: 0.0
      why_noticed: ""

  unnoticed_but_observable:
    - fact_id: ""
      content: ""
      why_missed: ""

  ambiguous_signals:
    - signal_id: ""
      content: ""
      possible_interpretations:
        - interpretation: ""
          weight: 0.0

  subjective_impressions:
    - target: ""
      impression: ""
      basis: ""
      confidence: 0.0

  affective_coloring:
    current_emotional_lens:
      - emotion: ""
        intensity: 0.0
        impact_on_attention: ""
        impact_on_interpretation: ""

  memory_activations:
    - trigger: ""
      recalled_memory: ""
      influence: ""

  immediate_concerns: []
```

## 7.4 Handoff Rule
Downstream modules must not treat `subjective_impressions` as world truth.

Downstream distinction must remain:
- `noticed_facts` = perceived cues,
- `subjective_impressions` = character-colored impressions,
- `ambiguous_signals` = unresolved or multi-interpretation cues.

---

## 8. BeliefUpdater Protocol

## 8.1 Responsibility
Update subjective scene understanding, relation inference, emotional tension, and decision-relevant beliefs.

## 8.2 Input

```yaml
belief_update_input:
  character_profile: {}
  mind_model_card: {}
  prior_beliefs: []
  relationship_model: {}
  prior_emotions: []
  embodiment_state: {}
  character_perception_packet: {}
```

## 8.3 Output: `character_belief_update`

```yaml
character_belief_update:
  character_id: ""
  scene_turn_id: ""

  stable_beliefs_reinforced:
    - belief: ""
      support: ""
      confidence_delta: 0.0

  stable_beliefs_weakened:
    - belief: ""
      contradiction: ""
      confidence_delta: 0.0

  new_hypotheses:
    - hypothesis: ""
      source: perception|memory|inference|emotion
      confidence: 0.0
      status: tentative|working_assumption|strong_belief

  revised_models_of_others:
    - target: ""
      inferred_state: ""
      confidence: 0.0
      evidence: ""

  contradictions_and_tension:
    - conflict: ""
      resolution_style: denial|rationalization|reappraisal|suppression|acceptance

  emotional_shift:
    before:
      - emotion: ""
        intensity: 0.0
    after:
      - emotion: ""
        intensity: 0.0
    reason: ""

  decision_relevant_beliefs: []
```

## 8.4 Handoff Rule
`decision_relevant_beliefs` is the primary belief-facing bridge into `IntentAgent`.

`IntentAgent` should not need the entire raw perception packet unless explicitly configured for special cases.

---

## 9. IntentAgent Protocol

## 9.1 Responsibility
Produce candidate next-step intents and select a character-consistent main intent.

## 9.2 Input

```yaml
intent_input:
  character_profile: {}
  mind_model_card: {}
  current_goals: {}
  relationship_model: {}
  embodiment_state: {}
  character_belief_update: {}
```

## 9.3 Output: `character_intent_plan`

```yaml
character_intent_plan:
  character_id: ""
  scene_turn_id: ""

  active_goals:
    short_term: []
    medium_term: []
    hidden: []

  decision_frame:
    perceived_situation: ""
    main_risk: ""
    main_opportunity: ""
    urgency: 0.0

  candidate_intents:
    - intent: ""
      type: speak|hide|probe|comfort|deceive|withdraw|attack|test|stall|observe|assist|escape
      target: ""
      motive: ""
      expected_outcome: ""
      risk: 0.0
      consistency_with_character: 0.0

  selected_intent:
    intent: ""
    reason: ""
    depends_on_beliefs: []
    emotional_driver: ""
    suppressed_alternatives:
      - option: ""
        why_not_chosen: ""

  expression_constraints:
    reveal_level: direct|guarded|masked|deceptive|silent
    tone: ""
    behavioral_notes: []
```

---

## 10. ActionSelector / SurfaceRealizer Protocol

## 10.1 Responsibility
Select execution priority and render intent into external output.

## 10.2 Input

```yaml
action_realization_input:
  scene_model: {}
  selected_intents:
    - character_id: ""
      character_intent_plan: {}
  arbitration_context: {}
```

## 10.3 Output

```yaml
rendered_turn_output:
  turn_id: ""
  execution_order:
    - character_id: ""
      reason: ""
  rendered_actions:
    - character_id: ""
      outward_action: ""
      dialogue: ""
      visible_behavior: []
      hidden_behavior: []
```

---

## 11. StateCommitter Protocol

## 11.1 Responsibility
Persist changes caused by the current turn.

## 11.2 Input

```yaml
state_commit_input:
  prior_character_states: []
  scene_model: {}
  embodiment_states: []
  perception_packets: []
  belief_updates: []
  intent_plans: []
  rendered_turn_output: {}
  world_consequence_delta: {}
```

## 11.3 Commit Targets
StateCommitter should persist at minimum:
- belief deltas,
- emotional deltas,
- relation deltas,
- body state deltas,
- scene state deltas,
- memory write candidates,
- turn history summary.

---

## 12. Access Boundary Rules

## 12.1 Character-Facing Modules
The following modules must not consume unavailable truth:
- PerceptionDistributor
- BeliefUpdater
- IntentAgent

## 12.2 SceneStateExtractor
May be closer to world truth, but must output observable state rather than narrator psychology.

## 12.3 SurfaceRealizer
May access selected intent and allowed concealment rules, but should not rewrite upstream belief logic.

---

## 13. Orchestration Rules

## 13.1 Per-Character Isolation
Perception, belief, and intent should be run per character in isolation to avoid contamination.

## 13.2 Stable Order
Recommended order:
1. update scene model,
2. resolve embodiment for all active characters,
3. run perception per character,
4. run belief update per character,
5. run intent per character,
6. arbitrate action order,
7. render output,
8. commit state.

## 13.3 Incremental Input Strategy
Prefer incremental turn deltas over full-history reprocessing when possible.

---

## 14. Minimal Example of Handoff Semantics

### SceneStateExtractor produces
- dim lighting,
- backlight zone,
- medicine + fresh blood odor,
- hesitation before reply,
- re-folded letter on table.

### EmbodimentResolver for fox spirit produces
- smell acuity high,
- irritation risk moderate,
- pain load moderate,
- visual precision reduced by lighting.

### PerceptionDistributor produces
- noticed: blood scent anomaly,
- noticed: hesitation,
- missed: subtle hand tremor in low light,
- impression: concealment likely.

### BeliefUpdater produces
- suspicion reinforced,
- hypothesis linking letter and injury,
- emotional tension increased.

### IntentAgent produces
- candidate intents: direct accusation / guarded probe / withdrawal,
- selected intent: guarded probe.

---

## 16. Scene Filtering Protocol

### 16.1 Responsibility
Given scene_model + character_position + embodiment_state, produce filtered_scene_view.

This protocol defines how to filter the objective scene into a character-specific view based on sensory capabilities and physical constraints.

### 16.2 Input

```yaml
scene_filtering_input:
  scene_model: {}
  character_id: ""
  character_position:
    location_id: ""
    orientation: ""           # facing direction
  embodiment_state: {}
```

### 16.3 Output: `filtered_scene_view`

```yaml
filtered_scene_view:
  character_id: ""
  scene_turn_id: ""

  visible_entities:
    - entity_id: ""
      visibility_score: 0.0   # 0.0-1.0
      clarity: 0.0            # clarity of perception
      notes: ""

  audible_signals:
    - signal_id: ""
      content: ""
      audibility_score: 0.0
      direction: ""

  olfactory_signals:
    - signal_id: ""
      content: ""
      intensity: 0.0
      freshness: ""

  tactile_signals:
    - signal_id: ""
      content: ""
      immediacy: 0.0

  spatial_context:
    reachable_areas: []
    nearby_obstacles: []
```

### 16.4 Basic Filtering Rules (MVP)

#### Visual Filtering
1. If `vision.availability < 0.1`: return empty `visible_entities`
2. For each entity in `scene_model.entities`:
   - Calculate `base_visibility` from `lighting_level`
   - Check if blocked by obstacles (simple line-of-sight)
   - Apply `vision.acuity` modifier to `clarity`
   - Include if `visibility_score > threshold`

#### Auditory Filtering
1. If `hearing.availability < 0.1`: return empty `audible_signals`
2. For each `auditory_signal` in `scene_model.auditory_signals`:
   - Calculate `base_audibility` from `loudness` and `distance`
   - Check if blocked by sound-blocking obstacles
   - Apply `hearing.acuity` modifier
   - Include if `audibility_score > threshold`

#### Olfactory Filtering
1. If `smell.availability < 0.1`: return empty `olfactory_signals`
2. For each `odor_source` in `scene_model.olfactory_field.odor_sources`:
   - Calculate `detectability` from `intensity`, `airflow`, `distance`
   - Apply species-specific sensitivity modifier (e.g., `fox_spirit: 1.5x-2.0x`)
   - Include if `detectability > threshold`

#### Tactile Filtering
1. If `touch.availability < 0.1`: return empty `tactile_signals`
2. Only include signals within immediate reach radius
3. Apply injury/pain modifiers to sensitivity

### 16.5 Handoff Rule
`filtered_scene_view` must be consumed by `PerceptionDistributor` and `BeliefUpdater`.
It must NOT contain any information the character cannot access.

---

## 17. Memory Access Protocol

### 17.1 Memory Entry Structure

```yaml
memory_entry:
  memory_id: ""
  content: ""
  owner_character_id: ""       # character who owns this memory
  known_by: []                 # list of character_ids who know this
  visibility: public | private | shared
  emotional_weight: 0.0
  created_at: ""
  last_accessed_at: ""
```

### 17.2 Known_By Mechanism

#### When Event Occurs
1. Determine which characters directly witnessed the event
2. Create memory entry with `known_by = [witnessing_character_ids]`
3. If event is private to one character: `known_by = [that_character_id]`
4. If event is public knowledge: `visibility = public`, `known_by = [*]`

#### Memory Visibility Types
- **private**: Only `owner_character_id` can access
- **shared**: Characters in `known_by` list can access
- **public**: All characters can access

### 17.3 Memory Retrieval Input

```yaml
memory_retrieval_input:
  character_id: ""
  query_context: ""            # current situation description
  recent_events: []
  belief_state: {}
  emotion_state: {}
```

### 17.4 Memory Retrieval Output

```yaml
memory_retrieval_output:
  accessible_memories: []      # memories where character_id ∈ known_by
  relevant_memories: []        # ranked by relevance to query_context
  triggered_memories: []       # activated by belief/emotion state
```

### 17.5 Retrieval Rules
1. Character can only retrieve memories where `character_id ∈ known_by` OR `visibility = public`
2. Relevance ranking considers:
   - semantic similarity to `query_context`
   - `emotional_weight` alignment with `emotion_state`
   - recency (`last_accessed_at`)
3. Belief state may trigger associated memories (e.g., suspicion triggers related past events)

### 17.6 Handoff Rule
Memory retrieval must be called during Character Input Assembly.
Retrieved memories must only include `accessible_memories`.

---

## 18. Character Input Assembly Protocol

### 18.1 Purpose
Assemble complete filtered input for a character's cognitive pass.
This is the single entry point for preparing character-specific input.

### 18.2 Assembly Flow

```text
scene_model + character_runtime_state + event_delta
    ↓
[1. Position Resolution]
    → character_position from scene_state or last known location
    ↓
[2. Embodiment Resolution]
    → embodiment_state from baseline_body_profile + temporary_body_state + scene_conditions
    ↓
[3. Scene Filtering]
    → filtered_scene_view using Scene Filtering Protocol
    ↓
[4. Memory Retrieval]
    → accessible_memories using Memory Access Protocol
    ↓
[5. Belief State]
    → prior_beliefs from character_runtime_state.belief_state
    ↓
character_cognitive_pass_input
```

### 18.3 Input

```yaml
character_input_assembly_request:
  scene_model: {}
  character_runtime_state: {}
  event_delta: []
```

### 18.4 Output

```yaml
character_cognitive_pass_input:
  character_id: ""
  scene_turn_id: ""

  # From Scene Filtering
  filtered_scene_view: {}

  # From Embodiment Resolution
  embodiment_state: {}
  body_state: {}

  # From Memory Retrieval
  accessible_memories: []

  # From Character Runtime State
  prior_belief_state: {}
  relation_models: {}
  emotion_state: {}
  current_goals: {}

  # Event Context
  recent_event_delta: []
```

### 18.5 Rules
1. Each step must complete before the next begins
2. Scene Filtering must use `embodiment_state` from step 2
3. Memory Retrieval must only return accessible memories
4. No world truth should leak into the output

### 18.6 Per-Character Isolation
This protocol MUST be executed independently for each character.
Results for different characters must not influence each other.

---

## 19. Non-Goals of This Document

This document does not define:
- final exact prompt wording,
- DB table schema,
- worldbook compatibility layer,
- frontend state editor UX,
- evaluation dataset structure.

Those belong to companion documents.

---

## 20. Summary

This document is the runtime source of truth for:
- object schemas,
- module I/O,
- orchestration flow,
- access boundaries,
- structured handoff semantics.

It operationalizes the framework spec into something implementable.

