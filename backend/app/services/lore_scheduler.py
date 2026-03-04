from __future__ import annotations

import json
from datetime import datetime, timezone
from time import perf_counter
from typing import Callable

from app.models import generate_id
from app.models.api_config import ApiConfig
from app.models.lore import (
    LoreCategory,
    LoreIndexEntry,
    ScheduleStatus,
    SchedulerPromptTemplate,
)
from app.models.log import LogEntry
from app.models.session import Message
from app.providers.base import ProviderError
from app.providers.registry import get_provider
from app.services.api_config_service import get_api_config_storage
from app.services.lore_date import (
    compute_age_at,
    extract_scene_date,
    format_fantasy_date,
    is_birthday_today,
    parse_fantasy_date,
)
from app.services.log_service import log_service
from app.services.lore_nlp import LoreNlpEngine
from app.services.rst_runtime_service import rst_runtime_service
from app.services.session_service import get_session_dir, get_session_storage
from app.storage.encryption import decrypt_api_key
from app.storage.lore_store import LoreStore
from app.storage.message_store import MessageStore


MAX_CANDIDATES_AFTER_EXPANSION = 50


class LoreScheduler:
    """Two-phase lore scheduler with memory visibility filtering."""

    def __init__(self) -> None:
        self._engines: dict[str, LoreNlpEngine] = {}

    def _utc_iso(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _store(self, session_name: str) -> LoreStore:
        get_session_storage(session_name)
        return LoreStore(get_session_dir(session_name))

    def _engine(self, session_name: str, index_items: list[LoreIndexEntry]) -> LoreNlpEngine:
        engine = self._engines.get(session_name)
        if engine is None:
            engine = LoreNlpEngine()
            self._engines[session_name] = engine
        engine.build_index(index_items)
        return engine

    def release_session(self, session_name: str) -> None:
        self._engines.pop(session_name, None)

    def _select_messages(self, messages: list[Message], scan_depth: int) -> list[Message]:
        visible = [msg for msg in messages if msg.visible]
        if scan_depth < 0:
            return visible
        return visible[-scan_depth:] if scan_depth > 0 else []

    def _conversation_text(self, messages: list[Message]) -> str:
        chunks = [f"{msg.role}: {msg.content}" for msg in messages if msg.content.strip()]
        return "\n".join(chunks)

    def _present_character_ids(self, store: LoreStore, conversation_text: str) -> set[str]:
        text = conversation_text.lower()
        present: set[str] = set()
        for character in store.list_characters():
            if character.character_id.lower() in text:
                present.add(character.character_id)
                continue
            if character.name and character.name.lower() in text:
                present.add(character.character_id)
        return present

    def _memory_visible(
        self,
        store: LoreStore,
        item: LoreIndexEntry,
        present_character_ids: set[str],
    ) -> bool:
        if item.category != LoreCategory.MEMORY:
            return True
        memory = store.load_memory_by_id(item.entry_id)
        if memory is None:
            return False

        owner_id = item.owner or ""
        owner_present = owner_id in present_character_ids
        if not owner_present:
            return False
        if not memory.known_by:
            return owner_present
        return owner_present or any(char_id in memory.known_by for char_id in present_character_ids)

    def _filter_memory_candidates(
        self,
        store: LoreStore,
        items_by_id: dict[str, LoreIndexEntry],
        candidate_ids: list[str],
        present_character_ids: set[str],
    ) -> list[str]:
        filtered: list[str] = []
        for entry_id in candidate_ids:
            item = items_by_id.get(entry_id)
            if item is None:
                continue
            if not self._memory_visible(store, item, present_character_ids):
                continue
            filtered.append(entry_id)
        return filtered

    def _merge_ids(self, *groups: list[str]) -> list[str]:
        merged: list[str] = []
        seen: set[str] = set()
        for group in groups:
            for entry_id in group:
                if entry_id in seen:
                    continue
                seen.add(entry_id)
                merged.append(entry_id)
        return merged

    def _build_alias_index(self, store: LoreStore) -> dict[str, list[str]]:
        alias_to_ids: dict[str, list[str]] = {}

        def _append_alias(key: str, character_id: str) -> None:
            bucket = alias_to_ids.setdefault(key, [])
            if character_id not in bucket:
                bucket.append(character_id)

        for character in store.list_characters():
            for alias in [character.name, *character.aliases]:
                key = alias.strip().lower()
                if not key:
                    continue
                _append_alias(key, character.character_id)

        return alias_to_ids

    def _expand_character(
        self,
        store: LoreStore,
        engine: LoreNlpEngine,
        character_id: str,
        alias_to_ids: dict[str, list[str]],
        add_fn: Callable[[str], None],
    ) -> None:
        char_file = store.load_character(character_id)
        if char_file is None:
            return
        char = char_file.data

        if char.race:
            for entry_id in engine.lookup_by_name_or_tag(char.race):
                add_fn(entry_id)

        if char.faction:
            for entry_id in engine.lookup_by_name_or_tag(char.faction):
                add_fn(entry_id)

        if char.homeland:
            for entry_id in engine.lookup_by_name_or_tag(char.homeland):
                add_fn(entry_id)

        for rel in char.relationship:
            if not rel.target:
                continue
            for entry_id in engine.lookup_by_name(rel.target):
                add_fn(entry_id)
            rel_key = rel.target.strip().lower()
            if not rel_key:
                continue
            for entry_id in alias_to_ids.get(rel_key, []):
                add_fn(entry_id)

        active_form = next(
            (form for form in char.forms if form.form_id == char.active_form_id),
            char.forms[0] if char.forms else None,
        )
        if active_form is None:
            return

        for skill_id in active_form.skills:
            add_fn(skill_id)
        for element_id in active_form.element:
            add_fn(element_id)

    def _expand_entry(
        self,
        engine: LoreNlpEngine,
        item: LoreIndexEntry,
        add_fn: Callable[[str], None],
    ) -> None:
        for tag in item.tags:
            for entry_id in engine.lookup_by_name(tag):
                add_fn(entry_id)

    def _expand_related_ids(
        self,
        store: LoreStore,
        engine: LoreNlpEngine,
        first_round_ids: list[str],
        items_by_id: dict[str, LoreIndexEntry],
    ) -> list[str]:
        first_round_set = set(first_round_ids)
        expanded: list[str] = []
        seen: set[str] = set()
        alias_to_ids = self._build_alias_index(store)

        def _add(entry_id: str) -> None:
            if entry_id in first_round_set or entry_id in seen:
                return
            item = items_by_id.get(entry_id)
            if item is None or item.disabled:
                return
            seen.add(entry_id)
            expanded.append(entry_id)

        for entry_id in first_round_ids:
            item = items_by_id.get(entry_id)
            if item is None:
                continue
            if item.category == LoreCategory.CHARACTER:
                self._expand_character(store, engine, entry_id, alias_to_ids, _add)
                continue
            self._expand_entry(engine, item, _add)

        return expanded

    def _cap_candidates_after_expansion(
        self,
        constant_ids: list[str],
        candidate_ids: list[str],
    ) -> list[str]:
        if len(candidate_ids) <= MAX_CANDIDATES_AFTER_EXPANSION:
            return candidate_ids

        constant_set = set(constant_ids)
        kept_constants = [entry_id for entry_id in candidate_ids if entry_id in constant_set]
        if len(kept_constants) >= MAX_CANDIDATES_AFTER_EXPANSION:
            return kept_constants

        capped = list(kept_constants)
        cap_size = MAX_CANDIDATES_AFTER_EXPANSION - len(kept_constants)
        for entry_id in candidate_ids:
            if entry_id in constant_set:
                continue
            capped.append(entry_id)
            if len(capped) >= len(kept_constants) + cap_size:
                break
        return capped

    def _build_candidate_text(
        self,
        store: LoreStore,
        candidate_ids: list[str],
        scene_context: str,
    ) -> str:
        if not candidate_ids:
            return ""

        index = store.load_index()
        index_map = {item.entry_id: item for item in index.items}
        blocks: list[str] = []
        scene_date = extract_scene_date(scene_context)
        scene_date_text = format_fantasy_date(scene_date) if scene_date is not None else ""

        for entry_id in candidate_ids:
            item = index_map.get(entry_id)
            if item is None:
                continue

            if item.category == LoreCategory.MEMORY:
                memory = store.load_memory_by_id(entry_id)
                if memory is None:
                    continue
                owner_name = "unknown"
                if item.owner:
                    owner = store.load_character(item.owner)
                    if owner is not None:
                        owner_name = owner.data.name
                blocks.append(
                    "\n".join(
                        [
                            f"[MEMORY:{owner_name}] {entry_id}",
                            f"event: {memory.event}",
                            f"importance: {memory.importance}",
                            f"tags: {', '.join(memory.tags)}",
                        ]
                    )
                )
                continue

            if item.category == LoreCategory.CHARACTER:
                char_file = store.load_character(entry_id)
                if char_file is None:
                    continue
                payload = char_file.model_dump(mode="json")
                birth_date = parse_fantasy_date(char_file.data.birth)
                if birth_date is not None and scene_date is not None:
                    payload["scene_meta"] = {
                        "scene_date": scene_date_text,
                        "age": compute_age_at(birth_date, scene_date),
                        "birthday_today": is_birthday_today(birth_date, scene_date),
                    }
                blocks.append(
                    "\n".join(
                        [
                            f"[CHARACTER_FULL] {char_file.data.name} ({entry_id})",
                            json.dumps(payload, ensure_ascii=False, indent=2),
                        ]
                    )
                )
                continue

            found = store.find_entry(entry_id)
            if found is None:
                continue
            entry = found[0]
            type_label = {
                LoreCategory.SKILLS: "[SKILL]",
                LoreCategory.PLOT: "[PLOT]",
            }.get(entry.category, "[SETTING]")
            blocks.append(
                "\n".join(
                    [
                        f"{type_label} {entry.name}",
                        entry.content,
                    ]
                )
            )

        return "\n\n".join(block for block in blocks if block.strip())

    async def _call_scheduler_llm(
        self,
        session_name: str,
        api_config: ApiConfig,
        prompt: str,
    ) -> str:
        request_time = self._utc_iso()
        started_at = perf_counter()
        provider_name = api_config.provider.value
        api_key = decrypt_api_key(api_config.encrypted_key)
        provider = get_provider(api_config.provider)
        prompt_messages = [{"role": "user", "content": prompt}]
        raw_request = {
            "provider": provider_name,
            "base_url": api_config.base_url,
            "model": api_config.model,
            "temperature": api_config.temperature,
            "max_tokens": api_config.max_tokens,
            "stream": False,
            "prompt_messages": prompt_messages,
            "stage": "scheduler_confirm",
        }
        try:
            result = await provider.chat(
                api_config.base_url,
                api_key,
                messages=prompt_messages,
                model=api_config.model,
                temperature=api_config.temperature,
                max_tokens=api_config.max_tokens,
                stream=False,
            )
        except ProviderError as exc:
            response_time = self._utc_iso()
            duration_ms = int((perf_counter() - started_at) * 1000)
            log_service.add_log(
                LogEntry(
                    id=generate_id(),
                    chat_name=session_name,
                    request_source="scheduler",
                    provider=provider_name,
                    model=api_config.model,
                    status="error",
                    request_time=request_time,
                    response_time=response_time,
                    duration_ms=duration_ms,
                    raw_request={**raw_request, "provider_request": exc.request},
                    raw_response={
                        "error": str(exc),
                        "status_code": exc.status_code,
                        "provider_response": exc.response,
                    },
                )
            )
            raise
        except Exception as exc:  # pragma: no cover - defensive guard
            response_time = self._utc_iso()
            duration_ms = int((perf_counter() - started_at) * 1000)
            log_service.add_log(
                LogEntry(
                    id=generate_id(),
                    chat_name=session_name,
                    request_source="scheduler",
                    provider=provider_name,
                    model=api_config.model,
                    status="error",
                    request_time=request_time,
                    response_time=response_time,
                    duration_ms=duration_ms,
                    raw_request=raw_request,
                    raw_response={"error": str(exc)},
                )
            )
            raise

        response_time = self._utc_iso()
        duration_ms = int((perf_counter() - started_at) * 1000)
        log_service.add_log(
            LogEntry(
                id=generate_id(),
                chat_name=session_name,
                request_source="scheduler",
                provider=provider_name,
                model=api_config.model,
                status="success",
                request_time=request_time,
                response_time=response_time,
                duration_ms=duration_ms,
                raw_request={**raw_request, "provider_request": result.request},
                raw_response=result.response,
            )
        )
        return result.text.strip()

    def _render_confirm_prompt(
        self,
        template: SchedulerPromptTemplate,
        conversation_context: str,
        candidate_entries: str,
    ) -> str:
        prompt = template.confirm_prompt or ""
        prompt = prompt.replace("{conversation_context}", conversation_context)
        prompt = prompt.replace("{candidate_entries}", candidate_entries)
        return prompt

    async def pre_retrieve(
        self,
        session_name: str,
        messages: list[Message],
        scan_depth: int,
    ) -> list[str]:
        store = self._store(session_name)
        selected = self._select_messages(messages, scan_depth)
        context = self._conversation_text(selected)

        index = store.load_index()
        enabled_items = [item for item in index.items if not item.disabled]
        items_by_id = {item.entry_id: item for item in enabled_items}
        constant_ids = [item.entry_id for item in enabled_items if item.constant]
        engine = self._engine(session_name, enabled_items)
        nlp_ids = engine.retrieve(context, top_k=20)
        first_round_ids = self._merge_ids(constant_ids, nlp_ids)
        expanded_ids = self._expand_related_ids(store, engine, first_round_ids, items_by_id)

        present_character_ids = self._present_character_ids(store, context)
        merged = self._merge_ids(constant_ids, nlp_ids, expanded_ids)
        capped = self._cap_candidates_after_expansion(constant_ids, merged)
        filtered = self._filter_memory_candidates(store, items_by_id, capped, present_character_ids)

        rst_runtime_service.update_session_state(
            session_name,
            pre_retrieve_candidates=filtered,
            pre_retrieve_at=datetime.utcnow().isoformat(),
        )
        return filtered

    async def _run_schedule_with_candidates(
        self,
        session_name: str,
        candidate_ids: list[str],
        context_messages: list[Message],
        scheduler_api_config_id: str,
    ) -> str:
        store = self._store(session_name)
        template = store.load_scheduler_template()
        context = self._conversation_text(context_messages)
        candidate_text = self._build_candidate_text(store, candidate_ids, context)
        if not candidate_text.strip():
            rst_runtime_service.update_session_state(
                session_name,
                pre_retrieve_candidates=[],
                last_schedule_at=datetime.utcnow().isoformat(),
                last_injection_block="",
                last_matched_count=0,
                last_matched_entry_ids=[],
            )
            return ""

        prompt = self._render_confirm_prompt(template, context, candidate_text)
        api_config = get_api_config_storage(scheduler_api_config_id)
        injection_block = await self._call_scheduler_llm(session_name, api_config, prompt)

        rst_runtime_service.update_session_state(
            session_name,
            pre_retrieve_candidates=[],
            last_schedule_at=datetime.utcnow().isoformat(),
            last_injection_block=injection_block,
            last_matched_count=len(candidate_ids),
            last_matched_entry_ids=candidate_ids,
        )
        return injection_block

    async def full_schedule(
        self,
        session_name: str,
        messages: list[Message],
        scan_depth: int,
        user_input: str,
        scheduler_api_config_id: str,
    ) -> str:
        started_at = perf_counter()
        rst_runtime_service.update_session_state(session_name, schedule_running=True)
        store = self._store(session_name)
        index = store.load_index()
        enabled_items = [item for item in index.items if not item.disabled]
        items_by_id = {item.entry_id: item for item in enabled_items}

        state = rst_runtime_service.get_session_state(session_name)
        cached = list(state.get("pre_retrieve_candidates", []))

        constant_ids = [item.entry_id for item in enabled_items if item.constant]
        engine = self._engine(session_name, enabled_items)
        user_ids = engine.retrieve(user_input, top_k=20) if user_input.strip() else []
        user_expanded_ids = self._expand_related_ids(
            store,
            engine,
            self._merge_ids(constant_ids, cached, user_ids),
            items_by_id,
        )

        selected_messages = self._select_messages(messages, scan_depth)
        context = self._conversation_text(selected_messages)
        present_character_ids = self._present_character_ids(store, context)

        merged = self._merge_ids(constant_ids, cached, user_ids, user_expanded_ids)
        capped = self._cap_candidates_after_expansion(constant_ids, merged)
        filtered = self._filter_memory_candidates(store, items_by_id, capped, present_character_ids)
        try:
            injection = await self._run_schedule_with_candidates(
                session_name,
                filtered,
                selected_messages,
                scheduler_api_config_id,
            )
            return injection
        finally:
            duration_ms = int((perf_counter() - started_at) * 1000)
            rst_runtime_service.update_session_state(
                session_name,
                schedule_running=False,
                schedule_last_duration_ms=duration_ms,
            )

    async def full_schedule_from_cache(
        self,
        session_name: str,
        scheduler_api_config_id: str,
    ) -> str:
        started_at = perf_counter()
        rst_runtime_service.update_session_state(session_name, schedule_running=True)
        store = self._store(session_name)
        state = rst_runtime_service.get_session_state(session_name)
        cached = list(state.get("pre_retrieve_candidates", []))
        session = get_session_storage(session_name)
        message_store = MessageStore(get_session_dir(session_name))
        if session.scan_depth == 0:
            recent_messages = []
        elif session.scan_depth < 0:
            recent_messages = message_store.load_all()
        else:
            recent_messages = message_store.load_recent(session.scan_depth)

        try:
            if not cached:
                rst_runtime_service.update_session_state(
                    session_name,
                    pre_retrieve_candidates=[],
                    last_schedule_at=datetime.utcnow().isoformat(),
                    last_injection_block="",
                    last_matched_count=0,
                    last_matched_entry_ids=[],
                )
                return ""

            return await self._run_schedule_with_candidates(
                session_name,
                cached,
                recent_messages,
                scheduler_api_config_id,
            )
        finally:
            duration_ms = int((perf_counter() - started_at) * 1000)
            rst_runtime_service.update_session_state(
                session_name,
                schedule_running=False,
                schedule_last_duration_ms=duration_ms,
            )

    def get_status(self, session_name: str) -> ScheduleStatus:
        state = rst_runtime_service.get_session_state(session_name)
        return ScheduleStatus(
            running=bool(state.get("schedule_running", False)),
            last_run_at=state.get("last_schedule_at"),
            last_matched_count=state.get("last_matched_count"),
            last_matched_entry_ids=list(state.get("last_matched_entry_ids", [])),
            cached_candidates=list(state.get("pre_retrieve_candidates", [])),
        )


lore_scheduler = LoreScheduler()


__all__ = ["LoreScheduler", "lore_scheduler"]
