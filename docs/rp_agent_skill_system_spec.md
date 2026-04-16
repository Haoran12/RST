# RP Agent Skill System Specification

Version: 0.1  
Status: Draft  
Audience: Runtime / Combat Resolution / Capability Modeling / Prompt Engineering

---

## 1. Document Scope

This document summarizes the current design decisions for the RP Agent skill system.

It defines:
- capability-side character stats used by skills,
- runtime resources,
- resistance categories,
- status effect categories,
- skill template structure,
- skill delivery and resolution layers,
- same-skill/different-user handling,
- skill mastery, scaling, and variant boundaries.

This document is a companion to:
- `rp_agent_framework_spec.md`
- `rp_agent_runtime_protocol_spec.md`
- `rp_agent_prompt_skill_spec.md`
- future `rp_agent_multi_character_arbitration_spec.md`

This document focuses on the **skill/capability model**, not full turn arbitration.

---

## 2. Design Goal

The skill system must support all of the following at the same time:

1. the same named skill can be used differently by different characters,
2. those differences remain rule-grounded rather than fully improvised,
3. skill performance depends on mastery, attributes, resources, body state, status effects, and environment,
4. high-fantasy confrontation such as spell clashes, illusion, charm, suppression, sealing, and sensory interference can be resolved consistently,
5. the system remains expressive for roleplay and does not collapse into a rigid game-only ruleset.

In short:

**The skill system should make character action differences legible, comparable, and narratively usable without destroying flexibility.**

---

## 3. Base Attributes

The current confirmed base attribute set is:

```yaml
base_attributes:
  physique: 0.0
  agility: 0.0
  endurance: 0.0
  insight: 0.0
  mana_capacity: 0.0
  mana_control: 0.0
  soul_strength: 0.0
```

## 3.1 Attribute Roles

### `physique`
Represents bodily quality and direct physical force baseline.

### `agility`
Represents coordination, motion adjustment, precision movement, and reaction-linked bodily responsiveness.

### `endurance`
Represents sustained effort, fatigue resistance, pain tolerance, and injury persistence.

### `insight`
Represents tactical reading, pattern recognition, deception reading, spell recognition, and interpretive sharpness.

### `mana_capacity`
Represents total magical energy / mana reserve capacity.

### `mana_control`
Represents magical precision, shaping quality, stability, and fine control in skill execution.

### `soul_strength`
Represents soul-level firmness, will-root, soul-defense baseline, and resistance to deep mental or spiritual intrusion.

---

## 4. Resources

The current confirmed runtime resource set is:

```yaml
resources:
  vitality: 0.0
  mana: 0.0
  spirit: 0.0
  soul_stability: 0.0
```

## 4.1 Resource Roles

### `vitality`
Represents bodily integrity and life-bearing condition.

### `mana`
Represents directly usable magical energy.

### `spirit`
Represents current mental/attentional/spiritual operating reserve for concentration, subtle control, prolonged mental pressure, and fine skill execution.

### `soul_stability`
Represents current soul-layer structural stability. It should generally be more serious and slower-changing than ordinary mana loss.

## 4.2 No Separate Stamina Pool
At present, there is no separate `stamina` resource.

Physical exertion and overload should instead be represented through:
- `endurance`,
- `vitality` when relevant,
- attrition-type status effects such as `strained`, `fatigued`, and `exhausted`.

---

## 5. Resistances

Recommended resistance skeleton:

```yaml
resistances:
  physical: 0.0
  elemental: {}
  poison_toxin: 0.0
  illusion: 0.0
  mental: 0.0
  soul: 0.0
  binding: 0.0
  suppression: 0.0
  sensory_interference: 0.0
```

## 5.1 Resistance Roles

### `physical`
Against direct bodily damage and impact.

### `elemental`
Configurable per setting, e.g. fire / ice / lightning / wind / earth / water / wood.

### `poison_toxin`
Against poison, corrosive agents, sedatives, smoke, and biologically disruptive substances.

### `illusion`
Against false sensory interpretation, perception distortion, and deceptive sensory overlays.

### `mental`
Against emotion manipulation, fear, charm, mental intrusion, and motivational distortion.

### `soul`
Against direct soul attacks, soul pressure, soul rupture, spiritual invasion, and related effects.

### `binding`
Against movement-restricting or action-restricting control such as immobilization, capture, restraint, or field locking.

### `suppression`
Against pressure, domain suppression, magical sealing pressure, cultivation pressure, or spiritual oppression.

### `sensory_interference`
Against blindness, tinnitus, scent overload, spiritual static, and other perception corruption.

## 5.2 Why `illusion` and `mental` Stay Separate
These should not be merged.

- `illusion` is about sensing the wrong thing.
- `mental` is about wanting / feeling / deciding the wrong thing.

Some skills may target both, but they are not the same mechanism.

---

## 6. Status Effects

Recommended high-level categories:

```yaml
status_categories:
  - perception
  - mobility
  - casting
  - mental
  - defensive
  - attrition
  - soul
```

## 6.1 Category Examples

### `perception`
- blinded
- obscured_vision
- scent_overloaded
- spiritual_perception_blocked
- perception_distorted

### `mobility`
- slowed
- restrained
- immobilized
- off_balance
- staggered
- knocked_down

### `casting`
- casting_unstable
- mana_disrupted
- silenced
- channel_broken
- backfiring_risk_up

### `mental`
- charmed
- feared
- confused
- distracted
- enraged
- fixated

### `defensive`
- shielded
- hardened
- vulnerable
- exposed
- destabilized

### `attrition`
- bleeding
- burning
- poisoned
- corroded
- strained
- fatigued
- exhausted

### `soul`
- soul_shaken
- soul_wounded
- spirit_suppressed
- soul_marked
- will_fragmented

## 6.2 Status Effect Template

```yaml
status_effect:
  effect_id: ""
  name: ""
  category: perception|mobility|casting|mental|defensive|attrition|soul

  source: ""
  stacks: 1
  max_stacks: 1

  duration:
    type: turns|until_removed|instant|channeled
    value: 0

  modifiers:
    base_attributes: {}
    derived_stats: {}
    resources: {}
    resistances: {}

  special_rules:
    cannot_move: false
    cannot_cast: false
    blocks_reaction: false
    breaks_on_damage: false
    suppresses_concealment: false

  periodic_effects:
    vitality_loss: 0.0
    mana_loss: 0.0
    spirit_loss: 0.0
    soul_stability_loss: 0.0

  removal_conditions: []

  visibility:
    obvious_to_others: true
    detectable_via_spiritual_perception: false
```

## 6.3 Fatigue Without a Stamina Pool
Because the design does not use a separate stamina bar, the following statuses are especially important:
- `strained`
- `fatigued`
- `exhausted`

These should carry most of the physical-overuse expression normally handled by stamina depletion systems.

---

## 7. Skill Template

A skill must be more than a name and prose description. It must be structurally resolvable.

Recommended template:

```yaml
skill_template:
  skill_id: ""
  name: ""
  category: attack|defense|movement|control|illusion|detection|support|sealing|escape
  tags: []

  activation_type: active|passive|reaction|channeled|triggered
  domain: physical|mana|mental|soul|hybrid

  requirements:
    realm_minimum: ""
    hand_free: false
    voice_required: false
    line_of_sight: optional
    target_lock_required: false
    stance_required: ""
    artifact_required: []
    resource_minimum:
      vitality: 0.0
      mana: 0.0
      spirit: 0.0
      soul_stability: 0.0

  timing:
    startup_time: 0.0
    commitment_point: 0.0
    completion_time: 0.0

  range:
    type: self|touch|line|single_target|area|field
    max_distance: 0.0
    radius: 0.0

  target_rules:
    valid_targets: []
    friendly_fire: false
    can_hit_hidden_targets: false

  cost:
    vitality: 0.0
    mana: 0.0
    spirit: 0.0
    soul_stability: 0.0

  maintenance_cost_per_turn:
    vitality: 0.0
    mana: 0.0
    spirit: 0.0
    soul_stability: 0.0

  cooldown: 0

  scaling:
    primary_stats: []
    secondary_stats: []
    power_ratio: 0.0

  effects:
    - effect_type: damage|status_apply|control|shield|dispel|reposition|perception_distortion|seal|detect
      value_formula: ""
      applied_status: ""
      duration: 0

  checks:
    hit_check: ""
    resist_check: ""
    interrupted_by: []
    countered_by: []

  detectability:
    pre_cast_signature: none|low|medium|high
    visible_effect_strength: 0.0
    spiritual_trace_strength: 0.0

  side_effects: []
```

---

## 8. Two Mandatory Skill Fields Added by Discussion

Two additional fields are strongly recommended as part of the skill schema.

## 8.1 `resolution_layer`

```yaml
resolution_layer:
  primary: body|perception|mind|soul|scene
  secondary: []
```

This field tells the runtime what the skill mainly resolves against.

Examples:
- wind blade → primary `body`
- charm gaze → primary `mind`, secondary `soul`
- illusion fog → primary `perception`
- sealing array → primary `scene` or `soul`, depending on design

## 8.2 `delivery_channel`

```yaml
delivery_channel:
  type: gaze|voice|scent|touch|spiritual_link|projectile|hybrid
  must_be_established: true
  broken_by: []
```

This field matters especially for charm, illusion, detection, and special attack delivery models.

Examples:
- wind blade → `projectile`
- charm gaze → `gaze`
- voice charm → `voice`
- scent allure → `scent`

---

## 9. Skill Resolution Logic

A general skill resolution flow should resemble:

```text
1. Can the action candidate be used?
2. Can the delivery channel be established?
3. Is the action noticed?
4. Can it be interrupted or countered?
5. Does delivery succeed?
6. Does hit/contact/mental entry succeed?
7. Does resistance/defense reduce it?
8. What effect tier is produced?
9. What state changes are committed?
```

Attack-type skills and mental-type skills follow the same overall logic, but differ sharply in which layer and resistance are tested.

---

## 10. Example Skill Types from Discussion

## 10.1 Wind Blade
Used as the baseline attack-type example.

Important characteristics:
- category: attack
- domain: mana
- resolution layer: body
- delivery channel: projectile
- scalable axes: startup_time / range / damage / detectability / stability

Typical resolution path:
- validate cast,
- detect pre-cast,
- open interrupt window,
- resolve path delivery,
- resolve hit,
- apply physical / wind mitigation,
- apply damage and possible secondary status.

## 10.2 Charm Gaze
Used as the baseline charm/control example.

Important characteristics:
- category: control
- domain: mental
- resolution layer: primary mind, secondary soul
- delivery channel: gaze
- scalable axes: startup_time / detectability / influence_strength / duration / break_resistance

Typical resolution path:
- validate cast,
- establish channel,
- determine target notice,
- open break window,
- test mental/soul penetration,
- assign influence tier,
- degrade or sustain effect,
- feed back into perception, belief, and intent.

## 10.3 Charm Must Not Default to Total Control
Charm should typically support graded tiers such as:
- no effect,
- brief disturbance,
- soft bias,
- strong influence,
- partial control,
- dominant control.

Ordinary charm should not default to hard domination.

---

## 11. Same Skill, Different Users

This was identified as a core problem: how to make the same named skill behave differently for different characters without losing structural clarity.

The adopted solution is a **three-layer model**.

## 11.1 Layer 1: Skill Template
Defines what the skill fundamentally is.

## 11.2 Layer 2: Character Skill Binding
Defines how this character has learned and shaped that skill.

## 11.3 Layer 3: Runtime Skill Instance
Defines the actual form of that skill in the current turn after applying:
- template,
- binding,
- current attributes,
- current resources,
- current statuses,
- environment,
- equipment and special factors.

---

## 12. Character Skill Binding

Recommended structure:

```yaml
character_skill_binding:
  character_id: ""
  skill_id: ""

  learned: true
  mastery_rank: 1
  proficiency_score: 0.0

  style_bias: []
  specialization_notes: []

  parameter_bias:
    startup_time_bonus: 0.0
    mana_cost_modifier: 0.0
    spirit_cost_modifier: 0.0
    range_bonus: 0.0
    effect_power_bonus: 0.0
    detectability_modifier: 0.0
    stability_bonus: 0.0
    break_resistance_bonus: 0.0

  unlock_state:
    unlocked_features: []
    locked_features: []

  known_variants: []

  reliability_profile:
    miscast_risk_base: 0.0
    under_pressure_penalty: 0.0
    fatigue_penalty: 0.0
    injury_penalty: 0.0

  usage_memory:
    total_usage_count: 0
    last_used_turn: ""
    notable_history: []
```

## 12.1 Role of `mastery_rank`
Represents broad developmental stage.

Suggested mapping:

```yaml
mastery_rank:
  1: novice
  2: trained
  3: skilled
  4: expert
  5: master
```

## 12.2 Role of `proficiency_score`
Provides fine-grained detail inside the mastery tier.

## 12.3 Role of `style_bias`
Expresses character-specific usage style such as:
- fast_cast,
- low_signature,
- heavy_cut,
- soft_influence,
- forceful_invasion,
- long_hold.

## 12.4 Role of `parameter_bias`
Represents long-term personal skew in how the character expresses the skill.

Example:
- faster but weaker,
- heavier but louder,
- subtler but shorter range,
- more stable but higher spirit cost.

---

## 13. Runtime Skill Instance

A runtime skill instance should be understood as:

```text
runtime_skill_instance
= skill_template
+ character_skill_binding
+ current_runtime_modifiers
```

Recommended structure:

```yaml
runtime_skill_instance:
  caster: ""
  skill_id: ""

  effective_timing: {}
  effective_range: {}
  effective_cost: {}
  effective_effects: {}
  effective_detectability: {}
  effective_reliability: {}
```

This is the object that arbitration and conflict resolution should actually consume.

---

## 14. Skill Growth and Scaling Policy

The discussion concluded that skill parameters should be divided into three classes.

## 14.1 Soft-Scalable
These may vary continuously within the same template.

Typical examples:
- startup time,
- completion time,
- mana cost,
- spirit cost,
- range,
- effect power,
- detectability,
- stability,
- break resistance.

## 14.2 Threshold-Unlock
These should not vary freely, but may be unlocked at higher mastery.

Examples:
- silent_cast,
- reduced_signature,
- split_second_blade,
- lower_notice_probability,
- partial_control_threshold_unlock.

## 14.3 Variant-Boundary
These should not be treated as ordinary template scaling.
If these change, the skill should usually become a named variant.

---

## 15. Variant-Boundary Rules

The discussion established four strong boundary rules.

A skill should generally be promoted to a **variant** if it changes any of the following:

### 15.1 Delivery Channel Changes
Examples:
- gaze → voice
- gaze → scent
- projectile → field

### 15.2 Primary Resolution Layer Changes
Examples:
- body → mind
- mind → soul
- body → scene

### 15.3 Target Scale Changes
Examples:
- single target → area
- touch → multi-target
- single-target charm → group aura charm

### 15.4 Primary Effect Type Changes
Examples:
- damage → control
- soft charm → domination
- projectile cut → binding attack

These are not ordinary growth; they imply a new skill variant.

---

## 16. Practical Scaling Guidance

Skill performance should not be determined by prose alone.

A recommended pattern is:

```text
effective_value
= template_base
× mastery_modifier
× attribute_modifier
× resource_modifier
× status_modifier
× style_modifier
× environment_modifier
```

Not every parameter needs every modifier. Which modifiers apply should be explicitly controlled by the skill design.

### Example: Wind Blade Startup Time
Should reasonably depend on:
- mastery,
- mana_control,
- agility,
- fatigue or instability,
- fast-cast style bias.

### Example: Charm Influence Strength
Should reasonably depend on:
- soul_strength,
- mana_control,
- current spirit,
- mastery,
- channel quality,
- target susceptibility,
- current target state.

---

## 17. MVP Recommendation

If implementation scope needs to be reduced, the minimum viable version should still preserve:

1. base attributes,
2. four resources,
3. resistance skeleton,
4. status effect template,
5. skill template,
6. `resolution_layer`,
7. `delivery_channel`,
8. character skill binding,
9. runtime skill instance,
10. variant-boundary rules.

Without these, the skill system will likely become too improvised and lose consistency under conflict resolution.

---

## 18. Summary

The current skill-system design can be summarized as follows:

- characters use a compact capability stat set,
- skills consume a compact but expressive resource set,
- resistances and status effects are organized by mechanism rather than lore name,
- each skill is defined as a structured template,
- skill delivery and resolution layers are explicit,
- the same named skill can behave differently for different users through character skill binding,
- runtime skill performance is generated from template + binding + current conditions,
- skills may scale, unlock features, or branch into variants,
- once delivery channel, resolution layer, target scale, or primary effect type changes, the skill should usually be treated as a variant rather than the same template.

This design keeps the system grounded enough for arbitration while preserving narrative flexibility and character individuality.

