from __future__ import annotations

from app.models.lore import (
    CharacterData,
    CharacterMemory,
    LoreCategory,
    LoreEntry,
    LoreIndex,
    ScheduleStatus,
    SceneState,
    SyncStatus,
)
from app.time_utils import now_local


def _current_offset_suffix() -> str:
    current_offset = now_local().strftime("%z")
    return f"{current_offset[:3]}:{current_offset[3:]}"


def test_lore_entry_normalizes_legacy_naive_datetime() -> None:
    entry = LoreEntry(
        id="entry-1",
        name="Legacy Place",
        category=LoreCategory.PLACE,
        created_at="2026-03-05T18:20:30.123456",
        updated_at="2026-03-05T18:20:31.123456",
    )

    suffix = _current_offset_suffix()
    assert entry.created_at.isoformat().endswith(suffix)
    assert entry.updated_at.isoformat().endswith(suffix)


def test_character_and_memory_normalize_legacy_naive_datetime() -> None:
    memory = CharacterMemory(
        memory_id="memory-1",
        event="legacy memory",
        created_at="2026-03-05T18:30:30",
    )
    character = CharacterData(
        character_id="char-1",
        name="Legacy Character",
        race="Human",
        memories=[memory],
        created_at="2026-03-05T18:20:30",
        updated_at="2026-03-05T18:21:30",
    )

    suffix = _current_offset_suffix()
    assert character.created_at.isoformat().endswith(suffix)
    assert character.updated_at.isoformat().endswith(suffix)
    assert character.memories[0].created_at.isoformat().endswith(suffix)


def test_lore_index_normalizes_legacy_naive_datetime() -> None:
    index = LoreIndex(items=[], updated_at="2026-03-05T18:20:30")

    assert index.updated_at.isoformat().endswith(_current_offset_suffix())


def test_scene_state_normalizes_legacy_naive_updated_at_iso_string() -> None:
    scene = SceneState(updated_at="2026-03-05T18:20:30")
    assert scene.updated_at.endswith(_current_offset_suffix())


def test_scene_state_keeps_invalid_updated_at_unchanged() -> None:
    scene = SceneState(updated_at="not-a-datetime")
    assert scene.updated_at == "not-a-datetime"


def test_schedule_status_normalizes_legacy_naive_last_run_at() -> None:
    status = ScheduleStatus(running=False, last_run_at="2026-03-05T18:20:30")
    assert status.last_run_at is not None
    assert status.last_run_at.endswith(_current_offset_suffix())


def test_sync_status_normalizes_legacy_naive_last_run_at() -> None:
    status = SyncStatus(running=False, last_run_at="2026-03-05T18:20:30")
    assert status.last_run_at is not None
    assert status.last_run_at.endswith(_current_offset_suffix())
