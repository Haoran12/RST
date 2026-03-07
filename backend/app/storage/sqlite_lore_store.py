from __future__ import annotations

import json
import re
import sqlite3
from pathlib import Path
from typing import Any

from app.models import generate_id
from app.models.lore import (
    ENTRY_CATEGORIES,
    CharacterData,
    CharacterFile,
    CharacterMemory,
    LoreCategory,
    LoreEntry,
    LoreFile,
    LoreIndex,
    LoreIndexEntry,
    SceneState,
    SchedulerPromptTemplate,
)
from app.time_utils import now_local

try:
    import jieba  # type: ignore[import-untyped]
except Exception:  # pragma: no cover
    jieba = None  # type: ignore[assignment]

SQLITE_DB_FILENAME = "lore.db"

_CATEGORY_VALUES = tuple(category.value for category in ENTRY_CATEGORIES)
_CATEGORY_PLACEHOLDERS = ", ".join(f"'{value}'" for value in _CATEGORY_VALUES)
_SCHEMA_PATH = Path(__file__).with_name("migration") / "schema.sql"
_FTS_TOKEN_RE = re.compile(r"[\w\u4e00-\u9fff]+", re.UNICODE)


class OptimisticLockError(RuntimeError):
    pass


class SQLiteLoreStore:
    """Manage lore data for a session using SQLite."""

    def __init__(self, session_dir: Path, db_path: Path | None = None) -> None:
        self.session_dir = session_dir
        self.rst_data_dir = session_dir / "rst_data"
        self.db_path = db_path or (self.rst_data_dir / SQLITE_DB_FILENAME)
        self._ensure_layout()
        self._ensure_database()

    def _ensure_layout(self) -> None:
        self.rst_data_dir.mkdir(parents=True, exist_ok=True)

    def _get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        conn.execute("PRAGMA cache_size = -64000")
        conn.execute("PRAGMA temp_store = MEMORY")
        conn.execute("PRAGMA mmap_size = 268435456")
        return conn

    def _ensure_database(self) -> None:
        conn = self._get_conn()
        try:
            schema_sql = _SCHEMA_PATH.read_text(encoding="utf-8")
            conn.executescript(schema_sql)
            self._ensure_defaults(conn)
            conn.commit()
        finally:
            conn.close()

    def _ensure_defaults(self, conn: sqlite3.Connection) -> None:
        template = SchedulerPromptTemplate()
        conn.execute(
            """
            INSERT OR IGNORE INTO scheduler_templates
            (id, name, confirm_prompt, extract_prompt, consolidate_prompt, version)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                template.id,
                template.name,
                template.confirm_prompt,
                template.extract_prompt,
                template.consolidate_prompt,
                template.version,
            ),
        )
        conn.execute(
            "INSERT OR IGNORE INTO scene_state (id, current_time, current_location, characters, raw_tag, updated_at) VALUES (1, '', '', '[]', '', '')"
        )

    @staticmethod
    def _json_dumps(value: Any) -> str:
        return json.dumps(value, ensure_ascii=False)

    @staticmethod
    def _json_loads(value: str | None, default: Any) -> Any:
        if not value:
            return default
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return default

    @staticmethod
    def _bool_to_int(value: bool) -> int:
        return 1 if value else 0

    @staticmethod
    def _expected_timestamp(value: Any) -> str | None:
        if value is None:
            return None
        if hasattr(value, "isoformat"):
            return value.isoformat()
        return str(value)

    def _ensure_character_expected_state(
        self,
        conn: sqlite3.Connection,
        character_id: str,
        expected_updated_at: Any,
    ) -> sqlite3.Row:
        row = conn.execute(
            "SELECT * FROM characters WHERE character_id = ?",
            (character_id,),
        ).fetchone()
        if row is None:
            raise ValueError("character not found")
        expected_value = self._expected_timestamp(expected_updated_at)
        if expected_value is not None and row["updated_at"] != expected_value:
            raise OptimisticLockError(f"character changed concurrently: {character_id}")
        return row

    def _tokenize_search_query(self, query: str) -> list[str]:
        text = query.strip()
        if not text:
            return []
        if jieba is not None:
            return [token.strip() for token in jieba.cut(text) if token.strip()]
        return [token.strip() for token in _FTS_TOKEN_RE.findall(text) if token.strip()]

    def _build_fts_query(self, query: str) -> str | None:
        tokens = self._tokenize_search_query(query)
        unique_tokens: list[str] = []
        seen: set[str] = set()
        for token in tokens:
            if token in seen:
                continue
            seen.add(token)
            unique_tokens.append(token.replace('"', ''))
        if not unique_tokens:
            return None
        return " OR ".join(f'"{token}"' for token in unique_tokens)

    def _character_row_to_data(
        self,
        row: sqlite3.Row,
        forms: list[dict[str, Any]],
        memories: list[dict[str, Any]],
    ) -> CharacterData:
        payload = {
            "character_id": row["character_id"],
            "name": row["name"],
            "race": row["race"],
            "gender": row["gender"],
            "birth": row["birth"],
            "homeland": row["homeland"],
            "aliases": self._json_loads(row["aliases"], []),
            "role": row["role"],
            "faction": row["faction"],
            "objective": row["objective"],
            "personality": row["personality"],
            "relationship": self._json_loads(row["relationship"], []),
            "memories": memories,
            "forms": forms,
            "active_form_id": row["active_form_id"],
            "tags": self._json_loads(row["tags"], []),
            "sort_order": row["sort_order"],
            "disabled": bool(row["disabled"]),
            "constant": bool(row["constant"]),
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }
        return CharacterData.model_validate(payload)

    def _form_row_to_payload(self, row: sqlite3.Row) -> dict[str, Any]:
        return {
            "form_id": row["form_id"],
            "form_name": row["form_name"],
            "is_default": bool(row["is_default"]),
            "physique": row["physique"],
            "features": row["features"],
            "vitality_max": row["vitality_max"],
            "strength": row["strength"],
            "mana_potency": row["mana_potency"],
            "toughness": row["toughness"],
            "weak": self._json_loads(row["weak"], []),
            "resist": self._json_loads(row["resist"], []),
            "element": self._json_loads(row["element"], []),
            "skills": self._json_loads(row["skills"], []),
            "penetration": self._json_loads(row["penetration"], []),
            "clothing": row["clothing"],
            "body": row["body"],
            "mind": row["mind"],
            "vitality_cur": row["vitality_cur"],
            "activity": row["activity"],
        }

    def _memory_row_to_payload(self, row: sqlite3.Row) -> dict[str, Any]:
        return {
            "memory_id": row["memory_id"],
            "event": row["event"],
            "importance": row["importance"],
            "tags": self._json_loads(row["tags"], []),
            "known_by": self._json_loads(row["known_by"], []),
            "plot_event_id": row["plot_event_id"],
            "is_consolidated": bool(row["is_consolidated"]),
            "created_at": row["created_at"],
        }

    def _entry_row_to_model(self, row: sqlite3.Row) -> LoreEntry:
        return LoreEntry.model_validate(
            {
                "id": row["id"],
                "name": row["name"],
                "category": row["category"],
                "content": row["content"],
                "disabled": bool(row["disabled"]),
                "constant": bool(row["constant"]),
                "tags": self._json_loads(row["tags"], []),
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
            }
        )

    def _insert_entry(self, conn: sqlite3.Connection, entry: LoreEntry, world_id: str) -> None:
        conn.execute(
            """
            INSERT OR REPLACE INTO lore_entries
            (id, name, category, content, disabled, constant, tags, created_at, updated_at, world_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                entry.id,
                entry.name,
                entry.category.value,
                entry.content,
                self._bool_to_int(entry.disabled),
                self._bool_to_int(entry.constant),
                self._json_dumps(list(entry.tags)),
                entry.created_at.isoformat(),
                entry.updated_at.isoformat(),
                world_id,
            ),
        )

    def _insert_form(self, conn: sqlite3.Connection, character_id: str, form: Any) -> None:
        conn.execute(
            """
            INSERT INTO character_forms
            (
                form_id, character_id, form_name, is_default, physique, features,
                vitality_max, strength, mana_potency, toughness, weak, resist,
                element, skills, penetration, clothing, body, mind, vitality_cur, activity
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                form.form_id,
                character_id,
                form.form_name,
                self._bool_to_int(form.is_default),
                form.physique,
                form.features,
                form.vitality_max,
                form.strength,
                form.mana_potency,
                form.toughness,
                self._json_dumps(list(form.weak)),
                self._json_dumps(list(form.resist)),
                self._json_dumps(list(form.element)),
                self._json_dumps(list(form.skills)),
                self._json_dumps(list(form.penetration)),
                form.clothing,
                form.body,
                form.mind,
                form.vitality_cur,
                form.activity,
            ),
        )

    def _insert_memory(
        self,
        conn: sqlite3.Connection,
        character_id: str,
        memory: CharacterMemory,
    ) -> None:
        conn.execute(
            """
            INSERT INTO character_memories
            (
                memory_id, character_id, event, importance, tags, known_by,
                plot_event_id, is_consolidated, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                memory.memory_id,
                character_id,
                memory.event,
                memory.importance,
                self._json_dumps(list(memory.tags)),
                self._json_dumps(list(memory.known_by)),
                memory.plot_event_id,
                self._bool_to_int(memory.is_consolidated),
                memory.created_at.isoformat(),
            ),
        )

    def _load_forms(self, conn: sqlite3.Connection, character_id: str) -> list[dict[str, Any]]:
        rows = conn.execute(
            """
            SELECT *
            FROM character_forms
            WHERE character_id = ?
            ORDER BY is_default DESC, rowid ASC
            """,
            (character_id,),
        ).fetchall()
        return [self._form_row_to_payload(row) for row in rows]

    def _load_memories(self, conn: sqlite3.Connection, character_id: str) -> list[dict[str, Any]]:
        rows = conn.execute(
            """
            SELECT *
            FROM character_memories
            WHERE character_id = ?
            ORDER BY rowid ASC
            """,
            (character_id,),
        ).fetchall()
        return [self._memory_row_to_payload(row) for row in rows]

    def _load_character_full(self, conn: sqlite3.Connection, character_id: str) -> CharacterFile | None:
        row = conn.execute(
            "SELECT * FROM characters WHERE character_id = ?",
            (character_id,),
        ).fetchone()
        if row is None:
            return None
        data = self._character_row_to_data(
            row,
            forms=self._load_forms(conn, character_id),
            memories=self._load_memories(conn, character_id),
        )
        return CharacterFile(data=data, version=1)

    def _build_index(self, updated_at: str | None = None) -> LoreIndex:
        conn = self._get_conn()
        try:
            items: list[LoreIndexEntry] = []
            lore_rows = conn.execute(
                """
                SELECT id, name, category, tags, constant, disabled, world_id
                FROM lore_entries
                ORDER BY category ASC, rowid ASC
                """
            ).fetchall()
            for row in lore_rows:
                items.append(
                    LoreIndexEntry(
                        entry_id=row["id"],
                        name=row["name"],
                        category=row["category"],
                        tags=self._json_loads(row["tags"], []),
                        constant=bool(row["constant"]),
                        disabled=bool(row["disabled"]),
                        file_path=str(Path(row["world_id"]) / f"{row['category']}.json"),
                        importance=5,
                    )
                )

            char_rows = conn.execute(
                """
                SELECT character_id, name, tags, constant, disabled
                FROM characters
                ORDER BY sort_order ASC, rowid ASC
                """
            ).fetchall()
            for row in char_rows:
                character_id = row["character_id"]
                items.append(
                    LoreIndexEntry(
                        entry_id=character_id,
                        name=row["name"],
                        category=LoreCategory.CHARACTER,
                        tags=self._json_loads(row["tags"], []),
                        constant=bool(row["constant"]),
                        disabled=bool(row["disabled"]),
                        file_path=str(Path("characters") / f"{character_id}.json"),
                        importance=5,
                    )
                )
                memory_rows = conn.execute(
                    """
                    SELECT memory_id, event, tags, importance
                    FROM character_memories
                    WHERE character_id = ?
                    ORDER BY rowid ASC
                    """,
                    (character_id,),
                ).fetchall()
                for memory_row in memory_rows:
                    items.append(
                        LoreIndexEntry(
                            entry_id=memory_row["memory_id"],
                            name=memory_row["event"],
                            category=LoreCategory.MEMORY,
                            tags=self._json_loads(memory_row["tags"], []),
                            constant=False,
                            disabled=bool(row["disabled"]),
                            file_path=str(Path("characters") / f"{character_id}.json"),
                            owner=character_id,
                            importance=memory_row["importance"],
                        )
                    )

            return LoreIndex(items=items, updated_at=updated_at or now_local())
        finally:
            conn.close()

    def load_index(self) -> LoreIndex:
        return self._build_index()

    def save_index(self, index: LoreIndex) -> None:
        conn = self._get_conn()
        try:
            conn.execute(
                "INSERT OR REPLACE INTO store_metadata (key, value) VALUES (?, ?)",
                ("index_updated_at", index.updated_at.isoformat()),
            )
            conn.commit()
        finally:
            conn.close()

    def rebuild_index(self) -> LoreIndex:
        index = self._build_index()
        self.save_index(index)
        return index

    def load_character(self, character_id: str) -> CharacterFile | None:
        conn = self._get_conn()
        try:
            return self._load_character_full(conn, character_id)
        finally:
            conn.close()

    def _save_character_with_conn(
        self,
        conn: sqlite3.Connection,
        char_file: CharacterFile,
        expected_updated_at: Any = None,
    ) -> None:
        character = char_file.data
        existing = conn.execute(
            "SELECT updated_at FROM characters WHERE character_id = ?",
            (character.character_id,),
        ).fetchone()
        expected_value = self._expected_timestamp(expected_updated_at)
        if expected_value is not None:
            if existing is None or existing["updated_at"] != expected_value:
                raise OptimisticLockError(f"character changed concurrently: {character.character_id}")
        conn.execute(
            """
            INSERT OR REPLACE INTO characters
            (
                character_id, name, race, gender, birth, homeland,
                aliases, role, faction, objective, personality, relationship,
                active_form_id, tags, sort_order, disabled, constant,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                character.character_id,
                character.name,
                character.race,
                character.gender,
                character.birth,
                character.homeland,
                self._json_dumps(list(character.aliases)),
                character.role,
                character.faction,
                character.objective,
                character.personality,
                self._json_dumps([item.model_dump(mode="json") for item in character.relationship]),
                character.active_form_id,
                self._json_dumps(list(character.tags)),
                character.sort_order,
                self._bool_to_int(character.disabled),
                self._bool_to_int(character.constant),
                character.created_at.isoformat(),
                character.updated_at.isoformat(),
            ),
        )
        conn.execute("DELETE FROM character_forms WHERE character_id = ?", (character.character_id,))
        conn.execute("DELETE FROM character_memories WHERE character_id = ?", (character.character_id,))
        for form in character.forms:
            self._insert_form(conn, character.character_id, form)
        for memory in character.memories:
            self._insert_memory(conn, character.character_id, memory)

    def save_character(self, char_file: CharacterFile, expected_updated_at: Any = None) -> None:
        conn = self._get_conn()
        try:
            self._save_character_with_conn(conn, char_file, expected_updated_at)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def delete_character(self, character_id: str) -> bool:
        conn = self._get_conn()
        try:
            cursor = conn.execute("DELETE FROM characters WHERE character_id = ?", (character_id,))
            conn.commit()
            return cursor.rowcount > 0
        finally:
            conn.close()

    def list_characters(self) -> list[CharacterData]:
        conn = self._get_conn()
        try:
            rows = conn.execute(
                "SELECT character_id FROM characters ORDER BY sort_order ASC, rowid ASC"
            ).fetchall()
            results: list[CharacterData] = []
            for row in rows:
                char_file = self._load_character_full(conn, row["character_id"])
                if char_file is not None:
                    results.append(char_file.data)
            return results
        finally:
            conn.close()

    def _empty_lore_file(self, category: LoreCategory, world_id: str) -> LoreFile:
        return LoreFile(world_id=world_id, category=category, entries=[])

    def load_category_file(self, category: LoreCategory, world_id: str = "default") -> LoreFile:
        if category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise ValueError("character/memory does not map to category file")
        conn = self._get_conn()
        try:
            rows = conn.execute(
                """
                SELECT *
                FROM lore_entries
                WHERE category = ? AND world_id = ?
                ORDER BY rowid ASC
                """,
                (category.value, world_id),
            ).fetchall()
            entries = [self._entry_row_to_model(row) for row in rows]
            return LoreFile(world_id=world_id, category=category, entries=entries)
        finally:
            conn.close()

    def save_category_file(self, lore_file: LoreFile) -> None:
        conn = self._get_conn()
        try:
            conn.execute(
                "DELETE FROM lore_entries WHERE category = ? AND world_id = ?",
                (lore_file.category.value, lore_file.world_id),
            )
            for entry in lore_file.entries:
                self._insert_entry(conn, entry, lore_file.world_id)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def find_entry(self, entry_id: str) -> tuple[LoreEntry, LoreFile] | None:
        conn = self._get_conn()
        try:
            row = conn.execute("SELECT * FROM lore_entries WHERE id = ?", (entry_id,)).fetchone()
            if row is None:
                return None
            entry = self._entry_row_to_model(row)
            lore_file = self.load_category_file(entry.category, row["world_id"])
            return entry, lore_file
        finally:
            conn.close()

    def add_entry(self, entry: LoreEntry, world_id: str = "default") -> None:
        conn = self._get_conn()
        try:
            self._insert_entry(conn, entry, world_id)
            conn.commit()
        finally:
            conn.close()

    def update_entry(self, entry_id: str, updates: dict) -> LoreEntry | None:
        found = self.find_entry(entry_id)
        if found is None:
            return None
        entry, lore_file = found
        updated_entry = entry.model_copy(update={**updates, "updated_at": now_local()})

        conn = self._get_conn()
        try:
            if updated_entry.category != lore_file.category:
                conn.execute("DELETE FROM lore_entries WHERE id = ?", (entry_id,))
                self._insert_entry(conn, updated_entry, lore_file.world_id)
            else:
                self._insert_entry(conn, updated_entry, lore_file.world_id)
            conn.commit()
            return updated_entry
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def delete_entry(self, entry_id: str) -> bool:
        conn = self._get_conn()
        try:
            cursor = conn.execute("DELETE FROM lore_entries WHERE id = ?", (entry_id,))
            conn.commit()
            return cursor.rowcount > 0
        finally:
            conn.close()

    def load_scheduler_template(self) -> SchedulerPromptTemplate:
        conn = self._get_conn()
        try:
            row = conn.execute(
                """
                SELECT id, name, confirm_prompt, extract_prompt, consolidate_prompt, version
                FROM scheduler_templates
                WHERE id = 'default'
                """
            ).fetchone()
            if row is None:
                template = SchedulerPromptTemplate()
                self.save_scheduler_template(template)
                return template
            return SchedulerPromptTemplate.model_validate(dict(row))
        finally:
            conn.close()

    def save_scheduler_template(self, template: SchedulerPromptTemplate) -> None:
        conn = self._get_conn()
        try:
            conn.execute(
                """
                INSERT OR REPLACE INTO scheduler_templates
                (id, name, confirm_prompt, extract_prompt, consolidate_prompt, version)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    template.id,
                    template.name,
                    template.confirm_prompt,
                    template.extract_prompt,
                    template.consolidate_prompt,
                    template.version,
                ),
            )
            conn.commit()
        finally:
            conn.close()

    def load_scene_state(self) -> SceneState:
        conn = self._get_conn()
        try:
            row = conn.execute(
                """
                SELECT
                    scene_state.current_time AS current_time,
                    scene_state.current_location AS current_location,
                    scene_state.characters AS characters,
                    scene_state.raw_tag AS raw_tag,
                    scene_state.updated_at AS updated_at
                FROM scene_state
                WHERE id = 1
                """
            ).fetchone()
            if row is None:
                scene = SceneState()
                self.save_scene_state(scene)
                return scene
            return SceneState.model_validate(
                {
                    "current_time": row["current_time"],
                    "current_location": row["current_location"],
                    "characters": self._json_loads(row["characters"], []),
                    "raw_tag": row["raw_tag"],
                    "updated_at": row["updated_at"],
                }
            )
        finally:
            conn.close()

    def save_scene_state(self, scene: SceneState) -> None:
        conn = self._get_conn()
        try:
            conn.execute(
                """
                INSERT OR REPLACE INTO scene_state
                (id, current_time, current_location, characters, raw_tag, updated_at)
                VALUES (1, ?, ?, ?, ?, ?)
                """,
                (
                    scene.current_time,
                    scene.current_location,
                    self._json_dumps(list(scene.characters)),
                    scene.raw_tag,
                    scene.updated_at,
                ),
            )
            conn.commit()
        finally:
            conn.close()

    def load_all_entries(self) -> list[LoreEntry | CharacterData]:
        items: list[LoreEntry | CharacterData] = []
        for category in ENTRY_CATEGORIES:
            items.extend(self.load_category_file(category).entries)
        items.extend(self.list_characters())
        return items

    def load_entries_by_ids(self, entry_ids: list[str]) -> list[LoreEntry | CharacterData]:
        items: list[LoreEntry | CharacterData] = []
        wanted = set(entry_ids)
        if not wanted:
            return items
        for category in ENTRY_CATEGORIES:
            for entry in self.load_category_file(category).entries:
                if entry.id in wanted:
                    items.append(entry)
        for character in self.list_characters():
            if character.character_id in wanted:
                items.append(character)
        return items

    def load_memory_by_id(self, memory_id: str) -> CharacterMemory | None:
        conn = self._get_conn()
        try:
            row = conn.execute(
                "SELECT * FROM character_memories WHERE memory_id = ?",
                (memory_id,),
            ).fetchone()
            if row is None:
                return None
            return CharacterMemory.model_validate(self._memory_row_to_payload(row))
        finally:
            conn.close()

    def load_character_memories(self, character_id: str) -> list[CharacterMemory]:
        conn = self._get_conn()
        try:
            rows = conn.execute(
                "SELECT * FROM character_memories WHERE character_id = ? ORDER BY rowid ASC",
                (character_id,),
            ).fetchall()
            return [CharacterMemory.model_validate(self._memory_row_to_payload(row)) for row in rows]
        finally:
            conn.close()

    def add_memory(
        self,
        character_id: str,
        memory: CharacterMemory,
        expected_updated_at: Any = None,
    ) -> None:
        conn = self._get_conn()
        try:
            self._ensure_character_expected_state(conn, character_id, expected_updated_at)
            self._insert_memory(conn, character_id, memory)
            conn.execute(
                "UPDATE characters SET updated_at = ? WHERE character_id = ?",
                (now_local().isoformat(), character_id),
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def update_memory(self, character_id: str, memory_id: str, updates: dict) -> CharacterMemory | None:
        conn = self._get_conn()
        try:
            row = conn.execute(
                "SELECT * FROM character_memories WHERE character_id = ? AND memory_id = ?",
                (character_id, memory_id),
            ).fetchone()
            if row is None:
                return None
            current = CharacterMemory.model_validate(self._memory_row_to_payload(row))
            updated = current.model_copy(update=updates)
            conn.execute(
                """
                UPDATE character_memories
                SET event = ?, importance = ?, tags = ?, known_by = ?, plot_event_id = ?, is_consolidated = ?
                WHERE character_id = ? AND memory_id = ?
                """,
                (
                    updated.event,
                    updated.importance,
                    self._json_dumps(list(updated.tags)),
                    self._json_dumps(list(updated.known_by)),
                    updated.plot_event_id,
                    self._bool_to_int(updated.is_consolidated),
                    character_id,
                    memory_id,
                ),
            )
            conn.execute(
                "UPDATE characters SET updated_at = ? WHERE character_id = ?",
                (now_local().isoformat(), character_id),
            )
            conn.commit()
            return updated
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def delete_memory(self, character_id: str, memory_id: str) -> bool:
        conn = self._get_conn()
        try:
            cursor = conn.execute(
                "DELETE FROM character_memories WHERE character_id = ? AND memory_id = ?",
                (character_id, memory_id),
            )
            if cursor.rowcount > 0:
                conn.execute(
                    "UPDATE characters SET updated_at = ? WHERE character_id = ?",
                    (now_local().isoformat(), character_id),
                )
            conn.commit()
            return cursor.rowcount > 0
        finally:
            conn.close()

    def replace_memories(
        self,
        character_id: str,
        memories: list[CharacterMemory],
        expected_updated_at: Any = None,
    ) -> None:
        conn = self._get_conn()
        try:
            self._ensure_character_expected_state(conn, character_id, expected_updated_at)
            conn.execute("DELETE FROM character_memories WHERE character_id = ?", (character_id,))
            for memory in memories:
                self._insert_memory(conn, character_id, memory)
            conn.execute(
                "UPDATE characters SET updated_at = ? WHERE character_id = ?",
                (now_local().isoformat(), character_id),
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def update_character_fields(
        self,
        character_id: str,
        char_updates: dict[str, Any],
        form_updates: dict[str, Any],
        expected_updated_at: Any = None,
    ) -> CharacterFile | None:
        conn = self._get_conn()
        try:
            self._ensure_character_expected_state(conn, character_id, expected_updated_at)
            current = self._load_character_full(conn, character_id)
            if current is None:
                return None

            data = current.data
            if char_updates:
                data = data.model_copy(update=char_updates)
            if form_updates and data.forms:
                active_id = data.active_form_id or data.forms[0].form_id
                forms = [
                    form.model_copy(update=form_updates) if form.form_id == active_id else form
                    for form in data.forms
                ]
                data = data.model_copy(update={"forms": forms})

            data = data.model_copy(update={"updated_at": now_local()})
            self._save_character_with_conn(
                conn,
                CharacterFile(data=data, version=current.version),
                expected_updated_at=expected_updated_at,
            )
            conn.commit()
            return self._load_character_full(conn, character_id)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def append_or_create_lore_update(
        self,
        category: LoreCategory,
        name: str,
        content_append: str,
        tags: list[str],
    ) -> tuple[str, LoreEntry, str, list[str], str | None]:
        conn = self._get_conn()
        try:
            now = now_local()
            row = conn.execute(
                """
                SELECT *
                FROM lore_entries
                WHERE category = ? AND lower(trim(name)) = lower(trim(?))
                ORDER BY rowid ASC
                LIMIT 1
                """,
                (category.value, name),
            ).fetchone()
            append_text = content_append.strip()
            if row is not None:
                entry = self._entry_row_to_model(row)
                merged_content = entry.content
                if append_text:
                    merged_content = (
                        f"{entry.content}\n{append_text}".strip() if entry.content.strip() else append_text
                    )
                merged_tags = list(dict.fromkeys([*entry.tags, *tags]))
                updated_entry = entry.model_copy(
                    update={
                        "content": merged_content,
                        "tags": merged_tags,
                        "updated_at": now,
                    }
                )
                self._insert_entry(conn, updated_entry, row["world_id"])
                conn.commit()
                tags_added = [tag for tag in tags if tag not in entry.tags]
                return "updated", updated_entry, merged_content, tags_added, entry.content or None

            new_entry = LoreEntry(
                id=generate_id(),
                name=name,
                category=category,
                content=append_text,
                disabled=False,
                constant=False,
                tags=list(dict.fromkeys(tags)),
                created_at=now,
                updated_at=now,
            )
            self._insert_entry(conn, new_entry, "default")
            conn.commit()
            return "created", new_entry, new_entry.content, list(dict.fromkeys(tags)), None
        finally:
            conn.close()

    def search_entries(
        self,
        query: str,
        categories: list[LoreCategory] | None = None,
        limit: int = 50,
    ) -> list[tuple[str, float]]:
        match_query = self._build_fts_query(query)
        if not match_query:
            return []
        conn = self._get_conn()
        try:
            sql = """
                SELECT le.id, bm25(lore_entries_fts) AS score
                FROM lore_entries_fts
                INNER JOIN lore_entries AS le ON lore_entries_fts.rowid = le.rowid
                WHERE lore_entries_fts MATCH ?
            """
            params: list[Any] = [match_query]
            if categories:
                placeholders = ", ".join("?" for _ in categories)
                sql += f" AND le.category IN ({placeholders})"
                params.extend(category.value for category in categories)
            sql += " ORDER BY score LIMIT ?"
            params.append(limit)
            rows = conn.execute(sql, params).fetchall()
            return [(row["id"], abs(float(row["score"]))) for row in rows]
        finally:
            conn.close()

    def search_characters(self, query: str, limit: int = 50) -> list[tuple[str, float]]:
        match_query = self._build_fts_query(query)
        if not match_query:
            return []
        conn = self._get_conn()
        try:
            rows = conn.execute(
                """
                SELECT c.character_id, bm25(characters_fts) AS score
                FROM characters_fts
                INNER JOIN characters AS c ON characters_fts.rowid = c.rowid
                WHERE characters_fts MATCH ?
                ORDER BY score
                LIMIT ?
                """,
                (match_query, limit),
            ).fetchall()
            return [(row["character_id"], abs(float(row["score"]))) for row in rows]
        finally:
            conn.close()

    def export_json_bundle(self) -> dict[str, Any]:
        characters: list[dict[str, Any]] = []
        for character in self.list_characters():
            char_file = self.load_character(character.character_id)
            if char_file is not None:
                characters.append(char_file.model_dump(mode="json"))

        entries: list[dict[str, Any]] = []
        for category in ENTRY_CATEGORIES:
            entries.extend(
                entry.model_dump(mode="json") for entry in self.load_category_file(category).entries
            )

        return {
            "format": "rst-lore-snapshot-v1",
            "entries": entries,
            "characters": characters,
            "scene_state": self.load_scene_state().model_dump(mode="json"),
            "scheduler_template": self.load_scheduler_template().model_dump(mode="json"),
        }

    def import_json_bundle(self, payload: dict[str, Any], replace: bool = True) -> None:
        raw_entries = payload.get("entries", [])
        raw_characters = payload.get("characters", [])
        raw_scene_state = payload.get("scene_state")
        raw_scheduler_template = payload.get("scheduler_template")

        entries = [LoreEntry.model_validate(item) for item in raw_entries]
        characters = [CharacterFile.model_validate(item) for item in raw_characters]
        scene_state = (
            SceneState.model_validate(raw_scene_state)
            if isinstance(raw_scene_state, dict)
            else SceneState()
        )
        scheduler_template = (
            SchedulerPromptTemplate.model_validate(raw_scheduler_template)
            if isinstance(raw_scheduler_template, dict)
            else SchedulerPromptTemplate()
        )

        if replace:
            conn = self._get_conn()
            try:
                conn.execute("DELETE FROM character_memories")
                conn.execute("DELETE FROM character_forms")
                conn.execute("DELETE FROM characters")
                conn.execute("DELETE FROM lore_entries")
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            finally:
                conn.close()

        for entry in entries:
            self.add_entry(entry)
        for char_file in characters:
            self.save_character(char_file)

        self.save_scene_state(scene_state)
        self.save_scheduler_template(scheduler_template)
        self.rebuild_index()
