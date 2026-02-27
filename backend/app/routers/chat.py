from __future__ import annotations

import asyncio
from contextlib import suppress

from fastapi import APIRouter, HTTPException, Request, status

from app.models.chat import ChatRequest, ChatResponse, MessageListResponse, MessageUpdate
from app.models.session import Message
from app.providers.base import ProviderError
from app.services.chat_service import ChatConfigError, run_chat
from app.services.session_service import SessionNotFoundError, get_session_dir, get_session_storage, touch_session
from app.storage.message_store import MessageStore
from app.storage.encryption import EncryptionError
from app.services.api_config_service import ApiConfigNotFoundError
from app.services.preset_service import PresetNotFoundError

router = APIRouter()


async def _await_with_disconnect(
    task: "asyncio.Task[ChatResponse]",
    request: Request,
) -> ChatResponse:
    while not task.done():
        if await request.is_disconnected():
            task.cancel()
            with suppress(asyncio.CancelledError):
                await task
            raise HTTPException(status_code=499, detail="Request cancelled")
        await asyncio.sleep(0.05)
    return await task


@router.get("/sessions/{name}/messages", response_model=MessageListResponse)
def list_messages(name: str) -> MessageListResponse:
    try:
        get_session_storage(name)
        store = MessageStore(get_session_dir(name))
        messages, total = store.load_for_frontend()
        return MessageListResponse(messages=messages, total=total)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.patch(
    "/sessions/{name}/messages/{message_id}", response_model=Message
)
def update_message(name: str, message_id: str, payload: MessageUpdate) -> Message:
    try:
        get_session_storage(name)
        store = MessageStore(get_session_dir(name))
        updated = store.update_message(message_id, payload.content, payload.visible)
        if updated is None:
            raise HTTPException(status_code=404, detail="Message not found")
        touch_session(name)
        return updated
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/sessions/{name}/messages/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_message(name: str, message_id: str):
    try:
        get_session_storage(name)
        store = MessageStore(get_session_dir(name))
        deleted = store.delete_message(message_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Message not found")
        touch_session(name)
        return None
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/sessions/{name}/chat", response_model=ChatResponse)
async def chat(name: str, payload: ChatRequest, request: Request) -> ChatResponse:
    task = asyncio.create_task(run_chat(name, payload))
    try:
        return await _await_with_disconnect(task, request)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PresetNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc
    except ChatConfigError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
