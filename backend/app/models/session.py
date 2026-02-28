from __future__ import annotations

import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

NAME_PATTERN = re.compile(r"^[a-zA-Z0-9_\- \u4e00-\u9fff]{1,64}$")


class SessionMeta(BaseModel):
    name: str
    mode: Literal["ST", "RST"] = "RST"
    is_closed: bool = False
    user_description: str = ""
    scan_depth: int = Field(default=4, ge=-1, le=50)
    mem_length: int = Field(default=40, ge=-1, le=500)
    lore_sync_interval: int = Field(default=3, ge=1, le=5)
    created_at: datetime
    updated_at: datetime
    main_api_config_id: str
    scheduler_api_config_id: str | None = None
    preset_id: str
    version: int = 1

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        if not NAME_PATTERN.fullmatch(value):
            raise ValueError("Session name contains invalid characters or length")
        return value

    @model_validator(mode="after")
    def validate_sync_interval(self) -> "SessionMeta":
        upper = 5 if self.mem_length < 0 else min(5, self.mem_length)
        upper = max(1, upper)
        if self.lore_sync_interval > upper:
            raise ValueError(f"lore_sync_interval must be <= {upper} for current mem_length")
        return self


class SessionCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    mode: Literal["ST", "RST"] = "RST"
    is_closed: bool = False
    main_api_config_id: str
    scheduler_api_config_id: str | None = None
    preset_id: str
    user_description: str = ""
    scan_depth: int = Field(default=4, ge=-1, le=50)
    mem_length: int = Field(default=40, ge=-1, le=500)
    lore_sync_interval: int = Field(default=3, ge=1, le=5)

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        if not NAME_PATTERN.fullmatch(value):
            raise ValueError("Session name contains invalid characters or length")
        return value

    @model_validator(mode="after")
    def validate_sync_interval(self) -> "SessionCreate":
        upper = 5 if self.mem_length < 0 else min(5, self.mem_length)
        upper = max(1, upper)
        if self.lore_sync_interval > upper:
            raise ValueError(f"lore_sync_interval must be <= {upper} for current mem_length")
        return self


class SessionUpdate(BaseModel):
    """All fields are optional; only provided fields will be updated."""

    mode: Literal["ST", "RST"] | None = None
    is_closed: bool | None = None
    main_api_config_id: str | None = None
    scheduler_api_config_id: str | None = None
    preset_id: str | None = None
    user_description: str | None = None
    scan_depth: int | None = Field(default=None, ge=-1, le=50)
    mem_length: int | None = Field(default=None, ge=-1, le=500)
    lore_sync_interval: int | None = Field(default=None, ge=1, le=5)


class SessionRename(BaseModel):
    new_name: str = Field(min_length=1, max_length=64)

    @field_validator("new_name")
    @classmethod
    def validate_new_name(cls, value: str) -> str:
        if not NAME_PATTERN.fullmatch(value):
            raise ValueError("Session name contains invalid characters or length")
        return value


class SessionSummary(BaseModel):
    name: str
    mode: Literal["ST", "RST"]
    is_closed: bool
    updated_at: datetime


class SessionResponse(BaseModel):
    name: str
    mode: Literal["ST", "RST"]
    is_closed: bool
    user_description: str
    scan_depth: int
    mem_length: int
    lore_sync_interval: int
    created_at: datetime
    updated_at: datetime
    main_api_config_id: str
    scheduler_api_config_id: str | None
    preset_id: str
    version: int


class ChatAttachment(BaseModel):
    name: str
    size: int
    type: str
    content: str | None = None


class Message(BaseModel):
    id: str
    role: Literal["system", "user", "assistant"]
    content: str
    timestamp: datetime
    visible: bool = True
    attachments: list[ChatAttachment] | None = None
