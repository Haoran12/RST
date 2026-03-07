from __future__ import annotations

import shutil
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from app.storage.json_lore_store import JsonLoreStore
from app.storage.sqlite_lore_store import SQLITE_DB_FILENAME, SQLiteLoreStore


@dataclass(slots=True)
class MigrationResult:
    session_dir: Path
    db_path: Path
    backup_path: Path | None
    lore_entry_count: int
    character_count: int
    memory_count: int
    verified: bool


class JsonToSqliteMigrator:
    def __init__(self, session_dir: Path, db_path: Path | None = None) -> None:
        self.session_dir = session_dir
        self.rst_data_dir = session_dir / "rst_data"
        self.db_path = db_path or (self.rst_data_dir / SQLITE_DB_FILENAME)

    def migrate(
        self,
        backup: bool = False,
        verify: bool = False,
        overwrite: bool = False,
    ) -> MigrationResult:
        if not self.rst_data_dir.exists():
            raise FileNotFoundError(f"RST data directory not found: {self.rst_data_dir}")
        if self.db_path.exists() and not overwrite:
            raise FileExistsError(f"SQLite database already exists: {self.db_path}")
        if self.db_path.exists() and overwrite:
            self.db_path.unlink()

        backup_path = self._backup_json_data() if backup else None
        source = JsonLoreStore(self.session_dir)
        target = SQLiteLoreStore(self.session_dir, self.db_path)

        bundle = source.export_json_bundle()
        target.import_json_bundle(bundle, replace=True)

        lore_entry_count = len(bundle.get("entries", []))
        character_count = len(bundle.get("characters", []))
        memory_count = sum(
            len(item.get("data", {}).get("memories", []))
            for item in bundle.get("characters", [])
            if isinstance(item, dict)
        )

        verified = self.verify(source, target) if verify else False
        return MigrationResult(
            session_dir=self.session_dir,
            db_path=self.db_path,
            backup_path=backup_path,
            lore_entry_count=lore_entry_count,
            character_count=character_count,
            memory_count=memory_count,
            verified=verified,
        )

    def verify(self, source: JsonLoreStore, target: SQLiteLoreStore) -> bool:
        for category in ENTRY_CATEGORIES:
            source_entries = source.load_category_file(category).entries
            target_entries = target.load_category_file(category).entries
            if len(source_entries) != len(target_entries):
                return False

        source_characters = source.list_characters()
        target_characters = target.list_characters()
        if len(source_characters) != len(target_characters):
            return False

        source_memory_count = sum(len(character.memories) for character in source_characters)
        target_memory_count = sum(len(character.memories) for character in target_characters)
        if source_memory_count != target_memory_count:
            return False

        return (
            source.load_scene_state().model_dump(mode="json")
            == target.load_scene_state().model_dump(mode="json")
            and source.load_scheduler_template().model_dump(mode="json")
            == target.load_scheduler_template().model_dump(mode="json")
        )

    def _backup_json_data(self) -> Path:
        stamp = datetime.now().strftime("%Y%m%d%H%M%S")
        backup_path = self.session_dir / f"rst_data_json_backup_{stamp}"
        shutil.copytree(self.rst_data_dir, backup_path)
        return backup_path
