PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS store_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS lore_entries (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN ('world_base', 'society', 'place', 'faction', 'skills', 'others', 'plot')),
    content TEXT DEFAULT '',
    disabled INTEGER DEFAULT 0,
    constant INTEGER DEFAULT 0,
    tags TEXT DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    world_id TEXT DEFAULT 'default'
);

CREATE INDEX IF NOT EXISTS idx_lore_category ON lore_entries(category);
CREATE INDEX IF NOT EXISTS idx_lore_disabled ON lore_entries(disabled);
CREATE INDEX IF NOT EXISTS idx_lore_constant ON lore_entries(constant);
CREATE INDEX IF NOT EXISTS idx_lore_updated ON lore_entries(updated_at DESC);

CREATE VIRTUAL TABLE IF NOT EXISTS lore_entries_fts USING fts5(
    entry_id UNINDEXED,
    name,
    content,
    tags,
    content='lore_entries',
    content_rowid='rowid'
);

CREATE TRIGGER IF NOT EXISTS lore_entries_ai AFTER INSERT ON lore_entries BEGIN
    INSERT INTO lore_entries_fts(rowid, entry_id, name, content, tags)
    VALUES (new.rowid, new.id, new.name, new.content, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS lore_entries_ad AFTER DELETE ON lore_entries BEGIN
    INSERT INTO lore_entries_fts(lore_entries_fts, rowid, entry_id, name, content, tags)
    VALUES ('delete', old.rowid, old.id, old.name, old.content, old.tags);
END;

CREATE TRIGGER IF NOT EXISTS lore_entries_au AFTER UPDATE ON lore_entries BEGIN
    INSERT INTO lore_entries_fts(lore_entries_fts, rowid, entry_id, name, content, tags)
    VALUES ('delete', old.rowid, old.id, old.name, old.content, old.tags);
    INSERT INTO lore_entries_fts(rowid, entry_id, name, content, tags)
    VALUES (new.rowid, new.id, new.name, new.content, new.tags);
END;

CREATE TABLE IF NOT EXISTS characters (
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

CREATE INDEX IF NOT EXISTS idx_char_name ON characters(name);
CREATE INDEX IF NOT EXISTS idx_char_faction ON characters(faction);
CREATE INDEX IF NOT EXISTS idx_char_disabled ON characters(disabled);
CREATE INDEX IF NOT EXISTS idx_char_sort ON characters(sort_order);

CREATE VIRTUAL TABLE IF NOT EXISTS characters_fts USING fts5(
    character_id UNINDEXED,
    name,
    aliases,
    role,
    faction,
    personality,
    content='characters',
    content_rowid='rowid'
);

CREATE TRIGGER IF NOT EXISTS characters_ai AFTER INSERT ON characters BEGIN
    INSERT INTO characters_fts(rowid, character_id, name, aliases, role, faction, personality)
    VALUES (new.rowid, new.character_id, new.name, new.aliases, new.role, new.faction, new.personality);
END;

CREATE TRIGGER IF NOT EXISTS characters_ad AFTER DELETE ON characters BEGIN
    INSERT INTO characters_fts(characters_fts, rowid, character_id, name, aliases, role, faction, personality)
    VALUES ('delete', old.rowid, old.character_id, old.name, old.aliases, old.role, old.faction, old.personality);
END;

CREATE TRIGGER IF NOT EXISTS characters_au AFTER UPDATE ON characters BEGIN
    INSERT INTO characters_fts(characters_fts, rowid, character_id, name, aliases, role, faction, personality)
    VALUES ('delete', old.rowid, old.character_id, old.name, old.aliases, old.role, old.faction, old.personality);
    INSERT INTO characters_fts(rowid, character_id, name, aliases, role, faction, personality)
    VALUES (new.rowid, new.character_id, new.name, new.aliases, new.role, new.faction, new.personality);
END;

CREATE TABLE IF NOT EXISTS character_forms (
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

CREATE INDEX IF NOT EXISTS idx_form_char ON character_forms(character_id);
CREATE INDEX IF NOT EXISTS idx_form_default ON character_forms(is_default);

CREATE TABLE IF NOT EXISTS character_memories (
    memory_id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,
    event TEXT NOT NULL,
    importance INTEGER DEFAULT 5 CHECK(importance BETWEEN 1 AND 10),
    tags TEXT DEFAULT '[]',
    known_by TEXT DEFAULT '[]',
    plot_event_id TEXT DEFAULT NULL,
    is_consolidated INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY (character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_memory_char ON character_memories(character_id);
CREATE INDEX IF NOT EXISTS idx_memory_importance ON character_memories(importance DESC);
CREATE INDEX IF NOT EXISTS idx_memory_plot_event ON character_memories(plot_event_id);

CREATE TABLE IF NOT EXISTS scene_state (
    id INTEGER PRIMARY KEY CHECK(id = 1),
    current_time TEXT DEFAULT '',
    current_location TEXT DEFAULT '',
    characters TEXT DEFAULT '[]',
    raw_tag TEXT DEFAULT '',
    updated_at TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS scheduler_templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    confirm_prompt TEXT NOT NULL,
    extract_prompt TEXT NOT NULL,
    consolidate_prompt TEXT NOT NULL,
    version INTEGER DEFAULT 1
);
