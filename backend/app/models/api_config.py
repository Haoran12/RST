from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field, field_validator


def _normalize_temperature(value: float) -> float:
    # Avoid serialized artifacts like 0.30000000000000004 caused by binary floats.
    return round(value, 10)


class ProviderType(str, Enum):
    OPENAI = "openai"
    GEMINI = "gemini"
    DEEPSEEK = "deepseek"
    ANTHROPIC = "anthropic"
    OPENAI_COMPAT = "openai_compat"


DEFAULT_BASE_URLS: dict[ProviderType, str] = {
    ProviderType.OPENAI: "https://api.openai.com/v1",
    ProviderType.GEMINI: "https://generativelanguage.googleapis.com/v1beta",
    ProviderType.DEEPSEEK: "https://api.deepseek.com/v1",
    ProviderType.ANTHROPIC: "https://api.anthropic.com/v1",
    ProviderType.OPENAI_COMPAT: "",
}


class ApiConfig(BaseModel):
    id: str
    name: str
    provider: ProviderType
    base_url: str
    encrypted_key: str
    model: str = ""
    temperature: float = 0.7
    max_tokens: int = 4096
    stream: bool = True
    version: int = 1

    @field_validator("temperature")
    @classmethod
    def validate_temperature(cls, value: float) -> float:
        return _normalize_temperature(value)


class ApiConfigCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    provider: ProviderType
    base_url: str | None = None
    api_key: str
    model: str = ""
    temperature: float = Field(default=0.7, ge=0, le=2)
    max_tokens: int = Field(default=4096, ge=1, le=1_000_000)
    stream: bool = True

    @field_validator("temperature")
    @classmethod
    def validate_temperature(cls, value: float) -> float:
        return _normalize_temperature(value)


class ApiConfigUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=64)
    provider: ProviderType | None = None
    base_url: str | None = None
    api_key: str | None = None
    model: str | None = None
    temperature: float | None = Field(default=None, ge=0, le=2)
    max_tokens: int | None = Field(default=None, ge=1, le=1_000_000)
    stream: bool | None = None

    @field_validator("temperature")
    @classmethod
    def validate_temperature(cls, value: float | None) -> float | None:
        if value is None:
            return None
        return _normalize_temperature(value)


class ApiConfigResponse(BaseModel):
    id: str
    name: str
    provider: ProviderType
    base_url: str
    api_key_preview: str
    model: str = ""
    temperature: float = 0.7
    max_tokens: int = 4096
    stream: bool = True
    version: int = 1


class ApiConfigSummary(BaseModel):
    id: str
    name: str
    provider: ProviderType
    model: str


class ModelListResponse(BaseModel):
    models: list[str]
    error: str | None = None
