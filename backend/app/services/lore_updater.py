from __future__ import annotations

import asyncio
import json
from datetime import datetime
from time import perf_counter
from typing import Any

from app.models import generate_id
from app.models.api_config import ApiConfig
from app.models.lore import (
    CharacterData,
    CharacterFile,
    CharacterForm,
    CharacterMemory,
    ConsolidateResult,
    LoreCategory,
    LoreEntry,
    SchedulerPromptTemplate,
    SyncChange,
    SyncFieldChange,
    SyncResult,
    SyncStatus,
)
from app.models.log import LogEntry
from app.models.session import Message
from app.providers.base import ProviderError
from app.providers.registry import get_provider
from app.services.api_config_service import get_api_config_storage
from app.services.log_service import log_service
from app.services.rst_runtime_service import rst_runtime_service
from app.services.session_service import get_session_dir, get_session_storage
from app.storage.encryption import decrypt_api_key
from app.storage.lore_store import LoreStore

MEMORY_CONSOLIDATION_THRESHOLD = 30
MEMORY_CONSOLIDATION_TARGET = 20


class LoreUpdater:
    """Extract lore updates from conversations and apply them to storage."""

    def _store(self, session_name: str) -> LoreStore:
        get_session_storage(session_name)
        return LoreStore(get_session_dir(session_name))

    def _select_messages(self, messages: list[Message], scan_depth: int) -> list[Message]:
        visible = [msg for msg in messages if msg.visible]
        if scan_depth < 0:
            return visible
        return visible[-scan_depth:] if scan_depth > 0 else []

    def _conversation_text(self, messages: list[Message]) -> str:
        return "\n".join(f"{msg.role}: {msg.content}" for msg in messages if msg.content.strip())

    def _existing_summary(self, store: LoreStore) -> str:
        chunks: list[str] = []
        for entry in store.load_all_entries():
            if isinstance(entry, CharacterData):
                chunks.append(
                    f"[character] {entry.name}: strength={entry.strength}, role={entry.role}, objective={entry.objective}"
                )
            else:
                content = entry.content.strip().replace("\n", " ")
                if len(content) > 80:
                    content = f"{content[:80]}..."
                chunks.append(f"[{entry.category.value}] {entry.name}: {content}")
        return "\n".join(chunks[:200])

    def _character_list_summary(self, store: LoreStore) -> str:
        chars = store.list_characters()
        if not chars:
            return "(none)"
        return "\n".join(f"- {char.name} ({char.character_id})" for char in chars)

    async def _call_llm(
        self,
        session_name: str,
        api_config: ApiConfig,
        prompt: str,
        stage: str,
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
            "stage": stage,
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

    def _extract_json_array(self, text: str) -> list[dict[str, Any]]:
        raw = text.strip()
        if not raw:
            return []

        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                return [item for item in parsed if isinstance(item, dict)]
        except json.JSONDecodeError:
            pass

        start = raw.find("[")
        end = raw.rfind("]")
        if start == -1 or end == -1 or end <= start:
            return []

        try:
            parsed = json.loads(raw[start : end + 1])
            if isinstance(parsed, list):
                return [item for item in parsed if isinstance(item, dict)]
        except json.JSONDecodeError:
            return []
        return []

    def _render_extract_prompt(
        self,
        template: SchedulerPromptTemplate,
        conversation_context: str,
        existing_entries_summary: str,
        character_list: str,
    ) -> str:
        prompt = template.extract_prompt or ""
        prompt = prompt.replace("{conversation_context}", conversation_context)
        prompt = prompt.replace("{existing_entries_summary}", existing_entries_summary)
        prompt = prompt.replace("{character_list}", character_list)
        return prompt

    def _format_change_value(self, value: Any) -> str:
        if value is None:
            return ""
        if isinstance(value, str):
            return value
        if isinstance(value, (int, float, bool)):
            return str(value)
        try:
            return json.dumps(value, ensure_ascii=False)
        except Exception:
            return str(value)

    def _render_consolidate_prompt(
        self,
        template: SchedulerPromptTemplate,
        character_name: str,
        memories_to_consolidate: str,
    ) -> str:
        prompt = template.consolidate_prompt or ""
        prompt = prompt.replace("{character_name}", character_name)
        prompt = prompt.replace("{memories_to_consolidate}", memories_to_consolidate)
        return prompt

    def _find_character_by_name(self, store: LoreStore, name: str) -> CharacterFile | None:
        target = name.strip().lower()
        if not target:
            return None
        for character in store.list_characters():
            if character.name.strip().lower() == target:
                return store.load_character(character.character_id)
        return None

    def _ensure_character(self, store: LoreStore, name: str) -> CharacterFile:
        existing = self._find_character_by_name(store, name)
        if existing is not None:
            return existing

        now = datetime.utcnow()
        default_form = CharacterForm(form_id=generate_id(), form_name="默认形态", is_default=True)
        data = CharacterData(
            character_id=generate_id(),
            name=name.strip() or "未命名角色",
            race="未知",
            strength=10,
            birth="",
            homeland="",
            aliases=[],
            role="",
            faction="",
            objective="",
            personality="",
            relationship=[],
            memories=[],
            forms=[default_form],
            active_form_id=default_form.form_id,
            tags=[],
            disabled=False,
            constant=False,
            created_at=now,
            updated_at=now,
        )
        file = CharacterFile(data=data, version=1)
        store.save_character(file)
        return file

    def _resolve_known_by_ids(self, store: LoreStore, names: list[str]) -> list[str]:
        name_map = {char.name.strip().lower(): char.character_id for char in store.list_characters()}
        ids: list[str] = []
        for raw in names:
            character_id = name_map.get(raw.strip().lower())
            if character_id and character_id not in ids:
                ids.append(character_id)
        return ids

    def _resolve_plot_event_id(self, store: LoreStore, event_name: str | None) -> str | None:
        if not event_name:
            return None
        target = event_name.strip().lower()
        if not target:
            return None
        plot_file = store.load_category_file(LoreCategory.PLOT)
        for entry in plot_file.entries:
            if entry.name.strip().lower() == target:
                return entry.id
        return None

    def _append_or_create_lore_update(
        self,
        store: LoreStore,
        category: LoreCategory,
        name: str,
        content_append: str,
        tags: list[str],
        created_entries: list[str],
        updated_entries: list[str],
        changes: list[SyncChange],
    ) -> None:
        category_file = store.load_category_file(category)
        now = datetime.utcnow()
        for index, entry in enumerate(category_file.entries):
            if entry.name.strip().lower() != name.strip().lower():
                continue
            append_text = content_append.strip()
            before_content = entry.content
            merged_content = entry.content
            if append_text:
                merged_content = (
                    f"{entry.content}\n{append_text}".strip()
                    if entry.content.strip()
                    else append_text
                )
            merged_tags = list(dict.fromkeys([*entry.tags, *tags]))
            tags_added = [tag for tag in tags if tag not in entry.tags]
            category_file.entries[index] = entry.model_copy(
                update={
                    "content": merged_content,
                    "tags": merged_tags,
                    "updated_at": now,
                }
            )
            store.save_category_file(category_file)
            updated_entries.append(entry.id)
            changes.append(
                SyncChange(
                    entry_id=entry.id,
                    name=entry.name,
                    category=category.value,
                    action="updated",
                    summary="Lore content appended",
                    before_content=before_content or None,
                    after_content=merged_content or None,
                    content_append=append_text or None,
                    tags_added=tags_added,
                )
            )
            return

        append_text = content_append.strip()
        new_entry = LoreEntry(
            id=generate_id(),
            name=name,
            category=category,
            content=append_text,
            disabled=False,
            constant=False,
            tags=list(dict.fromkeys(tags)),
            created_at=now,
            updated_at=now,
        )
        category_file.entries.append(new_entry)
        store.save_category_file(category_file)
        created_entries.append(new_entry.id)
        changes.append(
            SyncChange(
                entry_id=new_entry.id,
                name=new_entry.name,
                category=category.value,
                action="created",
                summary="Lore entry created",
                after_content=new_entry.content or None,
                content_append=append_text or None,
                tags_added=list(dict.fromkeys(tags)),
            )
        )

    async def sync_from_conversation(
        self,
        session_name: str,
        messages: list[Message],
        scan_depth: int,
        scheduler_api_config_id: str,
    ) -> SyncResult:
        started_at = perf_counter()
        rst_runtime_service.update_session_state(session_name, sync_running=True)
        try:
            store = self._store(session_name)
            selected = self._select_messages(messages, scan_depth)
            template = store.load_scheduler_template()

            prompt = self._render_extract_prompt(
                template,
                self._conversation_text(selected),
                self._existing_summary(store),
                self._character_list_summary(store),
            )

            api_config = get_api_config_storage(scheduler_api_config_id)
            raw_text = await self._call_llm(
                session_name,
                api_config,
                prompt,
                stage="scheduler_sync_extract",
            )
            instructions = self._extract_json_array(raw_text)

            updated_entries: list[str] = []
            created_entries: list[str] = []
            new_memories = 0
            new_plot_events = 0
            affected_characters: set[str] = set()
            changes: list[SyncChange] = []

            for item in instructions:
                action_type = str(item.get("type", "")).strip().lower()
                if not action_type:
                    continue

                if action_type == "character_update":
                    name = str(item.get("name", "")).strip()
                    updates = item.get("field_updates")
                    if not name or not isinstance(updates, dict):
                        continue

                    char_file = self._ensure_character(store, name)
                    old_data = char_file.data
                    char_updates: dict[str, Any] = {}
                    form_updates: dict[str, Any] = {}
                    char_fields = set(CharacterData.model_fields.keys())
                    form_fields = set(CharacterForm.model_fields.keys())
                    for key, value in updates.items():
                        if key in char_fields:
                            char_updates[key] = value
                        elif key in form_fields:
                            form_updates[key] = value

                    data = old_data
                    if char_updates:
                        data = data.model_copy(update=char_updates)
                    if form_updates and data.forms:
                        active_id = data.active_form_id or data.forms[0].form_id
                        forms = [
                            form.model_copy(update=form_updates) if form.form_id == active_id else form
                            for form in data.forms
                        ]
                        data = data.model_copy(update={"forms": forms})

                    field_changes: list[SyncFieldChange] = []
                    for key in char_updates:
                        before_text = self._format_change_value(getattr(old_data, key, None))
                        after_text = self._format_change_value(getattr(data, key, None))
                        if before_text == after_text:
                            continue
                        field_changes.append(
                            SyncFieldChange(
                                field=key,
                                before=before_text,
                                after=after_text,
                            )
                        )

                    old_active_form = None
                    if old_data.forms:
                        old_active_id = old_data.active_form_id or old_data.forms[0].form_id
                        old_active_form = next(
                            (form for form in old_data.forms if form.form_id == old_active_id),
                            old_data.forms[0],
                        )
                    new_active_form = None
                    if data.forms:
                        new_active_id = data.active_form_id or data.forms[0].form_id
                        new_active_form = next(
                            (form for form in data.forms if form.form_id == new_active_id),
                            data.forms[0],
                        )

                    for key in form_updates:
                        before_text = self._format_change_value(
                            getattr(old_active_form, key, None) if old_active_form else None
                        )
                        after_text = self._format_change_value(
                            getattr(new_active_form, key, None) if new_active_form else None
                        )
                        if before_text == after_text:
                            continue
                        field_changes.append(
                            SyncFieldChange(
                                field=f"active_form.{key}",
                                before=before_text,
                                after=after_text,
                            )
                        )

                    data = data.model_copy(update={"updated_at": datetime.utcnow()})
                    store.save_character(CharacterFile(data=data, version=char_file.version))
                    updated_entries.append(data.character_id)
                    affected_characters.add(data.character_id)
                    changes.append(
                        SyncChange(
                            entry_id=data.character_id,
                            name=data.name,
                            category=LoreCategory.CHARACTER.value,
                            action="updated",
                            summary="Character fields updated",
                            field_changes=field_changes,
                        )
                    )
                    continue

                if action_type == "plot_event":
                    name = str(item.get("name", "")).strip()
                    content = str(item.get("content", "")).strip()
                    tags = [str(tag).strip() for tag in item.get("tags", []) if str(tag).strip()]
                    if not name or not content:
                        continue
                    self._append_or_create_lore_update(
                        store,
                        LoreCategory.PLOT,
                        name,
                        content,
                        tags,
                        created_entries,
                        updated_entries,
                        changes,
                    )
                    new_plot_events += 1
                    continue

                if action_type == "character_memory":
                    char_name = str(item.get("character_name", "")).strip()
                    event = str(item.get("event", "")).strip()
                    if not char_name or not event:
                        continue

                    char_file = self._ensure_character(store, char_name)
                    importance_raw = item.get("importance", 5)
                    try:
                        importance = int(importance_raw)
                    except Exception:
                        importance = 5
                    importance = max(1, min(10, importance))
                    tags = [str(tag).strip() for tag in item.get("tags", []) if str(tag).strip()]
                    known_by_names = [
                        str(name).strip() for name in item.get("known_by", []) if str(name).strip()
                    ]
                    known_by_ids = self._resolve_known_by_ids(store, known_by_names)
                    plot_event_id = self._resolve_plot_event_id(store, item.get("plot_event_name"))

                    memory = CharacterMemory(
                        memory_id=generate_id(),
                        event=event,
                        importance=importance,
                        tags=list(dict.fromkeys(tags)),
                        known_by=known_by_ids,
                        plot_event_id=plot_event_id,
                        is_consolidated=False,
                        created_at=datetime.utcnow(),
                    )
                    store.add_memory(char_file.data.character_id, memory)
                    new_memories += 1
                    affected_characters.add(char_file.data.character_id)
                    changes.append(
                        SyncChange(
                            entry_id=char_file.data.character_id,
                            name=char_file.data.name,
                            category=LoreCategory.MEMORY.value,
                            action="memory_added",
                            summary="Character memory added",
                            memory_event=memory.event,
                            tags_added=list(memory.tags),
                        )
                    )
                    continue

                if action_type == "lore_update":
                    name = str(item.get("name", "")).strip()
                    category_raw = str(item.get("category", "")).strip().lower()
                    content_append = str(item.get("content_append", "")).strip()
                    tags = [str(tag).strip() for tag in item.get("tags", []) if str(tag).strip()]
                    if not name or not content_append:
                        continue
                    try:
                        category = LoreCategory(category_raw)
                    except Exception:
                        continue
                    if category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
                        continue
                    self._append_or_create_lore_update(
                        store,
                        category,
                        name,
                        content_append,
                        tags,
                        created_entries,
                        updated_entries,
                        changes,
                    )

            store.rebuild_index()

            session = get_session_storage(session_name)
            sync_interval = session.lore_sync_interval
            for character_id in affected_characters:
                memories = store.load_character_memories(character_id)
                if len(memories) <= MEMORY_CONSOLIDATION_THRESHOLD:
                    continue
                task = asyncio.create_task(
                    self.consolidate_memories(
                        session_name=session_name,
                        character_id=character_id,
                        scheduler_api_config_id=scheduler_api_config_id,
                    )
                )
                rst_runtime_service.register_task(session_name, task)

            duration_ms = int((perf_counter() - started_at) * 1000)
            result = SyncResult(
                updated_entries=updated_entries,
                created_entries=created_entries,
                new_memories=new_memories,
                new_plot_events=new_plot_events,
                duration_ms=duration_ms,
                changes=changes,
            )

            rst_runtime_service.update_session_state(
                session_name,
                sync_last_run_at=datetime.utcnow().isoformat(),
                sync_last_result=result.model_dump(mode="json"),
                sync_interval=sync_interval,
            )
            return result
        finally:
            rst_runtime_service.update_session_state(session_name, sync_running=False)

    async def consolidate_memories(
        self,
        session_name: str,
        character_id: str,
        scheduler_api_config_id: str,
    ) -> ConsolidateResult:
        started_at = perf_counter()
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            return ConsolidateResult(
                character_id=character_id,
                removed_count=0,
                created_count=0,
                duration_ms=0,
            )

        memories = list(char_file.data.memories)
        if len(memories) <= MEMORY_CONSOLIDATION_TARGET:
            return ConsolidateResult(
                character_id=character_id,
                removed_count=0,
                created_count=0,
                duration_ms=0,
            )

        removable = [
            memory
            for memory in memories
            if memory.importance <= 3 or (memory.is_consolidated and memory.importance <= 5)
        ]
        removable.sort(key=lambda item: item.created_at)

        remove_count = max(0, len(memories) - MEMORY_CONSOLIDATION_TARGET)
        candidates = removable[:remove_count]
        if not candidates:
            return ConsolidateResult(
                character_id=character_id,
                removed_count=0,
                created_count=0,
                duration_ms=0,
            )

        template = store.load_scheduler_template()
        prompt_memories = "\n".join(
            f"- {memory.event} | importance={memory.importance} | tags={','.join(memory.tags)}"
            for memory in candidates
        )
        prompt = self._render_consolidate_prompt(template, char_file.data.name, prompt_memories)

        api_config = get_api_config_storage(scheduler_api_config_id)
        raw_text = await self._call_llm(
            session_name,
            api_config,
            prompt,
            stage="scheduler_memory_consolidate",
        )
        merged = self._extract_json_array(raw_text)

        new_memories: list[CharacterMemory] = []
        for item in merged:
            event = str(item.get("event", "")).strip()
            if not event:
                continue
            importance_raw = item.get("importance", 5)
            try:
                importance = int(importance_raw)
            except Exception:
                importance = 5
            importance = max(1, min(10, importance))
            tags = [str(tag).strip() for tag in item.get("tags", []) if str(tag).strip()]
            new_memories.append(
                CharacterMemory(
                    memory_id=generate_id(),
                    event=event,
                    importance=importance,
                    tags=list(dict.fromkeys(tags)),
                    known_by=[],
                    plot_event_id=None,
                    is_consolidated=True,
                    created_at=datetime.utcnow(),
                )
            )

        if not new_memories:
            return ConsolidateResult(
                character_id=character_id,
                removed_count=0,
                created_count=0,
                duration_ms=0,
            )

        removed_ids = {memory.memory_id for memory in candidates}
        remained = [memory for memory in memories if memory.memory_id not in removed_ids]
        final_memories = [*remained, *new_memories]
        store.replace_memories(character_id, final_memories)
        store.rebuild_index()

        duration_ms = int((perf_counter() - started_at) * 1000)
        return ConsolidateResult(
            character_id=character_id,
            removed_count=len(candidates),
            created_count=len(new_memories),
            duration_ms=duration_ms,
        )

    def get_status(self, session_name: str) -> SyncStatus:
        session = get_session_storage(session_name)
        state = rst_runtime_service.get_session_state(session_name)
        last_result_raw = state.get("sync_last_result")
        last_result: SyncResult | None = None
        if isinstance(last_result_raw, dict):
            try:
                last_result = SyncResult.model_validate(last_result_raw)
            except Exception:
                last_result = None
        return SyncStatus(
            running=bool(state.get("sync_running", False)),
            last_run_at=state.get("sync_last_run_at"),
            rounds_since_last_sync=int(state.get("rounds_since_sync", 0)),
            sync_interval=int(state.get("sync_interval", session.lore_sync_interval)),
            last_result=last_result,
        )


lore_updater = LoreUpdater()


__all__ = [
    "LoreUpdater",
    "lore_updater",
    "MEMORY_CONSOLIDATION_THRESHOLD",
    "MEMORY_CONSOLIDATION_TARGET",
]
