from __future__ import annotations

import httpx

from app.providers.base import BaseProvider, ProviderError


class AnthropicProvider(BaseProvider):
    """Anthropic provider with a static model list fallback."""

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        return [
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307",
        ]

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
    ) -> str:
        system_parts: list[str] = []
        chat_messages: list[dict] = []
        for item in messages:
            role = item.get("role")
            content = item.get("content")
            if not isinstance(content, str):
                continue
            if role == "system":
                system_parts.append(content)
                continue
            if role in ("user", "assistant"):
                chat_messages.append({"role": role, "content": content})

        payload: dict[str, object] = {
            "model": model,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "messages": chat_messages,
        }
        if system_parts:
            payload["system"] = "\n\n".join(system_parts)

        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        url = f"{base_url.rstrip('/')}/messages"

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
        except Exception as exc:
            raise ProviderError("Failed to send Anthropic chat request") from exc

        try:
            parts = data.get("content", [])
            if not isinstance(parts, list):
                raise TypeError("Invalid content")
            texts = [part.get("text", "") for part in parts if isinstance(part, dict)]
            return "".join(texts)
        except Exception as exc:
            raise ProviderError("Invalid Anthropic response format") from exc
