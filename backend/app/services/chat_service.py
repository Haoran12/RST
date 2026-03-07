from __future__ import annotations

import asyncio
import hashlib
import os
from time import perf_counter
from typing import Any

from app.models import generate_id
from app.models.api_config import ProviderType
from app.models.chat import (
    ChatRequest,
    ChatResponse,
    PromptPreviewRequest,
    PromptPreviewResponse,
    PromptPreviewStage,
)
from app.models.lore import CharacterData, LoreCategory, LoreEntry
from app.models.log import LogEntry
from app.models.session import ChatAttachment, Message
from app.providers.base import ProviderError
from app.providers.registry import get_provider
from app.services.api_config_service import ApiConfigNotFoundError, get_api_config_storage
from app.services.lore_date import (
    FantasyDate,
    compute_age_at,
    extract_scene_date,
    is_birthday_today,
    parse_fantasy_date,
)
from app.services.lore_scheduler import lore_scheduler
from app.services.lore_updater import lore_updater
from app.services.preset_service import PresetNotFoundError, get_preset_storage
from app.services.prompt_assembler import PromptAssembler
from app.services.rst_runtime_service import rst_runtime_service
from app.services.scene_service import scene_service
from app.services.session_service import (
    SessionNotFoundError,
    get_session_dir,
    get_session_storage,
    touch_session,
)
from app.services.log_service import log_service
from app.storage.encryption import EncryptionError, decrypt_api_key
from app.storage.lore_store import LoreStore
from app.storage.message_store import MessageStore
from app.time_utils import now_local, now_local_iso


class ChatConfigError(RuntimeError):
    pass


DYNAMIC_PRESET_ENTRY_NAMES: set[str] = {
    "chat_history",
    "user_input",
    "lores",
    "scene",
    "user_description",
}


def _local_iso() -> str:
    return now_local_iso()


def _env_enabled(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _to_int(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    return None


def _format_attachments(attachments: list[ChatAttachment]) -> str:
    lines: list[str] = []
    for attachment in attachments:
        header = f"- {attachment.name} ({attachment.type}, {attachment.size} bytes)"
        lines.append(header)
        if attachment.content:
            lines.append(attachment.content)
    return "\n".join(lines)


def _compose_user_input(content: str, attachments: list[ChatAttachment] | None) -> str:
    if not attachments:
        return content
    block = _format_attachments(attachments)
    return f"{content}\n\n[Attachments]\n{block}"


def _load_history(store: MessageStore, mem_length: int) -> list[Message]:
    if mem_length == 0:
        return []
    if mem_length < 0:
        return store.load_all()
    return store.load_recent(mem_length)


def _build_openai_main_cache_options(
    *,
    preset_id: str,
    preset_version: int,
    preset_entries: list[Any],
    model: str,
) -> dict[str, Any] | None:
    if not _env_enabled("RST_OPENAI_PROMPT_CACHE_ENABLED", True):
        return None

    stable_chunks: list[str] = []
    for entry in preset_entries:
        if bool(getattr(entry, "disabled", False)):
            continue
        name = str(getattr(entry, "name", ""))
        if name in DYNAMIC_PRESET_ENTRY_NAMES:
            continue
        content = str(getattr(entry, "content", "")).strip()
        if not content:
            continue
        role = str(getattr(entry, "role", "system"))
        stable_chunks.append(f"{role}\n{name}\n{content}")

    if not stable_chunks:
        return None

    digest = hashlib.sha256("\n\n".join(stable_chunks).encode("utf-8")).hexdigest()[:24]
    cache_key = f"rstv2:preset:{preset_id}:v{preset_version}:m:{model}:{digest}"
    options: dict[str, Any] = {"prompt_cache_key": cache_key}

    retention = os.getenv("RST_OPENAI_PROMPT_CACHE_RETENTION", "24h").strip()
    if retention:
        options["prompt_cache_retention"] = retention
    return options


def _render_character_for_st_mode(
    character: CharacterData,
    scene_date: FantasyDate | None,
) -> str:
    active_form = next(
        (form for form in character.forms if form.form_id == character.active_form_id),
        character.forms[0] if character.forms else None,
    )
    lines = [
        f"# Character: {character.name}",
        f"race: {character.race}",
        f"gender: {character.gender}",
        f"birth: {character.birth}",
        f"role: {character.role}",
        f"faction: {character.faction}",
        f"objective: {character.objective}",
        f"personality: {character.personality}",
    ]
    birth_date = parse_fantasy_date(character.birth)
    if birth_date is not None and scene_date is not None:
        lines.append(f"age: {compute_age_at(birth_date, scene_date)}")
        lines.append(
            "birthday_today: "
            f"{'yes' if is_birthday_today(birth_date, scene_date) else 'no'}"
        )
    if active_form is not None:
        lines.extend(
            [
                f"activity: {active_form.activity}",
                f"body: {active_form.body}",
                f"mind: {active_form.mind}",
            ]
        )
    return "\n".join(line for line in lines if line.split(":", 1)[-1].strip())


def st_mode_inject(entries: list[LoreEntry | CharacterData], messages: list[Message]) -> str:
    """
    ST mode: inject constant entries and keyword-matched entries without scheduler LLM.
    """
    visible_messages = [msg for msg in messages if msg.visible]
    context = "\n".join(msg.content for msg in visible_messages).lower()
    scene_text = "\n".join(msg.content for msg in visible_messages)
    scene_date = extract_scene_date(scene_text)
    if not context and not entries:
        return ""

    selected_blocks: list[str] = []
    seen: set[str] = set()

    for entry in entries:
        if isinstance(entry, LoreEntry):
            if entry.category in {LoreCategory.PLOT, LoreCategory.MEMORY}:
                continue
            if entry.disabled:
                continue
            text = entry.content.strip()
            if not text:
                continue
            matched = False
            if entry.constant:
                matched = True
            else:
                keywords = [entry.name, *entry.tags]
                matched = any(keyword.strip().lower() in context for keyword in keywords if keyword.strip())
            if matched and entry.id not in seen:
                seen.add(entry.id)
                selected_blocks.append(text)
            continue

        if entry.disabled:
            continue
        matched = False
        if entry.constant:
            matched = True
        else:
            keywords = [entry.name, *entry.aliases, *entry.tags]
            matched = any(keyword.strip().lower() in context for keyword in keywords if keyword.strip())
        if matched and entry.character_id not in seen:
            seen.add(entry.character_id)
            selected_blocks.append(_render_character_for_st_mode(entry, scene_date))

    return "\n\n".join(block for block in selected_blocks if block.strip())


def _extract_usage(raw_response: Any) -> tuple[int | None, int | None, int | None]:
    if not isinstance(raw_response, dict):
        return None, None, None

    usage = raw_response.get("usage")
    if isinstance(usage, dict):
        prompt_tokens = _to_int(usage.get("prompt_tokens") or usage.get("input_tokens"))
        completion_tokens = _to_int(
            usage.get("completion_tokens") or usage.get("output_tokens")
        )
        total_tokens = _to_int(usage.get("total_tokens"))
        if total_tokens is None and prompt_tokens is not None and completion_tokens is not None:
            total_tokens = prompt_tokens + completion_tokens
        return prompt_tokens, completion_tokens, total_tokens

    usage_metadata = raw_response.get("usageMetadata")
    if isinstance(usage_metadata, dict):
        prompt_tokens = _to_int(usage_metadata.get("promptTokenCount"))
        completion_tokens = _to_int(
            usage_metadata.get("candidatesTokenCount")
            or usage_metadata.get("outputTokenCount")
        )
        total_tokens = _to_int(usage_metadata.get("totalTokenCount"))
        if total_tokens is None and prompt_tokens is not None and completion_tokens is not None:
            total_tokens = prompt_tokens + completion_tokens
        return prompt_tokens, completion_tokens, total_tokens

    return None, None, None


def _extract_stop_reason(raw_response: Any) -> str | None:
    if not isinstance(raw_response, dict):
        return None

    stop_reason = raw_response.get("stop_reason")
    if isinstance(stop_reason, str) and stop_reason:
        return stop_reason

    choices = raw_response.get("choices")
    if isinstance(choices, list) and choices and isinstance(choices[0], dict):
        finish_reason = choices[0].get("finish_reason")
        if isinstance(finish_reason, str) and finish_reason:
            return finish_reason

    candidates = raw_response.get("candidates")
    if isinstance(candidates, list) and candidates and isinstance(candidates[0], dict):
        finish_reason = candidates[0].get("finishReason")
        if isinstance(finish_reason, str) and finish_reason:
            return finish_reason

    return None


def _build_log_request(
    *,
    provider: str,
    base_url: str,
    model: str,
    temperature: float,
    max_tokens: int,
    stream: bool,
    prompt_messages: list[dict],
    provider_request: dict[str, Any] | None,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "provider": provider,
        "base_url": base_url,
        "model": model,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": stream,
        "prompt_messages": prompt_messages,
    }
    if provider_request is not None:
        request["provider_request"] = provider_request
    return request


def _render_prompt_messages_text(prompt_messages: list[dict[str, Any]]) -> str:
    chunks: list[str] = []
    for msg in prompt_messages:
        role = str(msg.get("role", "user")).upper()
        content = str(msg.get("content", ""))
        chunks.append(f"[{role}]\n{content}")
    return "\n\n".join(chunks)


def _preview_schedule_messages(
    store: MessageStore,
    scan_depth: int,
    payload: PromptPreviewRequest,
    has_explicit_input: bool,
) -> list[Message]:
    schedule_messages = _load_history(store, scan_depth)
    if not has_explicit_input:
        return schedule_messages
    schedule_messages.append(
        Message(
            id=payload.message_id or generate_id(),
            role="user",
            content=payload.content,
            timestamp=now_local(),
            visible=True,
            attachments=payload.attachments,
        )
    )
    return schedule_messages


async def preview_chat_prompts(
    session_name: str,
    payload: PromptPreviewRequest,
) -> PromptPreviewResponse:
    session = get_session_storage(session_name)
    preset = get_preset_storage(session.preset_id)
    store = MessageStore(get_session_dir(session_name))

    history = _load_history(store, session.mem_length)
    has_explicit_input = bool(payload.content.strip()) or bool(payload.attachments)
    prompt_history = history

    if has_explicit_input:
        user_input = _compose_user_input(payload.content, payload.attachments)
    else:
        latest_visible = store.find_latest_visible()
        if latest_visible is not None and latest_visible.role == "user":
            user_input = _compose_user_input(
                latest_visible.content,
                latest_visible.attachments,
            )
            prompt_history = [msg for msg in history if msg.id != latest_visible.id]
        else:
            user_input = "continue"

    stages: list[PromptPreviewStage] = []
    lores_block = ""
    schedule_messages = _preview_schedule_messages(
        store,
        session.scan_depth,
        payload,
        has_explicit_input,
    )

    if session.mode == "RST" and session.scheduler_api_config_id:
        confirm_prompt, matched_ids, confirm_notes = lore_scheduler.preview_confirm_prompt(
            session_name=session_name,
            messages=schedule_messages,
            scan_depth=session.scan_depth,
            user_input=user_input,
            has_explicit_input=has_explicit_input,
        )
        if confirm_prompt:
            stages.append(
                PromptPreviewStage(
                    stage="scheduler_confirm",
                    label="Scheduler Confirm",
                    prompt=confirm_prompt,
                    prompt_length=len(confirm_prompt),
                    notes=confirm_notes,
                    meta={
                        "matched_count": len(matched_ids),
                        "has_explicit_input": has_explicit_input,
                    },
                )
            )
        else:
            stages.append(
                PromptPreviewStage(
                    stage="scheduler_confirm",
                    label="Scheduler Confirm",
                    prompt="",
                    prompt_length=0,
                    notes=confirm_notes or ["No scheduler confirm prompt generated."],
                    meta={
                        "matched_count": len(matched_ids),
                        "has_explicit_input": has_explicit_input,
                    },
                )
            )

        extract_prompt, extract_notes = lore_updater.preview_extract_prompt(
            session_name=session_name,
            messages=schedule_messages,
            scan_depth=session.scan_depth,
        )
        stages.append(
            PromptPreviewStage(
                stage="scheduler_extract",
                label="Scheduler Extract",
                prompt=extract_prompt,
                prompt_length=len(extract_prompt),
                notes=extract_notes,
                meta={},
            )
        )

        consolidate_previews = lore_updater.preview_consolidate_prompts(
            session_name=session_name,
            max_items=max(0, payload.max_consolidate_prompts),
        )
        if not consolidate_previews:
            stages.append(
                PromptPreviewStage(
                    stage="scheduler_consolidate",
                    label="Scheduler Consolidate",
                    prompt="",
                    prompt_length=0,
                    notes=["No character currently exceeds memory consolidation threshold."],
                    meta={},
                )
            )
        else:
            for item in consolidate_previews:
                prompt = str(item.get("prompt", ""))
                stages.append(
                    PromptPreviewStage(
                        stage=f"scheduler_consolidate:{item.get('character_id', '')}",
                        label=f"Scheduler Consolidate ({item.get('character_name', '-')})",
                        prompt=prompt,
                        prompt_length=len(prompt),
                        notes=[],
                        meta={
                            "character_id": item.get("character_id", ""),
                            "memory_total": int(item.get("memory_total", 0)),
                            "candidate_count": int(item.get("candidate_count", 0)),
                        },
                    )
                )

        # Main prompt in RST depends on scheduler LLM output (injection block), which is unknown in preview.
        # Use last injection snapshot to make this stage inspectable while keeping the caveat explicit.
        state = rst_runtime_service.get_session_state(session_name)
        lores_block = str(state.get("last_injection_block", "") or "")
    elif session.mode == "ST":
        st_messages = _load_history(store, session.scan_depth)
        lores_block = st_mode_inject(LoreStore(get_session_dir(session_name)).load_all_entries(), st_messages)

    scene_block = ""
    if session.mode == "RST":
        scene_state = scene_service.load_scene_state(session_name)
        scene_block = scene_service.render_scene_prompt(scene_state)

    assembler = PromptAssembler()
    main_prompt_messages = assembler.build(
        session=session,
        preset=preset,
        messages=prompt_history,
        lores_block=lores_block,
        scene_block=scene_block,
        user_input=user_input,
    )
    main_notes: list[str] = []
    if session.mode == "RST" and session.scheduler_api_config_id:
        main_notes.append(
            "RST main prompt uses scheduler injection block from an LLM call at send time. "
            "Preview uses last_injection_block snapshot."
        )
    stages.insert(
        0,
        PromptPreviewStage(
            stage="main_chat",
            label="Main Chat",
            prompt=_render_prompt_messages_text(main_prompt_messages),
            prompt_length=sum(len(str(item.get("content", ""))) for item in main_prompt_messages),
            notes=main_notes,
            meta={"message_count": len(main_prompt_messages)},
        ),
    )

    return PromptPreviewResponse(
        mode=session.mode,
        has_explicit_input=has_explicit_input,
        user_input=user_input,
        stages=stages,
    )


async def run_chat(session_name: str, payload: ChatRequest) -> ChatResponse:
    session = get_session_storage(session_name)
    if session.is_closed:
        raise ChatConfigError("Session is closed")
    preset = get_preset_storage(session.preset_id)
    api_config = get_api_config_storage(session.main_api_config_id)

    if not api_config.model:
        raise ChatConfigError("Model is required for chat")

    api_key = decrypt_api_key(api_config.encrypted_key)
    provider = get_provider(api_config.provider)
    store = MessageStore(get_session_dir(session_name))

    has_explicit_input = bool(payload.content.strip()) or bool(payload.attachments)
    prompt_history: list[Message]
    user_message: Message | None = None

    if payload.regenerate:
        if has_explicit_input:
            raise ChatConfigError("Regenerate request does not accept content or attachments")
        latest_messages = store.load_recent(1)
        latest_message = latest_messages[0] if latest_messages else None
        if latest_message is None or latest_message.role != "assistant":
            raise ChatConfigError("Regenerate requires latest message to be assistant")
        if not store.delete_message(latest_message.id):
            raise ChatConfigError("Failed to delete latest assistant message")
        touch_session(session_name)

        history = _load_history(store, session.mem_length)
        prompt_history = history
        previous_messages = store.load_recent(1)
        previous_message = previous_messages[0] if previous_messages else None
        if previous_message is not None and previous_message.role == "user":
            user_input = _compose_user_input(
                previous_message.content,
                previous_message.attachments,
            )
            prompt_history = [msg for msg in history if msg.id != previous_message.id]
        else:
            user_input = "continue"
    else:
        history = _load_history(store, session.mem_length)
        prompt_history = history
        if has_explicit_input:
            user_input = _compose_user_input(payload.content, payload.attachments)
            user_message = Message(
                id=payload.message_id or generate_id(),
                role="user",
                content=payload.content,
                timestamp=now_local(),
                visible=True,
                attachments=payload.attachments,
            )
            store.append(user_message)
            touch_session(session_name)
        else:
            latest_visible = store.find_latest_visible()
            if latest_visible is not None and latest_visible.role == "user":
                user_input = _compose_user_input(
                    latest_visible.content,
                    latest_visible.attachments,
                )
                prompt_history = [msg for msg in history if msg.id != latest_visible.id]
            else:
                user_input = "continue"

    lores_block = ""
    if session.mode == "RST" and session.scheduler_api_config_id:
        if payload.regenerate:
            state = rst_runtime_service.get_session_state(session_name)
            lores_block = str(state.get("last_injection_block", "") or "")
        else:
            schedule_messages = _load_history(store, session.scan_depth)
            try:
                if has_explicit_input:
                    lores_block = await lore_scheduler.full_schedule(
                        session_name=session_name,
                        messages=schedule_messages,
                        scan_depth=session.scan_depth,
                        user_input=user_input,
                        scheduler_api_config_id=session.scheduler_api_config_id,
                    )
                else:
                    lores_block = await lore_scheduler.full_schedule_from_cache(
                        session_name=session_name,
                        scheduler_api_config_id=session.scheduler_api_config_id,
                    )
            except Exception:
                lores_block = ""
    elif session.mode == "ST":
        lore_store = LoreStore(get_session_dir(session_name))
        st_messages = _load_history(store, session.scan_depth)
        lores_block = st_mode_inject(lore_store.load_all_entries(), st_messages)

    scene_block = ""
    if session.mode == "RST":
        scene_state = scene_service.load_scene_state(session_name)
        scene_block = scene_service.render_scene_prompt(scene_state)

    assembler = PromptAssembler()
    prompt_messages = assembler.build(
        session=session,
        preset=preset,
        messages=prompt_history,
        lores_block=lores_block,
        scene_block=scene_block,
        user_input=user_input,
    )

    request_time = _local_iso()
    provider_name = api_config.provider.value
    cache_options: dict[str, Any] | None = None
    if api_config.provider in {ProviderType.OPENAI, ProviderType.OPENAI_COMPAT}:
        cache_options = _build_openai_main_cache_options(
            preset_id=preset.id,
            preset_version=preset.version,
            preset_entries=preset.entries,
            model=api_config.model,
        )
    started_at = perf_counter()
    rst_runtime_service.update_session_state(
        session_name,
        mode=session.mode,
        status="running",
        last_request_at=request_time,
        last_user_input_length=len(user_input),
        last_prompt_size=len(prompt_messages),
    )

    try:
        provider_result = await provider.chat(
            api_config.base_url,
            api_key,
            messages=prompt_messages,
            model=api_config.model,
            temperature=api_config.temperature,
            max_tokens=api_config.max_tokens,
            stream=api_config.stream,
            cache_options=cache_options,
        )
    except ProviderError as exc:
        response_time = _local_iso()
        duration_ms = int((perf_counter() - started_at) * 1000)
        raw_request = _build_log_request(
            provider=provider_name,
            base_url=api_config.base_url,
            model=api_config.model,
            temperature=api_config.temperature,
            max_tokens=api_config.max_tokens,
            stream=api_config.stream,
            prompt_messages=prompt_messages,
            provider_request=exc.request,
        )
        raw_response = {
            "error": str(exc),
            "status_code": exc.status_code,
            "provider_response": exc.response,
        }
        prompt_tokens, completion_tokens, total_tokens = _extract_usage(exc.response)
        stop_reason = _extract_stop_reason(exc.response)
        log_service.add_log(
            LogEntry(
                id=generate_id(),
                chat_name=session_name,
                request_source="main",
                provider=provider_name,
                model=api_config.model,
                status="error",
                request_time=request_time,
                response_time=response_time,
                duration_ms=duration_ms,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_tokens=total_tokens,
                stop_reason=stop_reason,
                raw_request=raw_request,
                raw_response=raw_response,
            )
        )
        rst_runtime_service.update_session_state(
            session_name,
            status="error",
            last_response_at=response_time,
        )
        raise
    except asyncio.CancelledError:
        rst_runtime_service.update_session_state(
            session_name,
            status="cancelled",
        )
        raise

    assistant_text = provider_result.text
    raw_response = provider_result.response
    assistant_message = Message(
        id=generate_id(),
        role="assistant",
        content=assistant_text,
        timestamp=now_local(),
        visible=True,
    )
    store.append(assistant_message)
    touch_session(session_name)
    if session.mode == "RST":
        parsed_scene = scene_service.parse_scene_tag(assistant_text)
        if parsed_scene is not None:
            previous_scene = scene_service.load_scene_state(session_name)
            merged_scene = scene_service.merge_scene_state(previous_scene, parsed_scene)
            merged_scene.updated_at = _local_iso()
            scene_service.save_scene_state(session_name, merged_scene)

    response_time = _local_iso()
    duration_ms = int((perf_counter() - started_at) * 1000)
    prompt_tokens, completion_tokens, total_tokens = _extract_usage(raw_response)
    stop_reason = _extract_stop_reason(raw_response)
    raw_request = _build_log_request(
        provider=provider_name,
        base_url=api_config.base_url,
        model=api_config.model,
        temperature=api_config.temperature,
        max_tokens=api_config.max_tokens,
        stream=api_config.stream,
        prompt_messages=prompt_messages,
        provider_request=provider_result.request,
    )

    log_service.add_log(
        LogEntry(
            id=generate_id(),
            chat_name=session_name,
            request_source="main",
            provider=provider_name,
            model=api_config.model,
            status="success",
            request_time=request_time,
            response_time=response_time,
            duration_ms=duration_ms,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=total_tokens,
            stop_reason=stop_reason,
            raw_request=raw_request,
            raw_response=raw_response,
        )
    )
    rst_runtime_service.update_session_state(
        session_name,
        status="idle",
        last_response_at=response_time,
        last_response_length=len(assistant_text),
    )

    if session.mode == "RST" and session.scheduler_api_config_id:
        recent_messages = _load_history(store, session.scan_depth)

        async def _safe_pre_retrieve() -> None:
            try:
                await lore_scheduler.pre_retrieve(
                    session_name=session_name,
                    messages=recent_messages,
                    scan_depth=session.scan_depth,
                )
            except Exception:
                return

        pre_retrieve_task = asyncio.create_task(_safe_pre_retrieve())
        rst_runtime_service.register_task(session_name, pre_retrieve_task)

        state = rst_runtime_service.get_session_state(session_name)
        rounds = int(state.get("rounds_since_sync", 0))
        if not payload.regenerate:
            rounds += 1

        if not payload.regenerate and rounds >= session.lore_sync_interval:

            async def _safe_sync() -> None:
                try:
                    await lore_updater.sync_from_conversation(
                        session_name=session_name,
                        messages=recent_messages,
                        scan_depth=session.scan_depth,
                        scheduler_api_config_id=session.scheduler_api_config_id or "",
                    )
                except Exception:
                    return

            sync_task = asyncio.create_task(_safe_sync())
            rst_runtime_service.register_task(session_name, sync_task)
            rounds = 0

        rst_runtime_service.update_session_state(
            session_name,
            rounds_since_sync=rounds,
            sync_interval=session.lore_sync_interval,
        )

    return ChatResponse(user_message=user_message, assistant_message=assistant_message)


__all__ = [
    "ChatConfigError",
    "ProviderError",
    "ApiConfigNotFoundError",
    "PresetNotFoundError",
    "SessionNotFoundError",
    "EncryptionError",
    "st_mode_inject",
    "run_chat",
]
