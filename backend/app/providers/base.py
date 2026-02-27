from __future__ import annotations

from abc import ABC, abstractmethod


class ProviderError(RuntimeError):
    """Raised when provider operations fail."""


class BaseProvider(ABC):
    @abstractmethod
    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        """Return available model ids or raise ProviderError."""

    @abstractmethod
    async def chat(self, *args: object, **kwargs: object) -> object:
        """Chat API placeholder for future milestones."""
