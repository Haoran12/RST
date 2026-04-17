# RP Agent Skill System Specification (Minimal Flexible Edition)

Version: 0.1  
Status: Draft  
Audience: Runtime / Capability Modeling / Lightweight RP Execution / MVP Development

---

## 1. Document Scope

This document defines a **minimal flexible** skill-system design for the RP Agent project.

It exists as a lightweight alternative to the fuller skill-system design.

This edition is designed for the following priorities:

1. keep the character model compact,
2. reduce implementation cost,
3. preserve narrative freedom,
4. avoid premature over-formalization,
5. support practical RP scenes and basic confrontation,
6. keep room for later expansion.

This document should be read as an MVP-oriented capability model.

Companion relationship:
- can coexist with the full `rp_agent_skill_system_spec.md`,
- may serve as the first implementation target,
- may later evolve toward the fuller version if needed.

---

## 2. Design Goal

The design goal of the minimal flexible edition is:

- keep only the character's essential base attributes,
- keep only the skill's trigger method and impact scope as hard structure,
- let the runtime preserve freedom in exact manifestation,
- allow deterministic program logic to perform coarse validation and arbitration,
- allow contextual interpretation to remain flexible.

In short:

**Keep the boundary hard, keep the expression soft.**

---

## 3. What This Edition Intentionally Removes

Compared with a fuller skill system, this edition intentionally avoids or defers:

- detailed resistance tables,
- extensive formal status-effect taxonomy,
- large skill template schemas,
- parameter-heavy scaling systems,
- detailed skill-binding structures,
- complex variant systems,
- high-resolution numeric combat comparison,
- large numbers of explicit rule branches.

The point is not that these are always bad, but that they are not required for an effective first implementation.

---

## 4. Core Principle

The minimal flexible edition treats skills as **structured boundaries**, not as fully specified simulation objects.

A skill should clearly say:
- how it is triggered,
- how it reaches the target,
- what kind of layer it primarily influences.

It should **not** attempt to fully predefine every consequence numerically.

Therefore:
- the program enforces coarse constraints,
- the model or runtime context can interpret the exact manifestation within those constraints.

---

## 5. Base Character Attributes

The confirmed base attribute set remains:

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

## 5.1 Attribute Roles

### `physique`
Bodily quality, force, structural strength.

### `agility`
Movement adjustment, responsiveness, dexterity, quickness.

### `endurance`
Sustain, fatigue tolerance, pain tolerance, longer action continuity.

### `insight`
Reading skill, pattern recognition, tactical understanding, deception and anomaly recognition.

### `mana_capacity`
Total magical reserve potential.

### `mana_control`
Precision, shaping, stability, and controllability of magical skill use.

### `soul_strength`
Soul-level firmness, will-root, and deep mental/spiritual resistance baseline.

---

## 6. Optional Runtime Resources

If the runtime wants lightweight resource tracking, the recommended compact resource set is:

```yaml
resources:
  vitality: 0.0
  mana: 0.0
  spirit: 0.0
  soul_stability: 0.0
```

However, the minimal flexible edition allows these resources to be handled more loosely if the implementation prefers.

### Recommended interpretation
- `vitality`: bodily integrity
- `mana`: active magical energy
- `spirit`: attention/mental operational reserve
- `soul_stability`: soul-layer stability under deep pressure

### Simplification rule
If needed, the first implementation may use these as coarse scene-state indicators rather than full simulation bars.

---

## 7. Skill Model: Minimal Version

The minimal flexible skill model intentionally keeps only a small number of required fields.

```yaml
skill:
  skill_id: ""
  name: ""

  trigger_mode: active|reaction|passive|channeled
  delivery_channel: gaze|voice|touch|projectile|scent|spiritual_link|ritual|field
  impact_scope: body|perception|mind|soul|scene

  notes: ""
```

## 7.1 Field Roles

### `trigger_mode`
Tells the runtime how the action begins.

Examples:
- active: deliberate use,
- reaction: triggered during a reaction window,
- passive: always or conditionally present,
- channeled: requires continued maintenance.

### `delivery_channel`
Tells the runtime how the skill reaches or connects with the target.

Examples:
- projectile,
- gaze,
- voice,
- touch,
- scent,
- ritual,
- spiritual_link,
- field.

### `impact_scope`
Tells the runtime which layer the skill mainly acts on.

Examples:
- `body`: direct physical or bodily harm/effect,
- `perception`: sensory distortion or concealment,
- `mind`: motivation, emotion, judgment, charm,
- `soul`: deep spiritual or soul-layer effect,
- `scene`: barriers, fields, environmental reshaping.

### `notes`
A lightweight freeform slot for author intent or special interpretation guidance.

---

## 8. Optional Extra Field: Category

If the implementation wants a slightly clearer grouping without much added complexity, this optional field may be used:

```yaml
category: attack|control|support|movement|detection|concealment
```

This field is not required, but can help organize skill families.

---

## 9. Character Skill Use Profile

To preserve some difference between users of the same skill, the minimal flexible edition recommends a minimal use profile.

```yaml
character_skill_use_profile:
  character_id: ""
  skill_id: ""
  mastery_rank: 1
  notes: ""
```

## 9.1 Purpose
This keeps only the minimum needed to say:
- the character knows the skill,
- the character is more or less practiced with it,
- there may be a short note about their style.

This intentionally avoids the heavier binding model with many parameter modifiers.

## 9.2 Mastery Rank
Recommended simple rank scale:

```yaml
mastery_rank:
  1: novice
  2: trained
  3: skilled
  4: expert
  5: master
```

The exact runtime meaning can remain coarse.

---

## 10. Same Skill, Different Users

The minimal flexible edition still supports different expressions of the same named skill.

It does so through a simple combination of:
- base attributes,
- skill mastery rank,
- current body/resource state,
- environment,
- scene context.

This means that two characters can both use `wind_blade`, but the runtime may still interpret one as:
- faster,
- more stable,
- more forceful,
- more precise,
- subtler,
- broader in effect,

without requiring a large parameter matrix.

### Important rule
The exact manifestation should stay consistent with the skill's fixed boundary:
- delivery channel,
- impact scope,
- general trigger mode.

That is how the system preserves freedom without losing identity.

---

## 11. Coarse Programmatic Resolution

The minimal flexible edition still expects the runtime to do coarse deterministic checks.

Recommended programmatic checks:

### 11.1 Trigger Legality
Can the skill be used at all right now?

Examples:
- gaze requires line of sight,
- voice requires audibility,
- touch requires proximity,
- projectile requires valid path,
- ritual may require setup.

### 11.2 Delivery Channel Validity
Can the channel actually connect?

Examples:
- is the gaze maintained,
- is the target hearing the voice,
- does the projectile have line/path,
- is the scent reaching the target,
- is the spiritual link possible.

### 11.3 Coarse Impact Layer Contest
The runtime should map the skill's `impact_scope` to a broad contest axis.

Suggested mapping:

- `body` → compare against bodily mobility / endurance / physique context
- `perception` → compare against insight and sensory clarity context
- `mind` → compare against insight and soul-strength context
- `soul` → compare mainly against soul-strength and soul-stability context
- `scene` → compare against scene constraints, space, or competing field effects

### 11.4 Result Tier
The runtime should produce coarse result tiers such as:
- fail,
- weak_success,
- partial_success,
- strong_success.

This is enough for many RP applications.

---

## 12. Minimal Outcome Tags

Instead of a heavy formal status system, the minimal flexible edition may use a small set of broad outcome tags.

Suggested set:

```yaml
effect_tags:
  - wounded
  - hindered
  - disturbed
  - influenced
  - suppressed
  - concealed
  - revealed
```

## 12.1 Interpretation
These are intentionally broad.

Examples:
- `wounded`: bodily harm or meaningful damage result,
- `hindered`: motion or action quality reduced,
- `disturbed`: perception, concentration, or mental flow disrupted,
- `influenced`: mind or judgment shifted,
- `suppressed`: pressure or sealing-like weakening,
- `concealed`: target or state hidden from ordinary access,
- `revealed`: hidden state, action, or presence exposed.

The exact narrative manifestation should remain context-sensitive.

---

## 13. Example Skills

## 13.1 Wind Blade

```yaml
skill:
  skill_id: wind_blade
  name: 风刃
  trigger_mode: active
  delivery_channel: projectile
  impact_scope: body
  notes: "A wind-formed cutting attack projected toward a target."
```

Meaning:
- active cast,
- travels as projectile-like delivery,
- primarily contests bodily outcome,
- exact strength and speed remain context-dependent.

## 13.2 Charm Gaze

```yaml
skill:
  skill_id: charm_gaze
  name: 魅惑
  trigger_mode: active
  delivery_channel: gaze
  impact_scope: mind
  notes: "A gaze-based influence skill that affects judgment, trust, or emotional openness."
```

Meaning:
- active use,
- requires gaze connection,
- primarily contests mental outcome,
- exact severity should be decided through context and coarse success tier.

---

## 14. What This Edition Gains

### 14.1 Lower Implementation Cost
Fewer fields, fewer interactions, fewer rules to encode.

### 14.2 Higher Narrative Flexibility
Skills retain broad expressive room.

### 14.3 Easier MVP Delivery
This design can be implemented much earlier than a full formalized system.

### 14.4 Better Fit for RP-First Use Cases
If the main goal is believable character behavior and scene freedom rather than exact tactical balance, this edition is often more appropriate.

---

## 15. What This Edition Sacrifices

### 15.1 Lower Determinism
Outcomes are less strictly comparable.

### 15.2 Less Formal Balance
Fine-grained skill balance becomes harder.

### 15.3 More Dependence on Contextual Interpretation
The runtime or model has to do more soft judgment.

### 15.4 Harder Long-Term Precision Scaling
Very detailed progression systems will require later extension.

These are acceptable tradeoffs for an MVP-focused flexible RP system.

---

## 16. Recommended Use Cases

This edition is best suited for:
- first implementation,
- RP-first systems,
- narrative-heavy character interaction,
- light-confrontation fantasy scenes,
- systems that want to minimize premature rules burden.

It is less suited for:
- highly balanced tactical combat,
- deep deterministic PVP-like resolution,
- large-scale skill catalogues requiring strict comparability.

---

## 17. Upgrade Path

The minimal flexible edition is intentionally compatible with future expansion.

A possible later upgrade path is:

1. keep the same base attributes,
2. keep the same lightweight skill identity fields,
3. add fuller resource logic,
4. add richer effect/state logic,
5. add stronger skill-binding structure,
6. add a fuller runtime skill instance model.

This allows the project to evolve without discarding the first implementation.

---

## 18. Summary

The minimal flexible edition defines a deliberately small skill system.

Its core rule is simple:

- characters have compact base attributes,
- skills define how they are triggered and what layer they affect,
- coarse program logic enforces whether the skill can connect and roughly how strong the outcome tier is,
- exact manifestation remains flexible and context-sensitive.

This approach is intentionally lightweight, RP-friendly, and practical for early implementation.

