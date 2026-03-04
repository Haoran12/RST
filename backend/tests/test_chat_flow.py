from __future__ import annotations

import asyncio
from datetime import datetime
import pytest

from app.providers.base import BaseProvider, ProviderChatResult


class _StubProvider(BaseProvider):
    def __init__(self, texts: list[str]) -> None:
        self.texts = texts
        self.calls: list[list[dict]] = []

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        return []

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
        self.calls.append([{"role": msg["role"], "content": msg["content"]} for msg in messages])
        index = len(self.calls) - 1
        text = self.texts[index]
        response_payload = {
            "choices": [{"message": {"content": text}, "finish_reason": "stop"}],
            "usage": {
                "prompt_tokens": 10 + index,
                "completion_tokens": 5 + index,
                "total_tokens": 15 + index * 2,
            },
        }
        request_payload = {
            "method": "POST",
            "url": f"{base_url.rstrip('/')}/chat/completions",
            "payload": {
                "model": model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "stream": stream,
            },
        }
        return ProviderChatResult(
            text=text,
            request=request_payload,
            response=response_payload,
        )


class _SlowProvider(BaseProvider):
    def __init__(self) -> None:
        self.started = asyncio.Event()
        self.cancelled = asyncio.Event()

    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        return []

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
        self.started.set()
        try:
            await asyncio.sleep(5)
        except asyncio.CancelledError:
            self.cancelled.set()
            raise
        return ProviderChatResult(
            text="slow-answer",
            request={"messages": messages, "model": model},
            response={"choices": [{"finish_reason": "stop"}]},
        )


async def _create_api_config(async_client, sample_api_config: dict) -> str:
    response = await async_client.post("/api-configs", json=sample_api_config)
    assert response.status_code == 201
    return response.json()["id"]


async def _create_preset(async_client) -> str:
    response = await async_client.post("/presets", json={"name": "ChatPreset"})
    assert response.status_code == 201
    return response.json()["id"]


async def _create_session(async_client, name: str, config_id: str, preset_id: str) -> None:
    payload = {
        "name": name,
        "mode": "RST",
        "main_api_config_id": config_id,
        "preset_id": preset_id,
    }
    response = await async_client.post("/sessions", json=payload)
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_empty_send_uses_continue_and_does_not_add_user_message(
    async_client, sample_api_config, monkeypatch
) -> None:
    provider = _StubProvider(texts=["first-answer", "second-answer"])
    monkeypatch.setattr("app.services.chat_service.get_provider", lambda _: provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ChatFlow1", config_id, preset_id)

    first = await async_client.post("/sessions/ChatFlow1/chat", json={"content": "hello"})
    assert first.status_code == 200
    assert first.json()["user_message"]["role"] == "user"

    second = await async_client.post("/sessions/ChatFlow1/chat", json={"content": ""})
    assert second.status_code == 200
    assert second.json()["user_message"] is None

    assert len(provider.calls) == 2
    second_prompt = provider.calls[1]
    assert second_prompt[-1] == {"role": "user", "content": "continue"}

    messages = await async_client.get("/sessions/ChatFlow1/messages")
    assert messages.status_code == 200
    roles = [item["role"] for item in messages.json()["messages"]]
    assert roles.count("user") == 1
    assert roles.count("assistant") == 2


@pytest.mark.asyncio
async def test_empty_send_reuses_latest_visible_user_as_user_input(
    async_client, sample_api_config, monkeypatch
) -> None:
    provider = _StubProvider(texts=["first-answer", "second-answer"])
    monkeypatch.setattr("app.services.chat_service.get_provider", lambda _: provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ChatFlow2", config_id, preset_id)

    first = await async_client.post("/sessions/ChatFlow2/chat", json={"content": "hello user"})
    assert first.status_code == 200
    assistant_id = first.json()["assistant_message"]["id"]

    hidden = await async_client.patch(
        f"/sessions/ChatFlow2/messages/{assistant_id}",
        json={"visible": False},
    )
    assert hidden.status_code == 200
    assert hidden.json()["visible"] is False

    second = await async_client.post("/sessions/ChatFlow2/chat", json={"content": ""})
    assert second.status_code == 200
    assert second.json()["user_message"] is None

    second_prompt = provider.calls[1]
    user_entries = [item for item in second_prompt if item["role"] == "user"]
    assert user_entries == [{"role": "user", "content": "hello user"}]

    messages = await async_client.get("/sessions/ChatFlow2/messages")
    assert messages.status_code == 200
    roles = [item["role"] for item in messages.json()["messages"]]
    assert roles.count("user") == 1
    assert roles.count("assistant") == 2


@pytest.mark.asyncio
async def test_logs_include_usage_and_stop_reason(async_client, sample_api_config, monkeypatch) -> None:
    provider = _StubProvider(texts=["log-answer"])
    monkeypatch.setattr("app.services.chat_service.get_provider", lambda _: provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ChatFlow3", config_id, preset_id)

    chat = await async_client.post("/sessions/ChatFlow3/chat", json={"content": "hello"})
    assert chat.status_code == 200

    logs = await async_client.get("/logs")
    assert logs.status_code == 200
    payload = logs.json()
    assert payload
    latest = payload[0]
    assert latest["chat_name"] == "ChatFlow3"
    assert latest["provider"] == "openai"
    assert latest["status"] == "success"
    assert latest["prompt_tokens"] == 10
    assert latest["completion_tokens"] == 5
    assert latest["total_tokens"] == 15
    assert latest["stop_reason"] == "stop"
    assert "provider_request" in latest["raw_request"]
    assert datetime.fromisoformat(latest["request_time"]).tzinfo is not None
    assert datetime.fromisoformat(latest["response_time"]).tzinfo is not None


@pytest.mark.asyncio
async def test_closed_session_rejects_chat(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ClosedChat", config_id, preset_id)

    close_response = await async_client.put("/sessions/ClosedChat", json={"is_closed": True})
    assert close_response.status_code == 200
    assert close_response.json()["is_closed"] is True

    chat = await async_client.post("/sessions/ClosedChat/chat", json={"content": "hello"})
    assert chat.status_code == 400
    assert "Session is closed" in chat.json()["detail"]


@pytest.mark.asyncio
async def test_closing_session_cancels_runtime_and_clears_memory(
    async_client, sample_api_config, monkeypatch
) -> None:
    from app.services.rst_runtime_service import rst_runtime_service

    provider = _SlowProvider()
    monkeypatch.setattr("app.services.chat_service.get_provider", lambda _: provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "RuntimeClose", config_id, preset_id)

    chat_task = asyncio.create_task(
        async_client.post("/sessions/RuntimeClose/chat", json={"content": "hello"})
    )
    await asyncio.wait_for(provider.started.wait(), timeout=1.5)

    runtime_state = rst_runtime_service.get_session_state("RuntimeClose")
    assert runtime_state.get("status") == "running"

    close_response = await async_client.put("/sessions/RuntimeClose", json={"is_closed": True})
    assert close_response.status_code == 200
    assert close_response.json()["is_closed"] is True

    await asyncio.wait_for(provider.cancelled.wait(), timeout=1.5)
    chat_response = await chat_task
    assert chat_response.status_code == 499
    assert rst_runtime_service.get_session_state("RuntimeClose") == {}
    assert rst_runtime_service.has_running_tasks("RuntimeClose") is False
