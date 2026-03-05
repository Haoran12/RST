# RST Lores 关联扩展检索 —— 技术规格文档

> 版本: 1.0  
> 日期: 2026-03-04  
> 状态: 已定稿，可交付开发  
> 前置文档: [rst-lores-technical-spec.md](./rst-lores-technical-spec.md) v1.1

---

## 目录

1. [问题分析](#1-问题分析)
2. [方案概述](#2-方案概述)
3. [数据模型中的关联字段](#3-数据模型中的关联字段)
4. [详细设计](#4-详细设计)
5. [调用集成点](#5-调用集成点)
6. [性能与边界约束](#6-性能与边界约束)
7. [测试规格](#7-测试规格)
8. [改动范围总结](#8-改动范围总结)
9. [决策记录](#9-决策记录)

---

## 1. 问题分析

### 1.1 现状

当前 Lore 调度器的检索阶段（Phase 1 预检索 / Phase 2 正式调度）依赖 `LoreNlpEngine` 的 BM25 检索。BM25 索引语料仅包含每个条目的 `name + tags`：

```python
# lore_nlp.py — 当前实现
def _entry_text(self, entry: LoreIndexEntry) -> str:
    return f"{entry.name} {' '.join(entry.tags)}"
```

查询文本为对话消息的原文拼接。

### 1.2 核心缺陷

**结构化语义关联无法被词频匹配覆盖。**

典型场景：对话中提到人物"吴晔"，BM25 通过 name 匹配命中了该角色条目。但角色的结构化字段蕴含的关联信息——

| CharacterData 字段 | 值 | 应关联的条目 |
|---|---|---|
| `race` | `"人类"` | WORLD_BASE/SOCIETY 中"人类"种族设定 |
| `faction` | `"宜河吴氏"` | FACTION 中"宜河吴氏"势力设定 |
| `homeland` | `"宜河"` | PLACE 中"宜河"地点设定 |
| `relationship[0].target` | `"陈若水"` | CHARACTER 中"陈若水"角色 |
| `active_form.skills` | `["fireball_id"]` | SKILLS 中对应技能条目 |

——这些值既不在 BM25 的索引语料中（索引仅含 `name + tags`），也不在对话文本中（用户谈论"吴晔"时不会把"人类"、"宜河吴氏"等元数据词汇写出来），因此 **无法被 BM25 召回**。

### 1.3 被否决的替代方案：两轮 BM25 检索

用户最初提出的方案：将第一轮 BM25 检索命中条目的完整内容作为第二轮 BM25 查询的输入文本。

**否决理由**：

| 缺陷 | 说明 |
|---|---|
| 噪声大 | 角色描述文本中大量非关联词汇产生误命中 |
| 不确定性 | "人类"等高频通用词因 BM25 IDF 权重低反而排名靠后 |
| 性能损耗 | 需加载候选条目完整内容 + 额外一轮 BM25 打分计算 |
| 不可控 | 无法按类别精细控制展开深度 |

---

## 2. 方案概述

### 2.1 核心思路：结构化关联扩展（Structured Relation Expansion）

利用 `CharacterData` 和 `LoreIndexEntry` 中已有的结构化字段，在 BM25 检索完成后，通过 **反向索引查找** 精确展开关联条目。

```
对话文本
  │
  ▼
BM25 检索 ── 第一轮候选 ──┐
                           │
                    ┌──────▼────────┐
                    │ 关联扩展       │
                    │ (dict lookup) │
                    └──────┬────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         race 关联    faction 关联   relationship 关联 ...
              │            │            │
              ▼            ▼            ▼
         扩展候选 ─── 合并去重 ──── 最终候选集
                                        │
                                        ▼
                                  调度 LLM 确认
```

### 2.2 方案优势

| 对比维度 | 两轮 BM25 | 结构化关联扩展 |
|---------|----------|---------------|
| 精确度 | 低（受词频/IDF 影响） | 高（精确字段匹配） |
| 性能 | 需加载内容 + 第二轮 BM25 计算 | 仅 dict 查找，O(1) per lookup |
| 可控性 | 难以控制召回范围 | 完全可控，可按类别/字段微调 |
| 实现复杂度 | 中等 | 低（利用现有数据结构） |
| 召回完整性 | 可能遗漏（BM25 排序不确定） | 确定性召回所有关联条目 |
| 侵入性 | 需改动 NLP 引擎核心逻辑 | 仅在现有 BM25 结果上叠加一层 |

---

## 3. 数据模型中的关联字段

### 3.1 CHARACTER 条目的关联字段

以下字段值可用于关联查找其他条目：

```python
class CharacterData(BaseModel):
    race: str           # → 查找 WORLD_BASE / SOCIETY 条目
    faction: str        # → 查找 FACTION 条目
    homeland: str       # → 查找 PLACE/SOCIETY 条目
    relationship: list[Relationship]  # → 查找其他 CHARACTER 条目
    active_form:
    skills: list[str]    # → 查找 SKILLS 条目（已是 entry_id，直接加入）
    element: list[str]   # → 查找 SKILLS 条目（已是 entry_id，直接加入）
```

### 3.2 非 CHARACTER 条目的关联字段

```python
class LoreIndexEntry(BaseModel):
    tags: list[str]     # → 查找其他条目的 name 或 tags 匹配
```

### 3.3 关联查找方向总结

```
┌─────────────────────────────────────────────────────────────────┐
│                     关联扩展规则表                                │
├───────────────────┬──────────────┬───────────────────────────────┤
│ 源条目类型         │ 源字段        │ 目标查找方式                   │
├───────────────────┼──────────────┼───────────────────────────────┤
│ CHARACTER         │ race         │ name_index 查找                │
│ CHARACTER         │ faction      │ name_index 查找                │
│ CHARACTER         │ homeland     │ name_index 查找                │
│ CHARACTER         │ rel.target   │ name_index 查找（角色名）       │
│ CHARACTER         │ skills[]     │ 直接加入（已是 entry_id）       │
│ CHARACTER         │ element[]    │ 直接加入（已是 entry_id）       │
│ 非 CHARACTER      │ tags[]       │ name_index + tag_index 查找    │
├───────────────────┴──────────────┴───────────────────────────────┤
│ 注: name_index = 条目名称 → entry_id 的反向映射                   │
│     tag_index  = 标签值 → entry_id 的反向映射                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. 详细设计

### 4.1 反向索引结构（`LoreNlpEngine` 扩展）

在 `LoreNlpEngine.build_index()` 中同步构建两个反向索引：

```python
class LoreNlpEngine:
    def __init__(self) -> None:
        # ... 现有字段 ...
        self._name_to_ids: dict[str, list[str]] = {}   # 新增
        self._tag_to_ids: dict[str, list[str]] = {}     # 新增
```

#### 4.1.1 `_name_to_ids` 构建规则

键为条目 `name` 的标准化值（`strip().lower()`），值为匹配的 `entry_id` 列表。

```python
# build_index 中新增逻辑
self._name_to_ids = {}
for entry in entries:
    key = entry.name.strip().lower()
    if key:
        self._name_to_ids.setdefault(key, []).append(entry.entry_id)
```

角色的 `aliases` 也应注册到 `_name_to_ids` 中（需从 `CharacterData` 获取）。由于 `LoreIndexEntry` 不包含 aliases，需要在 `build_index` 时传入额外信息，或在 `LoreScheduler._expand_related_ids()` 中直接处理。

**决策**：aliases 信息在展开阶段通过 `LoreStore.load_character()` 获取，不修改 `LoreIndexEntry` 结构。这保持了索引的轻量性。

#### 4.1.2 `_tag_to_ids` 构建规则

键为每个 tag 的标准化值（`strip().lower()`），值为包含该 tag 的 `entry_id` 列表。

```python
self._tag_to_ids = {}
for entry in entries:
    for tag in entry.tags:
        key = tag.strip().lower()
        if key:
            self._tag_to_ids.setdefault(key, []).append(entry.entry_id)
```

#### 4.1.3 查找方法

```python
def lookup_by_name(self, name: str) -> list[str]:
    """根据名称查找匹配的 entry_id 列表。"""
    key = name.strip().lower()
    if not key:
        return []
    return list(self._name_to_ids.get(key, []))

def lookup_by_tag(self, tag: str) -> list[str]:
    """根据标签查找匹配的 entry_id 列表。"""
    key = tag.strip().lower()
    if not key:
        return []
    return list(self._tag_to_ids.get(key, []))

def lookup_by_name_or_tag(self, value: str) -> list[str]:
    """根据名称或标签查找匹配的 entry_id 列表（合并去重）。"""
    key = value.strip().lower()
    if not key:
        return []
    results: list[str] = []
    seen: set[str] = set()
    for entry_id in self._name_to_ids.get(key, []):
        if entry_id not in seen:
            seen.add(entry_id)
            results.append(entry_id)
    for entry_id in self._tag_to_ids.get(key, []):
        if entry_id not in seen:
            seen.add(entry_id)
            results.append(entry_id)
    return results
```

#### 4.1.4 增量维护

现有的 `update_entry()` 和 `remove_entry()` 方法会调用 `build_index()` 重建全量索引，反向索引随之自动重建，无需额外处理。

### 4.2 关联扩展方法（`LoreScheduler` 扩展）

在 `LoreScheduler` 中新增 `_expand_related_ids()` 方法：

```python
def _expand_related_ids(
    self,
    store: LoreStore,
    engine: LoreNlpEngine,
    first_round_ids: list[str],
    items_by_id: dict[str, LoreIndexEntry],
) -> list[str]:
    """
    对第一轮检索命中的条目，通过结构化字段关联扩展出额外条目。
    
    Args:
        store: 当前 session 的 LoreStore
        engine: 当前 session 的 LoreNlpEngine（含反向索引）
        first_round_ids: 第一轮 BM25 检索 + constant 合并后的 entry_id 列表
        items_by_id: entry_id → LoreIndexEntry 映射
    
    Returns:
        扩展出的额外 entry_id 列表（已去重，不含 first_round_ids 中已有的）
    """
    first_round_set = set(first_round_ids)
    extra: list[str] = []
    seen: set[str] = set()

    def _add(entry_id: str) -> None:
        if entry_id not in first_round_set and entry_id not in seen:
            item = items_by_id.get(entry_id)
            if item is not None and not item.disabled:
                seen.add(entry_id)
                extra.append(entry_id)

    for entry_id in first_round_ids:
        item = items_by_id.get(entry_id)
        if item is None:
            continue

        if item.category == LoreCategory.CHARACTER:
            self._expand_character(store, engine, entry_id, _add)
        else:
            self._expand_entry(engine, item, _add)

    return extra


def _expand_character(
    self,
    store: LoreStore,
    engine: LoreNlpEngine,
    character_id: str,
    add_fn: Callable[[str], None],
) -> None:
    """展开单个 CHARACTER 条目的关联。"""
    char_file = store.load_character(character_id)
    if char_file is None:
        return
    char = char_file.data

    # 1. race → 查找种族相关设定
    if char.race:
        for eid in engine.lookup_by_name_or_tag(char.race):
            add_fn(eid)

    # 2. faction → 查找势力设定
    if char.faction:
        for eid in engine.lookup_by_name_or_tag(char.faction):
            add_fn(eid)

    # 3. homeland → 查找地点设定
    if char.homeland:
        for eid in engine.lookup_by_name_or_tag(char.homeland):
            add_fn(eid)

    # 4. relationship → 查找关联角色
    for rel in char.relationship:
        if rel.target:
            for eid in engine.lookup_by_name(rel.target):
                add_fn(eid)

    # 5. active_form.skills / element → 直接加入（已是 entry_id）
    active_form = next(
        (f for f in char.forms if f.form_id == char.active_form_id),
        char.forms[0] if char.forms else None,
    )
    if active_form is not None:
        for skill_id in active_form.skills:
            add_fn(skill_id)
        for element_id in active_form.element:
            add_fn(element_id)


def _expand_entry(
    self,
    engine: LoreNlpEngine,
    item: LoreIndexEntry,
    add_fn: Callable[[str], None],
) -> None:
    """展开单个非 CHARACTER 条目的关联（通过 tags）。"""
    for tag in item.tags:
        for eid in engine.lookup_by_name(tag):
            add_fn(eid)
```

### 4.3 完整检索流程（改造后）

```
┌───────────────────────────────────────────────────────────────┐
│                 改造后的检索流程                                │
│                                                               │
│  Step 1: 从 LoreIndex 筛选 enabled 条目                       │
│          构建 items_by_id 映射                                 │
│                                                               │
│  Step 2: 标记 constant=true 条目为「必选」                      │
│          → constant_ids                                       │
│                                                               │
│  Step 3: BM25 检索（现有逻辑不变）                              │
│          query = 对话文本 / 用户输入                             │
│          → nlp_ids (top_k=20)                                 │
│                                                               │
│  Step 4: 【新增】关联扩展                                      │
│          输入: constant_ids + nlp_ids                          │
│          对每个命中条目:                                        │
│            CHARACTER → 展开 race/faction/homeland/rel/skills  │
│            其他      → 展开 tags                               │
│          → expanded_ids                                       │
│                                                               │
│  Step 5: 合并去重                                              │
│          merged = merge(constant_ids, nlp_ids, expanded_ids)  │
│                                                               │
│  Step 6: MEMORY 可见性过滤（现有逻辑不变）                       │
│          → filtered                                           │
│                                                               │
│  Step 7: 输出最终候选集                                        │
└───────────────────────────────────────────────────────────────┘
```

---

## 5. 调用集成点

### 5.1 `pre_retrieve()` 改造

```python
async def pre_retrieve(
    self,
    session_name: str,
    messages: list[Message],
    scan_depth: int,
) -> list[str]:
    store = self._store(session_name)
    selected = self._select_messages(messages, scan_depth)
    context = self._conversation_text(selected)

    index = store.load_index()
    enabled_items = [item for item in index.items if not item.disabled]
    items_by_id = {item.entry_id: item for item in enabled_items}
    constant_ids = [item.entry_id for item in enabled_items if item.constant]
    engine = self._engine(session_name, enabled_items)
    nlp_ids = engine.retrieve(context, top_k=20)

    # ---- 新增: 关联扩展 ----
    expanded_ids = self._expand_related_ids(
        store, engine, 
        self._merge_ids(constant_ids, nlp_ids),  # 对第一轮全部命中进行展开
        items_by_id,
    )
    # ---- 新增结束 ----

    present_character_ids = self._present_character_ids(store, context)
    merged = self._merge_ids(constant_ids, nlp_ids, expanded_ids)  # 加入 expanded_ids
    filtered = self._filter_memory_candidates(
        store, items_by_id, merged, present_character_ids
    )

    rst_runtime_service.update_session_state(
        session_name,
        pre_retrieve_candidates=filtered,
        pre_retrieve_at=datetime.utcnow().isoformat(),
    )
    return filtered
```

### 5.2 `full_schedule()` 改造

```python
async def full_schedule(
    self,
    session_name: str,
    messages: list[Message],
    scan_depth: int,
    user_input: str,
    scheduler_api_config_id: str,
) -> str:
    started_at = perf_counter()
    rst_runtime_service.update_session_state(session_name, schedule_running=True)
    store = self._store(session_name)
    index = store.load_index()
    enabled_items = [item for item in index.items if not item.disabled]
    items_by_id = {item.entry_id: item for item in enabled_items}

    state = rst_runtime_service.get_session_state(session_name)
    cached = list(state.get("pre_retrieve_candidates", []))

    constant_ids = [item.entry_id for item in enabled_items if item.constant]
    engine = self._engine(session_name, enabled_items)
    user_ids = engine.retrieve(user_input, top_k=20) if user_input.strip() else []

    # ---- 新增: 对 user_ids 也进行关联扩展 ----
    user_expanded_ids = self._expand_related_ids(
        store, engine,
        self._merge_ids(constant_ids, cached, user_ids),
        items_by_id,
    )
    # ---- 新增结束 ----

    selected_messages = self._select_messages(messages, scan_depth)
    context = self._conversation_text(selected_messages)
    present_character_ids = self._present_character_ids(store, context)

    merged = self._merge_ids(constant_ids, cached, user_ids, user_expanded_ids)  # 加入扩展
    filtered = self._filter_memory_candidates(
        store, items_by_id, merged, present_character_ids
    )
    try:
        injection = await self._run_schedule_with_candidates(
            session_name,
            filtered,
            selected_messages,
            scheduler_api_config_id,
        )
        return injection
    finally:
        duration_ms = int((perf_counter() - started_at) * 1000)
        rst_runtime_service.update_session_state(
            session_name,
            schedule_running=False,
            schedule_last_duration_ms=duration_ms,
        )
```

### 5.3 `full_schedule_from_cache()` — 无需改造

该方法直接使用 Phase 1 缓存的候选（已经过关联扩展），无需额外修改。

---

## 6. 性能与边界约束

### 6.1 性能分析

| 操作 | 时间复杂度 | 说明 |
|------|-----------|------|
| 反向索引构建 | O(N × T) | N=条目数, T=平均 tags 数; 随 `build_index` 一起执行 |
| 单次 name lookup | O(1) | dict hash 查找 |
| 单次 tag lookup | O(1) | dict hash 查找 |
| 关联展开（全部） | O(K × F) | K=第一轮命中数, F=平均关联字段数; 典型值 K≤30, F≤8 |
| CHARACTER 加载 | O(K_c) | K_c=命中的角色数; 需要磁盘 I/O 读取角色文件 |

**典型场景**：20 个 BM25 命中中有 3 个 CHARACTER，每个角色展开约 5 个关联查找 → 共 ~15 次 dict 查找 + 3 次角色文件读取。总耗时可忽略不计（<5ms）。

### 6.2 展开深度限制

**仅展开一层**（不递归）。即：BM25 命中 A → 展开出 B，但不会对 B 再做展开。

理由：
1. 一层展开已能覆盖绝大多数关联场景（角色→种族/势力/地点）
2. 递归展开会导致候选集指数级膨胀
3. 调度 LLM 的 prompt 长度有限，候选过多反而降低筛选质量

### 6.3 候选数量上限

关联扩展后，合并候选集的理论上限可能较大。设置以下约束：

```python
MAX_CANDIDATES_AFTER_EXPANSION = 50  # 扩展后最大候选数
```

当扩展后候选数超过上限时，按以下优先级截断：
1. `constant=true` 条目（全部保留）
2. BM25 第一轮命中条目（按 BM25 分数排序）
3. 关联扩展条目（按来源条目的 BM25 排名排序）

### 6.4 禁用条目处理

关联扩展出的条目如果 `disabled=true`，在 `_add()` 中直接跳过，不加入候选集。

---

## 7. 测试规格

### 7.1 单元测试：反向索引构建与查找

文件：`backend/tests/test_lore_nlp.py`（新建或追加）

```python
class TestLoreNlpReverseLookup:
    """测试 LoreNlpEngine 的反向索引功能。"""

    def test_build_name_index(self):
        """build_index 后 _name_to_ids 包含所有条目名称。"""
        entries = [
            LoreIndexEntry(entry_id="e1", name="人类", category=LoreCategory.WORLD_BASE, ...),
            LoreIndexEntry(entry_id="e2", name="宜河吴氏", category=LoreCategory.FACTION, ...),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        assert engine.lookup_by_name("人类") == ["e1"]
        assert engine.lookup_by_name("宜河吴氏") == ["e2"]

    def test_build_tag_index(self):
        """build_index 后 _tag_to_ids 包含所有标签。"""
        entries = [
            LoreIndexEntry(entry_id="e1", name="人类", tags=["种族", "修行"], ...),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        assert engine.lookup_by_tag("种族") == ["e1"]
        assert engine.lookup_by_tag("修行") == ["e1"]

    def test_lookup_case_insensitive(self):
        """查找忽略大小写。"""
        entries = [
            LoreIndexEntry(entry_id="e1", name="Dark Forest", ...),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        assert engine.lookup_by_name("dark forest") == ["e1"]
        assert engine.lookup_by_name("DARK FOREST") == ["e1"]

    def test_lookup_by_name_or_tag(self):
        """同时查找 name 和 tag，结果去重。"""
        entries = [
            LoreIndexEntry(entry_id="e1", name="人类", tags=["种族"], ...),
            LoreIndexEntry(entry_id="e2", name="精灵", tags=["人类"], ...),  # tag 含"人类"
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        result = engine.lookup_by_name_or_tag("人类")
        assert "e1" in result  # name 匹配
        assert "e2" in result  # tag 匹配

    def test_lookup_empty_string(self):
        """空字符串查找返回空列表。"""
        engine = LoreNlpEngine()
        engine.build_index([...])
        assert engine.lookup_by_name("") == []
        assert engine.lookup_by_tag("") == []

    def test_index_rebuilt_on_update(self):
        """update_entry / remove_entry 后反向索引自动重建。"""
        ...
```

### 7.2 单元测试：关联扩展

文件：`backend/tests/test_lore_scheduler.py`（新建或追加）

```python
class TestExpandRelatedIds:
    """测试 LoreScheduler._expand_related_ids()。"""

    def test_character_race_expansion(self):
        """
        角色 race="人类" → 扩展出 name="人类" 的 WORLD_BASE 条目。
        """
        # 准备:
        #   角色条目 char1 (race="人类")
        #   设定条目 e_race (name="人类", category=WORLD_BASE)
        # 第一轮命中: [char1]
        # 期望扩展: [e_race]
        ...

    def test_character_faction_expansion(self):
        """
        角色 faction="宜河吴氏" → 扩展出 name="宜河吴氏" 的 FACTION 条目。
        """
        ...

    def test_character_homeland_expansion(self):
        """
        角色 homeland="宜河" → 扩展出 name="宜河" 的 PLACE 条目。
        """
        ...

    def test_character_relationship_expansion(self):
        """
        角色 relationship=[{target: "陈若水", ...}]
        → 扩展出 name="陈若水" 的 CHARACTER 条目。
        """
        ...

    def test_character_skills_expansion(self):
        """
        角色 active_form.skills=["skill_id_1"]
        → 扩展出 entry_id="skill_id_1" 的 SKILLS 条目。
        """
        ...

    def test_entry_tag_expansion(self):
        """
        非角色条目 tags=["宜河"] → 扩展出 name="宜河" 的 PLACE 条目。
        """
        ...

    def test_no_duplicate_in_expansion(self):
        """
        多个第一轮命中指向同一个关联条目时，扩展结果不重复。
        """
        ...

    def test_disabled_entries_excluded(self):
        """
        关联扩展出的条目如果 disabled=true，不会加入结果。
        """
        ...

    def test_no_recursive_expansion(self):
        """
        扩展仅执行一层，不递归展开。
        """
        ...

    def test_first_round_ids_not_duplicated(self):
        """
        第一轮已命中的 entry_id 不会在扩展结果中重复出现。
        """
        ...
```

### 7.3 集成测试：完整调度流程

文件：`backend/tests/test_lore_scheduler.py`（追加）

```python
class TestSchedulerWithExpansion:
    """测试关联扩展在完整调度流程中的集成效果。"""

    async def test_pre_retrieve_with_expansion(self):
        """
        场景: 对话提到"吴晔"
        预期: pre_retrieve 返回的候选中同时包含:
          - 吴晔角色条目（BM25 命中）
          - 人类种族设定（通过 race 展开）
          - 宜河吴氏势力设定（通过 faction 展开）
        """
        ...

    async def test_full_schedule_with_expansion(self):
        """
        场景: Phase 1 缓存 + 用户新输入
        预期: full_schedule 的候选集包含两轮展开的全部关联条目。
        """
        ...
```

---

## 8. 改动范围总结

### 8.1 修改文件

| 文件 | 改动内容 | 改动量 |
|------|---------|--------|
| `backend/app/services/lore_nlp.py` | 新增 `_name_to_ids`, `_tag_to_ids` 反向索引；新增 `lookup_by_name()`, `lookup_by_tag()`, `lookup_by_name_or_tag()` 方法；`build_index()` 中增加反向索引构建逻辑 | ~40 行新增 |
| `backend/app/services/lore_scheduler.py` | 新增 `_expand_related_ids()`, `_expand_character()`, `_expand_entry()` 方法；修改 `pre_retrieve()` 和 `full_schedule()` 以调用展开逻辑 | ~80 行新增, ~10 行修改 |

### 8.2 新增文件

| 文件 | 内容 |
|------|------|
| `backend/tests/test_lore_nlp.py` | 反向索引单元测试 |
| `backend/tests/test_lore_scheduler.py`（追加） | 关联扩展单元测试 + 集成测试 |

### 8.3 不涉及的文件

- **数据模型**（`lore.py`）—— 无需修改，利用现有结构化字段
- **存储层**（`lore_store.py`）—— 无需修改
- **API 路由**（`lores.py`）—— 无需修改，无新接口
- **前端** —— 无需修改，检索增强对前端透明
- **依赖** —— 无新增依赖

---

## 9. 决策记录

| # | 决策点 | 最终方案 | 理由 |
|---|--------|---------|------|
| R1 | 关联展开深度 | 仅一层，不递归 | 避免候选集指数膨胀；一层已覆盖主要关联 |
| R2 | aliases 处理方式 | 在 `_expand_character` 中通过 `load_character` 获取，不修改索引结构 | 保持 `LoreIndexEntry` 轻量；aliases 仅在角色展开时需要 |
| R3 | 反向索引维护策略 | 随 `build_index()` 全量重建 | 现有 `update_entry` / `remove_entry` 已调用 `build_index`，无额外开销 |
| R4 | 候选上限 | 扩展后最多 50 个候选 | 调度 LLM prompt 长度限制；超过时按优先级截断 |
| R5 | 关联扩展结果是否需要经过 MEMORY 可见性过滤 | 是 | 扩展出的 MEMORY 条目同样需要 `known_by` 过滤 |
| R6 | 非角色条目的 tag 展开范围 | 仅用 tag 值查找 `name_index`（不查 `tag_index`） | 避免 tag↔tag 交叉导致过多噪声 |
| R7 | 方案选型 | 结构化关联扩展（非两轮 BM25） | 精确度高、性能好、可控性强（详见 §2.2） |
