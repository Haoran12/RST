from __future__ import annotations

import json
import os
import re
from typing import Any

import yaml
from pydantic import ValidationError

from app.models import generate_id
from app.models.lore import (
    CharacterData,
    CharacterFile,
    CharacterForm,
    ConversionAction,
    ConversionReport,
    ConversionWarning,
    LoreCategory,
    LoreEntry,
    Relationship,
    SourceEntry,
    SourceLoreFile,
)
from app.models.log import LogEntry
from app.providers.base import ProviderError
from app.providers.registry import get_provider
from app.services.api_config_service import ApiConfigNotFoundError, get_api_config_storage
from app.services.log_service import log_service
from app.services.session_service import get_session_dir
from app.storage.encryption import EncryptionError, decrypt_api_key
from app.storage.lore_store import LoreStore
from app.time_utils import now_local, now_local_iso


def _env_positive_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        value = int(raw)
    except ValueError:
        return default
    return value if value > 0 else default


class LoreConverter:
    """Convert legacy static Lore JSON into RST lore files."""

    CATEGORY_MAP: dict[str, LoreCategory] = {
        "world_base": LoreCategory.WORLD_BASE,
        "society": LoreCategory.SOCIETY,
        "place": LoreCategory.PLACE,
        "factions": LoreCategory.FACTION,
        "faction": LoreCategory.FACTION,
        "skills": LoreCategory.SKILLS,
        "elements": LoreCategory.SKILLS,
        "others": LoreCategory.OTHERS,
        "characters": LoreCategory.CHARACTER,
    }

    _name_block_pattern = re.compile(r"(?im)^\s*name\s*:\s*.+$")
    # Aim to minimize API request count (RPM pressure) by packing more characters per LLM call.
    # Effective batch size is still bounded by prompt size and a max_tokens-based estimate.
    _llm_batch_max_items = 48
    _llm_batch_max_chars = 48000
    _llm_batch_tokens_per_item_estimate = 80
    _llm_single_fallback_budget_default = 2

    def _local_iso(self) -> str:
        return now_local_iso()

    def __init__(
        self,
        session_name: str,
        source_data: dict[str, Any],
        source_filename: str = "",
        split_faction_characters: bool = False,
        llm_fallback: bool = False,
        llm_api_config_id: str | None = None,
    ) -> None:
        self.session_name = session_name
        self.source_data = source_data
        self.source_filename = source_filename or "unknown"
        self.split_faction_characters = split_faction_characters
        self.llm_fallback = llm_fallback
        self.llm_api_config_id = llm_api_config_id.strip() if llm_api_config_id else None

        self._store = LoreStore(get_session_dir(session_name))
        self._now = now_local()

        self._llm_ready = self.llm_fallback
        self._llm_unavailable_reason: str | None = None
        self._llm_unavailable_reported = False
        self._llm_batch_prepared = False
        self._llm_batch_cache: dict[str, dict[str, Any]] = {}
        self._llm_single_fallback_budget = self._llm_single_fallback_budget_default
        self._llm_batch_max_items = _env_positive_int(
            "RST_LORE_IMPORT_LLM_BATCH_MAX_ITEMS",
            self._llm_batch_max_items,
        )
        self._llm_batch_max_chars = _env_positive_int(
            "RST_LORE_IMPORT_LLM_BATCH_MAX_CHARS",
            self._llm_batch_max_chars,
        )
        self._llm_batch_tokens_per_item_estimate = _env_positive_int(
            "RST_LORE_IMPORT_LLM_BATCH_TOKENS_PER_ITEM",
            self._llm_batch_tokens_per_item_estimate,
        )
        if self.llm_fallback and not self.llm_api_config_id:
            self._llm_ready = False
            self._llm_unavailable_reason = "LLM fallback requested but no API config id is available."

        self._warnings: list[ConversionWarning] = []
        self._errors: list[str] = []
        self._actions: list[ConversionAction] = []
        self._id_mapping: dict[str, str] = {}
        self._category_summary: dict[str, int] = {}
        self._converted_entries = 0
        self._converted_characters = 0
        self._skipped = 0

    async def convert(self) -> ConversionReport:
        try:
            source = SourceLoreFile.model_validate(self.source_data)
        except ValidationError as exc:
            raise ValueError("Invalid source lore format") from exc

        await self._prepare_llm_batch_for_failed_characters(source.entries)

        for src in source.entries:
            try:
                await self._convert_one(src)
            except Exception as exc:  # pragma: no cover - defensive guard
                self._skipped += 1
                error_message = f"entry '{src.name or src.id}' conversion failed: {exc}"
                self._errors.append(error_message)
                self._record_action(
                    source_id=src.id,
                    name=src.name or "unnamed_entry",
                    source_category=src.category,
                    action="entry_failed",
                    errors=[str(exc)],
                    notes=[error_message],
                )

        self._store.rebuild_index()
        self._attach_action_warnings()

        statistics = {
            "total_source_entries": len(source.entries),
            "converted_entries": self._converted_entries,
            "converted_characters": self._converted_characters,
            "skipped": self._skipped,
            "warnings_count": len(self._warnings),
            "errors_count": len(self._errors),
        }
        return ConversionReport(
            source_file=self.source_filename,
            session_name=self.session_name,
            timestamp=self._iso_timestamp(),
            statistics=statistics,
            id_mapping=self._id_mapping,
            category_summary=self._category_summary,
            actions=self._actions,
            warnings=self._warnings,
            errors=self._errors,
        )

    async def _convert_one(self, src: SourceEntry) -> None:
        category = self._map_category(src)
        if category == LoreCategory.CHARACTER:
            character_file, notes, action_name = await self._convert_character(src)
            self._store.save_character(character_file)
            self._remember_mapping(src.id, character_file.data.character_id)
            self._converted_characters += 1
            self._bump_category(LoreCategory.CHARACTER)
            self._record_action(
                source_id=src.id,
                name=src.name or character_file.data.name,
                source_category=src.category,
                action=action_name,
                target_category=LoreCategory.CHARACTER.value,
                created_ids=[character_file.data.character_id],
                notes=notes,
            )
            return

        if category == LoreCategory.FACTION:
            await self._convert_faction(src)
            return

        entry = self._convert_generic_entry(src, category_override=category)
        self._store.add_entry(entry)
        self._remember_mapping(src.id, entry.id)
        self._converted_entries += 1
        self._bump_category(entry.category)
        self._record_action(
            source_id=src.id,
            name=entry.name,
            source_category=src.category,
            action="generic_entry_created",
            target_category=entry.category.value,
            created_ids=[entry.id],
            notes=["Imported as generic LoreEntry."],
        )

    def _map_category(self, src: SourceEntry) -> LoreCategory:
        raw = src.category.strip().lower()
        mapped = self.CATEGORY_MAP.get(raw)
        if mapped is None:
            self._warn(
                src,
                "category_unknown",
                f"Unknown source category '{src.category}', mapped to 'others'.",
            )
            return LoreCategory.OTHERS
        if raw == "elements":
            self._warn(src, "category_unknown", "Source category 'elements' is mapped to 'skills'.")
        return mapped

    async def _convert_faction(self, src: SourceEntry) -> None:
        blocks = list(self._name_block_pattern.finditer(src.content))
        if len(blocks) <= 1:
            entry = self._convert_generic_entry(src, category_override=LoreCategory.FACTION)
            self._store.add_entry(entry)
            self._remember_mapping(src.id, entry.id)
            self._converted_entries += 1
            self._bump_category(entry.category)
            self._record_action(
                source_id=src.id,
                name=entry.name,
                source_category=src.category,
                action="faction_entry_created",
                target_category=entry.category.value,
                created_ids=[entry.id],
                notes=["No embedded character blocks detected."],
            )
            return

        if not self.split_faction_characters:
            self._warn(
                src,
                "faction_embedded_characters",
                "Embedded character blocks detected in faction entry; kept as faction entry.",
            )
            entry = self._convert_generic_entry(src, category_override=LoreCategory.FACTION)
            self._store.add_entry(entry)
            self._remember_mapping(src.id, entry.id)
            self._converted_entries += 1
            self._bump_category(entry.category)
            self._record_action(
                source_id=src.id,
                name=entry.name,
                source_category=src.category,
                action="faction_kept_with_embedded_characters",
                target_category=entry.category.value,
                created_ids=[entry.id],
                notes=["Embedded characters were kept inside faction content by configuration."],
            )
            return

        overview, character_blocks = self._split_faction_content(src.content)
        faction_entry = self._convert_generic_entry(
            src,
            category_override=LoreCategory.FACTION,
            content_override=overview or "Characters were split into standalone character entries.",
        )
        self._store.add_entry(faction_entry)
        self._remember_mapping(src.id, faction_entry.id)
        self._converted_entries += 1
        self._bump_category(faction_entry.category)

        split_character_ids: list[str] = []
        for index, block in enumerate(character_blocks, start=1):
            inferred_name = self._extract_block_name(block) or f"{src.name}-character-{index}"
            char_src = SourceEntry(
                id=f"{src.id}#{index}",
                name=inferred_name,
                category="characters",
                disable=src.disable,
                constant=src.constant,
                key=list(src.key),
                content=block,
            )
            character_file, notes, action_name = await self._convert_character(
                char_src,
                faction_override=src.name.strip(),
            )
            self._store.save_character(character_file)
            self._remember_mapping(char_src.id, character_file.data.character_id)
            self._converted_characters += 1
            self._bump_category(LoreCategory.CHARACTER)
            split_character_ids.append(character_file.data.character_id)
            self._record_action(
                source_id=char_src.id,
                name=character_file.data.name,
                source_category=src.category,
                action=action_name,
                target_category=LoreCategory.CHARACTER.value,
                created_ids=[character_file.data.character_id],
                notes=[f"Split from faction '{src.name}'.", *notes],
            )

        self._warn(
            src,
            "faction_embedded_characters",
            f"Split {len(character_blocks)} embedded character block(s) from faction entry.",
        )
        self._record_action(
            source_id=src.id,
            name=src.name,
            source_category=src.category,
            action="faction_split_into_characters",
            target_category=LoreCategory.FACTION.value,
            created_ids=[faction_entry.id, *split_character_ids],
            notes=[
                f"Faction entry kept and split into {len(split_character_ids)} character entry(ies).",
                "Character faction fields were set to source faction name.",
            ],
        )

    def _convert_generic_entry(
        self,
        src: SourceEntry,
        *,
        category_override: LoreCategory | None = None,
        content_override: str | None = None,
    ) -> LoreEntry:
        category = category_override or self._map_category(src)
        return LoreEntry(
            id=generate_id(),
            name=src.name.strip() or "unnamed_entry",
            category=category,
            content=content_override if content_override is not None else src.content,
            disabled=src.disable,
            constant=src.constant,
            tags=self._normalize_tags(src.key),
            created_at=self._now,
            updated_at=self._now,
        )

    async def _convert_character(
        self,
        src: SourceEntry,
        faction_override: str | None = None,
    ) -> tuple[CharacterFile, list[str], str]:
        parsed = self._parse_character_yaml(src.content)
        parse_source = "yaml" if parsed is not None else "none"
        llm_attempt_note = ""
        if parsed is None and self.llm_fallback:
            parsed, llm_attempt_note = await self._parse_character_with_llm(src)
            if parsed is not None:
                parse_source = "llm"

        used_keys: set[str] = set()
        action_notes: list[str] = []
        if parse_source == "llm":
            action_name = "character_llm_structured_created"
            action_notes.append("YAML parse failed; structured fields were extracted by LLM fallback.")
        elif parse_source == "yaml":
            action_name = "character_structured_created"
            action_notes.append("Structured fields extracted from YAML content.")
        else:
            action_name = "character_yaml_fallback_created"

        form = self._build_default_form(parsed, used_keys) if parsed else CharacterForm(
            form_id=generate_id(),
            form_name="default",
            is_default=True,
        )

        name = src.name.strip() or "Unnamed character"
        race = "Unknown"
        gender = ""
        strength = 100
        birth = ""
        homeland = ""
        aliases: list[str] = []
        role = ""
        faction = faction_override or ""
        objective = ""
        personality = ""
        relationship: list[Relationship] = []

        if parsed is None:
            form.features = src.content
            self._warn(
                src,
                "yaml_parse_error",
                "YAML parsing failed, raw character content was kept in default form features.",
            )
            action_notes.append("YAML parsing failed, raw content was kept in default form features.")
            if llm_attempt_note:
                action_notes.append(llm_attempt_note)
        else:
            if llm_attempt_note:
                action_notes.append(llm_attempt_note)

            (
                name,
                race,
                gender,
                strength,
                birth,
                homeland,
                aliases,
                role,
                faction_from_yaml,
                objective,
                personality,
                relationship,
                relation_parse_failed,
            ) = self._extract_character_fields(parsed, used_keys, src.name)

            if faction_override:
                faction = faction_override
                action_notes.append(f"faction field was overridden by source faction: {faction_override}")
            else:
                faction = faction_from_yaml

            if relation_parse_failed:
                action_notes.append(
                    "Some relationships could not be fully parsed and were appended to personality."
                )

            remaining_text, remaining_keys = self._collect_remaining(parsed, used_keys)
            if remaining_text:
                if form.features:
                    form.features = f"{form.features}\n\n---\n# Unmapped source content\n{remaining_text}"
                else:
                    form.features = f"---\n# Unmapped source content\n{remaining_text}"
                self._warn(
                    src,
                    "partial_parse",
                    "Some fields were not auto-mapped and were preserved in features: "
                    + ", ".join(remaining_keys),
                )
                action_notes.append(
                    "Unmapped fields were preserved in default form features: "
                    + ", ".join(remaining_keys)
                )
            action_notes.append(f"Parsed relationships: {len(relationship)}")

        # Put strength onto the form instead of CharacterData
        form.strength = strength

        character = CharacterData(
            character_id=generate_id(),
            name=name,
            race=race,
            gender=gender,
            birth=birth,
            homeland=homeland,
            aliases=aliases,
            role=role,
            faction=faction,
            objective=objective,
            personality=personality,
            relationship=relationship,
            memories=[],
            forms=[form],
            active_form_id=form.form_id,
            tags=self._normalize_tags(src.key),
            disabled=src.disable,
            constant=src.constant,
            created_at=self._now,
            updated_at=self._now,
        )
        return CharacterFile(data=character, version=1), action_notes, action_name

    def _parse_character_yaml(self, content: str) -> dict[str, Any] | None:
        cleaned_lines = [
            line for line in content.replace("\r\n", "\n").split("\n")
            if not line.lstrip().startswith("#")
        ]
        cleaned = "\n".join(cleaned_lines).strip()
        if not cleaned:
            return None

        parsed = self._safe_load_yaml(cleaned)
        if isinstance(parsed, dict):
            return parsed

        merged: dict[str, Any] = {}
        for doc in self._safe_load_all_yaml(cleaned):
            if isinstance(doc, dict):
                merged.update(doc)
        return merged or None

    async def _prepare_llm_batch_for_failed_characters(self, entries: list[SourceEntry]) -> None:
        if not self.llm_fallback:
            return
        self._llm_batch_prepared = True

        # Batch mode only activates when multiple character entries fail YAML parsing.
        # Single-entry fallback remains on the existing per-entry LLM path.
        candidates: list[SourceEntry] = []
        for src in entries:
            mapped = self.CATEGORY_MAP.get(src.category.strip().lower())
            if mapped != LoreCategory.CHARACTER:
                continue
            if self._parse_character_yaml(src.content) is None:
                candidates.append(src)

        if len(candidates) <= 1:
            return

        api_config = self._resolve_llm_api_config()
        if api_config is None:
            if self._llm_unavailable_reason and not self._llm_unavailable_reported:
                self._warn(candidates[0], "llm_parse_skipped", self._llm_unavailable_reason)
                self._llm_unavailable_reported = True
            return

        # Bound by (1) prompt-size char budget, and (2) a rough output max_tokens estimate.
        # The prompt instructs a compact schema, so we can safely pack more items and reduce
        # the total request count (mitigates RPM limit errors).
        max_items = self._llm_batch_max_items
        if self._llm_batch_tokens_per_item_estimate > 0:
            max_items = min(
                max_items,
                max(1, api_config.max_tokens // self._llm_batch_tokens_per_item_estimate),
            )

        pending_by_id = {src.id: src for src in candidates}
        for batch in self._iter_llm_character_batches(
            candidates,
            max_items=max_items,
            max_chars=self._llm_batch_max_chars,
        ):
            prompt = self._render_llm_batch_character_prompt(batch)
            batch_ids = {src.id for src in batch}

            try:
                raw = await self._call_llm_for_character_batch(batch, api_config, prompt)
            except Exception as exc:  # pragma: no cover - provider/network guard
                message = f"LLM batch fallback call failed: {exc}"
                for src in batch:
                    self._warn(src, "llm_parse_error", message)
                continue

            payload = self._extract_json_value(raw)
            parsed_by_id = self._normalize_batch_character_results(payload, batch_ids)
            for src_id, parsed in parsed_by_id.items():
                self._llm_batch_cache[src_id] = parsed
                pending_by_id.pop(src_id, None)

            missing = [pending_by_id[src_id] for src_id in batch_ids if src_id in pending_by_id]
            for src in missing:
                self._warn(
                    src,
                    "llm_parse_error",
                    "LLM batch fallback did not return a valid structured object for this character.",
                )

    def _iter_llm_character_batches(
        self,
        candidates: list[SourceEntry],
        *,
        max_items: int,
        max_chars: int,
    ) -> list[list[SourceEntry]]:
        batches: list[list[SourceEntry]] = []
        current: list[SourceEntry] = []
        current_chars = 0

        for src in candidates:
            approx = len(src.id) + len(src.name) + len(src.content) + 128
            exceeds_size = current and (current_chars + approx > max_chars)
            exceeds_count = current and (len(current) >= max_items)
            if exceeds_size or exceeds_count:
                batches.append(current)
                current = []
                current_chars = 0

            current.append(src)
            current_chars += approx

        if current:
            batches.append(current)
        return batches

    def _render_llm_batch_character_prompt(self, batch: list[SourceEntry]) -> str:
        sections: list[str] = []
        for src in batch:
            sections.append(
                "\n".join(
                    [
                        f"SOURCE_ID: {src.id}",
                        f"NAME_HINT: {src.name.strip() or '(unknown)'}",
                        "CONTENT:",
                        src.content,
                    ]
                )
            )

        joined = "\n\n---\n\n".join(sections)
        return (
            "Convert each character lore section into compact structured JSON.\n"
            "Output JSON only. Do not output markdown or extra text.\n"
            "Required schema:\n"
            "{\n"
            '  "items": [\n'
            '    { "source_id": "SOURCE_ID", "parsed": { ...structured fields... } }\n'
            "  ]\n"
            "}\n"
            "Rules:\n"
            "- Use source_id exactly as provided.\n"
            "- parsed must be a JSON object (not a string). Omit unknown fields.\n"
            "- Keep the output compact to reduce token usage (avoid RPM-triggering multi-call batches).\n"
            "- Do NOT include raw content or long narrative blocks; the original content is preserved elsewhere.\n"
            "- Prefer these keys when present (only include if you can extract confidently):\n"
            "  race/species, gender, birth/age, homeland/origin, aliases/nicknames,\n"
            "  identities/identity, faction/organization, objective/goal,\n"
            "  strength/power/combat_power, spirit_level/mana/mana_potency,\n"
            "  relationships/relationship.\n"
            "- Limit each string value to <= 120 characters (summarize if longer).\n"
            "- Limit arrays to <= 10 items.\n"
            "Character sections:\n"
            f"{joined}"
        )

    async def _call_llm_for_character_batch(
        self,
        batch: list[SourceEntry],
        api_config,
        prompt: str,
    ) -> str:
        request_time = self._local_iso()
        started_at = now_local()
        provider_name = api_config.provider.value
        source_ids = [src.id for src in batch]

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
            "stage": "import_character_llm_batch",
            "source_ids": source_ids,
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
            response_time = self._local_iso()
            duration_ms = int((now_local() - started_at).total_seconds() * 1000)
            log_service.add_log(
                LogEntry(
                    id=generate_id(),
                    chat_name=self.session_name,
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
            response_time = self._local_iso()
            duration_ms = int((now_local() - started_at).total_seconds() * 1000)
            log_service.add_log(
                LogEntry(
                    id=generate_id(),
                    chat_name=self.session_name,
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

        response_time = self._local_iso()
        duration_ms = int((now_local() - started_at).total_seconds() * 1000)
        log_service.add_log(
            LogEntry(
                id=generate_id(),
                chat_name=self.session_name,
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

    def _extract_json_value(self, text: str) -> Any | None:
        raw = text.strip()
        if not raw:
            return None

        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass

        decoder = json.JSONDecoder()
        for marker in ("{", "["):
            start = raw.find(marker)
            while start != -1:
                try:
                    parsed, _ = decoder.raw_decode(raw[start:])
                    return parsed
                except json.JSONDecodeError:
                    start = raw.find(marker, start + 1)
        return None

    def _normalize_batch_character_results(
        self,
        payload: Any,
        expected_ids: set[str],
    ) -> dict[str, dict[str, Any]]:
        normalized: dict[str, dict[str, Any]] = {}

        if isinstance(payload, dict):
            items = payload.get("items")
            if isinstance(items, list):
                payload_items = items
            else:
                payload_items = []
                for key, value in payload.items():
                    src_id = str(key).strip()
                    if src_id in expected_ids and isinstance(value, dict):
                        normalized[src_id] = {str(k): v for k, v in value.items()}
                return normalized
        elif isinstance(payload, list):
            payload_items = payload
        else:
            return normalized

        for item in payload_items:
            if not isinstance(item, dict):
                continue
            src_id = str(item.get("source_id") or item.get("id") or "").strip()
            if not src_id or src_id not in expected_ids:
                continue

            parsed = item.get("parsed")
            if not isinstance(parsed, dict):
                for key in ("fields", "data", "result", "output"):
                    candidate = item.get(key)
                    if isinstance(candidate, dict):
                        parsed = candidate
                        break
            if not isinstance(parsed, dict):
                continue

            payload_dict = {str(key): value for key, value in parsed.items()}
            if payload_dict:
                normalized[src_id] = payload_dict
        return normalized

    async def _parse_character_with_llm(self, src: SourceEntry) -> tuple[dict[str, Any] | None, str]:
        cached = self._llm_batch_cache.get(src.id)
        if cached is not None:
            return cached, "LLM batch fallback parsed character content successfully."

        if self._llm_batch_prepared and self._llm_single_fallback_budget <= 0:
            message = (
                "LLM batch fallback did not cover this character and single-entry fallback was "
                "skipped to reduce request count."
            )
            self._warn(src, "llm_parse_skipped", message)
            return None, message

        api_config = self._resolve_llm_api_config()
        if api_config is None:
            note = ""
            if self._llm_unavailable_reason and not self._llm_unavailable_reported:
                self._warn(src, "llm_parse_skipped", self._llm_unavailable_reason)
                self._llm_unavailable_reported = True
                note = self._llm_unavailable_reason
            return None, note

        if self._llm_batch_prepared and self._llm_single_fallback_budget > 0:
            self._llm_single_fallback_budget -= 1

        prompt = self._render_llm_character_prompt(src)
        try:
            raw = await self._call_llm_for_character_yaml(src, api_config, prompt)
        except (ApiConfigNotFoundError, EncryptionError) as exc:
            self._llm_ready = False
            self._llm_unavailable_reason = f"LLM fallback disabled: {exc}"
            self._warn(src, "llm_parse_error", self._llm_unavailable_reason)
            return None, self._llm_unavailable_reason
        except Exception as exc:  # pragma: no cover - provider/network guard
            message = f"LLM fallback call failed: {exc}"
            self._warn(src, "llm_parse_error", message)
            return None, message

        parsed = self._extract_json_object(raw)
        if parsed is None:
            message = "LLM fallback returned non-JSON output."
            self._warn(src, "llm_parse_error", message)
            return None, message

        normalized: dict[str, Any] = {}
        for key, value in parsed.items():
            normalized[str(key)] = value
        if not normalized:
            message = "LLM fallback returned an empty JSON object."
            self._warn(src, "llm_parse_error", message)
            return None, message
        return normalized, "LLM fallback parsed character content successfully."

    def _resolve_llm_api_config(self):
        if not self._llm_ready:
            return None
        if not self.llm_api_config_id:
            self._llm_ready = False
            self._llm_unavailable_reason = "LLM fallback requested but no API config id is available."
            return None
        try:
            return get_api_config_storage(self.llm_api_config_id)
        except ApiConfigNotFoundError:
            self._llm_ready = False
            self._llm_unavailable_reason = (
                f"LLM fallback API config '{self.llm_api_config_id}' was not found."
            )
            return None

    async def _call_llm_for_character_yaml(self, src: SourceEntry, api_config, prompt: str) -> str:
        request_time = self._local_iso()
        started_at = now_local()
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
            "stage": "import_character_llm_fallback",
            "source_id": src.id,
            "source_name": src.name,
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
            response_time = self._local_iso()
            duration_ms = int((now_local() - started_at).total_seconds() * 1000)
            log_service.add_log(
                LogEntry(
                    id=generate_id(),
                    chat_name=self.session_name,
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
            response_time = self._local_iso()
            duration_ms = int((now_local() - started_at).total_seconds() * 1000)
            log_service.add_log(
                LogEntry(
                    id=generate_id(),
                    chat_name=self.session_name,
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

        response_time = self._local_iso()
        duration_ms = int((now_local() - started_at).total_seconds() * 1000)
        log_service.add_log(
            LogEntry(
                id=generate_id(),
                chat_name=self.session_name,
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

    def _render_llm_character_prompt(self, src: SourceEntry) -> str:
        return (
            "Convert the following character lore text into a single JSON object.\n"
            "Output JSON only, with no markdown and no extra text.\n"
            "Try to preserve the source semantics.\n"
            "Prefer keys compatible with this parser when present:\n"
            "name, species, race, strength, power, combat_power, age, birth, gender, homeland, origin, identities, aliases, "
            "nicknames, faction, organization, objective, goal, personality, temperament, "
            "social_deportment, habitual_mannerisms, relationships, relationship, appearance, "
            "physique, overall_impression, facial_features, hair_style, features, clothing, "
            "clothing_style, abilities, growth_experience, experience, key_events, "
            "family_background, hobbies, vocal_characteristics, common_phrases, speech_style, "
            "communication, accessories.\n"
            f"Character name hint: {src.name.strip() or '(unknown)'}\n"
            "Raw content:\n"
            f"{src.content}"
        )

    def _extract_json_object(self, text: str) -> dict[str, Any] | None:
        raw = text.strip()
        if not raw:
            return None
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass

        start = raw.find("{")
        end = raw.rfind("}")
        if start == -1 or end == -1 or end <= start:
            return None
        try:
            parsed = json.loads(raw[start : end + 1])
        except json.JSONDecodeError:
            return None
        return parsed if isinstance(parsed, dict) else None

    # ── Semantic key mapping tables ──────────────────────────────────────
    # Each RST target field maps to a tuple of candidate source keys that
    # will be tried in order (first match wins).  Keys are normalised to
    # lower-case with underscores before lookup, so source YAML like
    # "Growth_Experience", "灵力水平", or "speech style" all match.

    _SEMANTIC_NAME_KEYS = ("name",)
    _SEMANTIC_RACE_KEYS = ("species", "race", "种族")
    _SEMANTIC_GENDER_KEYS = ("gender", "sex", "性别")
    _SEMANTIC_BIRTH_KEYS = ("age", "birth", "年龄", "出生", "诞生")
    _SEMANTIC_HOMELAND_KEYS = ("homeland", "origin", "故乡", "出身地")
    _SEMANTIC_ALIASES_KEYS = ("aliases", "nicknames", "别名", "昵称", "别称")
    _SEMANTIC_IDENTITY_KEYS = ("identities", "identity", "身份")
    _SEMANTIC_FACTION_KEYS = ("faction", "organization", "organisation", "势力", "组织", "阵营")
    _SEMANTIC_OBJECTIVE_KEYS = ("objective", "goal", "目标", "动机", "motivation")

    _SEMANTIC_PERSONALITY_KEYS = (
        "personality", "temperament", "social_deportment", "habitual_mannerisms",
        "性格", "气质", "社交举止", "习惯动作",
        "core", "surface", "inner",
    )
    _SEMANTIC_RELATIONSHIP_KEYS = ("relationships", "relationship", "关系")

    # Form-level semantic keys
    _SEMANTIC_MANA_KEYS = (
        "mana_potency", "mana", "灵力水平", "灵力", "cultivation_base",
        "spirit_level", "修为",
    )
    _SEMANTIC_STRENGTH_KEYS = ("strength", "power", "combat_power", "力量", "物理力量")

    # Keys whose content should be merged into the personality/background block
    _SEMANTIC_BACKGROUND_KEYS = (
        "growth_experience", "experience", "family_background", "key_events",
        "经历", "背景", "成长经历", "家庭背景", "关键事件",
    )
    _SEMANTIC_SPEECH_KEYS = (
        "speech_style", "vocal_characteristics", "common_phrases", "communication",
        "说话方式", "口头禅", "语言风格", "台词",
    )
    _SEMANTIC_HOBBY_KEYS = ("hobbies", "hobby", "爱好", "兴趣")
    _SEMANTIC_ABILITY_KEYS = (
        "abilities", "ability", "skills", "learned_skills", "innate_power",
        "inherit_power", "gifted_power", "refined_skills", "esoteric_items",
        "能力", "技能", "法术", "武功", "overall_summary",
    )

    def _extract_character_fields(
        self,
        parsed: dict[str, Any],
        used_keys: set[str],
        source_name: str,
    ) -> tuple[str, str, str, int, str, str, list[str], str, str, str, str, list[Relationship], list[str]]:
        name = source_name.strip() or self._as_text(self._take_value(parsed, used_keys, *self._SEMANTIC_NAME_KEYS)) or "unnamed_character"
        race = self._as_text(self._take_value(parsed, used_keys, *self._SEMANTIC_RACE_KEYS)) or "unknown"
        gender = self._as_text(self._take_value(parsed, used_keys, *self._SEMANTIC_GENDER_KEYS))
        # strength now goes to form, but we still extract it here for backward compat return
        strength = self._to_non_negative_int(
            self._take_value(parsed, used_keys, *self._SEMANTIC_STRENGTH_KEYS),
            default=100,
        )
        birth = self._as_text(self._take_value(parsed, used_keys, *self._SEMANTIC_BIRTH_KEYS))
        homeland = self._as_text(self._take_value(parsed, used_keys, *self._SEMANTIC_HOMELAND_KEYS))

        aliases_raw = self._take_value(parsed, used_keys, *self._SEMANTIC_ALIASES_KEYS)
        aliases = self._to_string_list(aliases_raw)

        identities = self._take_value(parsed, used_keys, *self._SEMANTIC_IDENTITY_KEYS)
        role = self._join_text(identities)

        faction = self._as_text(self._take_value(parsed, used_keys, *self._SEMANTIC_FACTION_KEYS))
        objective = self._as_text(self._take_value(parsed, used_keys, *self._SEMANTIC_OBJECTIVE_KEYS))

        personality_parts: list[str] = []
        for key in self._SEMANTIC_PERSONALITY_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                personality_parts.append(text)

        # Merge background / experience blocks into personality
        for key in self._SEMANTIC_BACKGROUND_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                personality_parts.append(f"[{key}] {text}")

        # Merge speech / vocal style
        for key in self._SEMANTIC_SPEECH_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                personality_parts.append(f"[{key}] {text}")

        # Merge hobbies
        for key in self._SEMANTIC_HOBBY_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                personality_parts.append(f"[hobbies] {text}")

        relation_raw = self._take_value(parsed, used_keys, *self._SEMANTIC_RELATIONSHIP_KEYS)
        relationships, relation_parse_failed = self._parse_relationships(relation_raw)
        if relation_parse_failed:
            personality_parts.append("Unparsed relationship source: " + "; ".join(relation_parse_failed))

        personality = "\n".join(part for part in personality_parts if part).strip()
        return (
            name,
            race,
            gender,
            strength,
            birth,
            homeland,
            aliases,
            role,
            faction,
            objective,
            personality,
            relationships,
            relation_parse_failed,
        )

    _SEMANTIC_APPEARANCE_KEYS = (
        "overall_impression", "physique", "facial_features", "hair_style",
        "appearance", "外貌", "容貌", "体型", "面部特征", "发型",
        "human_physique", "loong_physique", "human_facial_features",
        "phys", "body_shape", "face_shape", "skin_tone", "eyes", "nose", "lips",
    )
    _SEMANTIC_FEATURES_KEYS = ("features", "特征", "特点")
    _SEMANTIC_CLOTHING_KEYS = (
        "clothing", "clothing_style", "服装", "衣着", "穿着", "accessories", "饰品",
    )

    def _build_default_form(self, parsed: dict[str, Any], used_keys: set[str]) -> CharacterForm:
        form = CharacterForm(
            form_id=generate_id(),
            form_name="default",
            is_default=True,
        )
        form.physique = self._merge_appearance(parsed, used_keys)

        features_parts: list[str] = []
        for key in self._SEMANTIC_FEATURES_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                features_parts.append(text)

        # Merge abilities into features
        for key in self._SEMANTIC_ABILITY_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                features_parts.append(f"[{key}] {text}")

        if features_parts:
            form.features = "\n".join(features_parts)

        clothing_parts: list[str] = []
        for key in self._SEMANTIC_CLOTHING_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                clothing_parts.append(text)
        if clothing_parts:
            form.clothing = "\n".join(clothing_parts)

        # Extract mana_potency from semantic keys
        mana_raw = self._take_value(parsed, used_keys, *self._SEMANTIC_MANA_KEYS)
        if mana_raw is not None:
            mana_value = self._parse_mana_value(mana_raw)
            if mana_value > 0:
                form.mana_potency = mana_value

        return form

    def _parse_mana_value(self, raw: Any) -> int:
        """Parse mana/灵力水平 values like '10k', '14k', 300, '灵力水平: 12k'."""
        if raw is None:
            return 0
        if isinstance(raw, (int, float)) and not isinstance(raw, bool):
            return max(0, int(raw))
        text = self._flatten_yaml_value(raw).strip().lower()
        if not text:
            return 0
        # Try to find a numeric pattern like "14k", "10000", "300k+"
        import re as _re
        match = _re.search(r'(\d+(?:\.\d+)?)\s*k', text)
        if match:
            return max(0, int(float(match.group(1)) * 1000))
        match = _re.search(r'(\d+)', text)
        if match:
            return max(0, int(match.group(1)))
        return 0

    def _parse_relationships(self, raw: Any) -> tuple[list[Relationship], list[str]]:
        if raw is None:
            return [], []

        relationships: list[Relationship] = []
        parse_failed: list[str] = []

        def add_pair(target: str, relation: Any) -> None:
            target_text = target.strip()
            if not target_text:
                return
            relation_text = self._as_text(relation)
            relationships.append(Relationship(target=target_text, relation=relation_text))

        def parse_text(text: str) -> bool:
            lines = [line.strip() for line in text.splitlines() if line.strip()]
            candidates = lines if lines else [text.strip()]
            parsed_any = False
            for content in candidates:
                if not content:
                    continue
                if "：" in content:
                    left, right = content.split("：", 1)
                    add_pair(left, right)
                    parsed_any = True
                    continue
                if ":" in content:
                    left, right = content.split(":", 1)
                    add_pair(left, right)
                    parsed_any = True
            return parsed_any

        if isinstance(raw, dict):
            for key, value in raw.items():
                add_pair(self._as_text(key), value)
            return relationships, parse_failed

        if isinstance(raw, list):
            for item in raw:
                if isinstance(item, dict):
                    for key, value in item.items():
                        add_pair(self._as_text(key), value)
                    continue
                text = self._as_text(item)
                if not parse_text(text):
                    parse_failed.append(text)
            return relationships, parse_failed

        text = self._as_text(raw)
        if not parse_text(text):
            parse_failed.append(text)
        return relationships, parse_failed

    def _flatten_yaml_value(self, value: Any, indent: int = 0) -> str:
        if value is None:
            return ""
        if isinstance(value, str):
            return value.strip()
        if isinstance(value, list):
            parts = [self._flatten_yaml_value(item, indent) for item in value]
            return "; ".join(part for part in parts if part)
        if isinstance(value, dict):
            lines: list[str] = []
            for key, nested in value.items():
                flat_nested = self._flatten_yaml_value(nested, indent + 1)
                if not flat_nested:
                    continue
                lines.append(f"{'  ' * indent}{key}: {flat_nested}")
            return "\n".join(lines)
        return str(value)

    def _merge_appearance(self, parsed: dict[str, Any], used_keys: set[str]) -> str:
        merged: list[str] = []
        for key in self._SEMANTIC_APPEARANCE_KEYS:
            value = self._take_value(parsed, used_keys, key)
            text = self._flatten_yaml_value(value) if value is not None else ""
            if text:
                merged.append(f"[{key}] {text}")
        return "\n".join(merged)

    def _collect_remaining(
        self,
        parsed: dict[str, Any],
        used_keys: set[str],
    ) -> tuple[str, list[str]]:
        remaining: dict[str, Any] = {}
        for key, value in parsed.items():
            normalized = self._normalize_key(self._as_text(key))
            if normalized in used_keys:
                continue
            remaining[self._as_text(key)] = value

        if not remaining:
            return "", []

        text = yaml.safe_dump(
            remaining,
            allow_unicode=True,
            sort_keys=False,
        ).strip()
        return text, list(remaining.keys())

    def _take_value(
        self,
        parsed: dict[str, Any],
        used_keys: set[str],
        *candidate_keys: str,
    ) -> Any | None:
        normalized_candidates = {self._normalize_key(key) for key in candidate_keys}
        for key, value in parsed.items():
            normalized = self._normalize_key(self._as_text(key))
            if normalized not in normalized_candidates:
                continue
            used_keys.add(normalized)
            return value
        return None

    def _split_faction_content(self, content: str) -> tuple[str, list[str]]:
        matches = list(self._name_block_pattern.finditer(content))
        if len(matches) <= 1:
            return content.strip(), []

        overview = content[:matches[0].start()].strip()
        blocks: list[str] = []
        for index, match in enumerate(matches):
            start = match.start()
            end = matches[index + 1].start() if index + 1 < len(matches) else len(content)
            block = content[start:end].strip()
            if block:
                blocks.append(block)
        return overview, blocks

    def _extract_block_name(self, block: str) -> str:
        match = re.search(r"(?im)^\s*name\s*:\s*(.+)$", block)
        if not match:
            return ""
        return match.group(1).strip().strip("'\"")

    def _normalize_tags(self, tags: list[str]) -> list[str]:
        deduped: list[str] = []
        seen: set[str] = set()
        for raw in tags:
            tag = raw.strip()
            if not tag or tag in seen:
                continue
            seen.add(tag)
            deduped.append(tag)
        return deduped

    def _join_text(self, value: Any) -> str:
        if value is None:
            return ""
        if isinstance(value, list):
            parts = [self._as_text(item).strip() for item in value]
            return "; ".join(part for part in parts if part)
        return self._as_text(value).strip()

    def _to_string_list(self, value: Any) -> list[str]:
        if value is None:
            return []
        if isinstance(value, list):
            items = [self._as_text(item).strip() for item in value]
            return [item for item in items if item]
        text = self._as_text(value).strip()
        return [text] if text else []

    def _to_non_negative_int(self, value: Any, default: int = 0) -> int:
        if value is None:
            return default
        if isinstance(value, bool):
            return default
        if isinstance(value, int):
            return value if value >= 0 else default
        try:
            parsed = int(float(self._as_text(value).strip()))
        except (TypeError, ValueError):
            return default
        return parsed if parsed >= 0 else default

    def _as_text(self, value: Any) -> str:
        if value is None:
            return ""
        if isinstance(value, str):
            return value
        return str(value)

    def _normalize_key(self, key: str) -> str:
        return key.strip().lower().replace("-", "_").replace(" ", "_")

    def _warn(self, src: SourceEntry, warning_type: str, message: str) -> None:
        self._warnings.append(
            ConversionWarning(
                source_id=src.id,
                name=src.name,
                type=warning_type,
                message=message,
            )
        )

    def _record_action(
        self,
        *,
        source_id: str,
        name: str,
        source_category: str,
        action: str,
        target_category: str | None = None,
        created_ids: list[str] | None = None,
        notes: list[str] | None = None,
        warnings: list[str] | None = None,
        errors: list[str] | None = None,
    ) -> None:
        self._actions.append(
            ConversionAction(
                source_id=source_id,
                name=name,
                source_category=source_category,
                action=action,
                target_category=target_category,
                created_ids=created_ids or [],
                notes=notes or [],
                warnings=warnings or [],
                errors=errors or [],
            )
        )

    def _attach_action_warnings(self) -> None:
        warning_map: dict[str, list[str]] = {}
        for warning in self._warnings:
            warning_map.setdefault(warning.source_id, []).append(
                f"[{warning.type}] {warning.message}"
            )
        for action in self._actions:
            linked = warning_map.get(action.source_id, [])
            if not linked:
                continue
            merged = [*action.warnings]
            for item in linked:
                if item not in merged:
                    merged.append(item)
            action.warnings = merged

    def _bump_category(self, category: LoreCategory) -> None:
        key = category.value
        self._category_summary[key] = self._category_summary.get(key, 0) + 1

    def _remember_mapping(self, source_id: str, target_id: str) -> None:
        key = source_id.strip()
        if not key:
            return
        self._id_mapping[key] = target_id

    def _iso_timestamp(self) -> str:
        return self._now.replace(microsecond=0).isoformat()

    def _safe_load_yaml(self, text: str) -> Any:
        try:
            return yaml.safe_load(text)
        except yaml.YAMLError:
            return None

    def _safe_load_all_yaml(self, text: str) -> list[Any]:
        try:
            return list(yaml.safe_load_all(text))
        except yaml.YAMLError:
            return []


__all__ = ["LoreConverter"]
