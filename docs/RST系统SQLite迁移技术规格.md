# RST 系统 SQLite 迁移技术规格

## 文档信息

- 文档类型：技术规格 / 迁移设计
- 适用范围：RST Lore、角色、记忆、场景状态与调度模板数据层
- 当前状态：已归档为 Markdown，便于后续维护与版本追踪
- 目标读者：后端开发、数据迁移维护者、发布与测试人员

## 1. 背景与目标

RST 早期版本主要使用 JSON 文件存储 Lore、角色、记忆与场景状态数据。这种方式具备直观、零配置的优点，但在以下场景中存在明显瓶颈：

- 多实体联合查询能力弱，复杂检索依赖全文件扫描。
- 缺乏事务与外键约束，更新链条较长时容易出现一致性问题。
- 难以支持高效全文检索、排序、过滤与并发读写。
- 随着长对话数据积累，Lore / 角色 / 记忆结构越来越复杂，JSON 维护成本持续上升。

本规格定义 SQLite 迁移方案，目标如下：

- 将新会话的 Lore / 运行时数据迁移到 SQLite 作为主存储。
- 保持上层 `LoreStore` 使用体验与接口兼容。
- 为全文搜索、事务写入、并发控制和数据完整性提供基础设施。
- 提供从 JSON 到 SQLite 的迁移路径、校验方案与回滚思路。

## 2. 现有数据结构分析

### 2.1 当前 JSON 存储结构

```text
rst_data/
├── .index/
│   └── index.json               # 全局索引（1127 条记录）
├── characters/                  # 角色文件（15 个角色）
│   ├── 9oqaeejfufj1.json        # 遐蝶
│   ├── cn85kuaazk0q.json        # 吴晔
│   └── ...
├── default/                     # 分类 Lore 条目
│   ├── world_base.json          # 世界观基础
│   ├── society.json             # 社会制度
│   ├── place.json               # 地点
│   ├── faction.json             # 势力组织
│   ├── skills.json              # 技能
│   ├── others.json              # 其他
│   └── plot.json                # 剧情事件
├── scene_state.json             # 场景状态
└── scheduler_template.json      # 调度器模板
```

### 2.2 数据量统计（RST0 会话）

- 角色数：15 个
- 角色记忆总数：约 50～100 条
- Lore 条目：约 40～50 条
- 剧情事件：4 条
- 索引条目：1127 条

## 3. SQLite 数据库 Schema 设计

### 3.1 核心表结构

#### 3.1.1 Lore 条目表

```sql
CREATE TABLE lore_entries (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN (
        'world_base', 'society', 'place', 'faction',
        'skills', 'others', 'plot'
    )),
    content TEXT DEFAULT '',
    disabled INTEGER DEFAULT 0,
    constant INTEGER DEFAULT 0,
    tags TEXT DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    world_id TEXT DEFAULT 'default'
);

CREATE INDEX idx_lore_category ON lore_entries(category);
CREATE INDEX idx_lore_disabled ON lore_entries(disabled);
CREATE INDEX idx_lore_constant ON lore_entries(constant);
CREATE INDEX idx_lore_updated ON lore_entries(updated_at DESC);
```

#### 3.1.2 Lore 全文搜索索引（FTS5）

```sql
CREATE VIRTUAL TABLE lore_entries_fts USING fts5(
    entry_id UNINDEXED,
    name,
    content,
    tags,
    content='lore_entries',
    content_rowid='rowid'
);

CREATE TRIGGER lore_entries_ai AFTER INSERT ON lore_entries BEGIN
    INSERT INTO lore_entries_fts(rowid, entry_id, name, content, tags)
    VALUES (new.rowid, new.id, new.name, new.content, new.tags);
END;

CREATE TRIGGER lore_entries_ad AFTER DELETE ON lore_entries BEGIN
    DELETE FROM lore_entries_fts WHERE rowid = old.rowid;
END;

CREATE TRIGGER lore_entries_au AFTER UPDATE ON lore_entries BEGIN
    UPDATE lore_entries_fts
    SET name = new.name, content = new.content, tags = new.tags
    WHERE rowid = new.rowid;
END;
```

#### 3.1.3 角色表

```sql
CREATE TABLE characters (
    character_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    race TEXT NOT NULL,
    gender TEXT DEFAULT '',
    birth TEXT DEFAULT '',
    homeland TEXT DEFAULT '',
    aliases TEXT DEFAULT '[]',
    role TEXT DEFAULT '',
    faction TEXT DEFAULT '',
    objective TEXT DEFAULT '',
    personality TEXT DEFAULT '',
    relationship TEXT DEFAULT '[]',
    active_form_id TEXT DEFAULT '',
    tags TEXT DEFAULT '[]',
    sort_order INTEGER DEFAULT 0,
    disabled INTEGER DEFAULT 0,
    constant INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX idx_char_name ON characters(name);
CREATE INDEX idx_char_faction ON characters(faction);
CREATE INDEX idx_char_disabled ON characters(disabled);
CREATE INDEX idx_char_sort ON characters(sort_order);
```

#### 3.1.4 角色全文搜索

```sql
CREATE VIRTUAL TABLE characters_fts USING fts5(
    character_id UNINDEXED,
    name,
    aliases,
    role,
    faction,
    personality,
    content='characters',
    content_rowid='rowid'
);
```

#### 3.1.5 角色形态表

```sql
CREATE TABLE character_forms (
    form_id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,
    form_name TEXT NOT NULL,
    is_default INTEGER DEFAULT 1,
    physique TEXT DEFAULT '',
    features TEXT DEFAULT '',
    vitality_max INTEGER DEFAULT 100,
    strength INTEGER DEFAULT 100,
    mana_potency INTEGER DEFAULT 100,
    toughness INTEGER DEFAULT 100,
    weak TEXT DEFAULT '[]',
    resist TEXT DEFAULT '[]',
    element TEXT DEFAULT '[]',
    skills TEXT DEFAULT '[]',
    penetration TEXT DEFAULT '[]',
    clothing TEXT DEFAULT '',
    body TEXT DEFAULT '',
    mind TEXT DEFAULT '',
    vitality_cur INTEGER DEFAULT 50,
    activity TEXT DEFAULT '',
    FOREIGN KEY (character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

CREATE INDEX idx_form_char ON character_forms(character_id);
CREATE INDEX idx_form_default ON character_forms(is_default);
```

#### 3.1.6 角色记忆表

```sql
CREATE TABLE character_memories (
    memory_id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,
    event TEXT NOT NULL,
    importance INTEGER DEFAULT 5 CHECK(importance BETWEEN 1 AND 10),
    tags TEXT DEFAULT '[]',
    known_by TEXT DEFAULT '[]',
    plot_event_id TEXT DEFAULT NULL,
    is_consolidated INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY (character_id) REFERENCES characters(character_id) ON DELETE CASCADE,
    FOREIGN KEY (plot_event_id) REFERENCES lore_entries(id) ON DELETE SET NULL
);

CREATE INDEX idx_memory_char ON character_memories(character_id);
CREATE INDEX idx_memory_importance ON character_memories(importance DESC);
CREATE INDEX idx_memory_plot ON character_memories(plot_event_id);
CREATE INDEX idx_memory_consolidated ON character_memories(is_consolidated);
CREATE INDEX idx_memory_created ON character_memories(created_at DESC);
```

#### 3.1.7 记忆全文搜索

```sql
CREATE VIRTUAL TABLE memories_fts USING fts5(
    memory_id UNINDEXED,
    character_id UNINDEXED,
    event,
    tags,
    content='character_memories',
    content_rowid='rowid'
);
```

#### 3.1.8 场景状态表

```sql
CREATE TABLE scene_state (
    id INTEGER PRIMARY KEY CHECK(id = 1),
    current_time TEXT DEFAULT '',
    current_location TEXT DEFAULT '',
    characters TEXT DEFAULT '[]',
    raw_tag TEXT DEFAULT '',
    updated_at TEXT NOT NULL,
    version INTEGER DEFAULT 1
);

INSERT INTO scene_state (id, updated_at) VALUES (1, datetime('now'));
```

#### 3.1.9 调度器模板表

```sql
CREATE TABLE scheduler_template (
    id TEXT PRIMARY KEY DEFAULT 'default',
    name TEXT NOT NULL,
    confirm_prompt TEXT NOT NULL,
    extract_prompt TEXT NOT NULL,
    consolidate_prompt TEXT NOT NULL,
    version INTEGER DEFAULT 1
);
```

#### 3.1.10 元数据表

```sql
CREATE TABLE _metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

INSERT INTO _metadata VALUES
    ('schema_version', '1', datetime('now')),
    ('migrated_from', 'json', datetime('now')),
    ('session_name', '', datetime('now'));
```

### 3.2 视图设计（便于查询）

#### 3.2.1 完整角色视图

```sql
CREATE VIEW v_characters_full AS
SELECT
    c.*, 
    COUNT(DISTINCT m.memory_id) AS memory_count,
    COUNT(DISTINCT f.form_id) AS form_count,
    MAX(m.created_at) AS last_memory_at
FROM characters c
LEFT JOIN character_memories m ON c.character_id = m.character_id
LEFT JOIN character_forms f ON c.character_id = f.character_id
GROUP BY c.character_id;
```

#### 3.2.2 活跃角色视图

```sql
CREATE VIEW v_active_characters AS
SELECT c.*, m.last_memory
FROM characters c
INNER JOIN (
    SELECT character_id, MAX(created_at) AS last_memory
    FROM character_memories
    WHERE created_at > datetime('now', '-7 days')
    GROUP BY character_id
) m ON c.character_id = m.character_id
WHERE c.disabled = 0;
```

#### 3.2.3 重要记忆视图

```sql
CREATE VIEW v_important_memories AS
SELECT
    m.*, 
    c.name AS character_name,
    l.name AS plot_event_name
FROM character_memories m
INNER JOIN characters c ON m.character_id = c.character_id
LEFT JOIN lore_entries l ON m.plot_event_id = l.id
WHERE m.importance >= 7 AND m.is_consolidated = 0
ORDER BY m.importance DESC, m.created_at DESC;
```

## 4. 数据迁移策略

### 4.1 迁移脚本架构

文件建议：`backend/app/storage/migration/json_to_sqlite.py`

```python
from pathlib import Path
import sqlite3
import json
from datetime import datetime
from typing import Any

class JsonToSqliteMigrator:
    def __init__(self, session_dir: Path, db_path: Path):
        self.session_dir = session_dir
        self.rst_data_dir = session_dir / "rst_data"
        self.db_path = db_path
        self.conn: sqlite3.Connection | None = None

    def migrate(self) -> dict[str, Any]:
        """执行完整迁移"""
        stats = {
            "lore_entries": 0,
            "characters": 0,
            "forms": 0,
            "memories": 0,
            "errors": [],
        }

        try:
            self._init_database()
            self._migrate_lore_entries(stats)
            self._migrate_characters(stats)
            self._migrate_scene_state()
            self._migrate_scheduler_template()
            self._create_indexes()
            self.conn.commit()
        except Exception as exc:
            self.conn.rollback()
            stats["errors"].append(str(exc))
            raise
        finally:
            if self.conn:
                self.conn.close()

        return stats
```

### 4.2 迁移步骤

#### 步骤 1：创建数据库和表

```python
def _init_database(self):
    self.conn = sqlite3.connect(self.db_path)
    self.conn.execute("PRAGMA foreign_keys = ON")
    self.conn.execute("PRAGMA journal_mode = WAL")

    with open("backend/app/storage/migration/schema.sql") as f:
        self.conn.executescript(f.read())
```

#### 步骤 2：迁移 Lore 条目

```python
def _migrate_lore_entries(self, stats: dict):
    categories = [
        'world_base', 'society', 'place', 'faction',
        'skills', 'others', 'plot'
    ]

    for category in categories:
        file_path = self.rst_data_dir / "default" / f"{category}.json"
        if not file_path.exists():
            continue

        data = json.loads(file_path.read_text(encoding='utf-8'))
        entries = data.get("entries", [])

        for entry in entries:
            self.conn.execute("""
                INSERT INTO lore_entries
                (id, name, category, content, disabled, constant,
                 tags, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                entry["id"],
                entry["name"],
                entry["category"],
                entry.get("content", ""),
                1 if entry.get("disabled", False) else 0,
                1 if entry.get("constant", False) else 0,
                json.dumps(entry.get("tags", []), ensure_ascii=False),
                entry["created_at"],
                entry["updated_at"],
            ))
            stats["lore_entries"] += 1
```

#### 步骤 3：迁移角色数据

```python
def _migrate_characters(self, stats: dict):
    char_dir = self.rst_data_dir / "characters"

    for char_file in char_dir.glob("*.json"):
        data = json.loads(char_file.read_text(encoding='utf-8'))
        char_data = data["data"]

        self.conn.execute("""
            INSERT INTO characters
            (character_id, name, race, gender, birth, homeland,
             aliases, role, faction, objective, personality, relationship,
             active_form_id, tags, sort_order, disabled, constant,
             created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            char_data["character_id"],
            char_data["name"],
            char_data["race"],
            char_data.get("gender", ""),
            char_data.get("birth", ""),
            char_data.get("homeland", ""),
            json.dumps(char_data.get("aliases", []), ensure_ascii=False),
            char_data.get("role", ""),
            char_data.get("faction", ""),
            char_data.get("objective", ""),
            char_data.get("personality", ""),
            json.dumps(char_data.get("relationship", []), ensure_ascii=False),
            char_data.get("active_form_id", ""),
            json.dumps(char_data.get("tags", []), ensure_ascii=False),
            char_data.get("sort_order", 0),
            1 if char_data.get("disabled", False) else 0,
            1 if char_data.get("constant", False) else 0,
            char_data["created_at"],
            char_data["updated_at"],
        ))
        stats["characters"] += 1

        for form in char_data.get("forms", []):
            self._insert_form(char_data["character_id"], form, stats)

        for memory in char_data.get("memories", []):
            self._insert_memory(char_data["character_id"], memory, stats)
```

## 5. 新 LoreStore 实现

### 5.1 接口兼容层

文件建议：`backend/app/storage/lore_store_sqlite.py`

```python
import sqlite3
import json
from pathlib import Path
from typing import List
from app.models.lore import (
    LoreEntry, CharacterData, CharacterMemory,
    LoreCategory, SceneState,
)

class LoreStoreSQLite:
    """SQLite 实现的 LoreStore，保持与原 JSON 版本相同的接口"""

    def __init__(self, session_dir: Path):
        self.session_dir = session_dir
        self.db_path = session_dir / "rst_data.db"
        self._ensure_database()

    def _get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def load_all_entries(self) -> List[LoreEntry | CharacterData]:
        """加载所有条目（兼容原接口）"""
        conn = self._get_conn()
        try:
            entries = []
            cursor = conn.execute("SELECT * FROM lore_entries WHERE disabled = 0")
            for row in cursor:
                entries.append(self._row_to_lore_entry(row))

            cursor = conn.execute("SELECT * FROM characters WHERE disabled = 0")
            for row in cursor:
                entries.append(self._load_character_full(conn, row["character_id"]))

            return entries
        finally:
            conn.close()

    def get_entry(self, entry_id: str) -> LoreEntry | None:
        """获取单个 Lore 条目"""
        conn = self._get_conn()
        try:
            cursor = conn.execute(
                "SELECT * FROM lore_entries WHERE id = ?",
                (entry_id,),
            )
            row = cursor.fetchone()
            return self._row_to_lore_entry(row) if row else None
        finally:
            conn.close()

    def save_entry(self, entry: LoreEntry) -> None:
        """保存 Lore 条目（INSERT OR REPLACE）"""
        conn = self._get_conn()
        try:
            conn.execute("""
                INSERT OR REPLACE INTO lore_entries
                (id, name, category, content, disabled, constant,
                 tags, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                entry.id,
                entry.name,
                entry.category.value,
                entry.content,
                1 if entry.disabled else 0,
                1 if entry.constant else 0,
                json.dumps(entry.tags, ensure_ascii=False),
                entry.created_at.isoformat(),
                entry.updated_at.isoformat(),
            ))
            conn.commit()
        finally:
            conn.close()
```

### 5.2 角色操作

```python
def get_character(self, character_id: str) -> CharacterData | None:
    """获取完整角色数据"""
    conn = self._get_conn()
    try:
        cursor = conn.execute(
            "SELECT * FROM characters WHERE character_id = ?",
            (character_id,),
        )
        row = cursor.fetchone()
        if not row:
            return None
        return self._load_character_full(conn, character_id)
    finally:
        conn.close()


def save_character(self, character: CharacterData) -> None:
    """保存角色（事务）"""
    conn = self._get_conn()
    try:
        conn.execute("""
            INSERT OR REPLACE INTO characters
            (character_id, name, race, gender, birth, homeland,
             aliases, role, faction, objective, personality, relationship,
             active_form_id, tags, sort_order, disabled, constant,
             created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, self._character_to_tuple(character))

        conn.execute(
            "DELETE FROM character_forms WHERE character_id = ?",
            (character.character_id,),
        )
        conn.execute(
            "DELETE FROM character_memories WHERE character_id = ?",
            (character.character_id,),
        )

        for form in character.forms:
            self._insert_form(conn, character.character_id, form)

        for memory in character.memories:
            self._insert_memory(conn, character.character_id, memory)

        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
```

### 5.3 混合检索（BM25 + 语义）

```python
def search_entries(
    self,
    query: str,
    categories: List[LoreCategory] | None = None,
    limit: int = 50,
) -> List[tuple[str, float]]:
    """全文搜索（使用 FTS5）"""
    conn = self._get_conn()
    try:
        category_filter = ""
        if categories:
            cat_list = "','".join(c.value for c in categories)
            category_filter = f"AND category IN ('{cat_list}')"

        cursor = conn.execute(f"""
            SELECT
                le.id,
                lef.rank AS score
            FROM lore_entries_fts lef
            INNER JOIN lore_entries le ON lef.rowid = le.rowid
            WHERE lore_entries_fts MATCH ?
            {category_filter}
            ORDER BY rank
            LIMIT ?
        """, (query, limit))

        return [(row["id"], abs(row["score"])) for row in cursor]
    finally:
        conn.close()
```

### 5.4 性能优化配置

```python
def _ensure_database(self):
    """初始化数据库连接和性能配置"""
    if not self.db_path.exists():
        self._create_from_json()

    conn = self._get_conn()
    try:
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        conn.execute("PRAGMA cache_size = -64000")
        conn.execute("PRAGMA temp_store = MEMORY")
        conn.execute("PRAGMA mmap_size = 268435456")
    finally:
        conn.close()
```

## 6. 开发实施计划

### 阶段 1：基础设施（2～3 天）

#### 任务 1.1：创建 Schema 和迁移脚本

- 编写 `backend/app/storage/migration/schema.sql`
- 实现 `JsonToSqliteMigrator` 类
- 添加单元测试

#### 任务 1.2：实现 `LoreStoreSQLite`

- 实现基础 CRUD 操作
- 保持与 `LoreStore` 相同的接口
- 添加事务支持

#### 任务 1.3：迁移工具 CLI

```bash
python -m app.storage.migration.migrate \
    --session RST0 \
    --backup \
    --verify
```

### 阶段 2：功能迁移（3～4 天）

#### 任务 2.1：更新 `LoreScheduler`

- 修改 `lore_scheduler.py` 使用 SQLite 检索
- 实现 FTS5 全文搜索
- 进行性能对比测试

#### 任务 2.2：更新 `LoreUpdater`

- 修改 `lore_updater.py` 使用事务更新
- 添加并发控制（乐观锁）
- 测试记忆 consolidation 流程

#### 任务 2.3：更新 API 路由

- 修改 `backend/app/routers/lore.py`
- 确保前端兼容性
- 保持 API 响应格式不变

### 阶段 3：测试和优化（2～3 天）

#### 任务 3.1：性能测试

- 对比 JSON 与 SQLite 的查询性能
- 压力测试（1000+ 角色，10000+ 记忆）
- 优化慢查询

#### 任务 3.2：数据完整性验证

- 检查迁移前后数据一致性
- 验证外键约束
- 验证事务回滚

#### 任务 3.3：向后兼容

- 提供 JSON 导出功能
- 支持降级回 JSON 存储
- 更新相关文档

## 7. 关键技术决策

### 7.1 为什么选择 SQLite

| 需求 | SQLite 方案 | JSON 方案 |
| --- | --- | --- |
| 事务支持 | ✅ ACID 事务 | ❌ 无 |
| 并发控制 | ✅ WAL 模式支持并发读 | ❌ 文件锁冲突 |
| 查询性能 | ✅ 索引 + FTS5 | ❌ 全文件扫描 |
| 数据完整性 | ✅ 外键约束 | ❌ 手动维护 |
| 部署复杂度 | ✅ 零配置 | ✅ 零配置 |
| 数据可读性 | ⚠️ 需工具查看 | ✅ 直接查看 |

### 7.2 JSON 字段 vs 关系表

#### 适合使用 JSON 字段的场景

- `tags`：标签列表，不需要频繁 JOIN 查询
- `aliases`：别名列表
- `relationship`：关系数组，结构复杂且查询频率低
- `skills` / `weak` / `resist`：技能 ID 列表

#### 适合使用关系表的场景

- `character_forms`：需要独立查询和更新
- `character_memories`：需要按重要性排序和按时间过滤
- `lore_entries`：核心实体，需要更复杂的组合查询

### 7.3 迁移策略

#### 渐进式迁移（推荐）

- 新会话默认使用 SQLite
- 旧会话保持 JSON，提供迁移工具
- 两种存储后端共存 3～6 个月
- 最终废弃 JSON 存储

#### 一次性迁移（激进）

- 强制所有会话迁移到 SQLite
- 备份 JSON 文件
- 不再支持 JSON 存储

## 8. 风险与缓解措施

| 风险 | 影响 | 缓解措施 |
| --- | --- | --- |
| 迁移数据丢失 | 高 | 迁移前自动备份，提供回滚脚本 |
| 性能下降 | 中 | 充分测试，优化索引和查询 |
| 兼容性问题 | 中 | 保持接口不变，渐进式迁移 |
| SQLite 文件损坏 | 低 | WAL 模式 + 定期备份 |
| 并发写入冲突 | 低 | 使用事务 + 重试机制 |

## 9. 结论

SQLite 迁移方案在保持本地部署与零配置优势的同时，显著提升了数据一致性、可检索性和后续演进空间。对于 RST 这种具有长对话、结构化 Lore、角色状态追踪和复杂调度需求的应用，SQLite 作为新的 Lore / 运行时主存储是合理且可持续的方案。
