from __future__ import annotations

import argparse
from pathlib import Path

from app.config import settings
from app.storage.migration.migrator import JsonToSqliteMigrator


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Migrate RST session lore data from JSON to SQLite")
    parser.add_argument("--session", required=True, help="Session name under data/sessions")
    parser.add_argument("--backup", action="store_true", help="Create a backup copy of rst_data")
    parser.add_argument("--verify", action="store_true", help="Verify migrated data after import")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing lore.db")
    return parser


def session_dir_for(name: str) -> Path:
    return settings.data_path / "sessions" / name


def main() -> int:
    args = build_parser().parse_args()
    session_dir = session_dir_for(args.session)
    migrator = JsonToSqliteMigrator(session_dir)
    result = migrator.migrate(backup=args.backup, verify=args.verify, overwrite=args.overwrite)

    print(f"session={args.session}")
    print(f"db_path={result.db_path}")
    print(f"backup_path={result.backup_path or ''}")
    print(f"lore_entries={result.lore_entry_count}")
    print(f"characters={result.character_count}")
    print(f"memories={result.memory_count}")
    print(f"verified={result.verified}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
