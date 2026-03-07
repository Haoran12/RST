from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.session import ChatAttachment, Message


class ChatRequest(BaseModel):
    content: str = ""
    attachments: list[ChatAttachment] | None = None
    message_id: str | None = None
    regenerate: bool = False


class ChatResponse(BaseModel):
    user_message: Message | None = None
    assistant_message: Message


class MessageUpdate(BaseModel):
    content: str | None = None
    visible: bool | None = None
    attachments: list[ChatAttachment] | None = None


class MessageListResponse(BaseModel):
    messages: list[Message]
    total: int


class PromptPreviewRequest(BaseModel):
    content: str = ""
    attachments: list[ChatAttachment] | None = None
    message_id: str | None = None
    max_consolidate_prompts: int = 3


class PromptPreviewStage(BaseModel):
    stage: str
    label: str
    prompt: str
    prompt_length: int = 0
    notes: list[str] = Field(default_factory=list)
    meta: dict[str, str | int | bool | None] = Field(default_factory=dict)


class PromptPreviewResponse(BaseModel):
    mode: str
    has_explicit_input: bool
    user_input: str
    stages: list[PromptPreviewStage] = Field(default_factory=list)
