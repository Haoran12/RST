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
async def test_openai_list_models_uses_sillytavern_compat_headers(
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
    assert request.headers["HTTP-Referer"] == "https://sillytavern.app"
    assert request.headers["X-Title"] == "SillyTavern"


@pytest.mark.asyncio
async def test_openai_chat_uses_sillytavern_compat_headers_and_chat_payload(
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
    assert request.headers["HTTP-Referer"] == "https://sillytavern.app"
    assert request.headers["X-Title"] == "SillyTavern"
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
    assert request_context["headers"]["HTTP-Referer"] == "https://sillytavern.app"
    assert request_context["headers"]["X-Title"] == "SillyTavern"


@pytest.mark.asyncio
async def test_openai_chat_includes_cache_options_when_provided(
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
    _ = await provider.chat(
        "https://example.test/v1",
        "sk-test",
        messages=[{"role": "user", "content": "ping"}],
        model="gpt-test",
        temperature=0.7,
        max_tokens=256,
        stream=False,
        cache_options={
            "prompt_cache_key": "rstv2:test-key",
            "prompt_cache_retention": "24h",
        },
    )

    payload = json.loads(captured["request"].content.decode("utf-8"))
    assert payload["prompt_cache_key"] == "rstv2:test-key"
    assert payload["prompt_cache_retention"] == "24h"


@pytest.mark.asyncio
async def test_openai_chat_retries_without_cache_options_when_gateway_rejects(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        payload = json.loads(request.content.decode("utf-8"))
        has_cache_options = "prompt_cache_key" in payload or "prompt_cache_retention" in payload
        if len(requests) == 1 and has_cache_options:
            return httpx.Response(
                status_code=400,
                json={"error": {"message": "Unknown parameter: prompt_cache_key"}},
                request=request,
            )
        return httpx.Response(
            status_code=200,
            json={"choices": [{"message": {"content": "retried ok"}}]},
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
        stream=False,
        cache_options={
            "prompt_cache_key": "rstv2:test-key",
            "prompt_cache_retention": "24h",
        },
    )

    assert result.text == "retried ok"
    assert len(requests) == 2
    first_payload = json.loads(requests[0].content.decode("utf-8"))
    second_payload = json.loads(requests[1].content.decode("utf-8"))
    assert "prompt_cache_key" in first_payload
    assert "prompt_cache_retention" in first_payload
    assert "prompt_cache_key" not in second_payload
    assert "prompt_cache_retention" not in second_payload


@pytest.mark.asyncio
async def test_openrouter_list_models_uses_sillytavern_headers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(
            status_code=200,
            json={"data": [{"id": "openrouter/model-a"}]},
            request=request,
        )

    _patch_async_client(monkeypatch, handler)
    provider = OpenAIProvider()
    models = await provider.list_models("https://openrouter.ai/api/v1", "sk-or-test")

    assert models == ["openrouter/model-a"]
    request = captured["request"]
    assert request.method == "GET"
    assert request.url.path == "/api/v1/models"
    assert request.headers["Authorization"] == "Bearer sk-or-test"
    assert request.headers["HTTP-Referer"] == "https://sillytavern.app"
    assert request.headers["X-Title"] == "SillyTavern"


@pytest.mark.asyncio
async def test_openrouter_chat_uses_sillytavern_headers_and_payload_shape(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(
            status_code=200,
            json={"choices": [{"message": {"content": "openrouter hello"}}]},
            request=request,
        )

    _patch_async_client(monkeypatch, handler)
    provider = OpenAIProvider()
    result = await provider.chat(
        "https://openrouter.ai/api/v1",
        "sk-or-test",
        messages=[{"role": "user", "content": "ping"}],
        model="openrouter/model-a",
        temperature=0.7,
        max_tokens=256,
        stream=False,
    )

    assert result.text == "openrouter hello"
    request = captured["request"]
    assert request.method == "POST"
    assert request.url.path == "/api/v1/chat/completions"
    assert request.headers["Authorization"] == "Bearer sk-or-test"
    assert request.headers["Content-Type"].startswith("application/json")
    assert request.headers["HTTP-Referer"] == "https://sillytavern.app"
    assert request.headers["X-Title"] == "SillyTavern"

    payload = json.loads(request.content.decode("utf-8"))
    assert payload == {
        "model": "openrouter/model-a",
        "messages": [{"role": "user", "content": "ping"}],
        "temperature": 0.7,
        "max_tokens": 256,
        "stream": False,
        "transforms": ["middle-out"],
        "plugins": [],
        "include_reasoning": True,
    }

    request_context = result.request
    assert request_context["url"] == "https://openrouter.ai/api/v1/chat/completions"
    assert request_context["headers"]["Authorization"] == "Bearer [redacted]"
    assert request_context["headers"]["HTTP-Referer"] == "https://sillytavern.app"
    assert request_context["headers"]["X-Title"] == "SillyTavern"
