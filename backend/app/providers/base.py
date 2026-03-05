from __future__ import annotations

import os
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlparse


def _env_positive_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        value = float(raw)
    except ValueError:
        return default
    return value if value > 0 else default


PROVIDER_LIST_MODELS_TIMEOUT_SECONDS = _env_positive_float(
    "RST_PROVIDER_LIST_MODELS_TIMEOUT_SECONDS",
    60.0,
)
PROVIDER_CHAT_TIMEOUT_SECONDS = _env_positive_float(
    "RST_PROVIDER_CHAT_TIMEOUT_SECONDS",
    300.0,
)

# Keep provider defaults minimal. Provider-specific behavior should be explicit.
DEFAULT_OUTBOUND_HEADERS: dict[str, str] = {}

# SillyTavern identity headers used by OpenAI-compatible requests.
SILLYTAVERN_OPENAI_COMPAT_HEADERS: dict[str, str] = {
    "HTTP-Referer": "https://sillytavern.app",
    "X-Title": "SillyTavern",
}


def is_openrouter_base_url(base_url: str) -> bool:
    candidate = base_url.strip()
    if not candidate:
        return False
    if "://" not in candidate:
        candidate = f"https://{candidate}"

    try:
        hostname = urlparse(candidate).hostname
    except Exception:
        return False

    if not hostname:
        return False
    host = hostname.lower()
    return host == "openrouter.ai" or host.endswith(".openrouter.ai")


def build_outbound_headers(
    extra: dict[str, str] | None = None,
    *,
    base_url: str | None = None,
    use_sillytavern_openai_compat: bool = False,
) -> dict[str, str]:
    headers = dict(DEFAULT_OUTBOUND_HEADERS)
    if use_sillytavern_openai_compat or (
        base_url and is_openrouter_base_url(base_url)
    ):
        headers.update(SILLYTAVERN_OPENAI_COMPAT_HEADERS)
    if extra:
        headers.update(extra)
    return headers


def redact_outbound_headers(headers: dict[str, str]) -> dict[str, str]:
    redacted = dict(headers)
    for key in ("Authorization", "x-api-key", "api-key", "x-goog-api-key"):
        value = redacted.get(key)
        if value:
            if key == "Authorization" and value.startswith("Bearer "):
                redacted[key] = "Bearer [redacted]"
            else:
                redacted[key] = "[redacted]"
    return redacted


class ProviderError(RuntimeError):
    """Raised when provider operations fail."""

    def __init__(
        self,
        message: str,
        *,
        request: dict[str, Any] | None = None,
        response: Any | None = None,
        status_code: int | None = None,
    ) -> None:
        super().__init__(message)
        self.request = request
        self.response = response
        self.status_code = status_code


@dataclass(slots=True)
class ProviderChatResult:
    text: str
    request: dict[str, Any]
    response: Any


class BaseProvider(ABC):
    @abstractmethod
    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        """Return available model ids or raise ProviderError."""

    @abstractmethod
    async def chat(
        self,
        base_url: str,
        api_key: str,
        *,
        messages: list[dict],
        model: str,
        temperature: float,
        max_tokens: int,
        stream: bool = False,
        cache_options: dict[str, Any] | None = None,
    ) -> ProviderChatResult:
        """Return assistant response text or raise ProviderError."""
