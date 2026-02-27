from __future__ import annotations

import httpx

from app.providers.base import BaseProvider, ProviderError


class OpenAIProvider(BaseProvider):
    """OpenAI-compatible provider for /models listing."""

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        url = f"{base_url.rstrip('/')}/models"
        headers = {"Authorization": f"Bearer {api_key}"}
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(url, headers=headers)
            response.raise_for_status()
            payload = response.json()
        except Exception as exc:
            raise ProviderError("Failed to fetch models") from exc

        if not isinstance(payload, dict) or "data" not in payload:
            raise ProviderError("Invalid models response format")

        models: list[str] = []
        for item in payload.get("data", []):
            if isinstance(item, dict) and isinstance(item.get("id"), str):
                models.append(item["id"])
        return models

    async def chat(self, *args: object, **kwargs: object) -> object:
        raise NotImplementedError
