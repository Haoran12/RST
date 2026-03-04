from __future__ import annotations

from typing import Any

import httpx

from app.providers.base import (
    PROVIDER_CHAT_TIMEOUT_SECONDS,
    PROVIDER_LIST_MODELS_TIMEOUT_SECONDS,
    BaseProvider,
    ProviderChatResult,
    ProviderError,
    build_outbound_headers,
    is_openrouter_base_url,
    redact_outbound_headers,
)


def _safe_json(response: httpx.Response) -> Any:
    try:
        return response.json()
    except Exception:
        return response.text


class OpenAIProvider(BaseProvider):
    """OpenAI-compatible provider for /models listing."""

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        url = f"{base_url.rstrip('/')}/models"
        headers = build_outbound_headers(
            {"Authorization": f"Bearer {api_key}"},
            base_url=base_url,
            use_sillytavern_openai_compat=True,
        )
        try:
            async with httpx.AsyncClient(timeout=PROVIDER_LIST_MODELS_TIMEOUT_SECONDS) as client:
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
        url = f"{base_url.rstrip('/')}/chat/completions"
        headers = build_outbound_headers(
            {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            base_url=base_url,
            use_sillytavern_openai_compat=True,
        )
        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": False,
        }
        if is_openrouter_base_url(base_url):
            # Match SillyTavern's OpenRouter /chat/completions shape.
            payload.update(
                {
                    "transforms": ["middle-out"],
                    "plugins": [],
                    "include_reasoning": True,
                }
            )
        request_context = {
            "method": "POST",
            "url": url,
            "headers": redact_outbound_headers(headers),
            "payload": payload,
        }

        data: Any = None
        try:
            async with httpx.AsyncClient(timeout=PROVIDER_CHAT_TIMEOUT_SECONDS) as client:
                response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPStatusError as exc:
            raise ProviderError(
                "Failed to send chat request",
                request=request_context,
                response=_safe_json(exc.response),
                status_code=exc.response.status_code,
            ) from exc
        except Exception as exc:
            raise ProviderError("Failed to send chat request", request=request_context) from exc

        try:
            text = str(data["choices"][0]["message"]["content"])
        except Exception as exc:
            raise ProviderError(
                "Invalid chat response format",
                request=request_context,
                response=data,
                status_code=response.status_code,
            ) from exc

        return ProviderChatResult(
            text=text,
            request=request_context,
            response=data,
        )
