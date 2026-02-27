from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any


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
