from __future__ import annotations

import os
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any


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

# Browser-like defaults for outbound LLM API calls.
# The User-Agent intentionally identifies as SillyTavern-compatible.
DEFAULT_OUTBOUND_HEADERS: dict[str, str] = {
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Cache-Control": "no-cache",
    "Pragma": "no-cache",
    "DNT": "1",
    "Origin": "https://sillytavern.app",
    "Referer": "https://sillytavern.app/",
    "Sec-CH-UA": '"Not(A:Brand";v="99", "Google Chrome";v="124", "Chromium";v="124"',
    "Sec-CH-UA-Mobile": "?0",
    "Sec-CH-UA-Platform": '"Windows"',
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "cross-site",
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "SillyTavern/1.12.8 Chrome/124.0.0.0 Safari/537.36"
    ),
}


def build_outbound_headers(extra: dict[str, str] | None = None) -> dict[str, str]:
    headers = dict(DEFAULT_OUTBOUND_HEADERS)
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
    ) -> ProviderChatResult:
        """Return assistant response text or raise ProviderError."""
