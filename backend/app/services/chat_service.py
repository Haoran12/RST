from __future__ import annotations

from datetime import datetime

from app.models import generate_id
from app.models.chat import ChatRequest, ChatResponse
from app.models.log import LogEntry
from app.models.session import ChatAttachment, Message
from app.providers.base import ProviderError
from app.providers.registry import get_provider
from app.services.api_config_service import ApiConfigNotFoundError, get_api_config_storage
from app.services.preset_service import PresetNotFoundError, get_preset_storage
from app.services.prompt_assembler import PromptAssembler
from app.services.session_service import (
    SessionNotFoundError,
    get_session_dir,
    get_session_storage,
    touch_session,
)
from app.services.log_service import log_service
from app.storage.encryption import EncryptionError, decrypt_api_key
from app.storage.message_store import MessageStore


class ChatConfigError(RuntimeError):
    pass


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


async def run_chat(session_name: str, payload: ChatRequest) -> ChatResponse:
    session = get_session_storage(session_name)
    preset = get_preset_storage(session.preset_id)
    api_config = get_api_config_storage(session.main_api_config_id)

    if not api_config.model:
        raise ChatConfigError("Model is required for chat")

    api_key = decrypt_api_key(api_config.encrypted_key)
    provider = get_provider(api_config.provider)
    store = MessageStore(get_session_dir(session_name))

    history = _load_history(store, session.mem_length)
    user_input = _compose_user_input(payload.content, payload.attachments)
    assembler = PromptAssembler()
    prompt_messages = assembler.build(
        session=session,
        preset=preset,
        messages=history,
        lores_block="",
        user_input=user_input,
    )

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

    request_time = datetime.utcnow().isoformat()
    raw_request = {
        "provider": api_config.provider,
        "base_url": api_config.base_url,
        "model": api_config.model,
        "temperature": api_config.temperature,
        "max_tokens": api_config.max_tokens,
        "messages": prompt_messages,
    }

    try:
        assistant_text = await provider.chat(
            api_config.base_url,
            api_key,
            messages=prompt_messages,
            model=api_config.model,
            temperature=api_config.temperature,
            max_tokens=api_config.max_tokens,
            stream=api_config.stream,
        )
        raw_response = {"content": assistant_text}
    except ProviderError as exc:
        response_time = datetime.utcnow().isoformat()
        log_service.add_log(
            LogEntry(
                id=generate_id(),
                chat_name=session_name,
                model=api_config.model,
                request_time=request_time,
                response_time=response_time,
                raw_request=raw_request,
                raw_response={"error": str(exc)},
            )
        )
        raise

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
    log_service.add_log(
        LogEntry(
            id=generate_id(),
            chat_name=session_name,
            model=api_config.model,
            request_time=request_time,
            response_time=response_time,
            raw_request=raw_request,
            raw_response=raw_response,
        )
    )

    return ChatResponse(user_message=user_message, assistant_message=assistant_message)


__all__ = [
    "ChatConfigError",
    "ProviderError",
    "ApiConfigNotFoundError",
    "PresetNotFoundError",
    "SessionNotFoundError",
    "EncryptionError",
    "run_chat",
]
