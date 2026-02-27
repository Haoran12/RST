from __future__ import annotations

import httpx

from app.providers.base import BaseProvider, ProviderError


class GeminiProvider(BaseProvider):
    """Gemini provider for listing models."""

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        url = f"{base_url.rstrip('/')}/models"
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(url, params={"key": api_key})
            response.raise_for_status()
            payload = response.json()
        except Exception as exc:
            raise ProviderError("Failed to fetch models") from exc

        if not isinstance(payload, dict) or "models" not in payload:
            raise ProviderError("Invalid models response format")

        models: list[str] = []
        for item in payload.get("models", []):
            if not isinstance(item, dict):
                continue
            name = item.get("name")
            if isinstance(name, str):
                models.append(name.removeprefix("models/"))
        return models

    async def chat(self, *args: object, **kwargs: object) -> object:
        raise NotImplementedError
