from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

SYSTEM_ENTRIES: list[str] = [
    "Main_Prompt",
    "lores",
    "user_description",
    "chat_history",
    "scene",
    "user_input",
]


class PresetEntry(BaseModel):
    name: str
    role: Literal["system", "user", "assistant"] = "system"
    content: str = ""
    disabled: bool = False
    comment: str = ""


class Preset(BaseModel):
    id: str
    name: str
    entries: list[PresetEntry]
    version: int = 1


class PresetCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)


class PresetUpdate(BaseModel):
    """Replace the entire entries list, including ordering."""

    entries: list[PresetEntry]


class PresetRename(BaseModel):
    new_name: str = Field(min_length=1, max_length=64)


class PresetSummary(BaseModel):
    id: str
    name: str


class PresetResponse(BaseModel):
    id: str
    name: str
    entries: list[PresetEntry]
    version: int
