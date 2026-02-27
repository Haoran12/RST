from __future__ import annotations

from pathlib import Path

import pytest

from app.models.session import NAME_PATTERN


async def _create_api_config(async_client, sample_api_config: dict) -> str:
    response = await async_client.post("/api-configs", json=sample_api_config)
    assert response.status_code == 201
    return response.json()["id"]


async def _create_preset(async_client, name: str = "Preset A") -> str:
    response = await async_client.post("/presets", json={"name": name})
    assert response.status_code == 201
    return response.json()["id"]


async def _create_session(async_client, name: str, config_id: str, preset_id: str):
    payload = {
        "name": name,
        "mode": "RST",
        "main_api_config_id": config_id,
        "preset_id": preset_id,
    }
    return await async_client.post("/sessions", json=payload)


@pytest.mark.asyncio
async def test_create_session_creates_files(async_client, sample_api_config, tmp_data_dir: Path) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    response = await _create_session(async_client, "Session One", config_id, preset_id)
    assert response.status_code == 201

    session_dir = tmp_data_dir / "sessions" / "Session One"
    assert (session_dir / "session.json").exists()
    assert (session_dir / "messages.json").exists()
    assert (session_dir / "rst_data" / "characters").is_dir()
    assert (session_dir / "rst_data" / ".index").is_dir()


@pytest.mark.asyncio
async def test_create_duplicate_name_returns_409(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    await _create_session(async_client, "DupSession", config_id, preset_id)
    duplicate = await _create_session(async_client, "DupSession", config_id, preset_id)
    assert duplicate.status_code == 409


@pytest.mark.asyncio
async def test_create_invalid_name_returns_422(async_client, sample_api_config) -> None:
    assert not NAME_PATTERN.fullmatch("bad!")
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    response = await _create_session(async_client, "bad!", config_id, preset_id)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_list_sessions_sorted_by_updated_at(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    await _create_session(async_client, "Alpha", config_id, preset_id)
    await _create_session(async_client, "Beta", config_id, preset_id)

    # Update Alpha to bump updated_at
    await async_client.put("/sessions/Alpha", json={"mode": "ST"})

    response = await async_client.get("/sessions")
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 2
    assert items[0]["name"] == "Alpha"


@pytest.mark.asyncio
async def test_get_session_detail(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    await _create_session(async_client, "DetailSession", config_id, preset_id)
    response = await async_client.get("/sessions/DetailSession")
    assert response.status_code == 200
    payload = response.json()
    assert payload["name"] == "DetailSession"
    assert payload["is_closed"] is False
    assert payload["main_api_config_id"] == config_id
    assert payload["preset_id"] == preset_id


@pytest.mark.asyncio
async def test_update_session_partial(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    created = await _create_session(async_client, "EditSession", config_id, preset_id)
    original = created.json()

    updated = await async_client.put("/sessions/EditSession", json={"mode": "ST"})
    assert updated.status_code == 200
    payload = updated.json()
    assert payload["mode"] == "ST"
    assert payload["is_closed"] is False
    assert payload["main_api_config_id"] == original["main_api_config_id"]
    assert payload["preset_id"] == original["preset_id"]


@pytest.mark.asyncio
async def test_update_session_can_toggle_closed(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ClosableSession", config_id, preset_id)

    closed = await async_client.put("/sessions/ClosableSession", json={"is_closed": True})
    assert closed.status_code == 200
    assert closed.json()["is_closed"] is True

    reopened = await async_client.put("/sessions/ClosableSession", json={"is_closed": False})
    assert reopened.status_code == 200
    assert reopened.json()["is_closed"] is False


@pytest.mark.asyncio
async def test_delete_session_removes_directory(async_client, sample_api_config, tmp_data_dir: Path) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    await _create_session(async_client, "DeleteSession", config_id, preset_id)

    deleted = await async_client.delete("/sessions/DeleteSession")
    assert deleted.status_code == 204
    assert not (tmp_data_dir / "sessions" / "DeleteSession").exists()

    missing = await async_client.get("/sessions/DeleteSession")
    assert missing.status_code == 404


@pytest.mark.asyncio
async def test_rename_session(async_client, sample_api_config, tmp_data_dir: Path) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    await _create_session(async_client, "OldName", config_id, preset_id)

    renamed = await async_client.patch("/sessions/OldName/rename", json={"new_name": "NewName"})
    assert renamed.status_code == 200

    assert (tmp_data_dir / "sessions" / "NewName" / "session.json").exists()
    assert not (tmp_data_dir / "sessions" / "OldName").exists()

    payload = renamed.json()
    assert payload["name"] == "NewName"


@pytest.mark.asyncio
async def test_rename_session_duplicate_returns_409(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)

    await _create_session(async_client, "SessionA", config_id, preset_id)
    await _create_session(async_client, "SessionB", config_id, preset_id)

    response = await async_client.patch(
        "/sessions/SessionA/rename", json={"new_name": "SessionB"}
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_get_missing_session_returns_404(async_client) -> None:
    response = await async_client.get("/sessions/missing")
    assert response.status_code == 404

