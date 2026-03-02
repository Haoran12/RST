from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
import os
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
