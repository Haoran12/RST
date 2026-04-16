# RP Agent Framework Specification

Version: 0.1\
Status: Draft\
Audience: System Design / Product / Narrative Engine / Agent Runtime

---

## 1. Document Scope

This document defines the high-level framework for a character-centered AI RP Agent system.

It focuses on:

- system goals,
- architectural principles,
- information layering,
- core module responsibilities,
- end-to-end reasoning flow,
- why this architecture exists.

It does **not** serve as the source of truth for field-level runtime schemas or exact prompt templates. Those are defined in companion documents.

Companion documents:

- `rp_agent_runtime_protocol_spec.md`
- `rp_agent_prompt_skill_spec.md`
- `rp_agent_persistence_validation_spec.md`

---

## 2. Problem Statement

Conventional RP systems often fail in one or more of the following ways:

1. Characters behave as if they share a hidden omniscient narrator.
2. Different characters perceive the same scene too similarly.
3. Emotional bias, value systems, and prior beliefs do not materially affect reasoning.
4. Non-human sensory traits exist only as flavor text.
5. Injury, fatigue, concealment, and sensory constraints do not reliably alter behavior.
6. Intent generation optimizes for plot efficiency rather than character consistency.
7. The system confuses world truth with character-accessible truth.

This framework exists to solve those problems.

---

## 3. Design Goal

The design goal is to produce a system in which each character:

- exists as a distinct subjective agent,
- has a separate access boundary to information,
- interprets the same world differently,
- reasons through their current body and senses,
- updates beliefs through their own biases and relationships,
- forms intentions from subjective belief rather than objective truth.

In short:

**Characters should not act from the story. They should act from their own lived situation inside the story.**

---

## 4. Core Principles

## 4.1 Character-Centered Reasoning

The fundamental unit of reasoning is the **character**, not the global scene.

## 4.2 Subjective Access

Characters may only reason from what they could plausibly access.

## 4.3 Embodied Cognition

Characters perceive and reason through their current body state, not as abstract intelligence.

## 4.4 Bias Is Causal

Beliefs, emotions, relations, trauma, self-image, and worldview actively shape perception and interpretation.

## 4.5 Belief-Driven Action

Intent should emerge from what the character currently believes, even when those beliefs are incomplete or wrong.

## 4.6 Structured Handoffs

Each major reasoning phase must be explicitly separated and exchange structured outputs.

## 4.7 Traceable Subjectivity

When a character misperceives, misjudges, or overreacts, the cause should be explainable in system terms.

---

## 5. Conceptual Information Layers

The framework distinguishes multiple information layers.

## 5.1 World Truth Layer

This is the objective state of the world.

Examples:

- a lie is being told,
- someone is hiding behind a screen,
- a letter is forged,
- a wound is fresh.

This layer belongs to orchestration / simulation, not directly to character cognition.

## 5.2 Scene Layer

This is the structured environment and event representation of the current moment.

It contains:

- spatial layout,
- lighting,
- acoustics,
- smells,
- entities and objects,
- observable signals,
- dynamic events.

## 5.3 Embodiment Layer

This describes what a character can access through their current body.

It includes:

- sensory availability,
- species-specific strengths,
- injuries,
- fatigue,
- pain,
- overload vulnerability,
- action feasibility.

## 5.4 Perception Layer

This is the set of cues the character actually notices and how those cues are colored.

## 5.5 Belief Layer

This is the character's current subjective model of the scene, others, and likely meanings.

## 5.6 Intent Layer

This is the next-step subjective will of the character.

---

## 6. Core Runtime Flow

The framework requires a staged flow.

```text
World / Narrative Input
→ SceneStateExtractor
→ EmbodimentResolver (per character)
→ PerceptionDistributor (per character)
→ BeliefUpdater (per character)
→ IntentAgent (per character)
→ ActionSelector / SurfaceRealizer
→ StateCommitter
```

This chain is deliberate.

### Why this order matters

- The same scene can produce different perceptions.
- The same perceptions can produce different beliefs.
- The same beliefs can produce different intents depending on self-image, values, and relation strategy.
- Intent is only valid if it emerges after subjective filtering, not before it.

---

## 7. Core Modules

## 7.1 SceneStateExtractor

Role:

- convert text/world state into a structured model of environment, signals, and events.

This module should remain close to observable state and avoid character-specific interpretation.

## 7.2 EmbodimentResolver

Role:

- resolve how a specific body can access the scene.

This is where:

- blindness,
- darkness,
- fox-spirit smell sensitivity,
- injury,
- exhaustion,
- pain,
- overload risk become operational.

## 7.3 PerceptionDistributor

Role:

- determine what this specific character notices, misses, emphasizes, and initially interprets.

This module is where:

- attention,
- fear,
- relation bias,
- value bias,
- emotional filtering,
- memory triggers start to matter.

## 7.4 BeliefUpdater

Role:

- update the character's internal model of reality.

It answers:

- what does the character now think is happening,
- which prior beliefs are reinforced,
- what is now suspected,
- what contradictions emerge,
- how emotion changes in response.

## 7.5 IntentAgent

Role:

- generate the next likely intention from the character's current subjective state.

The correct output is not "best move for the plot". It is "most character-consistent next intention under current belief and body constraints".

## 7.6 ActionSelector / SurfaceRealizer

Role:

- decide how intent is externally expressed.

This includes:

- speech,
- silence,
- concealment,
- gesture,
- movement,
- direct action.

## 7.7 StateCommitter

Role:

- persist what changes.

Examples:

- memory,
- emotion,
- belief confidence,
- relations,
- bodily condition,
- scene consequences.

---

## 8. Character Model Philosophy

The framework assumes each character should have more than a static character sheet.

A useful character representation should include:

- stable traits,
- values,
- worldview,
- social strategy,
- defense patterns,
- self-image,
- relation models,
- current goals,
- belief state,
- emotion state,
- body state,
- memory references.

This allows the system to represent both:

- who the character generally is,
- who the character is **right now**.

---

## 9. Embodiment as a First-Class Principle

A major design requirement of this framework is that body state is not cosmetic.

Examples:

- a blindfolded character should shift to hearing, touch, airflow, and proprioception,
- a fox spirit should detect olfactory signals unavailable to humans,
- a wounded character should lose precision, patience, and attentional breadth,
- a smell-sensitive character may gain useful cues but also suffer overload,
- low visibility should reduce visual confidence and increase ambiguity.

Therefore the framework treats embodiment as a full reasoning constraint, not a flavor modifier.

---

## 10. What Makes Perception Character-Specific

Perception is not identical to scene exposure.

Two characters can occupy the same room and still differ because of:

- body differences,
- sensory differences,
- orientation and position,
- goals,
- fear triggers,
- emotional state,
- relation expectations,
- prior beliefs,
- memory activation.

Thus perception is modeled as:

```text
Accessible Signals
× Embodiment Constraints
× Attention Bias
× Emotional Coloring
× Relation Bias
× Prior Belief Bias
= Character Perception
```

---

## 11. Why Belief Must Be Separate from Perception

Many weak systems go directly from perception to action.

This causes:

- generic reactions,
- shallow personality,
- low persistence of worldview,
- insufficient contradiction handling.

BeliefUpdater exists so the system can represent:

- suspicion,
- denial,
- rationalization,
- hopeful reinterpretation,
- defensive certainty,
- cognitive dissonance,
- emotionally distorted inference.

The character acts not merely on what they sensed, but on what they now think it means.

---

## 12. Why Intent Must Be Separate from Belief

Many systems collapse belief and intent into a single step.

This makes characters feel too optimized and too similar.

Intent must remain separate so the system can represent:

- self-protective withdrawal,
- indirect probing,
- masked care,
- concealed hostility,
- performative calm,
- reckless attack under pain,
- silence driven by pride,
- lying for relation management.

Belief says: "what I think is happening."\
Intent says: "what I now want to do about it."

---

## 13. Non-Goals of This Framework

This framework does not by itself define:

- exact DB schema,
- exact prompt wording,
- frontend editing tools,
- worldbook import/export compatibility,
- combat rules in full detail,
- large-scale campaign memory compression strategy.

Those should be covered by companion documents.

---

## 14. Failure Modes the Framework Is Designed to Prevent

The framework explicitly tries to prevent:

1. Omniscient character reasoning.
2. Every character perceiving the same important detail.
3. Body state being ignored in cognition.
4. Species traits being decorative only.
5. Emotional state failing to affect salience and interpretation.
6. Intent acting like narrator optimization.
7. Scene description being too vague for sensory differentiation.
8. Hidden information leaking across characters.
9. Contradictory evidence being flattened too early.

---

## 15. Example Conceptual Walkthrough

Scene:

- dim room,
- one candle,
- medicinal smell mixed with faint blood,
- re-folded letter on table,
- hesitation before reply.

Character A:

- fox spirit,
- smell-sensitive,
- suspicious,
- mildly injured.

Character B:

- human,
- visually attentive,
- trusting,
- emotionally hopeful.

Framework expectation:

- The scene layer contains the same environmental reality for both.
- The embodiment layer differs sharply.
- Character A is likely to notice the blood and medicine smell pattern.
- Character B is more likely to focus on facial hesitation and table object details.
- Their beliefs diverge.
- Their resulting intentions diverge.

This is the desired behavior.

---

## 16. Companion Document Mapping

This document should be read together with:

### `rp_agent_runtime_protocol_spec.md`

Defines concrete runtime objects, schemas, and handoff contracts.

### `rp_agent_prompt_skill_spec.md`

Defines module prompts and anti-drift skill rules.

### `rp_agent_persistence_validation_spec.md`

Defines state persistence, validation, and acceptance criteria.

---

## 17. Acceptance Standard for the Framework Layer

The framework is conceptually successful if the implementation can consistently support the following:

1. Distinct characters in the same scene do not behave as if they share one mind.
2. Body and species materially influence accessible information.
3. Belief, emotion, and relation states materially alter interpretation.
4. Intent comes from subjective belief rather than objective truth.
5. Misunderstanding, tension, pride, fear, and indirectness remain representable.
6. Structured module boundaries reduce role collapse and omniscience leakage.

---

## 18. Summary

This framework defines an RP Agent as a layered subjective architecture.

It is not a single monolithic roleplay prompt. It is a staged system in which:

- the world is represented,
- the body filters access,
- perception selects and colors,
- belief interprets and stabilizes,
- intent chooses,
- action expresses.

That separation is what makes character behavior distinct, embodied, and believable.

