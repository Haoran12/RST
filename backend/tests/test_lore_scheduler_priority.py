from __future__ import annotations

from pathlib import Path

from app.models.lore import (
    CharacterData,
    CharacterFile,
    CharacterForm,
    LoreCategory,
    LoreEntry,
    LoreIndexEntry,
)
from app.services.lore_nlp import LoreNlpEngine
from app.services.lore_scheduler import (
    CHARACTER_CANDIDATE_QUOTA,
    OTHER_CANDIDATE_QUOTA,
    PLOT_MEMORY_CANDIDATE_QUOTA,
    LoreScheduler,
)
from app.storage.lore_store import LoreStore
from app.time_utils import now_local


def _index_entry(entry_id: str, name: str, category: LoreCategory) -> LoreIndexEntry:
    return LoreIndexEntry(
        entry_id=entry_id,
        name=name,
        category=category,
        tags=[],
        disabled=False,
        constant=False,
        file_path=f"default/{category.value}.json",
    )


def _character_file(character_id: str, name: str, aliases: list[str] | None = None) -> CharacterFile:
    now = now_local()
    form = CharacterForm(
        form_id=f"{character_id}-form",
        form_name="default",
        is_default=True,
    )
    return CharacterFile(
        data=CharacterData(
            character_id=character_id,
            name=name,
            race="human",
            aliases=aliases or [],
            forms=[form],
            active_form_id=form.form_id,
            created_at=now,
            updated_at=now,
        ),
        version=1,
    )


def test_prioritize_candidate_ids_demotes_memories() -> None:
    scheduler = LoreScheduler()
    candidate_ids = ["mem_1", "plot_1", "char_1", "mem_2", "char_2"]
    items_by_id = {
        "mem_1": _index_entry("mem_1", "memory one", LoreCategory.MEMORY),
        "plot_1": _index_entry("plot_1", "plot one", LoreCategory.PLOT),
        "char_1": _index_entry("char_1", "Alice", LoreCategory.CHARACTER),
        "mem_2": _index_entry("mem_2", "memory two", LoreCategory.MEMORY),
        "char_2": _index_entry("char_2", "Bob", LoreCategory.CHARACTER),
    }

    ranked = scheduler._prioritize_candidate_ids(candidate_ids, items_by_id, ["char_2"])

    assert ranked == ["char_2", "char_1", "mem_1", "plot_1", "mem_2"]


def test_prioritize_candidate_ids_applies_bucket_quotas() -> None:
    scheduler = LoreScheduler()
    candidate_ids: list[str] = []
    items_by_id: dict[str, LoreIndexEntry] = {}

    for idx in range(10):
        entry_id = f"char_{idx}"
        candidate_ids.append(entry_id)
        items_by_id[entry_id] = _index_entry(entry_id, f"Character {idx}", LoreCategory.CHARACTER)

    for idx in range(10):
        entry_id = f"plot_{idx}"
        candidate_ids.append(entry_id)
        items_by_id[entry_id] = _index_entry(entry_id, f"Plot {idx}", LoreCategory.PLOT)

    for idx in range(10):
        entry_id = f"mem_{idx}"
        candidate_ids.append(entry_id)
        items_by_id[entry_id] = _index_entry(entry_id, f"Memory {idx}", LoreCategory.MEMORY)

    for idx in range(20):
        entry_id = f"other_{idx}"
        candidate_ids.append(entry_id)
        items_by_id[entry_id] = _index_entry(entry_id, f"Other {idx}", LoreCategory.WORLD_BASE)

    ranked = scheduler._prioritize_candidate_ids(candidate_ids, items_by_id, [])

    top_n = CHARACTER_CANDIDATE_QUOTA + PLOT_MEMORY_CANDIDATE_QUOTA + OTHER_CANDIDATE_QUOTA
    first_n = ranked[:top_n]
    chars = [entry_id for entry_id in first_n if items_by_id[entry_id].category == LoreCategory.CHARACTER]
    plot_memory = [
        entry_id
        for entry_id in first_n
        if items_by_id[entry_id].category in {LoreCategory.PLOT, LoreCategory.MEMORY}
    ]
    others = [
        entry_id
        for entry_id in first_n
        if items_by_id[entry_id].category not in {LoreCategory.CHARACTER, LoreCategory.PLOT, LoreCategory.MEMORY}
    ]

    assert len(chars) == CHARACTER_CANDIDATE_QUOTA
    assert len(plot_memory) == PLOT_MEMORY_CANDIDATE_QUOTA
    assert len(others) == OTHER_CANDIDATE_QUOTA


def test_present_character_ids_supports_aliases(tmp_path: Path) -> None:
    store = LoreStore(tmp_path / "session")
    store.save_character(_character_file("char_ghost", "Ghost Seven", aliases=["Old Ghost"]))
    scheduler = LoreScheduler()

    present = scheduler._present_character_ids(store, "The ferryman Old Ghost appears.")

    assert "char_ghost" in present


def test_retrieve_ranked_ids_puts_memory_after_character(tmp_path: Path) -> None:
    store = LoreStore(tmp_path / "session")
    store.save_character(_character_file("char_ghost", "Ghost Seven"))
    scheduler = LoreScheduler()

    entries = [
        _index_entry("char_ghost", "Ghost Seven", LoreCategory.CHARACTER),
        _index_entry("mem_1", "Ghost Seven appeared near the lake", LoreCategory.MEMORY),
        _index_entry("mem_2", "The lake ferryman drifted asleep", LoreCategory.MEMORY),
        _index_entry("place_1", "Lake Shore", LoreCategory.PLACE),
    ]
    engine = LoreNlpEngine()
    engine.build_index(entries)
    items_by_id = {item.entry_id: item for item in entries}

    ranked, explicit = scheduler._retrieve_ranked_ids(
        "Ghost Seven at the lake",
        store,
        engine,
        items_by_id,
    )

    assert explicit == ["char_ghost"]
    assert ranked
    assert ranked[0] == "char_ghost"
    assert "mem_1" in ranked
    assert ranked.index("mem_1") > ranked.index("char_ghost")


def test_retrieve_ranked_ids_uses_sqlite_content_search(tmp_path: Path) -> None:
    store = LoreStore(tmp_path / "session", backend="sqlite")
    scheduler = LoreScheduler()

    now = now_local()
    lore_file = store.load_category_file(LoreCategory.PLACE)
    lore_file.entries.append(
        LoreEntry(
            id="place_hidden",
            name="Old Tower",
            category=LoreCategory.PLACE,
            content="A hidden gate opens below the old tower.",
            tags=[],
            created_at=now,
            updated_at=now,
        )
    )
    store.save_category_file(lore_file)

    index = store.load_index()
    enabled_items = [item for item in index.items if not item.disabled]
    items_by_id = {item.entry_id: item for item in enabled_items}
    engine = LoreNlpEngine()
    engine.build_index(enabled_items)

    ranked, explicit = scheduler._retrieve_ranked_ids(
        "Who knows about the hidden gate?",
        store,
        engine,
        items_by_id,
    )

    assert explicit == []
    assert "place_hidden" in ranked
