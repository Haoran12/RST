# RST Lores 模块 —— 技术规格文档

> 版本: 1.1  
> 日期: 2026-02-28  
> 状态: 已定稿，可交付开发  
> 变更: v1.1 新增记忆机制（§2.7, §2.8, §5.6, §7.4, §7.5），更新调度器流程、索引结构、prompt 模板

---

## 目录

1. [模块概览](#1-模块概览)
2. [数据结构](#2-数据结构)
3. [文件存储布局](#3-文件存储布局)
4. [后端架构](#4-后端架构)
5. [API 接口规格](#5-api-接口规格)
6. [Lore 调度器工作流](#6-lore-调度器工作流)
7. [动态更新工作流](#7-动态更新工作流)
8. [NLP 检索引擎](#8-nlp-检索引擎)
9. [ST 模式兼容](#9-st-模式兼容)
10. [前端架构](#10-前端架构)
11. [与现有代码的集成点](#11-与现有代码的集成点)
12. [新增依赖](#12-新增依赖)
13. [决策记录](#13-决策记录)

---

## 1. 模块概览

RST Lores 模块由两大子模块组成：

| 子模块 | 职责 |
|--------|------|
| **Lore 数据管理** | Lore 条目的 CRUD、文件存储、索引维护；包括世界设定、人物、技能、故事情节记忆与人物记忆 |
| **Lore 调度器 (Scheduler)** | 两阶段检索（预检索 + 正式调度） → LLM 确认/摘要 → 输出注入块；以及从对话中动态更新 Lore 与记忆 |

---

## 2. 数据结构

### 2.1 范畴枚举

```python
# backend/app/models/lore.py

from enum import Enum

class LoreCategory(str, Enum):
    WORLD_BASE = "world_base"    # 世界观与总体地理
    SOCIETY    = "society"       # 社会制度, 文化
    PLACE      = "place"         # 地点
    FACTION    = "faction"       # 组织与势力
    CHARACTER  = "character"     # 人物
    SKILLS     = "skills"        # 技能体系
    OTHERS     = "others"        # 其他
    PLOT       = "plot"          # 故事情节记忆（全局事件时间线）
    MEMORY     = "memory"        # 人物记忆（per-character，仅用于索引）
```

### 2.2 通用 Lore 条目（非 character 范畴）

```python
class LoreEntry(BaseModel):
    id: str                          # nanoid, 12 chars
    name: str                        # 条目名称
    category: LoreCategory           # 范畴（不可为 CHARACTER 或 MEMORY）
    content: str = ""                # YAML 格式设定文本
    disabled: bool = False           # 是否禁用（不参与调度）
    constant: bool = False           # 是否常驻注入（跳过调度判断）
    tags: list[str] = []             # 检索标签
    created_at: datetime
    updated_at: datetime
```

**说明**：`category=PLOT` 的条目使用 `LoreEntry` 结构，每条代表一个故事事件。`category=MEMORY` 不直接用于 `LoreEntry`，而是通过 `CharacterMemory` 嵌入人物数据中并在索引中注册。

skills 范畴分为两种条目:
```json
  elements : {
    [
      {
        "name": "火",
        "description": "高温与灼烧"
      },
      ...
    ]
  }   
  skills : {
    [
      {
        "name": "火球术",
        "description": "发射一个火球攻击敌人",
        "type": "active",
        "element": "火"
      },
      ...
    ]
}
```

### 2.3 Character 数据结构

#### 2.3.1 人物关系

```python
class Relationship(BaseModel):
    target: str                      # 对方人物id（character_id）
    relation: str                    # 关系描述
```

#### 2.3.2 人物形态

```python
class CharacterForm(BaseModel):
    form_id: str                     # nanoid, 12 chars
    form_name: str                   # 形态名称，如 "人形"、"战斗形态"、"灵体"
    is_default: bool = True          # 是否为默认形态

    # --- 长期属性（随故事发展更新，长期作用） ---
    physique: str = ""               # 身体特征：身高/体型/肤色/瞳色等
    features: str = ""               # 其他特点
    vitality_max: int = 100            # 精力/元气上限（数值）
    mana_potency: int = 100            # 法力水平（数值）
    toughness: int = 10               # 韧性/防御水平（数值）
    weak: list[str] = []             # 虚弱的技能元素
    resist: list[str] = []           # 耐受的技能元素
    element: list[str] = []          # 熟悉的元素（存储 skills 条目的 entry_id）
    skills: list[str] = []           # 技能表（存储 skills 条目的 entry_id）
    penetration: list[str] = []      # 穿透能力（skills 条目的 entry_id, elements条目）

    # --- 短期场景属性（当前场景状态，频繁更新） ---
    clothing: str = ""               # 当前衣着
    body: str = ""                   # 当前身体状况
    mind: str = ""                   # 当前精神状态和心理活动
    vitality_cur: int = 50           # 当前精力/元气（数值）
    activity: str = ""               # 当前行动
```

#### 2.3.3 完整人物数据

```python
class CharacterData(BaseModel):
    character_id: str                # nanoid, 12 chars

    # --- 基础固定字段 ---
    name: str                        # 人物名
    race: str                        # 种族（人/灵/妖/邪祟）
    birth: date                      # 出生年月日
    homeland: str = ""               # 故乡

    # --- 长期动态字段（跨形态共享） ---
    aliases: list[str] = []          # 别名/昵称/外号
    role: str = ""                   # 职业/身份
    faction: str = ""                # 所属组织（可为空）
    objective: str = ""              # 最近行动目标
    personality: str = ""            # 性格
    relationship: list[Relationship] = []  # 与其他人物的关系

    # --- 记忆 ---
    memories: list[CharacterMemory] = []   # 人物记忆列表（见 §2.7）

    # --- 形态列表 ---
    forms: list[CharacterForm] = []  # 至少一个默认形态
    active_form_id: str = ""         # 当前激活的形态 ID

    # --- 元数据 ---
    tags: list[str] = []             # 检索标签
    disabled: bool = False           # 是否禁用
    constant: bool = False           # 是否常驻注入
    created_at: datetime
    updated_at: datetime
```

#### 2.3.4 Character 文件

```python
class CharacterFile(BaseModel):
    data: CharacterData
    version: int = 1
```

### 2.4 范畴文件容器

非 character 范畴的条目按范畴归类到文件中：

```python
class LoreFile(BaseModel):
    world_id: str = "default"        # 世界标识，MVP 固定为 "default"
    category: LoreCategory           # 对应范畴（含 PLOT）
    entries: list[LoreEntry] = []    # 该范畴下所有条目
    version: int = 1
```

### 2.5 索引文件

用于快速检索，避免每次遍历所有文件：

```python
class LoreIndexEntry(BaseModel):
    entry_id: str                    # LoreEntry.id / CharacterData.character_id / CharacterMemory.memory_id
    name: str
    category: LoreCategory           # 包含 PLOT 和 MEMORY
    tags: list[str]
    constant: bool
    disabled: bool
    file_path: str                   # 相对于 rst_data/ 的路径
    owner: str | None = None         # MEMORY 类型时，指向所属 character_id
    importance: int = 5              # MEMORY/PLOT 的重要度，用于调度优先级排序（1-10）

class LoreIndex(BaseModel):
    items: list[LoreIndexEntry] = []
    updated_at: datetime
    version: int = 1
```

### 2.6 调度器 Prompt 模板

调度器的 LLM 提示词模板独立于主 Preset 存储：

```python
class SchedulerPromptTemplate(BaseModel):
    id: str = "default"
    name: str = "默认调度器模板"
    confirm_prompt: str = ""         # 确认/摘要阶段的 prompt 模板
    extract_prompt: str = ""         # 动态更新提取阶段的 prompt 模板
    consolidate_prompt: str = ""     # 记忆合并/摘要阶段的 prompt 模板（v1.1 新增）
    version: int = 1
```

存储位置：`data/sessions/{session_name}/rst_data/scheduler_template.json`

### 2.7 人物记忆（CharacterMemory）

人物记忆是 `CharacterData` 的嵌套结构，每条记忆代表人物对一个事件的主观认知：

```python
class CharacterMemory(BaseModel):
    memory_id: str                   # nanoid, 12 chars
    event: str                       # 事件描述（人物主观视角）
    importance: int = 5              # 重要度 1-10（影响调度优先级和合并淘汰）
    tags: list[str] = []             # 检索标签
    known_by: list[str] = []         # 知道此记忆的其他人物 character_id 列表
                                     # 空列表 = 仅此人物知道
                                     # 用于信息不对称过滤
    plot_event_id: str | None = None # 关联的全局 PlotEvent 的 entry_id（可为空，表示私人记忆）
    is_consolidated: bool = False    # 是否为合并摘要后的记忆（非原始记忆）
    created_at: datetime
```

**设计要点**：

1. 人物记忆存储在对应的 `CharacterFile` 中（`CharacterData.memories`）
2. 每条 memory 同时在 `LoreIndex` 中注册为 `category=MEMORY` 的索引条目
3. 调度器可以独立检索到某个人物的某条记忆
4. `known_by` 字段用于信息不对称：调度器在筛选记忆时，只注入当前场景中在场人物知道的记忆
5. `plot_event_id` 可选关联到全局故事事件，实现双向追溯
6. `is_consolidated` 标记合并后的摘要记忆，与原始记忆区分

### 2.8 故事情节记忆（Plot Events）

故事情节记忆使用 `LoreEntry` 结构，`category=PLOT`，存储在 `rst_data/default/plot.json` 中：

```python
# 每条 LoreEntry (category=PLOT) 代表一个故事事件：
# 
# name: "黑森林伏击"
# content: "第三章：主角团在黑森林行进时遭遇暗影教团伏击。艾琳娜被暗箭射中左臂，
#           凯尔临时决定倒戈相助。战斗持续约两小时，最终击退敌人但损失惨重。"
# tags: ["黑森林", "艾琳娜", "凯尔", "暗影教团", "伏击", "第三章"]
# constant: false   # 不常驻，由调度器按相关性选择注入
# disabled: false
```

**与人物记忆的关系**：

- 一个 PlotEvent 是客观事实的记录
- 多个 CharacterMemory 可以通过 `plot_event_id` 引用同一个 PlotEvent
- 不同人物对同一事件可以有不同的主观记忆
- 某些人物可能完全不知道某个事件（不会有对应的 CharacterMemory）

---

## 3. 文件存储布局

```
data/sessions/{session_name}/rst_data/
├── characters/
│   ├── {character_id}.json              # CharacterFile（含 memories 字段）
│   └── ...
├── default/                              # world_id = "default"
│   ├── world_base.json                  # LoreFile (category=world_base)
│   ├── society.json                     # LoreFile (category=society)
│   ├── place.json                       # LoreFile (category=place)
│   ├── faction.json                     # LoreFile (category=faction)
│   ├── skills.json                      # LoreFile (category=skills)
│   ├── others.json                      # LoreFile (category=others)
│   └── plot.json                        # LoreFile (category=plot) ← v1.1 新增
├── .index/
│   └── index.json                        # LoreIndex（含 PLOT 和 MEMORY 条目）
└── scheduler_template.json               # SchedulerPromptTemplate
```

### 存储规则

- 所有 JSON 文件必须包含 `version` 字段
- 所有写入使用现有 `file_io.atomic_write()`（临时文件 → 替换 + `.bak` 备份）
- 索引文件在每次 Lore CRUD 操作后同步更新
- Character 每人一文件，文件名为 `{character_id}.json`
- 非 character 范畴每个范畴一个文件，文件名为 `{category}.json`
- **记忆存储**：人物记忆内嵌在 character 文件中；故事事件存储在 `plot.json` 中

### 初始化

创建 Session 时（`session_service.create_session()`）需初始化：

1. `rst_data/characters/` 目录（已有）
2. `rst_data/.index/` 目录（已有）
3. `rst_data/default/` 目录（新增）
4. 各范畴空文件：`world_base.json`, `society.json`, `place.json`, `faction.json`, `skills.json`, `others.json`, **`plot.json`**（新增，内容为空 `LoreFile`）
5. `rst_data/.index/index.json`（新增，空 `LoreIndex`）
6. `rst_data/scheduler_template.json`（新增，默认模板）

---

## 4. 后端架构

### 4.1 新增文件清单

```
backend/app/
├── models/
│   └── lore.py                    # 所有 Lore 相关 Pydantic 模型（含 CharacterMemory）
├── services/
│   ├── lore_service.py            # Lore CRUD + 索引管理 + 记忆管理
│   ├── lore_scheduler.py          # 调度器（两阶段检索 + LLM 确认 + 记忆过滤）
│   ├── lore_updater.py            # 动态更新（从对话提取 Lore + 记忆 + 记忆合并）
│   └── lore_nlp.py                # NLP 检索引擎（jieba + BM25）
├── routers/
│   └── lores.py                   # REST API 路由
└── storage/
    └── lore_store.py              # Lore 文件读写封装
```

### 4.2 模块职责

#### `lore_store.py` — 存储层

```python
class LoreStore:
    """管理单个 Session 的 Lore 文件读写"""

    def __init__(self, session_dir: Path) -> None: ...

    # --- 索引 ---
    def load_index(self) -> LoreIndex: ...
    def save_index(self, index: LoreIndex) -> None: ...
    def rebuild_index(self) -> LoreIndex: ...

    # --- Character ---
    def load_character(self, character_id: str) -> CharacterFile | None: ...
    def save_character(self, char_file: CharacterFile) -> None: ...
    def delete_character(self, character_id: str) -> bool: ...
    def list_characters(self) -> list[CharacterData]: ...

    # --- 范畴文件 ---
    def load_category_file(self, category: LoreCategory, world_id: str = "default") -> LoreFile: ...
    def save_category_file(self, lore_file: LoreFile) -> None: ...

    # --- 条目操作（非 character） ---
    def find_entry(self, entry_id: str) -> tuple[LoreEntry, LoreFile] | None: ...
    def add_entry(self, entry: LoreEntry, world_id: str = "default") -> None: ...
    def update_entry(self, entry_id: str, updates: dict) -> LoreEntry | None: ...
    def delete_entry(self, entry_id: str) -> bool: ...

    # --- 调度器模板 ---
    def load_scheduler_template(self) -> SchedulerPromptTemplate: ...
    def save_scheduler_template(self, template: SchedulerPromptTemplate) -> None: ...

    # --- 批量读取 ---
    def load_all_entries(self) -> list[LoreEntry | CharacterData]: ...
    def load_entries_by_ids(self, entry_ids: list[str]) -> list[LoreEntry | CharacterData]: ...

    # --- 记忆操作 --- (v1.1 新增)
    def load_character_memories(self, character_id: str) -> list[CharacterMemory]: ...
    def add_memory(self, character_id: str, memory: CharacterMemory) -> None: ...
    def update_memory(self, character_id: str, memory_id: str, updates: dict) -> CharacterMemory | None: ...
    def delete_memory(self, character_id: str, memory_id: str) -> bool: ...
    def replace_memories(self, character_id: str, memories: list[CharacterMemory]) -> None: ...
        """用于记忆合并后批量替换"""
```

#### `lore_service.py` — 业务层

```python
class LoreService:
    """Lore CRUD 操作，维护索引一致性"""

    # --- 通用条目 CRUD ---
    def create_entry(session_name: str, payload: LoreEntryCreate) -> LoreEntry: ...
    def get_entry(session_name: str, entry_id: str) -> LoreEntry | CharacterData: ...
    def update_entry(session_name: str, entry_id: str, payload: LoreEntryUpdate) -> LoreEntry: ...
    def delete_entry(session_name: str, entry_id: str) -> None: ...
    def list_entries(session_name: str, category: LoreCategory | None = None) -> list[LoreEntry | CharacterData]: ...
    def batch_update(session_name: str, payload: LoreBatchUpdate) -> list: ...

    # --- Character 专用 CRUD ---
    def create_character(session_name: str, payload: CharacterCreate) -> CharacterData: ...
    def get_character(session_name: str, character_id: str) -> CharacterData: ...
    def update_character(session_name: str, character_id: str, payload: CharacterUpdate) -> CharacterData: ...
    def delete_character(session_name: str, character_id: str) -> None: ...

    # --- Character 形态管理 ---
    def add_form(session_name: str, character_id: str, payload: FormCreate) -> CharacterForm: ...
    def update_form(session_name: str, character_id: str, form_id: str, payload: FormUpdate) -> CharacterForm: ...
    def delete_form(session_name: str, character_id: str, form_id: str) -> None: ...
    def set_active_form(session_name: str, character_id: str, form_id: str) -> CharacterData: ...

    # --- Character 记忆管理 --- (v1.1 新增)
    def list_memories(session_name: str, character_id: str) -> list[CharacterMemory]: ...
    def add_memory(session_name: str, character_id: str, payload: MemoryCreate) -> CharacterMemory: ...
    def update_memory(session_name: str, character_id: str, memory_id: str, payload: MemoryUpdate) -> CharacterMemory: ...
    def delete_memory(session_name: str, character_id: str, memory_id: str) -> None: ...

    # --- 调度器模板 ---
    def get_scheduler_template(session_name: str) -> SchedulerPromptTemplate: ...
    def update_scheduler_template(session_name: str, payload: SchedulerTemplateUpdate) -> SchedulerPromptTemplate: ...
```

#### `lore_nlp.py` — NLP 检索引擎

```python
class LoreNlpEngine:
    """基于 jieba 分词 + BM25 的 Lore 检索引擎"""

    def __init__(self) -> None:
        self._tokenizer_ready: bool = False
        self._custom_dict: set[str] = set()
        self._bm25: BM25Okapi | None = None
        self._corpus_ids: list[str] = []

    def build_index(self, entries: list[LoreIndexEntry]) -> None:
        """
        从索引条目构建 BM25 检索索引。
        1. 将所有条目的 name + tags 加入 jieba 自定义词典
        2. 将每个条目的 name + tags 拼接为文档
           - MEMORY 条目额外拼接 event 摘要前 50 字
        3. jieba 分词后构建 BM25 索引
        """
        ...

    def retrieve(self, query_text: str, top_k: int = 20) -> list[str]:
        """
        对查询文本分词后，用 BM25 检索返回 top_k 个 entry_id。
        """
        ...

    def update_entry(self, entry: LoreIndexEntry) -> None:
        """增量更新单条目（重建索引的轻量版）"""
        ...

    def remove_entry(self, entry_id: str) -> None:
        """从索引中移除条目"""
        ...
```

#### `lore_scheduler.py` — 调度器

```python
class LoreScheduler:
    """两阶段 Lore 调度，含记忆过滤"""

    async def pre_retrieve(
        self,
        session_name: str,
        messages: list[Message],
        scan_depth: int,
    ) -> list[str]:
        """
        Phase 1 — 预检索。
        在 run_chat 返回后自动异步调用。
        输入：最近 scan_depth 条 visible 消息（含最新 assistant 回复）。
        输出：候选 entry_id 列表（含 PLOT 和 MEMORY 条目），缓存至 rst_runtime_service。
        不调用 LLM。
        
        记忆过滤：
        - MEMORY 条目通过 known_by 字段过滤：
          仅保留 known_by 包含当前场景中在场人物的记忆
        """
        ...

    async def full_schedule(
        self,
        session_name: str,
        messages: list[Message],
        scan_depth: int,
        user_input: str,
        scheduler_api_config_id: str,
    ) -> str:
        """
        Phase 2 — 正式调度。
        在 run_chat 组装 prompt 前调用。
        1. 取 Phase 1 缓存的候选 + 用户最新输入补充匹配
        2. constant=True 条目直接加入
        3. 对 MEMORY 条目应用 known_by 过滤
        4. 调用 scheduler LLM 确认/摘要（prompt 中标注条目类型）
        5. 返回 injection_block（string）
        """
        ...

    async def full_schedule_from_cache(
        self,
        session_name: str,
        scheduler_api_config_id: str,
    ) -> str:
        """
        空输入 Send 时使用。
        直接使用 Phase 1 缓存的候选，不做补充匹配。
        调用 LLM 确认/摘要后返回 injection_block。
        """
        ...
```

#### `lore_updater.py` — 动态更新

```python
class LoreUpdater:
    """从对话中提取信息并更新 Lore，包括记忆"""

    async def sync_from_conversation(
        self,
        session_name: str,
        messages: list[Message],
        scan_depth: int,
        scheduler_api_config_id: str,
    ) -> SyncResult:
        """
        1. 取最近 scan_depth 条 visible 消息
        2. 调用 scheduler LLM 提取结构化更新
        3. 解析 LLM 输出 JSON（含 plot 事件和 character 记忆）
        4. 对 character 属性：字段级覆盖
        5. 对 character 记忆：追加新记忆条目
        6. 对 plot 事件：创建新 LoreEntry (category=PLOT)
        7. 对其他范畴：追加内容
        8. 写入文件 + 更新索引
        9. 检查是否需要触发记忆合并
        """
        ...

    async def consolidate_memories(
        self,
        session_name: str,
        character_id: str,
        scheduler_api_config_id: str,
    ) -> ConsolidateResult:
        """
        记忆合并/摘要。当人物记忆数量超过阈值时自动触发。
        
        1. 加载该人物所有记忆
        2. 按 importance 排序
        3. 选取低重要度的旧记忆（如 importance ≤ 3 且 created_at 较早的）
        4. 调用 scheduler LLM 将多条旧记忆合并为 1-2 条摘要记忆
        5. 删除原始旧记忆，插入摘要记忆（is_consolidated=True）
        6. 更新索引
        """
        ...

class SyncResult(BaseModel):
    updated_entries: list[str]       # 更新的 entry_id 列表
    created_entries: list[str]       # 新建的 entry_id 列表
    new_memories: int                # 新增记忆数
    new_plot_events: int             # 新增故事事件数
    duration_ms: int

class ConsolidateResult(BaseModel):
    character_id: str
    removed_count: int               # 被合并删除的记忆数
    created_count: int               # 新增的摘要记忆数
    duration_ms: int
```

---

## 5. API 接口规格

所有接口挂载在 `/api/sessions/{session_name}/lores` 路径下。

### 5.1 通用 Lore 条目（非 character）

| 方法 | 路径 | 描述 | Request Body | Response |
|------|------|------|-------------|----------|
| `GET` | `/entries` | 列出所有非 character 条目 | Query: `?category=xxx`（可选，含 plot） | `LoreEntryListResponse` |
| `POST` | `/entries` | 创建条目 | `LoreEntryCreate` | `LoreEntry` |
| `GET` | `/entries/{entry_id}` | 获取单条目 | - | `LoreEntry` |
| `PUT` | `/entries/{entry_id}` | 更新条目 | `LoreEntryUpdate` | `LoreEntry` |
| `DELETE` | `/entries/{entry_id}` | 删除条目 | - | `204 No Content` |
| `PUT` | `/entries/batch` | 批量更新 disabled/constant | `LoreBatchUpdate` | `LoreEntryListResponse` |

#### 请求/响应模型

```python
class LoreEntryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: LoreCategory           # 不可为 CHARACTER 或 MEMORY；可为 PLOT
    content: str = ""
    disabled: bool = False
    constant: bool = False
    tags: list[str] = []

class LoreEntryUpdate(BaseModel):
    name: str | None = None
    content: str | None = None
    disabled: bool | None = None
    constant: bool | None = None
    tags: list[str] | None = None

class LoreBatchUpdate(BaseModel):
    updates: list[LoreBatchItem]

class LoreBatchItem(BaseModel):
    entry_id: str
    disabled: bool | None = None
    constant: bool | None = None

class LoreEntryListResponse(BaseModel):
    entries: list[LoreEntry]
    total: int
```

### 5.2 Character 接口

| 方法 | 路径 | 描述 | Request Body | Response |
|------|------|------|-------------|----------|
| `GET` | `/characters` | 列出所有 character | - | `CharacterListResponse` |
| `POST` | `/characters` | 创建 character | `CharacterCreate` | `CharacterData` |
| `GET` | `/characters/{character_id}` | 获取 character 详情 | - | `CharacterData` |
| `PUT` | `/characters/{character_id}` | 更新 character | `CharacterUpdate` | `CharacterData` |
| `DELETE` | `/characters/{character_id}` | 删除 character | - | `204 No Content` |

#### Character 形态接口

| 方法 | 路径 | 描述 | Request Body | Response |
|------|------|------|-------------|----------|
| `POST` | `/characters/{character_id}/forms` | 添加形态 | `FormCreate` | `CharacterForm` |
| `PUT` | `/characters/{character_id}/forms/{form_id}` | 更新形态 | `FormUpdate` | `CharacterForm` |
| `DELETE` | `/characters/{character_id}/forms/{form_id}` | 删除形态 | - | `204` |
| `PUT` | `/characters/{character_id}/active-form` | 切换激活形态 | `{"form_id": "xxx"}` | `CharacterData` |

#### 请求/响应模型

```python
class CharacterCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    race: str = Field(min_length=1, max_length=64)
    birth: str = ""
    homeland: str = ""
    aliases: list[str] = []
    role: str = ""
    faction: str = ""
    objective: str = ""
    personality: str = ""
    relationship: list[Relationship] = []
    tags: list[str] = []
    disabled: bool = False
    constant: bool = False
    # 创建时自动生成一个默认形态

class CharacterUpdate(BaseModel):
    name: str | None = None
    race: str | None = None
    birth: str | None = None
    homeland: str | None = None
    aliases: list[str] | None = None
    role: str | None = None
    faction: str | None = None
    objective: str | None = None
    personality: str | None = None
    relationship: list[Relationship] | None = None
    tags: list[str] | None = None
    disabled: bool | None = None
    constant: bool | None = None

class FormCreate(BaseModel):
    form_name: str = Field(min_length=1, max_length=64)
    is_default: bool = False
    physique: str = ""
    features: str = ""
    vitality_max: str = ""
    mana_potency: int = 0
    toughness: int = 0
    weak: list[str] = []
    resist: list[str] = []
    element: list[str] = []          # entry_id 列表
    skills: list[str] = []           # entry_id 列表
    penetration: int = 0

class FormUpdate(BaseModel):
    form_name: str | None = None
    is_default: bool | None = None
    physique: str | None = None
    features: str | None = None
    vitality_max: str | None = None
    mana_potency: int | None = None
    toughness: int | None = None
    weak: list[str] | None = None
    resist: list[str] | None = None
    element: list[str] | None = None
    skills: list[str] | None = None
    penetration: int | None = None
    clothing: str | None = None
    body: str | None = None
    mind: str | None = None
    vitality_cur: str | None = None
    activity: str | None = None

class CharacterListResponse(BaseModel):
    characters: list[CharacterData]
    total: int
```

### 5.3 调度器接口

| 方法 | 路径 | 描述 | Response |
|------|------|------|----------|
| `POST` | `/schedule` | 手动触发一次完整调度（调试用） | `ScheduleResult` |
| `GET` | `/schedule/status` | 查询调度状态 | `ScheduleStatus` |

```python
class ScheduleResult(BaseModel):
    injection_block: str
    matched_entry_ids: list[str]
    duration_ms: int

class ScheduleStatus(BaseModel):
    running: bool
    last_run_at: str | None = None
    last_matched_count: int | None = None
    cached_candidates: list[str] = []  # Phase 1 缓存的候选 ID
```

### 5.4 动态更新接口

| 方法 | 路径 | 描述 | Response |
|------|------|------|----------|
| `POST` | `/sync` | 手动触发一次从对话提取更新 | `SyncResult` |
| `GET` | `/sync/status` | 查询同步状态 | `SyncStatus` |

```python
class SyncResult(BaseModel):
    updated_entries: list[str]
    created_entries: list[str]
    new_memories: int
    new_plot_events: int
    duration_ms: int

class SyncStatus(BaseModel):
    running: bool
    last_run_at: str | None = None
    rounds_since_last_sync: int = 0
    sync_interval: int                # 当前 N 值
```

### 5.5 调度器模板接口

| 方法 | 路径 | 描述 | Request Body | Response |
|------|------|------|-------------|----------|
| `GET` | `/scheduler-template` | 获取调度器 prompt 模板 | - | `SchedulerPromptTemplate` |
| `PUT` | `/scheduler-template` | 更新调度器 prompt 模板 | `SchedulerTemplateUpdate` | `SchedulerPromptTemplate` |

```python
class SchedulerTemplateUpdate(BaseModel):
    confirm_prompt: str | None = None
    extract_prompt: str | None = None
    consolidate_prompt: str | None = None    # v1.1 新增
```

### 5.6 Character 记忆接口（v1.1 新增）

| 方法 | 路径 | 描述 | Request Body | Response |
|------|------|------|-------------|----------|
| `GET` | `/characters/{character_id}/memories` | 列出人物所有记忆 | - | `MemoryListResponse` |
| `POST` | `/characters/{character_id}/memories` | 手动添加记忆 | `MemoryCreate` | `CharacterMemory` |
| `PUT` | `/characters/{character_id}/memories/{memory_id}` | 更新记忆 | `MemoryUpdate` | `CharacterMemory` |
| `DELETE` | `/characters/{character_id}/memories/{memory_id}` | 删除记忆 | - | `204` |
| `POST` | `/characters/{character_id}/memories/consolidate` | 手动触发记忆合并 | - | `ConsolidateResult` |

```python
class MemoryCreate(BaseModel):
    event: str = Field(min_length=1)
    importance: int = Field(default=5, ge=1, le=10)
    tags: list[str] = []
    known_by: list[str] = []             # 其他知道此记忆的人物 character_id
    plot_event_id: str | None = None     # 关联的 PlotEvent entry_id

class MemoryUpdate(BaseModel):
    event: str | None = None
    importance: int | None = Field(default=None, ge=1, le=10)
    tags: list[str] | None = None
    known_by: list[str] | None = None

class MemoryListResponse(BaseModel):
    memories: list[CharacterMemory]
    total: int

class ConsolidateResult(BaseModel):
    character_id: str
    removed_count: int
    created_count: int
    duration_ms: int
```

---

## 6. Lore 调度器工作流

### 6.1 两阶段调度流程图

```
┌─────────────────────────────────────────────────────────┐
│                    Phase 1 — 预检索                       │
│  触发：run_chat 返回 assistant 回复后，自动异步启动          │
│                                                         │
│  输入：最近 scan_depth 条 visible 消息                     │
│        （含最新 assistant 回复）                           │
│                                                         │
│  步骤：                                                  │
│  1. 从 LoreIndex 筛选 disabled=false 的条目               │
│     （包含 PLOT 和 MEMORY 条目）                          │
│  2. constant=true 条目标记为「必选」                       │
│  3. 剩余条目用 NLP 引擎（jieba+BM25）检索                  │
│     - 消息文本 → jieba 分词 → BM25 查询 → top_k 候选      │
│  4. 对 MEMORY 条目应用 known_by 过滤：                    │
│     - 仅保留 known_by 包含当前场景在场人物的记忆            │
│     - 或 known_by 为空（仅所属人物知道的私人记忆，          │
│       仅当所属人物在场时保留）                              │
│  5. 合并「必选」+ 「BM25 top_k（已过滤）」= 候选集          │
│  6. 候选 entry_id 列表缓存至 rst_runtime_service           │
│     session_state["pre_retrieve_candidates"]              │
│                                                         │
│  输出：无（结果缓存在内存中）                               │
└─────────────────────────────────────────────────────────┘
                           ↓
                    用户开始输入...
                           ↓
                    用户点击 Send
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  Phase 2 — 正式调度                       │
│  触发：run_chat 组装 prompt 前                             │
│                                                         │
│  分支 A：用户 Send 了非空消息                               │
│  1. 取 Phase 1 缓存候选                                   │
│  2. 用最新 user_input 文本补充 BM25 检索                   │
│  3. 对新增的 MEMORY 条目应用 known_by 过滤                 │
│  4. 合并去重 → 最终候选集                                  │
│  5. 加载候选条目完整内容                                    │
│  6. 调用 scheduler LLM：                                  │
│     - 输入：候选条目内容（标注类型标签）                     │
│            + 最近 scan_depth 条消息摘要                     │
│     - Prompt：使用 scheduler_template.confirm_prompt       │
│     - 输出：injection_block                               │
│  7. 返回 injection_block → PromptAssembler.lores_block    │
│                                                         │
│  分支 B：用户 Send 了空消息                                 │
│  1. 直接使用 Phase 1 缓存候选（不做补充匹配）                │
│  2. 后续同分支 A 步骤 5-7                                  │
│                                                         │
│  输出：injection_block (string)                            │
└─────────────────────────────────────────────────────────┘
```

### 6.2 调度器 LLM Prompt 模板（默认值）

```
confirm_prompt 默认模板：

你是一个世界设定管理助手。以下是当前对话的最近几条消息和候选世界设定/人物/记忆条目。

## 当前对话上下文
{conversation_context}

## 候选设定与记忆条目
{candidate_entries}

条目类型标记说明：
- [SETTING] — 世界设定条目（世界观/地点/组织/社会等）
- [CHARACTER] — 人物属性条目
- [SKILL] — 技能/元素条目
- [PLOT] — 故事情节事件（全局客观记录）
- [MEMORY:人物名] — 人物主观记忆

请完成以下任务：
1. 判断哪些候选条目与当前对话场景相关
2. 对 [PLOT] 和 [MEMORY] 条目，仅注入与当前场景直接相关的
3. 对 [MEMORY] 条目，仅在该人物参与当前场景时注入其记忆
4. 对相关条目进行精简摘要，仅保留与当前场景有关的信息
5. 将结果组织为可直接注入对话提示词的文本块

输出要求：
- 直接输出整理后的设定文本，不要输出解释或标记
- 如果没有相关条目，输出空字符串
- 注意精简，避免冗余，不要注入与当前场景无关的历史记忆
```

### 6.3 缓存管理

Phase 1 预检索结果通过 `rst_runtime_service.update_session_state()` 缓存：

```python
rst_runtime_service.update_session_state(
    session_name,
    pre_retrieve_candidates=candidate_ids,       # list[str]
    pre_retrieve_at=datetime.utcnow().isoformat(),
)
```

Phase 2 完成后清除缓存：

```python
rst_runtime_service.update_session_state(
    session_name,
    pre_retrieve_candidates=[],
    last_schedule_at=datetime.utcnow().isoformat(),
    last_injection_block=injection_block,
)
```

---

## 7. 动态更新工作流

### 7.1 触发机制

- 每 N 轮对话触发一次（N = `lore_sync_interval`，默认 3）
- N 的约束：`1 ≤ N ≤ min(5, mem_length)`，`mem_length = -1` 时上限为 5
- 计数器维护在 `rst_runtime_service` 的 session_state 中

```python
# 在 run_chat 成功后递增
state = rst_runtime_service.get_session_state(session_name)
rounds = state.get("rounds_since_sync", 0) + 1

if rounds >= session.lore_sync_interval:
    # 异步启动动态更新任务
    task = asyncio.create_task(lore_updater.sync_from_conversation(...))
    rst_runtime_service.register_task(session_name, task)
    rounds = 0

rst_runtime_service.update_session_state(session_name, rounds_since_sync=rounds)
```

### 7.2 动态更新流程图

```
┌─────────────────────────────────────────────────────────┐
│                    动态更新流程                            │
│  触发：第 N 轮对话完成后（异步，不阻塞主对话）               │
│                                                         │
│  Step 1: 取最近 scan_depth 条 visible 消息                │
│                                                         │
│  Step 2: 调用 scheduler LLM                              │
│    - Prompt: scheduler_template.extract_prompt            │
│    - 输入: 消息文本 + 现有 Lore 条目摘要                    │
│    - 要求输出 JSON 格式的更新指令                           │
│                                                         │
│  Step 3: 解析 LLM 输出                                   │
│    预期格式:                                              │
│    [                                                     │
│      {                                                   │
│        "type": "character_update",                       │
│        "name": "艾琳娜",                                  │
│        "field_updates": {                                │
│          "vitality_cur": 45,                             │
│          "body": "左臂受伤，行动受限",                      │
│          "activity": "在营地休息疗伤"                      │
│        }                                                 │
│      },                                                  │
│      {                                                   │
│        "type": "plot_event",                             │
│        "name": "黑森林伏击",                               │
│        "content": "主角团在黑森林遭遇暗影教团伏击...",       │
│        "tags": ["黑森林", "艾琳娜", "凯尔", "暗影教团"]     │
│      },                                                  │
│      {                                                   │
│        "type": "character_memory",                       │
│        "character_name": "艾琳娜",                        │
│        "event": "在黑森林被暗箭射中左臂，凯尔救了我",       │
│        "importance": 7,                                  │
│        "tags": ["受伤", "凯尔", "黑森林"],                 │
│        "known_by": ["凯尔的character_id"],                │
│        "plot_event_name": "黑森林伏击"                    │
│      },                                                  │
│      {                                                   │
│        "type": "character_memory",                       │
│        "character_name": "凯尔",                          │
│        "event": "看到艾琳娜受伤后决定背叛暗影教团",         │
│        "importance": 9,                                  │
│        "tags": ["背叛", "艾琳娜", "暗影教团"],              │
│        "known_by": [],                                   │
│        "plot_event_name": "黑森林伏击"                    │
│      },                                                  │
│      {                                                   │
│        "type": "lore_update",                            │
│        "name": "黑森林",                                  │
│        "category": "place",                              │
│        "content_append": "第三章：此地发生了伏击战...",     │
│        "tags": ["黑森林"]                                 │
│      }                                                   │
│    ]                                                     │
│                                                         │
│  Step 4: 分类处理                                        │
│    - type=character_update → 字段级覆盖                   │
│    - type=plot_event → 创建 LoreEntry(category=PLOT)     │
│    - type=character_memory → 追加 CharacterMemory         │
│      - plot_event_name → 解析为 plot_event_id             │
│      - known_by 中的名字 → 解析为 character_id            │
│    - type=lore_update → 内容追加                          │
│    - 名字无匹配 → 创建新条目                               │
│                                                         │
│  Step 5: 写入文件 + 更新索引 + 更新 NLP 引擎索引           │
│                                                         │
│  Step 6: 检查记忆合并（见 §7.4）                          │
└─────────────────────────────────────────────────────────┘
```

### 7.3 提取 Prompt 模板（默认值）

```
extract_prompt 默认模板：

你是一个世界设定与记忆记录助手。请分析以下对话内容，提取需要记录或更新的信息。

## 当前对话
{conversation_context}

## 已有设定条目摘要
{existing_entries_summary}

## 已有人物列表
{character_list}

请输出 JSON 数组，每个元素为以下类型之一：

### 1. 人物属性更新 (character_update)
```json
{
  "type": "character_update",
  "name": "人物名",
  "field_updates": { "字段名": "新值", ... }
}
```

### 2. 故事情节事件 (plot_event)
新发生的重要故事事件，客观描述。
```json
{
  "type": "plot_event",
  "name": "事件标题",
  "content": "事件的客观描述",
  "tags": ["相关人物", "地点", "关键词"]
}
```

### 3. 人物记忆 (character_memory)
人物对事件的主观认知和记忆。同一事件可以生成多个人物的不同记忆。
```json
{
  "type": "character_memory",
  "character_name": "记忆所属人物名",
  "event": "人物视角的主观描述",
  "importance": 1-10,
  "tags": ["关键词"],
  "known_by": ["也知道此事的其他人物名"],
  "plot_event_name": "关联的故事事件标题（如有）"
}
```

### 4. 世界设定更新 (lore_update)
```json
{
  "type": "lore_update",
  "name": "条目名",
  "category": "world_base/society/place/faction/skills/others",
  "content_append": "需要追加的内容",
  "tags": ["关键词"]
}
```

注意：
- 同一个故事事件应同时生成一条 plot_event 和相关人物各自的 character_memory
- 人物记忆应反映该人物的主观视角，不同人物对同一事件的记忆可以不同
- known_by 列出知道此事的其他人物名（不含记忆所属人物自身）
- 如果某人物不在场或不知情，不要为其生成记忆

仅输出 JSON 数组，不要输出其他内容。如果没有需要更新的信息，输出空数组 []。
```

### 7.4 记忆合并机制（v1.1 新增）

当人物记忆数量超过阈值时，LLM 定期合并/摘要老旧低重要度的记忆。

#### 触发条件

在 `sync_from_conversation` 完成后检查：

```python
MEMORY_CONSOLIDATION_THRESHOLD = 30  # 记忆数超过此阈值触发合并
MEMORY_CONSOLIDATION_TARGET = 20     # 合并后目标数量

for character in affected_characters:
    if len(character.memories) > MEMORY_CONSOLIDATION_THRESHOLD:
        task = asyncio.create_task(
            lore_updater.consolidate_memories(
                session_name, character.character_id, scheduler_api_config_id
            )
        )
        rst_runtime_service.register_task(session_name, task)
```

#### 合并流程

```
┌─────────────────────────────────────────────────────────┐
│                    记忆合并流程                            │
│                                                         │
│  Step 1: 加载人物所有记忆                                 │
│                                                         │
│  Step 2: 选取合并候选                                     │
│    - importance ≤ 3 的旧记忆                              │
│    - 或 is_consolidated=True 且 importance ≤ 5 的旧摘要   │
│    - 按 created_at 升序排列                               │
│    - 选取前 N 条（N = 当前总数 - CONSOLIDATION_TARGET）   │
│                                                         │
│  Step 3: 调用 scheduler LLM                              │
│    - Prompt: scheduler_template.consolidate_prompt        │
│    - 输入: 待合并的记忆列表                                │
│    - 要求: 将多条记忆合并为 1-3 条摘要记忆                  │
│           保留关键信息，删除冗余细节                        │
│           输出 JSON 格式                                  │
│                                                         │
│  Step 4: 删除原始旧记忆                                   │
│                                                         │
│  Step 5: 插入摘要记忆（is_consolidated=True）             │
│                                                         │
│  Step 6: 更新索引                                        │
└─────────────────────────────────────────────────────────┘
```

#### 合并 Prompt 模板（默认值）

```
consolidate_prompt 默认模板：

你是一个记忆整理助手。以下是一个人物的多条旧记忆，请将它们合并为更精炼的摘要。

## 人物：{character_name}

## 待合并的记忆
{memories_to_consolidate}

请将上述记忆合并为 1-3 条摘要记忆。要求：
1. 保留关键事件和重要信息
2. 删除重复和冗余的细节
3. 维持人物主观视角
4. 每条摘要记忆设定合适的 importance（1-10）

输出 JSON 数组：
```json
[
  {
    "event": "合并后的记忆描述",
    "importance": 5,
    "tags": ["关键词"]
  }
]
```

仅输出 JSON，不要输出其他内容。
```

### 7.5 记忆与故事事件的关系图（v1.1 新增）

```
                    ┌──────────────────┐
                    │   PlotEvent      │
                    │  (category=PLOT)  │
                    │  LoreEntry 结构   │
                    │                  │
                    │  name: "黑森林伏击"│
                    │  content: 客观描述 │
                    │  tags: [...]     │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │ plot_event_id│              │ plot_event_id
              ▼              ▼              ▼
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │CharacterMemory│  │CharacterMemory│  │(无对应记忆)  │
    │ owner: 艾琳娜 │  │ owner: 凯尔  │  │ 莱恩不在场   │
    │ event: 主观   │  │ event: 主观  │  │ 不生成记忆   │
    │ known_by:    │  │ known_by: [] │  └─────────────┘
    │   [凯尔]     │  │ (仅自己知道) │
    │ importance:7 │  │ importance:9 │
    └─────────────┘  └─────────────┘
```

- 一个 PlotEvent 可被多个 CharacterMemory 引用
- 不同人物对同一事件有不同的主观记忆
- 不在场的人物不会有对应的记忆
- `known_by` 控制信息不对称：调度器只向知道此记忆的人物注入

---

## 8. NLP 检索引擎

### 8.1 技术选型

| 组件 | 库 | 版本 | 作用 |
|------|-----|------|------|
| 中文分词 | jieba | >=0.42 | 分词 + 自定义词典 |
| BM25 检索 | rank-bm25 | >=0.2 | 词频相关性排序 |

### 8.2 实现细节

#### 自定义词典构建

```python
def _build_custom_dict(self, entries: list[LoreIndexEntry]) -> None:
    """从 Lore 条目的 name + tags 构建 jieba 自定义词典"""
    for entry in entries:
        # 高频词权重
        jieba.add_word(entry.name, freq=10000)
        for tag in entry.tags:
            jieba.add_word(tag, freq=5000)
```

#### BM25 语料构建

每个条目的文档由 `name + " " + " ".join(tags)` 经 jieba 分词后构成。MEMORY 条目额外包含 event 摘要：

```python
def _build_corpus(self, entries: list[LoreIndexEntry]) -> None:
    corpus = []
    self._corpus_ids = []
    for entry in entries:
        if entry.disabled:
            continue
        text = f"{entry.name} {' '.join(entry.tags)}"
        # MEMORY 条目从对应的 CharacterMemory 中获取 event 前 50 字
        # 以增强语义检索能力
        tokens = list(jieba.cut(text))
        corpus.append(tokens)
        self._corpus_ids.append(entry.entry_id)
    self._bm25 = BM25Okapi(corpus)
```

#### 检索流程

```python
def retrieve(self, query_text: str, top_k: int = 20) -> list[str]:
    tokens = list(jieba.cut(query_text))
    scores = self._bm25.get_scores(tokens)
    top_indices = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)[:top_k]
    return [self._corpus_ids[i] for i in top_indices if scores[i] > 0]
```

### 8.3 索引生命周期

| 事件 | 动作 |
|------|------|
| Session 打开/首次访问 Lore | 从磁盘 LoreIndex 构建 NLP 索引 |
| 创建/更新/删除条目 | 增量更新 NLP 索引 |
| 动态更新完成（含新记忆/事件） | 增量更新 NLP 索引 |
| 记忆合并完成 | 增量更新 NLP 索引（删除旧 + 添加摘要） |
| Session 关闭/切换 | 释放内存中的 NLP 索引 |

NLP 索引为纯内存结构，不持久化。每次 Session 激活时从 `LoreIndex` 重建。

---

## 9. ST 模式兼容

| 特性 | ST 模式 | RST 模式 |
|------|---------|----------|
| 调度器（LLM 确认/摘要） | ❌ 关闭 | ✅ 启用 |
| 动态更新 | ❌ 关闭 | ✅ 启用 |
| 预检索 | ❌ 关闭 | ✅ 启用 |
| 记忆管理 | ❌ 关闭 | ✅ 启用 |
| 记忆合并 | ❌ 关闭 | ✅ 启用 |
| Lore 注入方式 | 传统模式 | 调度器模式 |
| 前端面板 | LorePanel（传统编辑器） | RstLorePanel（完整管理面板） |
| scheduler_api_config_id | 不需要 | 必须配置 |

### ST 模式 Lore 注入逻辑

```python
def st_mode_inject(entries: list[LoreEntry | CharacterData], messages: list[Message]) -> str:
    """
    ST 模式：传统 Lore 注入
    1. constant=True 的条目直接注入
    2. 其他条目：tags/name 与最近 scan_depth 条消息文本做子串匹配
    3. 匹配到的条目 content 拼接为 lores_block
    4. 不调用 LLM
    5. 不处理 PLOT 和 MEMORY 条目
    """
    ...
```

---

## 10. 前端架构

### 10.1 新增/修改文件清单

```
frontend/src/
├── types/
│   └── lore.ts                        # TypeScript 类型定义（含记忆类型）
├── api/
│   └── lores.ts                       # API 调用封装（含记忆接口）
├── stores/
│   └── lore.ts                        # Pinia store
├── components/panels/
│   ├── LorePanel.vue                  # 改造：ST 模式传统 Lore 编辑器
│   └── RstLorePanel.vue               # 改造：RST 模式完整管理面板
```

### 10.2 TypeScript 类型定义

```typescript
// frontend/src/types/lore.ts

export type LoreCategory =
  | 'world_base'
  | 'society'
  | 'place'
  | 'faction'
  | 'character'
  | 'skills'
  | 'others'
  | 'plot'          // v1.1 新增
  | 'memory'        // v1.1 新增（仅用于索引标识）

export interface Relationship {
  target: string       // character_id
  relation: string
}

export interface CharacterMemory {
  memory_id: string
  event: string
  importance: number
  tags: string[]
  known_by: string[]           // character_id 列表
  plot_event_id: string | null
  is_consolidated: boolean
  created_at: string
}

export interface CharacterForm {
  form_id: string
  form_name: string
  is_default: boolean
  physique: string
  features: string
  vitality_max: number
  mana_potency: number
  toughness: number
  weak: string[]
  resist: string[]
  element: string[]        // entry_id 引用
  skills: string[]         // entry_id 引用
  penetration: string[]    // entry_id 引用
  clothing: string
  body: string
  mind: string
  vitality_cur: number
  activity: string
}

export interface CharacterData {
  character_id: string
  name: string
  race: string
  birth: string
  homeland: string
  aliases: string[]
  role: string
  faction: string
  objective: string
  personality: string
  relationship: Relationship[]
  memories: CharacterMemory[]  // v1.1 新增
  forms: CharacterForm[]
  active_form_id: string
  tags: string[]
  disabled: boolean
  constant: boolean
  created_at: string
  updated_at: string
}

export interface LoreEntry {
  id: string
  name: string
  category: LoreCategory
  content: string
  disabled: boolean
  constant: boolean
  tags: string[]
  created_at: string
  updated_at: string
}

export interface LoreEntryCreate {
  name: string
  category: LoreCategory
  content?: string
  disabled?: boolean
  constant?: boolean
  tags?: string[]
}

export interface LoreEntryUpdate {
  name?: string
  content?: string
  disabled?: boolean
  constant?: boolean
  tags?: string[]
}

export interface CharacterCreate {
  name: string
  race: string
  birth?: string
  homeland?: string
  aliases?: string[]
  role?: string
  faction?: string
  objective?: string
  personality?: string
  relationship?: Relationship[]
  tags?: string[]
  disabled?: boolean
  constant?: boolean
}

export interface CharacterUpdate {
  name?: string
  race?: string
  birth?: string
  homeland?: string
  aliases?: string[]
  role?: string
  faction?: string
  objective?: string
  personality?: string
  relationship?: Relationship[]
  tags?: string[]
  disabled?: boolean
  constant?: boolean
}

export interface FormCreate {
  form_name: string
  is_default?: boolean
  physique?: string
  features?: string
  vitality_max?: number
  mana_potency?: number
  toughness?: number
  weak?: string[]
  resist?: string[]
  element?: string[]
  skills?: string[]
  penetration?: string[]
}

export interface FormUpdate {
  form_name?: string
  is_default?: boolean
  physique?: string
  features?: string
  vitality_max?: number
  mana_potency?: number
  toughness?: number
  weak?: string[]
  resist?: string[]
  element?: string[]
  skills?: string[]
  penetration?: string[]
  clothing?: string
  body?: string
  mind?: string
  vitality_cur?: number
  activity?: string
}

export interface MemoryCreate {
  event: string
  importance?: number
  tags?: string[]
  known_by?: string[]
  plot_event_id?: string
}

export interface MemoryUpdate {
  event?: string
  importance?: number
  tags?: string[]
  known_by?: string[]
}

export interface SchedulerPromptTemplate {
  id: string
  name: string
  confirm_prompt: string
  extract_prompt: string
  consolidate_prompt: string   // v1.1 新增
  version: number
}

export interface ScheduleStatus {
  running: boolean
  last_run_at: string | null
  last_matched_count: number | null
  cached_candidates: string[]
}

export interface SyncStatus {
  running: boolean
  last_run_at: string | null
  rounds_since_last_sync: number
  sync_interval: number
}

export interface SyncResult {
  updated_entries: string[]
  created_entries: string[]
  new_memories: number
  new_plot_events: number
  duration_ms: number
}

export interface ConsolidateResult {
  character_id: string
  removed_count: number
  created_count: number
  duration_ms: number
}
```

### 10.3 API 调用封装

```typescript
// frontend/src/api/lores.ts

import { client } from './client'

const BASE = (session: string) => `/api/sessions/${session}/lores`

// --- 通用条目（含 plot 事件） ---
export const listEntries = (session: string, category?: string) =>
  client.get(`${BASE(session)}/entries`, { params: { category } })

export const createEntry = (session: string, data: LoreEntryCreate) =>
  client.post(`${BASE(session)}/entries`, data)

export const getEntry = (session: string, entryId: string) =>
  client.get(`${BASE(session)}/entries/${entryId}`)

export const updateEntry = (session: string, entryId: string, data: LoreEntryUpdate) =>
  client.put(`${BASE(session)}/entries/${entryId}`, data)

export const deleteEntry = (session: string, entryId: string) =>
  client.delete(`${BASE(session)}/entries/${entryId}`)

// --- Character ---
export const listCharacters = (session: string) =>
  client.get(`${BASE(session)}/characters`)

export const createCharacter = (session: string, data: CharacterCreate) =>
  client.post(`${BASE(session)}/characters`, data)

export const getCharacter = (session: string, characterId: string) =>
  client.get(`${BASE(session)}/characters/${characterId}`)

export const updateCharacter = (session: string, characterId: string, data: CharacterUpdate) =>
  client.put(`${BASE(session)}/characters/${characterId}`, data)

export const deleteCharacter = (session: string, characterId: string) =>
  client.delete(`${BASE(session)}/characters/${characterId}`)

// --- 形态 ---
export const addForm = (session: string, characterId: string, data: FormCreate) =>
  client.post(`${BASE(session)}/characters/${characterId}/forms`, data)

export const updateForm = (session: string, characterId: string, formId: string, data: FormUpdate) =>
  client.put(`${BASE(session)}/characters/${characterId}/forms/${formId}`, data)

export const deleteForm = (session: string, characterId: string, formId: string) =>
  client.delete(`${BASE(session)}/characters/${characterId}/forms/${formId}`)

export const setActiveForm = (session: string, characterId: string, formId: string) =>
  client.put(`${BASE(session)}/characters/${characterId}/active-form`, { form_id: formId })

// --- 人物记忆 --- (v1.1 新增)
export const listMemories = (session: string, characterId: string) =>
  client.get(`${BASE(session)}/characters/${characterId}/memories`)

export const addMemory = (session: string, characterId: string, data: MemoryCreate) =>
  client.post(`${BASE(session)}/characters/${characterId}/memories`, data)

export const updateMemory = (session: string, characterId: string, memoryId: string, data: MemoryUpdate) =>
  client.put(`${BASE(session)}/characters/${characterId}/memories/${memoryId}`, data)

export const deleteMemory = (session: string, characterId: string, memoryId: string) =>
  client.delete(`${BASE(session)}/characters/${characterId}/memories/${memoryId}`)

export const consolidateMemories = (session: string, characterId: string) =>
  client.post(`${BASE(session)}/characters/${characterId}/memories/consolidate`)

// --- 调度器 ---
export const triggerSchedule = (session: string) =>
  client.post(`${BASE(session)}/schedule`)

export const getScheduleStatus = (session: string) =>
  client.get(`${BASE(session)}/schedule/status`)

// --- 动态更新 ---
export const triggerSync = (session: string) =>
  client.post(`${BASE(session)}/sync`)

export const getSyncStatus = (session: string) =>
  client.get(`${BASE(session)}/sync/status`)

// --- 调度器模板 ---
export const getSchedulerTemplate = (session: string) =>
  client.get(`${BASE(session)}/scheduler-template`)

export const updateSchedulerTemplate = (session: string, data: {
  confirm_prompt?: string
  extract_prompt?: string
  consolidate_prompt?: string
}) =>
  client.put(`${BASE(session)}/scheduler-template`, data)
```

### 10.4 RstLorePanel 面板结构

```
RstLorePanel.vue
├── 顶部 Tab 栏：[世界设定] [人物] [技能] [故事线] [调度器]
│
├── Tab: 世界设定
│   ├── 范畴选择器 (world_base / society / place / faction / others)
│   ├── 条目列表（显示 name, disabled/constant 开关, tags）
│   └── 条目编辑器（name, content, tags, disabled, constant）
│
├── Tab: 人物
│   ├── 人物列表（显示 name, race, role, disabled/constant 开关）
│   ├── 人物详情编辑器
│   │   ├── 基础信息区（name, race, birth, homeland, aliases）
│   │   ├── 身份信息区（role, faction, objective, personality）
│   │   ├── 关系列表（target + relation 的可编辑列表）
│   │   ├── 记忆列表（v1.1 新增）
│   │   │   ├── 按 importance 排序的记忆卡片
│   │   │   ├── 每条记忆显示 event, importance, tags, known_by
│   │   │   ├── 合并标记（is_consolidated）
│   │   │   ├── 关联 plot 事件链接
│   │   │   ├── 手动添加/编辑/删除记忆
│   │   │   └── 手动触发记忆合并按钮
│   │   ├── 形态 Tab 切换（多形态卡片）
│   │   │   ├── 外观属性（physique, features, clothing）
│   │   │   ├── 战斗属性（vitality, mana, toughness, penetration, weak, resist）
│   │   │   ├── 技能/元素引用（选择已有 skills 条目）
│   │   │   └── 场景状态（body, mind, vitality_cur, activity）
│   │   └── 元数据（tags, disabled, constant）
│
├── Tab: 技能
│   ├── 条目列表（category=skills 的条目）
│   └── 条目编辑器
│
├── Tab: 故事线（v1.1 新增）
│   ├── 故事事件列表（category=plot 的 LoreEntry）
│   │   ├── 按 created_at 时间线排序
│   │   ├── 每条显示 name, content 摘要, tags
│   │   └── 可展开查看完整内容
│   ├── 手动添加/编辑/删除故事事件
│   └── 关联记忆显示（展开事件时显示哪些人物有此事件的记忆）
│
├── Tab: 调度器（默认折叠）
│   ├── 调度状态显示（running, last_run_at, cached_candidates 数量）
│   ├── 同步状态显示（rounds_since_last_sync, sync_interval）
│   ├── 同步间隔设置（lore_sync_interval 滑块）
│   ├── 手动触发按钮（调度 / 同步）
│   └── Prompt 模板编辑器
│       ├── confirm_prompt（展开/折叠式，默认折叠）
│       ├── extract_prompt（展开/折叠式，默认折叠）
│       └── consolidate_prompt（展开/折叠式，默认折叠）← v1.1 新增
```

---

## 11. 与现有代码的集成点

### 11.1 `chat_service.run_chat()` — 核心集成

修改 `backend/app/services/chat_service.py`：

```python
# 在 PromptAssembler.build() 调用前，插入调度逻辑

if session.mode == "RST" and session.scheduler_api_config_id:
    # Phase 2: 正式调度
    if has_explicit_input:
        lores_block = await lore_scheduler.full_schedule(
            session_name=session_name,
            messages=history,
            scan_depth=session.scan_depth,
            user_input=user_input,
            scheduler_api_config_id=session.scheduler_api_config_id,
        )
    else:
        lores_block = await lore_scheduler.full_schedule_from_cache(
            session_name=session_name,
            scheduler_api_config_id=session.scheduler_api_config_id,
        )
elif session.mode == "ST":
    # ST 模式：传统关键词注入
    lores_block = st_mode_inject(
        entries=lore_store.load_all_entries(),
        messages=history[-session.scan_depth:] if session.scan_depth > 0 else history,
    )
else:
    lores_block = ""

# ... 现有 PromptAssembler.build() 调用，lores_block 已从 "" 替换为实际值
```

在 `run_chat` 返回成功后，插入异步后处理：

```python
# run_chat 成功返回前

if session.mode == "RST" and session.scheduler_api_config_id:
    # Phase 1 预检索（下一轮的准备）
    pre_retrieve_task = asyncio.create_task(
        lore_scheduler.pre_retrieve(
            session_name=session_name,
            messages=store.load_recent(session.scan_depth),
            scan_depth=session.scan_depth,
        )
    )
    rst_runtime_service.register_task(session_name, pre_retrieve_task)

    # 动态更新计数
    state = rst_runtime_service.get_session_state(session_name)
    rounds = state.get("rounds_since_sync", 0) + 1
    if rounds >= session.lore_sync_interval:
        sync_task = asyncio.create_task(
            lore_updater.sync_from_conversation(
                session_name=session_name,
                messages=store.load_recent(session.scan_depth),
                scan_depth=session.scan_depth,
                scheduler_api_config_id=session.scheduler_api_config_id,
            )
        )
        rst_runtime_service.register_task(session_name, sync_task)
        rounds = 0
    rst_runtime_service.update_session_state(session_name, rounds_since_sync=rounds)
```

### 11.2 `session_service.create_session()` — 初始化补充

在 `backend/app/services/session_service.py` 的 `create_session` 函数中补充：

```python
# 已有:
# (rst_data / "characters").mkdir(parents=True, exist_ok=True)
# (rst_data / ".index").mkdir(parents=True, exist_ok=True)

# 新增:
default_world = rst_data / "default"
default_world.mkdir(parents=True, exist_ok=True)

# 初始化空范畴文件（含 plot）
for cat in ["world_base", "society", "place", "faction", "skills", "others", "plot"]:
    empty_file = LoreFile(world_id="default", category=LoreCategory(cat), entries=[])
    write_json(default_world / f"{cat}.json", empty_file.model_dump(mode="json"))

# 初始化空索引
empty_index = LoreIndex(items=[], updated_at=datetime.utcnow())
write_json(rst_data / ".index" / "index.json", empty_index.model_dump(mode="json"))

# 初始化默认调度器模板
default_template = SchedulerPromptTemplate()
write_json(rst_data / "scheduler_template.json", default_template.model_dump(mode="json"))
```

### 11.3 `SessionMeta` — 新增字段

在 `backend/app/models/session.py` 中新增：

```python
class SessionMeta(BaseModel):
    ...
    lore_sync_interval: int = Field(default=3, ge=1, le=5)  # 动态更新间隔
```

相应地，`SessionCreate`, `SessionUpdate`, `SessionResponse` 也需添加此字段。

### 11.4 `prompt_assembler.py` — 无需修改

`PromptAssembler.build()` 已通过 `lores_block` 参数预留了注入口，无需修改。

### 11.5 `main.py` — 路由注册

```python
from app.routers import lores
app.include_router(lores.router)
```

---

## 12. 新增依赖

在 `backend/pyproject.toml` 中新增：

```toml
[project]
dependencies = [
    # ... 现有依赖 ...
    "jieba>=0.42",
    "rank-bm25>=0.2",
]
```

---

## 13. 决策记录

| # | 决策点 | 最终方案 |
|---|--------|---------|
| 1 | `world_id` 策略 | 固定 "default"，目录层级保留，API/UI 不暴露多世界切换 |
| 2 | 调度器触发时机 | 两阶段：Phase 1 后端自动预检索（含最新 assistant 回复），Phase 2 在 Send 时正式调度；空输入使用 Phase 1 缓存 |
| 3 | 动态更新触发时机 | 每 N 轮自动触发（异步），N=lore_sync_interval，默认 3，范围 1~min(5,mem_length) |
| 4 | 关键词匹配算法 | jieba 分词 + BM25 检索（层级 1+2） |
| 5 | 调度器 Prompt 模板 | 用户可编辑，独立于主 Preset，UI 默认折叠 |
| 6 | 动态更新策略 | Character：字段级覆盖；其他范畴：内容追加 |
| 7a | relationship 格式 | 结构化列表 `list[{target, relation}]`，target 为 character_id |
| 7b | element/skills 引用 | 使用 `entry_id`，UI 显示 name |
| 7c | vitality_max/cur 类型 | `int`（数值） |
| 7d | mana/toughness/penetration 类型 | `int`（数值量化），penetration 为 `list[str]` |
| M1 | 记忆容量管理 | LLM 定期合并/摘要老旧低重要度记忆（阈值 30 → 目标 20） |
| M2 | 记忆 API 管理方式 | plot 走现有 `/entries` CRUD（category=plot）；character memory 走 `/characters/{id}/memories` 子路由 |
| M3 | 信息不对称处理 | `CharacterMemory.known_by` 字段 + 调度器在检索时过滤 |
