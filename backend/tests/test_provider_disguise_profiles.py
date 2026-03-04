from __future__ import annotations

import json
from typing import Any

import httpx
import pytest

import app.providers.anthropic as anthropic_module
import app.providers.gemini as gemini_module
import app.providers.openai as openai_module
from app.providers.anthropic import AnthropicProvider
from app.providers.deepseek import DeepseekProvider
from app.providers.gemini import GeminiProvider


def _patch_async_client(
    monkeypatch: pytest.MonkeyPatch,
    module: Any,
    handler: Any,
) -> None:
    transport = httpx.MockTransport(handler)
    original = module.httpx.AsyncClient

    class _PatchedAsyncClient(original):  # type: ignore[misc, valid-type]
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(module.httpx, "AsyncClient", _PatchedAsyncClient)


@pytest.mark.asyncio
async def test_anthropic_chat_uses_sillytavern_style_headers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(
            status_code=200,
            json={"content": [{"type": "text", "text": "hello from claude"}]},
            request=request,
        )

    _patch_async_client(monkeypatch, anthropic_module, handler)
    provider = AnthropicProvider()
    result = await provider.chat(
        "https://api.anthropic.com/v1",
        "sk-ant-test",
        messages=[
            {"role": "system", "content": "sys"},
            {"role": "user", "content": "u1"},
            {"role": "assistant", "content": "a1"},
        ],
        model="claude-test",
        temperature=0.5,
        max_tokens=128,
    )

    assert result.text == "hello from claude"
    request = captured["request"]
    assert request.method == "POST"
    assert request.url.path == "/v1/messages"
    assert request.headers["x-api-key"] == "sk-ant-test"
    assert request.headers["anthropic-version"] == "2023-06-01"
    assert request.headers["Content-Type"].startswith("application/json")

    payload = json.loads(request.content.decode("utf-8"))
    assert payload == {
        "model": "claude-test",
        "max_tokens": 128,
        "temperature": 0.5,
        "messages": [
            {"role": "user", "content": "u1"},
            {"role": "assistant", "content": "a1"},
        ],
        "system": "sys",
    }
    assert result.request["headers"]["x-api-key"] == "[redacted]"


@pytest.mark.asyncio
async def test_gemini_chat_uses_sillytavern_style_headers(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(
            status_code=200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {"text": "hello from gemini"},
                            ]
                        }
                    }
                ]
            },
            request=request,
        )

    _patch_async_client(monkeypatch, gemini_module, handler)
    provider = GeminiProvider()
    result = await provider.chat(
        "https://generativelanguage.googleapis.com/v1beta",
        "gm-test-key",
        messages=[
            {"role": "system", "content": "sys gemini"},
            {"role": "user", "content": "u1"},
        ],
        model="gemini-2.0-flash",
        temperature=0.6,
        max_tokens=256,
    )

    assert result.text == "hello from gemini"
    request = captured["request"]
    assert request.method == "POST"
    assert request.url.path == "/v1beta/models/gemini-2.0-flash:generateContent"
    assert request.url.params.get("key") == "gm-test-key"
    assert request.headers["Content-Type"].startswith("application/json")

    payload = json.loads(request.content.decode("utf-8"))
    assert payload == {
        "contents": [{"role": "user", "parts": [{"text": "u1"}]}],
        "generationConfig": {"temperature": 0.6, "maxOutputTokens": 256},
        "systemInstruction": {"parts": [{"text": "sys gemini"}]},
    }
    assert result.request["query"]["key"] == "[redacted]"


@pytest.mark.asyncio
async def test_deepseek_chat_uses_openai_compat_disguise_headers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(
            status_code=200,
            json={"choices": [{"message": {"content": "hello from deepseek"}}]},
            request=request,
        )

    _patch_async_client(monkeypatch, openai_module, handler)
    provider = DeepseekProvider()
    result = await provider.chat(
        "https://api.deepseek.com/v1",
        "sk-deepseek-test",
        messages=[{"role": "user", "content": "u1"}],
        model="deepseek-chat",
        temperature=0.7,
        max_tokens=300,
    )

    assert result.text == "hello from deepseek"
    request = captured["request"]
    assert request.method == "POST"
    assert request.url.path == "/v1/chat/completions"
    assert request.headers["Authorization"] == "Bearer sk-deepseek-test"
    assert request.headers["Content-Type"].startswith("application/json")
    assert request.headers["HTTP-Referer"] == "https://sillytavern.app"
    assert request.headers["X-Title"] == "SillyTavern"
    assert result.request["headers"]["Authorization"] == "Bearer [redacted]"
