from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone
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
    Relationship,
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

CHARACTER_UPDATE_CHAR_FIELD_ALIASES: dict[str, tuple[str, ...]] = {
    "objective": ("goal", "target", "purpose", "目标", "目的"),
    "personality": ("persona", "traits", "性格"),
    "role": ("position", "identity", "角色", "身份"),
    "faction": ("camp", "组织", "阵营"),
    "relationship": ("relationships", "relation", "relations", "关系", "人际关系"),
}

CHARACTER_UPDATE_FORM_FIELD_ALIASES: dict[str, tuple[str, ...]] = {
    "activity": (
        "action",
        "current_action",
        "current_activity",
        "behavior",
        "behaviour",
        "当前行为",
        "行为",
        "行动",
        "当前行动",
    ),
    "physique": ("appearance", "look", "looks", "外貌", "体貌", "体型", "容貌"),
    "features": ("feature", "traits", "特点", "特征", "外观特征"),
    "body": ("body_state", "physical_state", "身体状态", "体力状态", "当前身体状态"),
    "mind": ("mind_state", "mental_state", "心理状态", "精神状态", "当前精神状态"),
    "clothing": ("outfit", "attire", "穿着", "衣着", "服饰"),
}

SYNC_ACTION_ALIASES: dict[str, str] = {
    "character": "character_update",
    "update_character": "character_update",
    "character_state": "character_update",
    "character_state_update": "character_update",
    "update_character_state": "character_update",
    "plot": "plot_event",
    "event": "plot_event",
    "plotevent": "plot_event",
    "memory": "character_memory",
    "add_memory": "character_memory",
    "memory_add": "character_memory",
    "update_lore": "lore_update",
    "append_lore": "lore_update",
    "lore_append": "lore_update",
}

EXTRACT_OUTPUT_CONTRACT = """OUTPUT CONTRACT (STRICT):
- Return a JSON array only. Do not add markdown fences.
- Every item must include a valid "type" and follow one of these schemas:
  1) {"type":"character_update","name":"角色名","field_updates":{"mind":"...","active_form.body":"..."}}
  2) {"type":"plot_event","name":"事件名","content":"事件内容","tags":["tag1"]}
  3) {"type":"character_memory","character_name":"角色名","event":"记忆内容","importance":1-10,"tags":["tag1"],"known_by":["角色名"],"plot_event_name":"事件名"}
  4) {"type":"lore_update","name":"条目名","category":"world_base|society|place|faction|skills|others|plot","content_append":"追加内容","tags":["tag1"]}
- Use exact key names above. For character updates, put fields under field_updates only.
- If nothing needs to be updated, return [].
"""


class LoreUpdater:
    """Extract lore updates from conversations and apply them to storage."""

    def _store(self, session_name: str) -> LoreStore:
        get_session_storage(session_name)
        return LoreStore(get_session_dir(session_name))

    def _utc_iso(self) -> str:
        return datetime.now(timezone.utc).isoformat()

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
                active_form = next(
                    (f for f in entry.forms if f.form_id == entry.active_form_id),
                    entry.forms[0] if entry.forms else None,
                )
                strength_val = active_form.strength if active_form else 100
                chunks.append(
                    f"[character] {entry.name}: strength={strength_val}, role={entry.role}, objective={entry.objective}"
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
        prompt = f"{prompt.rstrip()}\n\n{EXTRACT_OUTPUT_CONTRACT}"
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

    def _normalize_update_field_key(self, key: str) -> str:
        normalized = key.strip().lower().replace("-", "_").replace(" ", "_")
        while "__" in normalized:
            normalized = normalized.replace("__", "_")
        return normalized

    def _normalize_action_type(self, value: Any) -> str:
        normalized = self._normalize_update_field_key(str(value))
        if normalized in {"character_update", "plot_event", "character_memory", "lore_update"}:
            return normalized
        return SYNC_ACTION_ALIASES.get(normalized, "")

    def _normalize_string_list(self, value: Any) -> list[str]:
        if isinstance(value, list):
            return [str(item).strip() for item in value if str(item).strip()]
        if isinstance(value, str):
            return [part.strip() for part in value.replace("，", ",").split(",") if part.strip()]
        return []

    def _normalize_relationship_updates(self, value: Any) -> list[Relationship]:
        relations: list[Relationship] = []
        seen_targets: set[str] = set()

        def append_relation(target_raw: Any, relation_raw: Any) -> None:
            target = str(target_raw).strip()
            if not target:
                return
            relation = str(relation_raw).strip()
            target_key = target.lower()
            if target_key in seen_targets:
                return
            seen_targets.add(target_key)
            relations.append(Relationship(target=target, relation=relation))

        if isinstance(value, dict):
            for target, relation in value.items():
                append_relation(target, relation)
            return relations

        if isinstance(value, list):
            for item in value:
                if isinstance(item, Relationship):
                    append_relation(item.target, item.relation)
                    continue
                if isinstance(item, dict):
                    target = (
                        item.get("target")
                        or item.get("name")
                        or item.get("character")
                        or item.get("character_name")
                    )
                    relation = (
                        item.get("relation")
                        or item.get("description")
                        or item.get("summary")
                        or item.get("value")
                        or ""
                    )
                    append_relation(target, relation)
                    continue
                text = str(item).strip()
                if ":" in text:
                    target, relation = text.split(":", 1)
                    append_relation(target, relation)
            return relations

        text = str(value).strip()
        if not text:
            return relations
        for line in text.splitlines():
            candidate = line.strip().lstrip("-").strip()
            if ":" not in candidate:
                continue
            target, relation = candidate.split(":", 1)
            append_relation(target, relation)
        return relations

    def _coerce_legacy_character_updates(self, value: Any) -> dict[str, Any]:
        if not isinstance(value, dict):
            return {}

        updates: dict[str, Any] = {}
        for raw_key, raw_value in value.items():
            key = self._normalize_update_field_key(str(raw_key))

            if key == "field_updates" and isinstance(raw_value, dict):
                updates.update(raw_value)
                continue

            if key in {"state", "status"} and isinstance(raw_value, dict):
                for nested_key, nested_value in raw_value.items():
                    nested = self._normalize_update_field_key(str(nested_key))
                    if nested in {"relationship", "relationships", "relation", "relations"}:
                        relation_updates = self._normalize_relationship_updates(nested_value)
                        if relation_updates:
                            updates["relationship"] = relation_updates
                        continue
                    updates[str(nested_key)] = nested_value
                continue

            if key in {"relationship", "relationships", "relation", "relations"}:
                relation_updates = self._normalize_relationship_updates(raw_value)
                if relation_updates:
                    updates["relationship"] = relation_updates
                continue

            updates[str(raw_key)] = raw_value
        return updates

    def _infer_action_type(self, item: dict[str, Any]) -> str:
        inferred = self._normalize_action_type(item.get("type"))
        if inferred:
            return inferred

        for type_key in ("action", "kind", "op", "operation"):
            inferred = self._normalize_action_type(item.get(type_key))
            if inferred:
                return inferred

        name = str(item.get("name", "")).strip()
        character_name = str(item.get("character_name", "")).strip()
        has_character = bool(name or character_name)
        if has_character and (
            isinstance(item.get("field_updates"), dict) or isinstance(item.get("updates"), dict)
        ):
            return "character_update"

        event = str(item.get("event") or item.get("memory_event") or "").strip()
        if has_character and event:
            return "character_memory"

        category = self._normalize_update_field_key(str(item.get("category", "")))
        content_like = str(item.get("content") or item.get("content_append") or item.get("summary") or "").strip()
        if name and content_like and category in {"plot", "plot_event", "event"}:
            return "plot_event"
        if name and category and content_like:
            return "lore_update"
        return ""

    def _normalize_sync_instruction(self, item: dict[str, Any]) -> dict[str, Any]:
        action_type = self._infer_action_type(item)
        if not action_type:
            return {}

        normalized = dict(item)
        normalized["type"] = action_type

        if action_type == "character_update":
            if not str(normalized.get("name", "")).strip():
                candidate_name = str(normalized.get("character_name", "")).strip()
                if candidate_name:
                    normalized["name"] = candidate_name

            field_updates = normalized.get("field_updates")
            if not isinstance(field_updates, dict):
                field_updates = self._coerce_legacy_character_updates(normalized.get("updates"))
            if isinstance(field_updates, dict):
                normalized["field_updates"] = field_updates
            return normalized

        if action_type == "character_memory":
            if not str(normalized.get("character_name", "")).strip():
                alias_name = str(normalized.get("name", "")).strip()
                if alias_name:
                    normalized["character_name"] = alias_name
            if not str(normalized.get("event", "")).strip():
                memory_event = str(normalized.get("memory_event", "")).strip()
                if memory_event:
                    normalized["event"] = memory_event
            if "tags" in normalized:
                normalized["tags"] = self._normalize_string_list(normalized.get("tags"))
            if "known_by" in normalized:
                normalized["known_by"] = self._normalize_string_list(normalized.get("known_by"))
            return normalized

        if action_type == "plot_event":
            if not str(normalized.get("content", "")).strip():
                fallback = str(normalized.get("content_append") or normalized.get("summary") or "").strip()
                if fallback:
                    normalized["content"] = fallback
            if "tags" in normalized:
                normalized["tags"] = self._normalize_string_list(normalized.get("tags"))
            return normalized

        if not str(normalized.get("content_append", "")).strip():
            fallback = str(normalized.get("content") or normalized.get("summary") or "").strip()
            if fallback:
                normalized["content_append"] = fallback
        if "tags" in normalized:
            normalized["tags"] = self._normalize_string_list(normalized.get("tags"))
        category = str(normalized.get("category", "")).strip()
        if category:
            normalized["category"] = self._normalize_update_field_key(category)
        return normalized

    def _build_update_field_lookup(
        self,
        fields: set[str],
        aliases: dict[str, tuple[str, ...]],
    ) -> dict[str, str]:
        lookup = {self._normalize_update_field_key(field): field for field in fields}
        for canonical, names in aliases.items():
            if canonical not in fields:
                continue
            for name in names:
                normalized = self._normalize_update_field_key(name)
                if normalized:
                    lookup[normalized] = canonical
        return lookup

    def _split_character_form_updates(
        self,
        updates: dict[str, Any],
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        char_fields = set(CharacterData.model_fields.keys())
        form_fields = set(CharacterForm.model_fields.keys())
        char_lookup = self._build_update_field_lookup(char_fields, CHARACTER_UPDATE_CHAR_FIELD_ALIASES)
        form_lookup = self._build_update_field_lookup(form_fields, CHARACTER_UPDATE_FORM_FIELD_ALIASES)
        char_updates: dict[str, Any] = {}
        form_updates: dict[str, Any] = {}

        for raw_key, value in updates.items():
            key = self._normalize_update_field_key(str(raw_key))
            if not key:
                continue

            if key == "active_form" and isinstance(value, dict):
                for nested_key, nested_value in value.items():
                    nested = self._normalize_update_field_key(str(nested_key))
                    canonical = form_lookup.get(nested)
                    if canonical:
                        form_updates[canonical] = nested_value
                continue

            if "." in key:
                prefix, nested = key.split(".", 1)
                if prefix in {"active_form", "form"}:
                    canonical = form_lookup.get(nested)
                    if canonical:
                        form_updates[canonical] = value
                    continue

            canonical_char = char_lookup.get(key)
            if canonical_char:
                if canonical_char == "relationship":
                    relation_updates = self._normalize_relationship_updates(value)
                    if relation_updates:
                        char_updates[canonical_char] = relation_updates
                    continue
                char_updates[canonical_char] = value
                continue

            canonical_form = form_lookup.get(key)
            if canonical_form:
                form_updates[canonical_form] = value

        return char_updates, form_updates

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
            gender="",
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
            instructions = [
                normalized
                for item in self._extract_json_array(raw_text)
                if (normalized := self._normalize_sync_instruction(item))
            ]

            updated_entries: list[str] = []
            created_entries: list[str] = []
            new_memories = 0
            new_plot_events = 0
            affected_characters: set[str] = set()
            changes: list[SyncChange] = []

            for item in instructions:
                action_type = self._infer_action_type(item)
                if not action_type:
                    continue

                if action_type == "character_update":
                    name = str(item.get("name", "")).strip()
                    if not name:
                        character_id = str(item.get("character_id", "")).strip()
                        if character_id:
                            by_id = store.load_character(character_id)
                            if by_id is not None:
                                name = by_id.data.name
                    updates = item.get("field_updates")
                    if not isinstance(updates, dict):
                        updates = self._coerce_legacy_character_updates(item.get("updates"))
                    if not name or not isinstance(updates, dict):
                        continue

                    char_file = self._ensure_character(store, name)
                    old_data = char_file.data
                    char_updates, form_updates = self._split_character_form_updates(updates)
                    if not char_updates and not form_updates:
                        continue

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

                    if not field_changes:
                        continue

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
                    content = str(item.get("content") or item.get("content_append") or "").strip()
                    tags = self._normalize_string_list(item.get("tags"))
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
                    char_name = str(item.get("character_name") or item.get("name") or "").strip()
                    event = str(item.get("event") or item.get("memory_event") or "").strip()
                    if not char_name or not event:
                        continue

                    char_file = self._ensure_character(store, char_name)
                    importance_raw = item.get("importance", 5)
                    try:
                        importance = int(importance_raw)
                    except Exception:
                        importance = 5
                    importance = max(1, min(10, importance))
                    tags = self._normalize_string_list(item.get("tags"))
                    known_by_names = self._normalize_string_list(item.get("known_by"))
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
                    content_append = str(item.get("content_append") or item.get("content") or "").strip()
                    tags = self._normalize_string_list(item.get("tags"))
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
