from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, model_validator


class LoreCategory(str, Enum):
    WORLD_BASE = "world_base"
    SOCIETY = "society"
    PLACE = "place"
    FACTION = "faction"
    CHARACTER = "character"
    SKILLS = "skills"
    OTHERS = "others"
    PLOT = "plot"
    MEMORY = "memory"


ENTRY_CATEGORIES: tuple[LoreCategory, ...] = (
    LoreCategory.WORLD_BASE,
    LoreCategory.SOCIETY,
    LoreCategory.PLACE,
    LoreCategory.FACTION,
    LoreCategory.SKILLS,
    LoreCategory.OTHERS,
    LoreCategory.PLOT,
)


DEFAULT_CONFIRM_PROMPT = """你是一个世界设定管理助手。以下是当前对话上下文和候选设定条目。\n\n## 当前对话上下文\n{conversation_context}\n\n## 候选设定与记忆条目\n{candidate_entries}\n\n请筛选与当前场景相关的条目，并输出精简后的可注入设定文本。\n如果没有相关条目，输出空字符串。"""

DEFAULT_EXTRACT_PROMPT = """你是一个世界设定与记忆记录助手。请分析对话并输出需要更新的信息。\n\n## 当前对话\n{conversation_context}\n\n## 已有设定条目摘要\n{existing_entries_summary}\n\n## 已有人物列表\n{character_list}\n\n仅输出 JSON 数组，不要输出其他内容。"""

DEFAULT_CONSOLIDATE_PROMPT = """你是一个记忆整理助手。请将人物旧记忆合并为更精炼的摘要。\n\n## 人物：{character_name}\n\n## 待合并的记忆\n{memories_to_consolidate}\n\n请输出 JSON 数组，每个元素包含 event、importance、tags。"""


class LoreEntry(BaseModel):
    id: str
    name: str = Field(min_length=1, max_length=128)
    category: LoreCategory
    content: str = ""
    disabled: bool = False
    constant: bool = False
    tags: list[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    @model_validator(mode="after")
    def validate_category(self) -> "LoreEntry":
        if self.category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise ValueError("LoreEntry category cannot be character or memory")
        return self


class Relationship(BaseModel):
    """Relationship target is a name (or fuzzy descriptor), not a character id."""

    target: str
    relation: str = ""


class SourceEntry(BaseModel):
    """Single entry from legacy static Lore JSON."""

    id: str = ""
    name: str = ""
    category: str = ""
    object: str | None = None
    role: str = "System"
    disable: bool = False
    content: str = ""
    comment: str = ""
    constant: bool = False
    key: list[str] = Field(default_factory=list)
    preventRecursion: bool = True
    excludeRecursion: bool = False


class SourceLoreFile(BaseModel):
    """Legacy static Lore JSON payload."""

    scanDepth: int = 4
    entries: list[SourceEntry] = Field(default_factory=list)


class ConversionWarning(BaseModel):
    source_id: str
    name: str
    type: str
    message: str


class ConversionAction(BaseModel):
    source_id: str
    name: str
    source_category: str
    action: str
    target_category: str | None = None
    created_ids: list[str] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    errors: list[str] = Field(default_factory=list)


class ConversionReport(BaseModel):
    source_file: str
    session_name: str
    timestamp: str
    statistics: dict[str, int] = Field(default_factory=dict)
    id_mapping: dict[str, str] = Field(default_factory=dict)
    category_summary: dict[str, int] = Field(default_factory=dict)
    actions: list[ConversionAction] = Field(default_factory=list)
    warnings: list[ConversionWarning] = Field(default_factory=list)
    errors: list[str] = Field(default_factory=list)


class CharacterMemory(BaseModel):
    memory_id: str
    event: str = Field(min_length=1)
    importance: int = Field(default=5, ge=1, le=10)
    tags: list[str] = Field(default_factory=list)
    known_by: list[str] = Field(default_factory=list)
    plot_event_id: str | None = None
    is_consolidated: bool = False
    created_at: datetime


class CharacterForm(BaseModel):
    form_id: str
    form_name: str = Field(min_length=1, max_length=64)
    is_default: bool = True

    physique: str = ""
    features: str = ""
    vitality_max: int = Field(default=100, ge=0)
    mana_potency: int = Field(default=100, ge=0)
    toughness: int = Field(default=10, ge=0)
    weak: list[str] = Field(default_factory=list)
    resist: list[str] = Field(default_factory=list)
    element: list[str] = Field(default_factory=list)
    skills: list[str] = Field(default_factory=list)
    penetration: list[str] = Field(default_factory=list)

    clothing: str = ""
    body: str = ""
    mind: str = ""
    vitality_cur: int = Field(default=50, ge=0)
    activity: str = ""


class CharacterData(BaseModel):
    character_id: str

    name: str = Field(min_length=1, max_length=128)
    race: str = Field(min_length=1, max_length=64)
    gender: str = ""
    strength: int = Field(default=10, ge=0)
    birth: str = ""
    homeland: str = ""

    aliases: list[str] = Field(default_factory=list)
    role: str = ""
    faction: str = ""
    objective: str = ""
    personality: str = ""
    relationship: list[Relationship] = Field(default_factory=list)

    memories: list[CharacterMemory] = Field(default_factory=list)

    forms: list[CharacterForm] = Field(default_factory=list)
    active_form_id: str = ""

    tags: list[str] = Field(default_factory=list)
    sort_order: int = Field(default=0, ge=0)
    disabled: bool = False
    constant: bool = False
    created_at: datetime
    updated_at: datetime


class CharacterFile(BaseModel):
    data: CharacterData
    version: int = 1


class LoreFile(BaseModel):
    world_id: str = "default"
    category: LoreCategory
    entries: list[LoreEntry] = Field(default_factory=list)
    version: int = 1


class LoreIndexEntry(BaseModel):
    entry_id: str
    name: str
    category: LoreCategory
    tags: list[str] = Field(default_factory=list)
    constant: bool = False
    disabled: bool = False
    file_path: str
    owner: str | None = None
    importance: int = Field(default=5, ge=1, le=10)


class LoreIndex(BaseModel):
    items: list[LoreIndexEntry] = Field(default_factory=list)
    updated_at: datetime
    version: int = 1


class SchedulerPromptTemplate(BaseModel):
    id: str = "default"
    name: str = "默认调度器模板"
    confirm_prompt: str = DEFAULT_CONFIRM_PROMPT
    extract_prompt: str = DEFAULT_EXTRACT_PROMPT
    consolidate_prompt: str = DEFAULT_CONSOLIDATE_PROMPT
    version: int = 1


class LoreEntryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: LoreCategory
    content: str = ""
    disabled: bool = False
    constant: bool = False
    tags: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_category(self) -> "LoreEntryCreate":
        if self.category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise ValueError("Entry category cannot be character or memory")
        return self


class LoreEntryUpdate(BaseModel):
    name: str | None = None
    category: LoreCategory | None = None
    content: str | None = None
    disabled: bool | None = None
    constant: bool | None = None
    tags: list[str] | None = None

    @model_validator(mode="after")
    def validate_category(self) -> "LoreEntryUpdate":
        if self.category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise ValueError("Entry category cannot be character or memory")
        return self


class LoreBatchItem(BaseModel):
    entry_id: str
    disabled: bool | None = None
    constant: bool | None = None


class LoreBatchUpdate(BaseModel):
    updates: list[LoreBatchItem] = Field(default_factory=list)


class LoreEntryReorder(BaseModel):
    category: LoreCategory
    entry_ids: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_category(self) -> "LoreEntryReorder":
        if self.category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise ValueError("Entry category cannot be character or memory")
        return self


class LoreEntryListResponse(BaseModel):
    entries: list[LoreEntry] = Field(default_factory=list)
    total: int


class CharacterCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    race: str = Field(min_length=1, max_length=64)
    gender: str = ""
    strength: int = Field(default=10, ge=0)
    birth: str = ""
    homeland: str = ""
    aliases: list[str] = Field(default_factory=list)
    role: str = ""
    faction: str = ""
    objective: str = ""
    personality: str = ""
    relationship: list[Relationship] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    disabled: bool = False
    constant: bool = False


class CharacterUpdate(BaseModel):
    name: str | None = None
    race: str | None = None
    gender: str | None = None
    strength: int | None = Field(default=None, ge=0)
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


class CharacterReorder(BaseModel):
    character_ids: list[str] = Field(default_factory=list)


class CharacterListResponse(BaseModel):
    characters: list[CharacterData] = Field(default_factory=list)
    total: int


class FormCreate(BaseModel):
    form_name: str = Field(min_length=1, max_length=64)
    is_default: bool = False
    physique: str = ""
    features: str = ""
    vitality_max: int = Field(default=100, ge=0)
    mana_potency: int = Field(default=100, ge=0)
    toughness: int = Field(default=10, ge=0)
    weak: list[str] = Field(default_factory=list)
    resist: list[str] = Field(default_factory=list)
    element: list[str] = Field(default_factory=list)
    skills: list[str] = Field(default_factory=list)
    penetration: list[str] = Field(default_factory=list)


class FormUpdate(BaseModel):
    form_name: str | None = None
    is_default: bool | None = None
    physique: str | None = None
    features: str | None = None
    vitality_max: int | None = Field(default=None, ge=0)
    mana_potency: int | None = Field(default=None, ge=0)
    toughness: int | None = Field(default=None, ge=0)
    weak: list[str] | None = None
    resist: list[str] | None = None
    element: list[str] | None = None
    skills: list[str] | None = None
    penetration: list[str] | None = None
    clothing: str | None = None
    body: str | None = None
    mind: str | None = None
    vitality_cur: int | None = Field(default=None, ge=0)
    activity: str | None = None


class ActiveFormUpdate(BaseModel):
    form_id: str


class MemoryCreate(BaseModel):
    event: str = Field(min_length=1)
    importance: int = Field(default=5, ge=1, le=10)
    tags: list[str] = Field(default_factory=list)
    known_by: list[str] = Field(default_factory=list)
    plot_event_id: str | None = None


class MemoryUpdate(BaseModel):
    event: str | None = None
    importance: int | None = Field(default=None, ge=1, le=10)
    tags: list[str] | None = None
    known_by: list[str] | None = None


class MemoryListResponse(BaseModel):
    memories: list[CharacterMemory] = Field(default_factory=list)
    total: int


class SchedulerTemplateUpdate(BaseModel):
    confirm_prompt: str | None = None
    extract_prompt: str | None = None
    consolidate_prompt: str | None = None


class ScheduleResult(BaseModel):
    injection_block: str
    matched_entry_ids: list[str] = Field(default_factory=list)
    duration_ms: int


class ScheduleStatus(BaseModel):
    running: bool
    last_run_at: str | None = None
    last_matched_count: int | None = None
    last_matched_entry_ids: list[str] = Field(default_factory=list)
    cached_candidates: list[str] = Field(default_factory=list)


class SyncFieldChange(BaseModel):
    field: str
    before: str
    after: str


class SyncChange(BaseModel):
    entry_id: str
    name: str
    category: str
    action: str
    summary: str = ""
    before_content: str | None = None
    after_content: str | None = None
    content_append: str | None = None
    tags_added: list[str] = Field(default_factory=list)
    field_changes: list[SyncFieldChange] = Field(default_factory=list)
    memory_event: str | None = None


class SyncResult(BaseModel):
    updated_entries: list[str] = Field(default_factory=list)
    created_entries: list[str] = Field(default_factory=list)
    new_memories: int = 0
    new_plot_events: int = 0
    duration_ms: int = 0
    changes: list[SyncChange] = Field(default_factory=list)


class SyncStatus(BaseModel):
    running: bool
    last_run_at: str | None = None
    rounds_since_last_sync: int = 0
    sync_interval: int = 3
    last_result: SyncResult | None = None


class ConsolidateResult(BaseModel):
    character_id: str
    removed_count: int
    created_count: int
    duration_ms: int
