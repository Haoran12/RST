from __future__ import annotations

from datetime import datetime

import pytest

from app.models.lore import (
    CharacterData,
    CharacterFile,
    CharacterForm,
    LoreCategory,
    LoreEntry,
    LoreIndexEntry,
    Relationship,
)
from app.models.session import Message, SessionCreate
from app.services.lore_nlp import LoreNlpEngine
from app.services.lore_scheduler import LoreScheduler
from app.services.rst_runtime_service import rst_runtime_service
from app.services.session_service import create_session, get_session_dir
from app.storage.lore_store import LoreStore


def _index_entry(
    entry_id: str,
    name: str,
    category: LoreCategory,
    *,
    tags: list[str] | None = None,
    disabled: bool = False,
    constant: bool = False,
) -> LoreIndexEntry:
    return LoreIndexEntry(
        entry_id=entry_id,
        name=name,
        category=category,
        tags=tags or [],
        disabled=disabled,
        constant=constant,
        file_path=f"default/{category.value}.json",
    )


def _character_file(
    *,
    character_id: str,
    name: str,
    race: str = "人类",
    faction: str = "",
    homeland: str = "",
    aliases: list[str] | None = None,
    relationship: list[Relationship] | None = None,
    skills: list[str] | None = None,
    element: list[str] | None = None,
    mana_potency: int = 100,
) -> CharacterFile:
    now = datetime.utcnow()
    form = CharacterForm(
        form_id=f"{character_id}-form",
        form_name="默认形态",
        skills=skills or [],
        element=element or [],
        mana_potency=mana_potency,
    )
    return CharacterFile(
        data=CharacterData(
            character_id=character_id,
            name=name,
            race=race,
            homeland=homeland,
            aliases=aliases or [],
            faction=faction,
            relationship=relationship or [],
            forms=[form],
            active_form_id=form.form_id,
            created_at=now,
            updated_at=now,
        ),
        version=1,
    )


def _save_lore_entry(
    store: LoreStore,
    *,
    entry_id: str,
    name: str,
    category: LoreCategory,
    tags: list[str] | None = None,
    content: str = "",
    disabled: bool = False,
    constant: bool = False,
) -> None:
    now = datetime.utcnow()
    lore_file = store.load_category_file(category)
    lore_file.entries.append(
        LoreEntry(
            id=entry_id,
            name=name,
            category=category,
            content=content,
            disabled=disabled,
            constant=constant,
            tags=tags or [],
            created_at=now,
            updated_at=now,
        )
    )
    store.save_category_file(lore_file)


class TestExpandRelatedIds:
    def test_character_race_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(_character_file(character_id="char1", name="吴晔", race="人类"))
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("e_race", "人类", LoreCategory.WORLD_BASE),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["e_race"]

    def test_character_faction_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(
            _character_file(character_id="char1", name="吴晔", race="人类", faction="宜河吴氏")
        )
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("e_faction", "宜河吴氏", LoreCategory.FACTION),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["e_faction"]

    def test_character_homeland_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(
            _character_file(character_id="char1", name="吴晔", race="人类", homeland="宜河")
        )
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("e_place", "宜河", LoreCategory.PLACE),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["e_place"]

    def test_character_relationship_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(
            _character_file(
                character_id="char1",
                name="吴晔",
                relationship=[Relationship(target="陈若水", relation="友人")],
            )
        )
        store.save_character(_character_file(character_id="char2", name="陈若水"))
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("char2", "陈若水", LoreCategory.CHARACTER),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["char2"]

    def test_character_relationship_alias_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(
            _character_file(
                character_id="char1",
                name="吴晔",
                relationship=[Relationship(target="阿水", relation="友人")],
            )
        )
        store.save_character(
            _character_file(character_id="char2", name="陈若水", aliases=["阿水"])
        )
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("char2", "陈若水", LoreCategory.CHARACTER),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["char2"]

    def test_character_skills_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(
            _character_file(
                character_id="char1",
                name="吴晔",
                skills=["skill_id_1"],
            )
        )
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("skill_id_1", "火球术", LoreCategory.SKILLS),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["skill_id_1"]

    def test_entry_tag_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        entries = [
            _index_entry("e_plot", "宜河战事", LoreCategory.PLOT, tags=["宜河"]),
            _index_entry("e_place", "宜河", LoreCategory.PLACE),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["e_plot"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["e_place"]

    def test_no_duplicate_in_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(
            _character_file(
                character_id="char1",
                name="吴晔",
                race="人类",
                homeland="人类",
            )
        )
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("e_race", "人类", LoreCategory.WORLD_BASE),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["e_race"]

    def test_disabled_entries_excluded(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(_character_file(character_id="char1", name="吴晔", race="人类"))
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("e_race", "人类", LoreCategory.WORLD_BASE, disabled=True),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == []

    def test_no_recursive_expansion(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        entries = [
            _index_entry("e_plot", "宜河战事", LoreCategory.PLOT, tags=["宜河"]),
            _index_entry("e_place", "宜河", LoreCategory.PLACE, tags=["港口"]),
            _index_entry("e_port", "港口", LoreCategory.PLACE),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["e_plot"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == ["e_place"]

    def test_first_round_ids_not_duplicated(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(_character_file(character_id="char1", name="吴晔", race="人类"))
        entries = [
            _index_entry("char1", "吴晔", LoreCategory.CHARACTER),
            _index_entry("e_race", "人类", LoreCategory.WORLD_BASE),
        ]
        engine = LoreNlpEngine()
        engine.build_index(entries)
        scheduler = LoreScheduler()

        expanded = scheduler._expand_related_ids(
            store,
            engine,
            ["char1", "e_race"],
            {item.entry_id: item for item in entries},
        )
        assert expanded == []

    def test_cap_candidates_after_expansion(self) -> None:
        scheduler = LoreScheduler()
        constant_ids = ["const_1", "const_2"]
        extra = [f"id_{index}" for index in range(80)]
        merged = [*constant_ids, *extra]

        capped = scheduler._cap_candidates_after_expansion(constant_ids, merged)

        assert len(capped) == 50
        assert capped[:2] == constant_ids

    def test_build_candidate_text_includes_active_form_mana_potency(self, tmp_path) -> None:
        store = LoreStore(tmp_path / "session")
        store.save_character(
            _character_file(
                character_id="char1",
                name="Wu Ye",
                race="human",
                mana_potency=6000,
            )
        )
        store.rebuild_index()
        scheduler = LoreScheduler()

        candidate_text = scheduler._build_candidate_text(
            store=store,
            candidate_ids=["char1"],
            scene_context="",
        )

        assert "[CHARACTER_FULL] Wu Ye (char1)" in candidate_text
        assert '"character_id": "char1"' in candidate_text
        assert '"mana_potency": 6000' in candidate_text
        assert '"active_form_id": "char1-form"' in candidate_text


def _create_scheduler_fixture_session(name: str) -> tuple[LoreStore, LoreScheduler]:
    create_session(
        SessionCreate(
            name=name,
            mode="RST",
            main_api_config_id="main_cfg",
            scheduler_api_config_id="scheduler_cfg",
            preset_id="preset_cfg",
        )
    )
    store = LoreStore(get_session_dir(name))
    scheduler = LoreScheduler()
    return store, scheduler


def _seed_expansion_data(store: LoreStore) -> None:
    _save_lore_entry(
        store,
        entry_id="e_race",
        name="人类",
        category=LoreCategory.WORLD_BASE,
        content="人类种族设定",
    )
    _save_lore_entry(
        store,
        entry_id="e_faction",
        name="宜河吴氏",
        category=LoreCategory.FACTION,
        content="宜河吴氏势力设定",
    )
    _save_lore_entry(
        store,
        entry_id="e_place",
        name="宜河",
        category=LoreCategory.PLACE,
        content="宜河地点设定",
    )
    _save_lore_entry(
        store,
        entry_id="skill_fire",
        name="火球术",
        category=LoreCategory.SKILLS,
        content="火球术技能",
    )
    store.save_character(
        _character_file(
            character_id="char_wuye",
            name="吴晔",
            race="人类",
            faction="宜河吴氏",
            homeland="宜河",
            skills=["skill_fire"],
        )
    )
    store.rebuild_index()


class TestSchedulerWithExpansion:
    @pytest.mark.asyncio
    async def test_pre_retrieve_with_expansion(self, tmp_data_dir) -> None:  # noqa: ARG002
        store, scheduler = _create_scheduler_fixture_session("sched_pre_expand")
        _seed_expansion_data(store)

        messages = [
            Message(
                id="msg-1",
                role="user",
                content="我想了解吴晔最近的情况。",
                timestamp=datetime.utcnow(),
                visible=True,
            )
        ]
        candidates = await scheduler.pre_retrieve(
            session_name="sched_pre_expand",
            messages=messages,
            scan_depth=4,
        )

        assert "char_wuye" in candidates
        assert "e_race" in candidates
        assert "e_faction" in candidates

    @pytest.mark.asyncio
    async def test_full_schedule_with_expansion(self, tmp_data_dir, monkeypatch) -> None:  # noqa: ARG002
        store, scheduler = _create_scheduler_fixture_session("sched_full_expand")
        _seed_expansion_data(store)
        rst_runtime_service.update_session_state("sched_full_expand", pre_retrieve_candidates=[])

        captured: dict[str, list[str]] = {"candidates": []}

        async def _fake_run(
            session_name: str,
            candidate_ids: list[str],
            context_messages: list[Message],
            scheduler_api_config_id: str,
        ) -> str:
            captured["candidates"] = list(candidate_ids)
            return "injected lore block"

        monkeypatch.setattr(scheduler, "_run_schedule_with_candidates", _fake_run)

        messages = [
            Message(
                id="msg-1",
                role="assistant",
                content="场景切换到宜河城。",
                timestamp=datetime.utcnow(),
                visible=True,
            )
        ]
        result = await scheduler.full_schedule(
            session_name="sched_full_expand",
            messages=messages,
            scan_depth=4,
            user_input="继续描写吴晔的战斗",
            scheduler_api_config_id="scheduler_cfg",
        )

        assert result == "injected lore block"
        assert "char_wuye" in captured["candidates"]
        assert "e_race" in captured["candidates"]
        assert "e_faction" in captured["candidates"]
        assert "skill_fire" in captured["candidates"]
