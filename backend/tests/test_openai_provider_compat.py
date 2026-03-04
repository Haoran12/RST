from __future__ import annotations

import json
from typing import Any

import httpx
import pytest

import app.providers.openai as openai_module
from app.providers.openai import OpenAIProvider


def _patch_async_client(
    monkeypatch: pytest.MonkeyPatch,
    handler: Any,
) -> None:
    transport = httpx.MockTransport(handler)
    original = openai_module.httpx.AsyncClient

    class _PatchedAsyncClient(original):  # type: ignore[misc, valid-type]
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(openai_module.httpx, "AsyncClient", _PatchedAsyncClient)


@pytest.mark.asyncio
async def test_openai_list_models_uses_browser_like_headers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(
            status_code=200,
            json={"data": [{"id": "model-a"}, {"id": "model-b"}]},
            request=request,
        )

    _patch_async_client(monkeypatch, handler)
    provider = OpenAIProvider()
    models = await provider.list_models("https://example.test/v1", "sk-test")

    assert models == ["model-a", "model-b"]
    request = captured["request"]
    assert request.method == "GET"
    assert request.url.path == "/v1/models"
    assert request.headers["Authorization"] == "Bearer sk-test"
    assert "SillyTavern" in request.headers["User-Agent"]
    assert request.headers["Accept"] == "application/json, text/plain, */*"
    assert request.headers["Sec-Fetch-Mode"] == "cors"


@pytest.mark.asyncio
async def test_openai_chat_uses_sillytavern_style_headers_and_chat_payload(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(
            status_code=200,
            json={"choices": [{"message": {"content": "hello"}}]},
            request=request,
        )

    _patch_async_client(monkeypatch, handler)
    provider = OpenAIProvider()
    result = await provider.chat(
        "https://example.test/v1",
        "sk-test",
        messages=[{"role": "user", "content": "ping"}],
        model="gpt-test",
        temperature=0.7,
        max_tokens=256,
        stream=True,
    )

    assert result.text == "hello"
    request = captured["request"]
    assert request.method == "POST"
    assert request.url.path == "/v1/chat/completions"
    assert request.headers["Authorization"] == "Bearer sk-test"
    assert request.headers["Content-Type"].startswith("application/json")
    assert "SillyTavern" in request.headers["User-Agent"]
    payload = json.loads(request.content.decode("utf-8"))
    assert payload == {
        "model": "gpt-test",
        "messages": [{"role": "user", "content": "ping"}],
        "temperature": 0.7,
        "max_tokens": 256,
        "stream": False,
    }

    request_context = result.request
    assert request_context["url"] == "https://example.test/v1/chat/completions"
    assert request_context["headers"]["Authorization"] == "Bearer [redacted]"
