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
    redact_outbound_headers,
)


def _safe_json(response: httpx.Response) -> Any:
    try:
        return response.json()
    except Exception:
        return response.text


class GeminiProvider(BaseProvider):
    """Gemini provider for listing models."""

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        url = f"{base_url.rstrip('/')}/models"
        headers = build_outbound_headers()
        try:
            async with httpx.AsyncClient(timeout=PROVIDER_LIST_MODELS_TIMEOUT_SECONDS) as client:
                response = await client.get(url, params={"key": api_key}, headers=headers)
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
        url = f"{base_url.rstrip('/')}/models/{model}:generateContent"
        headers = build_outbound_headers({"Content-Type": "application/json"})
        system_parts: list[str] = []
        contents: list[dict] = []

        for item in messages:
            role = item.get("role")
            content = item.get("content")
            if not isinstance(content, str):
                continue
            if role == "system":
                system_parts.append(content)
                continue
            if role == "assistant":
                mapped_role = "model"
            elif role == "user":
                mapped_role = "user"
            else:
                continue
            contents.append({"role": mapped_role, "parts": [{"text": content}]})

        payload: dict[str, object] = {
            "contents": contents,
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_tokens,
            },
        }
        if system_parts:
            payload["systemInstruction"] = {"parts": [{"text": "\n\n".join(system_parts)}]}
        request_context = {
            "method": "POST",
            "url": url,
            "headers": redact_outbound_headers(headers),
            "query": {"key": "[redacted]"},
            "payload": payload,
        }

        data: Any = None
        try:
            async with httpx.AsyncClient(timeout=PROVIDER_CHAT_TIMEOUT_SECONDS) as client:
                response = await client.post(
                    url,
                    params={"key": api_key},
                    headers=headers,
                    json=payload,
                )
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPStatusError as exc:
            raise ProviderError(
                "Failed to send Gemini chat request",
                request=request_context,
                response=_safe_json(exc.response),
                status_code=exc.response.status_code,
            ) from exc
        except Exception as exc:
            raise ProviderError(
                "Failed to send Gemini chat request",
                request=request_context,
            ) from exc

        try:
            candidate = data["candidates"][0]["content"]["parts"][0]
            text = str(candidate.get("text", ""))
        except Exception as exc:
            raise ProviderError(
                "Invalid Gemini response format",
                request=request_context,
                response=data,
                status_code=response.status_code,
            ) from exc

        return ProviderChatResult(text=text, request=request_context, response=data)
