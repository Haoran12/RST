from __future__ import annotations

from datetime import datetime
from time import perf_counter

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
from app.services.log_service import log_service
from app.services.lore_nlp import LoreNlpEngine
from app.services.rst_runtime_service import rst_runtime_service
from app.services.session_service import get_session_dir, get_session_storage
from app.storage.encryption import decrypt_api_key
from app.storage.lore_store import LoreStore
from app.storage.message_store import MessageStore


class LoreScheduler:
    """Two-phase lore scheduler with memory visibility filtering."""

    def __init__(self) -> None:
        self._engines: dict[str, LoreNlpEngine] = {}

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

    def _build_candidate_text(self, store: LoreStore, candidate_ids: list[str]) -> str:
        if not candidate_ids:
            return ""

        index = store.load_index()
        index_map = {item.entry_id: item for item in index.items}
        blocks: list[str] = []

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
                active_form = next(
                    (form for form in char_file.data.forms if form.form_id == char_file.data.active_form_id),
                    char_file.data.forms[0] if char_file.data.forms else None,
                )
                profile = [
                    f"[CHARACTER] {char_file.data.name}",
                    f"race: {char_file.data.race}",
                    f"role: {char_file.data.role}",
                    f"objective: {char_file.data.objective}",
                ]
                if active_form is not None:
                    profile.append(f"activity: {active_form.activity}")
                    profile.append(f"body: {active_form.body}")
                blocks.append("\n".join(profile))
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
        request_time = datetime.utcnow().isoformat()
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
            response_time = datetime.utcnow().isoformat()
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
            response_time = datetime.utcnow().isoformat()
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

        response_time = datetime.utcnow().isoformat()
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

        present_character_ids = self._present_character_ids(store, context)
        merged = self._merge_ids(constant_ids, nlp_ids)
        filtered = self._filter_memory_candidates(store, items_by_id, merged, present_character_ids)

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
        candidate_text = self._build_candidate_text(store, candidate_ids)
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

        selected_messages = self._select_messages(messages, scan_depth)
        context = self._conversation_text(selected_messages)
        present_character_ids = self._present_character_ids(store, context)

        merged = self._merge_ids(constant_ids, cached, user_ids)
        filtered = self._filter_memory_candidates(store, items_by_id, merged, present_character_ids)
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
            cached_candidates=list(state.get("pre_retrieve_candidates", [])),
        )


lore_scheduler = LoreScheduler()


__all__ = ["LoreScheduler", "lore_scheduler"]
