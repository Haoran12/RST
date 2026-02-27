from __future__ import annotations

from app.providers.base import BaseProvider


class AnthropicProvider(BaseProvider):
    """Anthropic provider with a static model list fallback."""

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        return [
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307",
        ]

    async def chat(self, *args: object, **kwargs: object) -> object:
        raise NotImplementedError
