from __future__ import annotations

from pydantic import BaseModel, model_validator

from app.models.session import ChatAttachment, Message


class ChatRequest(BaseModel):
    content: str = ""
    attachments: list[ChatAttachment] | None = None
    message_id: str | None = None

    @model_validator(mode="after")
    def validate_payload(self) -> "ChatRequest":
        if not self.content.strip() and not self.attachments:
            raise ValueError("Message content or attachments required")
        return self


class ChatResponse(BaseModel):
    user_message: Message
    assistant_message: Message


class MessageUpdate(BaseModel):
    content: str | None = None
    visible: bool | None = None


class MessageListResponse(BaseModel):
    messages: list[Message]
    total: int
