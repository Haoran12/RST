from __future__ import annotations

from datetime import datetime

import pytest

from app.models import generate_id
from app.models.session import Message
from app.providers.base import BaseProvider, ProviderChatResult
from app.services.rst_runtime_service import rst_runtime_service
from app.services.session_service import get_session_dir
from app.storage.message_store import MessageStore


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


class _CaptureSchedulerProvider(BaseProvider):
    def __init__(self) -> None:
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
        self.calls.append(
            [{"role": message["role"], "content": message["content"]} for message in messages]
        )
        return ProviderChatResult(
            text="injected lore block",
            request={"messages": messages, "model": model},
            response={"choices": [{"finish_reason": "stop"}]},
        )


class _SchedulerSyncProvider(BaseProvider):
    def __init__(self, text: str) -> None:
        self.text = text

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
            text=self.text,
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
        json={"content": "危险森林（已更新）", "disabled": True, "category": "society"},
    )
    assert updated.status_code == 200
    assert updated.json()["disabled"] is True
    assert updated.json()["category"] == "society"

    listed_place = await async_client.get(
        "/sessions/LoreEntrySession/lores/entries",
        params={"category": "place"},
    )
    assert listed_place.status_code == 200
    assert listed_place.json()["total"] == 0

    listed_society = await async_client.get(
        "/sessions/LoreEntrySession/lores/entries",
        params={"category": "society"},
    )
    assert listed_society.status_code == 200
    assert listed_society.json()["total"] == 1
    assert listed_society.json()["entries"][0]["id"] == entry_id

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
        json={"name": "艾琳娜", "race": "人类", "gender": "女", "role": "游侠"},
    )
    assert created_character.status_code == 201
    created_payload = created_character.json()
    character_id = created_payload["character_id"]
    assert created_payload["gender"] == "女"

    updated_character = await async_client.put(
        f"/sessions/LoreCharSession/lores/characters/{character_id}",
        json={"gender": "女性"},
    )
    assert updated_character.status_code == 200
    assert updated_character.json()["gender"] == "女性"

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
async def test_character_reorder(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "LoreCharacterReorderSession", config_id, preset_id, config_id)

    created_ids: list[str] = []
    for name in ("角色A", "角色B", "角色C"):
        created = await async_client.post(
            "/sessions/LoreCharacterReorderSession/lores/characters",
            json={"name": name, "race": "人类"},
        )
        assert created.status_code == 201
        created_ids.append(created.json()["character_id"])

    listed = await async_client.get("/sessions/LoreCharacterReorderSession/lores/characters")
    assert listed.status_code == 200
    assert [item["character_id"] for item in listed.json()["characters"]] == created_ids

    reordered = await async_client.put(
        "/sessions/LoreCharacterReorderSession/lores/characters/reorder",
        json={"character_ids": [created_ids[2], created_ids[0], created_ids[1]]},
    )
    assert reordered.status_code == 200
    assert [item["character_id"] for item in reordered.json()["characters"]] == [
        created_ids[2],
        created_ids[0],
        created_ids[1],
    ]

    listed_after = await async_client.get("/sessions/LoreCharacterReorderSession/lores/characters")
    assert listed_after.status_code == 200
    assert [item["character_id"] for item in listed_after.json()["characters"]] == [
        created_ids[2],
        created_ids[0],
        created_ids[1],
    ]


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


@pytest.mark.asyncio
async def test_schedule_prompt_includes_birth_age_and_birthday(
    async_client,
    sample_api_config,
    monkeypatch,
) -> None:
    capture_provider = _CaptureSchedulerProvider()
    monkeypatch.setattr("app.services.lore_scheduler.get_provider", lambda _: capture_provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    session_name = "LoreScheduleBirthSession"
    await _create_session(async_client, session_name, config_id, preset_id, config_id)

    created_character = await async_client.post(
        f"/sessions/{session_name}/lores/characters",
        json={
            "name": "艾琳娜",
            "race": "精灵",
            "birth": "神历1200年15月20日",
            "constant": True,
        },
    )
    assert created_character.status_code == 201

    store = MessageStore(get_session_dir(session_name))
    store.append(
        Message(
            id=generate_id(),
            role="user",
            content="scene: 当前日期 神历1218年15月20日",
            timestamp=datetime.utcnow(),
            visible=True,
        )
    )

    scheduled = await async_client.post(f"/sessions/{session_name}/lores/schedule")
    assert scheduled.status_code == 200
    assert capture_provider.calls

    prompt_text = capture_provider.calls[-1][0]["content"]
    assert "birth: 神历1200年15月20日" in prompt_text
    assert "age: 18" in prompt_text
    assert "birthday_today: yes" in prompt_text


@pytest.mark.asyncio
async def test_sync_updates_character_activity_and_appearance_alias_fields(
    async_client,
    sample_api_config,
    monkeypatch,
) -> None:
    sync_text = """
[
  {
    "type": "character_update",
    "name": "柳璃",
    "field_updates": {
      "当前行为": "警戒四周",
      "外貌": "银发沾雨，披风破损",
      "active_form.body_state": "左臂擦伤",
      "active_form.mental_state": "紧张但冷静"
    }
  },
  {
    "type": "character_update",
    "name": "柳璃",
    "field_updates": {
      "appearance": "湿透的银发贴在额前",
      "behavior": "收刀入鞘后观察四周"
    }
  }
]
""".strip()
    provider = _SchedulerSyncProvider(sync_text)
    monkeypatch.setattr("app.services.lore_updater.get_provider", lambda _: provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    session_name = "LoreSyncAliasSession"
    await _create_session(async_client, session_name, config_id, preset_id, config_id)

    created_character = await async_client.post(
        f"/sessions/{session_name}/lores/characters",
        json={"name": "柳璃", "race": "人类"},
    )
    assert created_character.status_code == 201

    sync_response = await async_client.post(f"/sessions/{session_name}/lores/sync")
    assert sync_response.status_code == 200
    sync_payload = sync_response.json()
    assert sync_payload["updated_entries"]
    changed_fields = [
        item["field"]
        for change in sync_payload["changes"]
        for item in change.get("field_changes", [])
    ]
    assert "active_form.activity" in changed_fields
    assert "active_form.physique" in changed_fields
    assert "active_form.body" in changed_fields
    assert "active_form.mind" in changed_fields

    characters = await async_client.get(f"/sessions/{session_name}/lores/characters")
    assert characters.status_code == 200
    payload = characters.json()
    assert payload["total"] == 1
    active_form = payload["characters"][0]["forms"][0]
    assert active_form["activity"] == "收刀入鞘后观察四周"
    assert active_form["physique"] == "湿透的银发贴在额前"
    assert active_form["body"] == "左臂擦伤"
    assert active_form["mind"] == "紧张但冷静"


@pytest.mark.asyncio
async def test_sync_status_includes_last_result_details(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    session_name = "LoreSyncStatusSession"
    await _create_session(async_client, session_name, config_id, preset_id, config_id)

    rst_runtime_service.update_session_state(
        session_name,
        sync_running=False,
        sync_last_run_at="2026-03-02T10:00:00",
        rounds_since_sync=2,
        sync_interval=3,
        sync_last_result={
            "updated_entries": ["char-1"],
            "created_entries": ["entry-1"],
            "new_memories": 1,
            "new_plot_events": 0,
            "duration_ms": 123,
            "changes": [
                {
                    "entry_id": "char-1",
                    "name": "Alice",
                    "category": "character",
                    "action": "updated",
                    "summary": "Character fields updated",
                    "before_content": None,
                    "after_content": None,
                    "content_append": None,
                    "tags_added": [],
                    "field_changes": [
                        {"field": "active_form.strength", "before": "10", "after": "12"},
                    ],
                    "memory_event": None,
                }
            ],
        },
    )

    status = await async_client.get(f"/sessions/{session_name}/lores/sync/status")
    assert status.status_code == 200
    payload = status.json()
    assert payload["running"] is False
    assert payload["rounds_since_last_sync"] == 2
    assert payload["sync_interval"] == 3
    assert payload["last_result"] is not None
    assert payload["last_result"]["updated_entries"] == ["char-1"]
    assert payload["last_result"]["created_entries"] == ["entry-1"]
    assert payload["last_result"]["changes"][0]["field_changes"][0]["field"] == "active_form.strength"


@pytest.mark.asyncio
async def test_scene_state_get_and_put(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    session_name = "LoreSceneStateSession"
    await _create_session(async_client, session_name, config_id, preset_id, config_id)

    initial = await async_client.get(f"/sessions/{session_name}/lores/scene")
    assert initial.status_code == 200
    initial_payload = initial.json()
    assert initial_payload["current_time"] == ""
    assert initial_payload["current_location"] == ""
    assert initial_payload["characters"] == []

    updated = await async_client.put(
        f"/sessions/{session_name}/lores/scene",
        json={
            "current_time": "灵纪1042年3月18日 午后",
            "current_location": "泽源·潮汐城·港口",
            "characters": ["柳璃", "小溪"],
        },
    )
    assert updated.status_code == 200
    payload = updated.json()
    assert payload["current_time"] == "灵纪1042年3月18日 午后"
    assert payload["current_location"] == "泽源·潮汐城·港口"
    assert payload["characters"] == ["柳璃", "小溪"]
    assert payload["updated_at"]
