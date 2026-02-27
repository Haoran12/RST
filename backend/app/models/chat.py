from __future__ import annotations

from pydantic import BaseModel

from app.models.session import ChatAttachment, Message


class ChatRequest(BaseModel):
    content: str = ""
    attachments: list[ChatAttachment] | None = None
    message_id: str | None = None


class ChatResponse(BaseModel):
    user_message: Message | None = None
    assistant_message: Message


class MessageUpdate(BaseModel):
    content: str | None = None
    visible: bool | None = None


class MessageListResponse(BaseModel):
    messages: list[Message]
    total: int
