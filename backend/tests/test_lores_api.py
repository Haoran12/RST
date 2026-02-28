from __future__ import annotations

import pytest

from app.providers.base import BaseProvider, ProviderChatResult


class _SchedulerStubProvider(BaseProvider):
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
        return ProviderChatResult(
            text="injected lore block",
            request={"messages": messages, "model": model},
            response={"choices": [{"finish_reason": "stop"}]},
        )


async def _create_api_config(async_client, sample_api_config: dict) -> str:
    response = await async_client.post("/api-configs", json=sample_api_config)
    assert response.status_code == 201
    return response.json()["id"]


async def _create_preset(async_client, name: str = "LorePreset") -> str:
    response = await async_client.post("/presets", json={"name": name})
    assert response.status_code == 201
    return response.json()["id"]


async def _create_session(
    async_client,
    name: str,
    main_config_id: str,
    preset_id: str,
    scheduler_config_id: str | None = None,
):
    payload = {
        "name": name,
        "mode": "RST",
        "main_api_config_id": main_config_id,
        "preset_id": preset_id,
        "scheduler_api_config_id": scheduler_config_id,
    }
    response = await async_client.post("/sessions", json=payload)
    assert response.status_code == 201
    return response


@pytest.mark.asyncio
async def test_lore_entry_crud(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "LoreEntrySession", config_id, preset_id, config_id)

    created = await async_client.post(
        "/sessions/LoreEntrySession/lores/entries",
        json={
            "name": "黑森林",
            "category": "place",
            "content": "危险森林",
            "tags": ["森林", "危险"],
            "constant": True,
        },
    )
    assert created.status_code == 201
    entry_id = created.json()["id"]

    listed = await async_client.get(
        "/sessions/LoreEntrySession/lores/entries",
        params={"category": "place"},
    )
    assert listed.status_code == 200
    assert listed.json()["total"] == 1

    updated = await async_client.put(
        f"/sessions/LoreEntrySession/lores/entries/{entry_id}",
        json={"content": "危险森林（已更新）", "disabled": True},
    )
    assert updated.status_code == 200
    assert updated.json()["disabled"] is True

    deleted = await async_client.delete(f"/sessions/LoreEntrySession/lores/entries/{entry_id}")
    assert deleted.status_code == 204


@pytest.mark.asyncio
async def test_lore_entry_reorder(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "LoreReorderSession", config_id, preset_id, config_id)

    created_ids: list[str] = []
    for name in ("条目A", "条目B", "条目C"):
        created = await async_client.post(
            "/sessions/LoreReorderSession/lores/entries",
            json={
                "name": name,
                "category": "place",
                "content": f"{name}内容",
            },
        )
        assert created.status_code == 201
        created_ids.append(created.json()["id"])

    reordered = await async_client.put(
        "/sessions/LoreReorderSession/lores/entries/reorder",
        json={
            "category": "place",
            "entry_ids": [created_ids[2], created_ids[0], created_ids[1]],
        },
    )
    assert reordered.status_code == 200
    assert [item["id"] for item in reordered.json()["entries"]] == [
        created_ids[2],
        created_ids[0],
        created_ids[1],
    ]

    listed = await async_client.get(
        "/sessions/LoreReorderSession/lores/entries",
        params={"category": "place"},
    )
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()["entries"]] == [
        created_ids[2],
        created_ids[0],
        created_ids[1],
    ]


@pytest.mark.asyncio
async def test_character_and_memory_crud(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "LoreCharSession", config_id, preset_id, config_id)

    created_character = await async_client.post(
        "/sessions/LoreCharSession/lores/characters",
        json={"name": "艾琳娜", "race": "人类", "role": "游侠"},
    )
    assert created_character.status_code == 201
    character_id = created_character.json()["character_id"]

    created_memory = await async_client.post(
        f"/sessions/LoreCharSession/lores/characters/{character_id}/memories",
        json={"event": "在黑森林受伤", "importance": 7, "tags": ["黑森林", "受伤"]},
    )
    assert created_memory.status_code == 201
    memory_id = created_memory.json()["memory_id"]

    listed = await async_client.get(
        f"/sessions/LoreCharSession/lores/characters/{character_id}/memories"
    )
    assert listed.status_code == 200
    assert listed.json()["total"] == 1

    updated = await async_client.put(
        f"/sessions/LoreCharSession/lores/characters/{character_id}/memories/{memory_id}",
        json={"importance": 8},
    )
    assert updated.status_code == 200
    assert updated.json()["importance"] == 8

    deleted = await async_client.delete(
        f"/sessions/LoreCharSession/lores/characters/{character_id}/memories/{memory_id}"
    )
    assert deleted.status_code == 204


@pytest.mark.asyncio
async def test_schedule_route_returns_injection_block(
    async_client,
    sample_api_config,
    monkeypatch,
) -> None:
    stub_provider = _SchedulerStubProvider()
    monkeypatch.setattr("app.services.lore_scheduler.get_provider", lambda _: stub_provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "LoreScheduleSession", config_id, preset_id, config_id)

    create_entry = await async_client.post(
        "/sessions/LoreScheduleSession/lores/entries",
        json={
            "name": "常驻设定",
            "category": "world_base",
            "content": "这是一个被遗忘的王国。",
            "constant": True,
        },
    )
    assert create_entry.status_code == 201

    scheduled = await async_client.post("/sessions/LoreScheduleSession/lores/schedule")
    assert scheduled.status_code == 200
    payload = scheduled.json()
    assert payload["injection_block"] == "injected lore block"
