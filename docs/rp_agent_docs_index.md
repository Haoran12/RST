# RP Agent Documentation Set

Version: 0.1  
Status: Draft  
Audience: Product / Design / Backend / Prompt Engineering / Runtime Orchestration

---

## 1. Purpose

This document defines the documentation structure for the RP Agent project and clarifies the role and boundary of each document.

The goal is to avoid the common failure mode where one document mixes:
- high-level architecture,
- runtime contracts,
- prompt templates,
- persistence design,
- validation rules,
- implementation details.

Instead, the project should be maintained as a **layered documentation set**.

---

## 2. Documentation Hierarchy

```text
RP Agent Docs
├── 01. rp_agent_framework_spec.md
├── 02. rp_agent_runtime_protocol_spec.md
├── 03. rp_agent_prompt_skill_spec.md
└── 04. rp_agent_persistence_validation_spec.md
```

Recommended future additions:

```text
├── 05. rp_agent_worldbook_compat_spec.md
├── 06. rp_agent_turn_scheduler_spec.md
├── 07. rp_agent_frontend_editor_spec.md
└── 08. rp_agent_test_cases.md
```

---

## 3. Document Relationship Summary

## 3.1 `rp_agent_framework_spec.md`
Role:
- high-level architecture and design philosophy.

Answers:
- what the system is,
- why it is designed this way,
- what modules exist,
- what principles govern them,
- what information layers must be separated.

Does **not** define every runtime field in full detail.

---

## 3.2 `rp_agent_runtime_protocol_spec.md`
Role:
- runtime contract and module handoff specification.

Answers:
- what each module consumes,
- what each module outputs,
- how data moves between modules,
- what schemas and field contracts are required,
- what orchestration order is expected.

Builds directly on the framework spec.

---

## 3.3 `rp_agent_prompt_skill_spec.md`
Role:
- prompt/skill implementation guide.

Answers:
- how each module should be prompted,
- which constraints must be enforced in prompts,
- how to write system prompts,
- how to keep each module within scope,
- how to prevent omniscience and generic reasoning drift.

Builds directly on the runtime protocol spec.

---

## 3.4 `rp_agent_persistence_validation_spec.md`
Role:
- persistence, state-commit, validation, and implementation safety document.

Answers:
- what runtime state must be persisted,
- how memory / belief / relation / body state are stored,
- how validation and acceptance criteria are enforced,
- how to detect common failure cases.

Builds on both runtime protocol and prompt skill specs.

---

## 4. Dependency Graph

```text
rp_agent_framework_spec.md
    ↓
rp_agent_runtime_protocol_spec.md
    ↓
rp_agent_prompt_skill_spec.md
    ↓
rp_agent_persistence_validation_spec.md
```

The dependency is mostly one-directional:

- Framework Spec defines architecture and principles.
- Runtime Protocol Spec operationalizes architecture into data contracts.
- Prompt Skill Spec operationalizes runtime contracts into agent-facing prompts and skills.
- Persistence / Validation Spec operationalizes state transition and testing.

---

## 5. Boundary Rules

To keep the documentation stable, each document should obey the following boundary rules.

## 5.1 Framework Spec Boundary
Should include:
- design goals,
- architecture,
- module roles,
- information layers,
- overall workflow,
- non-goals,
- future extensibility.

Should avoid:
- long field-by-field schema dumps,
- prompt wording,
- exact table definitions,
- full database implementation details.

---

## 5.2 Runtime Protocol Spec Boundary
Should include:
- formal runtime objects,
- field definitions,
- handoff contracts,
- orchestration order,
- data access rules,
- module I/O examples.

Should avoid:
- philosophical justification already covered in framework spec,
- prompt wordsmithing,
- DB engine-specific implementation.

---

## 5.3 Prompt Skill Spec Boundary
Should include:
- system prompt templates,
- module-specific guardrails,
- output formatting rules,
- examples of good vs bad prompting,
- anti-drift instructions.

Should avoid:
- replacing formal runtime schema definitions,
- mixing database details,
- broad architecture discussion.

---

## 5.4 Persistence Validation Spec Boundary
Should include:
- persistent state categories,
- commit flow,
- versioning and migration considerations,
- validation checks,
- regression scenarios,
- runtime monitoring suggestions.

Should avoid:
- replacing the runtime schema source of truth,
- redefining prompt semantics.

---

## 6. Recommended Reading Order

For a new contributor:

1. `rp_agent_framework_spec.md`
2. `rp_agent_runtime_protocol_spec.md`
3. `rp_agent_prompt_skill_spec.md`
4. `rp_agent_persistence_validation_spec.md`

For a prompt engineer:

1. Framework Spec
2. Runtime Protocol Spec
3. Prompt Skill Spec

For a backend engineer:

1. Framework Spec
2. Runtime Protocol Spec
3. Persistence Validation Spec

For a QA / evaluator:

1. Framework Spec
2. Runtime Protocol Spec
3. Persistence Validation Spec

---

## 7. Canonical Ownership

Each concept should have one canonical home.

| Concept | Canonical Document |
|---|---|
| design goals | framework spec |
| module list | framework spec |
| information layers | framework spec |
| runtime object schema | runtime protocol spec |
| module I/O contract | runtime protocol spec |
| prompt templates | prompt skill spec |
| prompt guardrails | prompt skill spec |
| persistent state layout | persistence validation spec |
| commit rules | persistence validation spec |
| acceptance criteria | persistence validation spec |

This avoids duplicated definitions drifting apart.

---

## 8. Suggested File Naming Convention

Recommended canonical filenames:

- `01_rp_agent_framework_spec.md`
- `02_rp_agent_runtime_protocol_spec.md`
- `03_rp_agent_prompt_skill_spec.md`
- `04_rp_agent_persistence_validation_spec.md`

This makes dependency order obvious in file listings.

---

## 9. Change Management

When modifying the system:

- architecture changes should start in the Framework Spec,
- runtime object changes should start in the Runtime Protocol Spec,
- prompt behavior changes should start in the Prompt Skill Spec,
- persistence or evaluation changes should start in the Persistence Validation Spec.

If a lower-level document changes in a way that affects upstream assumptions, the upstream document must be updated accordingly.

---

## 10. Minimal Deliverable Set

The minimum implementation-ready doc set for this project is:

1. Framework Spec
2. Runtime Protocol Spec
3. Prompt Skill Spec
4. Persistence Validation Spec

Without this set, the project will likely suffer from:
- unclear module scope,
- prompt leakage across layers,
- inconsistent state semantics,
- weak validation,
- architecture drift.

---

## 11. Current Status

This document set currently defines:

- architecture and document boundaries,
- runtime contracts,
- prompt skill structure,
- persistence and validation scaffolding.

Recommended next follow-up documents:

1. Worldbook compatibility spec
2. Turn scheduler spec
3. Test case suite
4. Import/export and editor spec

---

## 12. Summary

The documentation set should be maintained as a layered system:

- **Framework Spec** defines what the RP Agent is.
- **Runtime Protocol Spec** defines how it runs.
- **Prompt Skill Spec** defines how modules are prompted.
- **Persistence Validation Spec** defines how runtime state is stored and checked.

This separation keeps the project understandable, implementable, and maintainable.

