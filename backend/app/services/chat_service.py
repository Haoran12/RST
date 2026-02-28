from __future__ import annotations

import asyncio
from datetime import datetime
from time import perf_counter
from typing import Any

from app.models import generate_id
from app.models.chat import ChatRequest, ChatResponse
from app.models.lore import CharacterData, LoreCategory, LoreEntry
from app.models.log import LogEntry
from app.models.session import ChatAttachment, Message
from app.providers.base import ProviderError
from app.providers.registry import get_provider
from app.services.api_config_service import ApiConfigNotFoundError, get_api_config_storage
from app.services.lore_scheduler import lore_scheduler
from app.services.lore_updater import lore_updater
from app.services.preset_service import PresetNotFoundError, get_preset_storage
from app.services.prompt_assembler import PromptAssembler
from app.services.rst_runtime_service import rst_runtime_service
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


class ChatConfigError(RuntimeError):
    pass


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


def _render_character_for_st_mode(character: CharacterData) -> str:
    active_form = next(
        (form for form in character.forms if form.form_id == character.active_form_id),
        character.forms[0] if character.forms else None,
    )
    lines = [
        f"# Character: {character.name}",
        f"race: {character.race}",
        f"role: {character.role}",
        f"faction: {character.faction}",
        f"objective: {character.objective}",
        f"personality: {character.personality}",
    ]
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
            selected_blocks.append(_render_character_for_st_mode(entry))

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

    history = _load_history(store, session.mem_length)
    has_explicit_input = bool(payload.content.strip()) or bool(payload.attachments)
    prompt_history = history
    user_message: Message | None = None

    if has_explicit_input:
        user_input = _compose_user_input(payload.content, payload.attachments)
        user_message = Message(
            id=payload.message_id or generate_id(),
            role="user",
            content=payload.content,
            timestamp=datetime.utcnow(),
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

    assembler = PromptAssembler()
    prompt_messages = assembler.build(
        session=session,
        preset=preset,
        messages=prompt_history,
        lores_block=lores_block,
        user_input=user_input,
    )

    request_time = datetime.utcnow().isoformat()
    provider_name = api_config.provider.value
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
        )
    except ProviderError as exc:
        response_time = datetime.utcnow().isoformat()
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
        timestamp=datetime.utcnow(),
        visible=True,
    )
    store.append(assistant_message)
    touch_session(session_name)

    response_time = datetime.utcnow().isoformat()
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
        rounds = int(state.get("rounds_since_sync", 0)) + 1
        if rounds >= session.lore_sync_interval:

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
