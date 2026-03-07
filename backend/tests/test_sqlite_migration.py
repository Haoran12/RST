from __future__ import annotations

from pathlib import Path

from app.models.lore import (
    CharacterData,
    CharacterFile,
    CharacterForm,
    CharacterMemory,
    LoreCategory,
    LoreEntry,
    SceneState,
    SchedulerPromptTemplate,
)
from app.storage.json_lore_store import JsonLoreStore
from app.storage.lore_store import LoreStore
from app.storage.migration.migrator import JsonToSqliteMigrator
from app.storage.sqlite_lore_store import OptimisticLockError, SQLiteLoreStore
from app.time_utils import now_local


def _character_file(character_id: str = "char-1") -> CharacterFile:
    now = now_local()
    form = CharacterForm(form_id="form-1", form_name="default")
    memory = CharacterMemory(
        memory_id="mem-1",
        event="Saw the hidden gate",
        importance=8,
        tags=["gate"],
        known_by=["Scout"],
        created_at=now,
    )
    return CharacterFile(
        data=CharacterData(
            character_id=character_id,
            name="Aster",
            race="Human",
            aliases=["Ash"],
            role="Scout",
            faction="North Watch",
            personality="Careful and observant",
            forms=[form],
            memories=[memory],
            active_form_id=form.form_id,
            tags=["lead"],
            created_at=now,
            updated_at=now,
        ),
        version=1,
    )


def test_sqlite_store_crud_and_search(tmp_data_dir: Path) -> None:
    store = SQLiteLoreStore(tmp_data_dir / "session")
    now = now_local()
    entry = LoreEntry(
        id="entry-1",
        name="Hidden Gate",
        category=LoreCategory.PLACE,
        content="A hidden gate under the old tower.",
        tags=["gate", "tower"],
        created_at=now,
        updated_at=now,
    )

    store.add_entry(entry)
    store.save_character(_character_file())

    loaded_file = store.load_category_file(LoreCategory.PLACE)
    assert [item.id for item in loaded_file.entries] == ["entry-1"]

    loaded_character = store.load_character("char-1")
    assert loaded_character is not None
    assert loaded_character.data.name == "Aster"
    assert loaded_character.data.memories[0].event == "Saw the hidden gate"

    matches = store.search_entries("hidden")
    assert matches
    assert matches[0][0] == "entry-1"

    index = store.rebuild_index()
    assert {item.entry_id for item in index.items} >= {"entry-1", "char-1", "mem-1"}


def test_json_to_sqlite_migration_and_auto_backend(tmp_data_dir: Path) -> None:
    session_dir = tmp_data_dir / "session"
    source = JsonLoreStore(session_dir)
    now = now_local()

    lore_file = source.load_category_file(LoreCategory.FACTION)
    lore_file.entries.append(
        LoreEntry(
            id="faction-1",
            name="North Watch",
            category=LoreCategory.FACTION,
            content="Protects the northern border.",
            tags=["watch"],
            created_at=now,
            updated_at=now,
        )
    )
    source.save_category_file(lore_file)
    source.save_character(_character_file())
    source.save_scene_state(
        SceneState(current_time="Dawn", current_location="North Tower", characters=["Aster"])
    )
    source.save_scheduler_template(
        SchedulerPromptTemplate(name="Migrated Template", confirm_prompt="confirm")
    )

    result = JsonToSqliteMigrator(session_dir).migrate(backup=True, verify=True)

    assert result.db_path.exists()
    assert result.backup_path is not None
    assert result.verified is True

    store = LoreStore(session_dir)
    assert store.backend_name == "sqlite"
    assert store.load_category_file(LoreCategory.FACTION).entries[0].id == "faction-1"
    assert store.load_character("char-1") is not None
    assert store.load_scene_state().current_location == "North Tower"
    assert store.load_scheduler_template().name == "Migrated Template"


def test_lore_store_auto_migrates_legacy_json_and_cleans_runtime_files(tmp_data_dir: Path) -> None:
    session_dir = tmp_data_dir / "auto-migrate-session"
    source = JsonLoreStore(session_dir)
    now = now_local()

    lore_file = source.load_category_file(LoreCategory.PLACE)
    lore_file.entries.append(
        LoreEntry(
            id="place-1",
            name="North Tower",
            category=LoreCategory.PLACE,
            content="A watchtower above the northern border.",
            tags=["tower"],
            created_at=now,
            updated_at=now,
        )
    )
    source.save_category_file(lore_file)
    source.save_character(_character_file("char-auto"))
    source.save_scene_state(
        SceneState(current_time="Dawn", current_location="North Tower", characters=["Aster"])
    )
    source.save_scheduler_template(
        SchedulerPromptTemplate(name="Auto Migrated Template", confirm_prompt="confirm")
    )

    assert (session_dir / "rst_data" / "default" / "place.json").exists()
    assert (session_dir / "rst_data" / "characters" / "char-auto.json").exists()
    assert (session_dir / "rst_data" / "scene_state.json").exists()
    assert (session_dir / "rst_data" / "scheduler_template.json").exists()

    store = LoreStore(session_dir)

    assert store.backend_name == "sqlite"
    assert store.load_category_file(LoreCategory.PLACE).entries[0].id == "place-1"
    assert store.load_character("char-auto") is not None
    assert store.load_scene_state().current_location == "North Tower"
    assert store.load_scheduler_template().name == "Auto Migrated Template"
    assert (session_dir / "rst_data" / "lore.db").exists()
    assert not (session_dir / "rst_data" / "default" / "place.json").exists()
    assert not (session_dir / "rst_data" / "characters" / "char-auto.json").exists()
    assert not (session_dir / "rst_data" / "scene_state.json").exists()
    assert not (session_dir / "rst_data" / "scheduler_template.json").exists()
    assert not (session_dir / "rst_data" / ".index" / "index.json").exists()


def test_snapshot_export_import_roundtrip_between_json_and_sqlite(tmp_data_dir: Path) -> None:
    source_session = tmp_data_dir / "snapshot-source"
    target_session = tmp_data_dir / "snapshot-target"
    source = JsonLoreStore(source_session)
    now = now_local()

    lore_file = source.load_category_file(LoreCategory.SKILLS)
    lore_file.entries.append(
        LoreEntry(
            id="skill-1",
            name="Frost Lance",
            category=LoreCategory.SKILLS,
            content="A piercing ice spell.",
            tags=["ice", "spell"],
            created_at=now,
            updated_at=now,
        )
    )
    source.save_category_file(lore_file)
    source.save_character(_character_file("char-snapshot"))
    source.save_scene_state(
        SceneState(current_time="Noon", current_location="Training Yard", characters=["Aster"])
    )
    source.save_scheduler_template(
        SchedulerPromptTemplate(name="Snapshot Template", confirm_prompt="confirm")
    )

    bundle = source.export_json_bundle()
    target = SQLiteLoreStore(target_session)
    target.import_json_bundle(bundle)

    assert target.load_category_file(LoreCategory.SKILLS).entries[0].id == "skill-1"
    assert target.load_character("char-snapshot") is not None
    assert target.load_scene_state().current_location == "Training Yard"
    assert target.load_scheduler_template().name == "Snapshot Template"


def test_sqlite_optimistic_lock_blocks_stale_character_write(tmp_data_dir: Path) -> None:
    store = SQLiteLoreStore(tmp_data_dir / "session")
    char_file = _character_file()
    store.save_character(char_file)

    original = store.load_character("char-1")
    assert original is not None

    fresh = original.model_copy(
        update={
            "data": original.data.model_copy(
                update={"personality": "Updated once", "updated_at": now_local()}
            )
        }
    )
    store.save_character(fresh, expected_updated_at=original.data.updated_at)

    stale = original.model_copy(
        update={
            "data": original.data.model_copy(
                update={"personality": "Stale overwrite", "updated_at": now_local()}
            )
        }
    )

    try:
        store.save_character(stale, expected_updated_at=original.data.updated_at)
    except OptimisticLockError:
        pass
    else:  # pragma: no cover - defensive guard
        raise AssertionError("expected optimistic lock failure")
