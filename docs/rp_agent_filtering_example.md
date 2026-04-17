# RP Agent 场景过滤示例

Version: 0.1
Status: Draft
Audience: Implementation / Testing / Understanding

---

## 1. Purpose

This document provides a concrete end-to-end example of how the Scene Filtering Protocol, Memory Access Protocol, and Character Input Assembly Protocol work together to produce character-specific input for cognitive passes.

---

## 2. Scene Setup

### 2.1 Environment

**Location**: 昏暗的药房 (Dim Apothecary)

**Lighting**:
```yaml
overall_level: dim
source_points:
  - type: candle
    intensity: 0.3
    location: "table_center"
```

**Olfactory Field**:
```yaml
odor_sources:
  - type: medicine
    intensity: 0.7
    freshness: recent
  - type: blood
    intensity: 0.5
    freshness: fresh
airflow: weak
```

**Spatial Layout**:
```yaml
scene_type: room
obstacles:
  - type: table
    location: "center"
    blocks_vision: false
  - type: shelf
    location: "wall_east"
    blocks_vision: true
```

### 2.2 Characters Present

**Character A** - 狐狸精 (Fox Spirit)
- Species: fox_spirit
- Sensory baseline: smell acuity 1.8x
- Current state: right arm injured (pain 0.6)
- Emotional state: suspicious, anxious

**Character B** - 人类 (Human)
- Species: human
- Sensory baseline: standard
- Current state: healthy
- Emotional state: trusting, concerned

---

## 3. Character A Input Assembly

### Step 1: Position Resolution

```yaml
character_position:
  location_id: "pharmacy_entrance"
  orientation: "facing_table"
```

### Step 2: Embodiment Resolution

```yaml
embodiment_state:
  sensory_capabilities:
    vision:
      availability: 0.7        # reduced by dim lighting
      acuity: 1.0
      stability: 0.9
    hearing:
      availability: 1.0
      acuity: 1.0
      stability: 1.0
    smell:
      availability: 1.0
      acuity: 1.8              # fox_spirit species bonus
      stability: 1.0
    touch:
      availability: 1.0
      acuity: 1.0
      stability: 0.8           # reduced by injury

  body_constraints:
    pain_load: 0.6             # right_arm injury
    mobility: 0.8
    cognitive_clarity: 0.9

  salience_modifiers:
    attention_pull:
      - stimulus_type: "blood_smell"
        modifier: 1.5          # heightened by injury context
        reason: "injury makes blood more salient"
```

### Step 3: Scene Filtering

```yaml
filtered_scene_view:
  character_id: "character_a"
  scene_turn_id: "turn_001"

  visible_entities:
    - entity_id: "character_b"
      visibility_score: 0.6
      clarity: 0.5             # dim + no face detail
      notes: "silhouette visible, facial expression unclear"
    - entity_id: "letter_on_table"
      visibility_score: 0.4
      clarity: 0.3
      notes: "blurry rectangular shape, cannot read"

  olfactory_signals:
    - signal_id: "medicine_smell"
      content: "草药味"
      intensity: 0.8           # base 0.7 * acuity 1.8 = 1.26, capped
      freshness: "recent"
    - signal_id: "blood_smell"
      content: "新鲜血腥味"
      intensity: 0.6           # base 0.5 * acuity 1.8 = 0.9, then attention modifier
      freshness: "fresh"
      notes: "clearly detectable, triggers injury association"

  audible_signals:
    - signal_id: "breathing_hesitation"
      content: "犹豫的呼吸声"
      audibility_score: 0.7
      direction: "from_table"
      notes: "character_b's breathing pattern"

  tactile_signals: []          # nothing within reach

  spatial_context:
    reachable_areas: ["pharmacy_entrance", "table_edge"]
    nearby_obstacles: ["shelf_wall_east"]
```

### Step 4: Memory Retrieval

```yaml
accessible_memories:
  - memory_id: "past_interaction_b"
    content: "上次与角色B的对话，讨论了信任问题"
    known_by: ["character_a", "character_b"]
    visibility: shared
    emotional_weight: 0.7

  - memory_id: "fox_spirit_traits"
    content: "狐狸精种族特性：嗅觉敏感，容易感知情绪波动"
    known_by: ["character_a"]
    visibility: private
    emotional_weight: 0.3

  - memory_id: "injury_fear"
    content: "受伤相关的恐惧：害怕被发现弱点"
    known_by: ["character_a"]
    visibility: private
    emotional_weight: 0.8

  - memory_id: "pharmacy_layout"
    content: "药房的布局和常见物品位置"
    known_by: ["character_a", "character_b"]
    visibility: shared
    emotional_weight: 0.2

relevant_memories:
  - memory_id: "injury_fear"    # triggered by blood smell
  - memory_id: "past_interaction_b"  # relevant to current interaction
```

### Step 5: Final Cognitive Pass Input

```yaml
character_cognitive_pass_input:
  character_id: "character_a"
  scene_turn_id: "turn_001"

  filtered_scene_view:
    # ... as above

  embodiment_state:
    # ... as above

  body_state:
    injury: right_arm
    pain_level: 0.6
    fatigue: 0.2

  accessible_memories:
    # ... as above

  prior_belief_state:
    suspicion_level: 0.7
    trust_in_b: 0.4
    current_hypothesis: "B may be hiding something"

  relation_models:
    character_b:
      trust: 0.4
      perceived_intent: "uncertain"
      past_interactions: "mostly_positive"

  emotion_state:
    anxiety: 0.5
    curiosity: 0.6
    fear: 0.3

  current_goals:
    short_term: "understand_B_behavior"
    medium_term: "protect_self"

  recent_event_delta:
    - event: "entered_pharmacy"
    - event: "noticed_blood_smell"
```

---

## 4. Character B Input Assembly

### Step 1: Position Resolution

```yaml
character_position:
  location_id: "table_center"
  orientation: "facing_entrance"
```

### Step 2: Embodiment Resolution

```yaml
embodiment_state:
  sensory_capabilities:
    vision:
      availability: 0.8        # human eyes adapt better to dim
      acuity: 1.0
      stability: 1.0
    hearing:
      availability: 1.0
      acuity: 1.0
      stability: 1.0
    smell:
      availability: 1.0
      acuity: 0.5              # human baseline (lower than fox_spirit)
      stability: 1.0
    touch:
      availability: 1.0
      acuity: 1.0
      stability: 1.0

  body_constraints:
    pain_load: 0.0             # healthy
    mobility: 1.0
    cognitive_clarity: 1.0

  salience_modifiers:
    attention_pull:
      - stimulus_type: "character_a_injury"
        modifier: 1.2
        reason: "concern for friend"
```

### Step 3: Scene Filtering

```yaml
filtered_scene_view:
  character_id: "character_b"
  scene_turn_id: "turn_001"

  visible_entities:
    - entity_id: "character_a"
      visibility_score: 0.7
      clarity: 0.6             # better than A's view of B
      notes: "can see injured right arm, facial expression partially visible"
    - entity_id: "letter_on_table"
      visibility_score: 0.5
      clarity: 0.4
      notes: "can see it's a letter, text not readable"

  olfactory_signals:
    - signal_id: "medicine_smell"
      content: "草药味"
      intensity: 0.5           # base 0.7 * acuity 0.5 = 0.35, below threshold but boosted by familiarity
      freshness: "recent"
    # blood_smell NOT included - below threshold for human nose

  audible_signals:
    - signal_id: "character_a_breathing"
      content: "角色A的呼吸声"
      audibility_score: 0.6
      direction: "from_entrance"
      notes: "slightly labored, possibly from pain"

  tactile_signals:
    - signal_id: "letter_texture"
      content: "信封的触感"
      immediacy: 0.9
      notes: "holding the letter"

  spatial_context:
    reachable_areas: ["table_center", "shelf_wall_east"]
    nearby_obstacles: []
```

### Step 4: Memory Retrieval

```yaml
accessible_memories:
  - memory_id: "past_interaction_a"
    content: "上次与角色A的对话，建立了信任"
    known_by: ["character_a", "character_b"]
    visibility: shared
    emotional_weight: 0.6

  - memory_id: "pharmacy_layout"
    content: "药房的布局和常见物品位置"
    known_by: ["character_a", "character_b"]
    visibility: shared
    emotional_weight: 0.2

  - memory_id: "letter_contents"
    content: "信封里的内容（私人的）"
    known_by: ["character_b"]
    visibility: private
    emotional_weight: 0.9

  - memory_id: "concern_for_a"
    content: "对角色A的关心"
    known_by: ["character_b"]
    visibility: private
    emotional_weight: 0.7

relevant_memories:
  - memory_id: "concern_for_a"    # triggered by seeing injury
  - memory_id: "letter_contents"  # relevant to current situation
```

### Step 5: Final Cognitive Pass Input

```yaml
character_cognitive_pass_input:
  character_id: "character_b"
  scene_turn_id: "turn_001"

  filtered_scene_view:
    # ... as above

  embodiment_state:
    # ... as above

  body_state:
    injury: none
    pain_level: 0.0
    fatigue: 0.1

  accessible_memories:
    # ... as above

  prior_belief_state:
    suspicion_level: 0.1
    trust_in_a: 0.8
    current_hypothesis: "A seems troubled, may need help"

  relation_models:
    character_a:
      trust: 0.8
      perceived_intent: "defensive"
      past_interactions: "positive"

  emotion_state:
    concern: 0.6
    curiosity: 0.4
    guilt: 0.3                  # from hiding letter

  current_goals:
    short_term: "comfort_a"
    medium_term: "maintain_trust"

  recent_event_delta:
    - event: "noticed_a_entered"
    - event: "saw_a_injury"
```

---

## 5. Key Differences Summary

| Aspect | Character A (Fox Spirit) | Character B (Human) |
|--------|-------------------------|---------------------|
| **Blood smell** | ✅ Detected (intensity 0.6) | ❌ Below threshold |
| **A's injury visibility** | ❌ Cannot see own arm clearly | ✅ Can see A's injured arm |
| **Letter clarity** | Blurry shape (clarity 0.3) | Recognizable letter (clarity 0.4) |
| **Private memories** | injury_fear, fox_traits | letter_contents, concern_for_a |
| **Emotional lens** | Suspicious, anxious | Concerned, trusting |
| **Salience** | Blood smell heightened | A's injury heightened |

---

## 6. Validation Check

### 6.1 Embodiment Validation (Character A)
- ✅ Vision available (0.7) → visible_entities not empty
- ✅ Smell available (1.0) → olfactory_signals not empty
- ✅ All visible entities satisfy line-of-sight

### 6.2 Memory Access Validation (Character A)
- ✅ All accessible_memories have character_a in known_by
- ✅ Private memories (fox_traits, injury_fear) only known by character_a

### 6.3 Embodiment Validation (Character B)
- ✅ Vision available (0.8) → visible_entities not empty
- ✅ Smell available (1.0) but acuity low → blood_smell correctly filtered out

### 6.4 Memory Access Validation (Character B)
- ✅ All accessible_memories have character_b in known_by
- ✅ Private memory (letter_contents) only known by character_b

### 6.5 No Leakage Check
- ✅ Character A cannot access letter_contents (not in known_by)
- ✅ Character B cannot access fox_traits (not in known_by)
- ✅ Neither character has access to world truth beyond filtered inputs

---

## 7. Expected Cognitive Outcomes

Based on the different inputs:

**Character A** is likely to:
- Form hypothesis about blood smell source
- Feel increased suspicion about what B is hiding
- Consider probing about the letter
- Be defensive about own injury

**Character B** is likely to:
- Express concern about A's injury
- Feel conflicted about hiding the letter
- Try to comfort A
- May accidentally reveal guilt through hesitation

This divergence in perception and belief is the intended behavior of the RP Agent system.
