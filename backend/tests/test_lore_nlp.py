from __future__ import annotations

from app.models.lore import LoreCategory, LoreIndexEntry
from app.services.lore_nlp import LoreNlpEngine


def _index_entry(
    entry_id: str,
    name: str,
    category: LoreCategory = LoreCategory.WORLD_BASE,
    *,
    tags: list[str] | None = None,
) -> LoreIndexEntry:
    return LoreIndexEntry(
        entry_id=entry_id,
        name=name,
        category=category,
        tags=tags or [],
        file_path=f"default/{category.value}.json",
    )


class TestLoreNlpReverseLookup:
    def test_build_name_index(self) -> None:
        engine = LoreNlpEngine()
        entries = [
            _index_entry("e1", "人类", LoreCategory.WORLD_BASE),
            _index_entry("e2", "宜河吴氏", LoreCategory.FACTION),
        ]
        engine.build_index(entries)

        assert engine.lookup_by_name("人类") == ["e1"]
        assert engine.lookup_by_name("宜河吴氏") == ["e2"]

    def test_build_tag_index(self) -> None:
        engine = LoreNlpEngine()
        entries = [
            _index_entry("e1", "人类", tags=["种族", "修行"]),
        ]
        engine.build_index(entries)

        assert engine.lookup_by_tag("种族") == ["e1"]
        assert engine.lookup_by_tag("修行") == ["e1"]

    def test_lookup_case_insensitive(self) -> None:
        engine = LoreNlpEngine()
        entries = [
            _index_entry("e1", "Dark Forest", LoreCategory.PLACE),
        ]
        engine.build_index(entries)

        assert engine.lookup_by_name("dark forest") == ["e1"]
        assert engine.lookup_by_name("DARK FOREST") == ["e1"]

    def test_lookup_by_name_or_tag(self) -> None:
        engine = LoreNlpEngine()
        entries = [
            _index_entry("e1", "人类", tags=["种族"]),
            _index_entry("e2", "精灵", tags=["人类"]),
        ]
        engine.build_index(entries)

        result = engine.lookup_by_name_or_tag("人类")
        assert result == ["e1", "e2"]

    def test_lookup_empty_string(self) -> None:
        engine = LoreNlpEngine()
        engine.build_index([_index_entry("e1", "人类")])

        assert engine.lookup_by_name("") == []
        assert engine.lookup_by_tag("") == []
        assert engine.lookup_by_name_or_tag("") == []

    def test_index_rebuilt_on_update_and_remove(self) -> None:
        engine = LoreNlpEngine()
        engine.build_index([_index_entry("e1", "旧名称", tags=["旧标签"])])

        engine.update_entry(_index_entry("e1", "新名称", tags=["新标签"]))
        assert engine.lookup_by_name("旧名称") == []
        assert engine.lookup_by_tag("旧标签") == []
        assert engine.lookup_by_name("新名称") == ["e1"]
        assert engine.lookup_by_tag("新标签") == ["e1"]

        engine.remove_entry("e1")
        assert engine.lookup_by_name("新名称") == []
        assert engine.lookup_by_tag("新标签") == []
