from __future__ import annotations

import pytest

from app.models.preset import SYSTEM_ENTRIES


async def _create_api_config(async_client, sample_api_config: dict) -> str:
    response = await async_client.post("/api-configs", json=sample_api_config)
    assert response.status_code == 201
    return response.json()["id"]


async def _create_preset(async_client, name: str = "Preset A") -> dict:
    response = await async_client.post("/presets", json={"name": name})
    assert response.status_code == 201
    return response.json()


async def _create_session(async_client, name: str, config_id: str, preset_id: str):
    payload = {
        "name": name,
        "mode": "RST",
        "main_api_config_id": config_id,
        "preset_id": preset_id,
    }
    return await async_client.post("/sessions", json=payload)


@pytest.mark.asyncio
async def test_create_preset_includes_system_entries(async_client) -> None:
    created = await _create_preset(async_client)
    entries = created["entries"]
    entry_names = {entry["name"] for entry in entries}
    assert set(SYSTEM_ENTRIES).issubset(entry_names)


@pytest.mark.asyncio
async def test_duplicate_preset_name_returns_409(async_client) -> None:
    await _create_preset(async_client, "DupPreset")
    duplicate = await async_client.post("/presets", json={"name": "DupPreset"})
    assert duplicate.status_code == 409


@pytest.mark.asyncio
async def test_list_presets(async_client) -> None:
    await _create_preset(async_client, "Preset A")
    await _create_preset(async_client, "Preset B")

    response = await async_client.get("/presets")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert set(data[0].keys()) == {"id", "name"}


@pytest.mark.asyncio
async def test_get_preset_detail(async_client) -> None:
    created = await _create_preset(async_client, "DetailPreset")
    preset_id = created["id"]

    response = await async_client.get(f"/presets/{preset_id}")
    assert response.status_code == 200
    payload = response.json()
    assert payload["id"] == preset_id
    assert payload["name"] == "DetailPreset"


@pytest.mark.asyncio
async def test_update_preset_reorders_entries(async_client) -> None:
    created = await _create_preset(async_client, "ReorderPreset")
    preset_id = created["id"]
    entries = created["entries"]
    reordered = list(reversed(entries))

    response = await async_client.put(
        f"/presets/{preset_id}", json={"entries": reordered}
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["entries"][0]["name"] == reordered[0]["name"]


@pytest.mark.asyncio
async def test_update_preset_missing_system_entries_auto_append(async_client) -> None:
    created = await _create_preset(async_client, "MissingSystem")
    preset_id = created["id"]

    entries = [entry for entry in created["entries"] if entry["name"] != "scene"]
    response = await async_client.put(
        f"/presets/{preset_id}", json={"entries": entries}
    )
    assert response.status_code == 200
    payload = response.json()
    names = [entry["name"] for entry in payload["entries"]]
    assert "scene" in names


@pytest.mark.asyncio
async def test_update_preset_conflicting_system_name_returns_400(async_client) -> None:
    created = await _create_preset(async_client, "ConflictPreset")
    preset_id = created["id"]
    entries = list(created["entries"])
    entries.append(
        {
            "name": "scene",
            "role": "assistant",
            "content": "custom",
            "disabled": False,
            "comment": "",
        }
    )

    response = await async_client.put(
        f"/presets/{preset_id}", json={"entries": entries}
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_delete_preset(async_client) -> None:
    created = await _create_preset(async_client, "DeletePreset")
    preset_id = created["id"]

    deleted = await async_client.delete(f"/presets/{preset_id}")
    assert deleted.status_code == 204

    missing = await async_client.get(f"/presets/{preset_id}")
    assert missing.status_code == 404


@pytest.mark.asyncio
async def test_delete_preset_in_use_returns_409(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset = await _create_preset(async_client, "InUsePreset")
    preset_id = preset["id"]

    session_response = await _create_session(async_client, "SessionUsesPreset", config_id, preset_id)
    assert session_response.status_code == 201

    deleted = await async_client.delete(f"/presets/{preset_id}")
    assert deleted.status_code == 409


@pytest.mark.asyncio
async def test_rename_preset(async_client) -> None:
    created = await _create_preset(async_client, "OldPreset")
    preset_id = created["id"]

    renamed = await async_client.patch(
        f"/presets/{preset_id}/rename", json={"new_name": "NewPreset"}
    )
    assert renamed.status_code == 200
    payload = renamed.json()
    assert payload["name"] == "NewPreset"


@pytest.mark.asyncio
async def test_rename_preset_duplicate_returns_409(async_client) -> None:
    first = await _create_preset(async_client, "PresetOne")
    await _create_preset(async_client, "PresetTwo")

    response = await async_client.patch(
        f"/presets/{first['id']}/rename", json={"new_name": "PresetTwo"}
    )
    assert response.status_code == 409

