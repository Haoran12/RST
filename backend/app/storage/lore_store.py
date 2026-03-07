from __future__ import annotations

from pathlib import Path
from typing import Any, Literal

from app.storage.json_lore_store import JsonLoreStore
from app.storage.migration.migrator import JsonToSqliteMigrator
from app.storage.sqlite_lore_store import SQLITE_DB_FILENAME, SQLiteLoreStore

StorageBackend = Literal["auto", "json", "sqlite"]


class LoreStore:
    """Select a lore storage backend for a single session."""

    def __init__(self, session_dir: Path, backend: StorageBackend = "auto") -> None:
        self.session_dir = session_dir
        self.rst_data_dir = session_dir / "rst_data"
        self.db_path = self.rst_data_dir / SQLITE_DB_FILENAME

        if backend == "json":
            self.backend_name = "json"
            self._impl = JsonLoreStore(session_dir)
            return

        if not self.db_path.exists() and self._has_legacy_json_payload():
            JsonToSqliteMigrator(self.session_dir, self.db_path).migrate(
                backup=False,
                verify=False,
                overwrite=False,
            )

        self.backend_name = "sqlite"
        self._impl = SQLiteLoreStore(session_dir, self.db_path)
        self._cleanup_legacy_json_artifacts()

    def _legacy_json_files(self) -> list[Path]:
        files = [
            self.rst_data_dir / ".index" / "index.json",
            self.rst_data_dir / "scene_state.json",
            self.rst_data_dir / "scheduler_template.json",
        ]
        files.extend((self.rst_data_dir / "default").glob("*.json"))
        files.extend((self.rst_data_dir / "characters").glob("*.json"))
        return files

    def _has_legacy_json_payload(self) -> bool:
        return any(path.is_file() for path in self._legacy_json_files())

    def _cleanup_legacy_json_artifacts(self) -> None:
        for path in self._legacy_json_files():
            if path.exists():
                path.unlink()

        for directory in (
            self.rst_data_dir / "characters",
            self.rst_data_dir / "default",
            self.rst_data_dir / ".index",
        ):
            try:
                directory.rmdir()
            except OSError:
                continue

    def __getattr__(self, name: str) -> Any:
        return getattr(self._impl, name)
