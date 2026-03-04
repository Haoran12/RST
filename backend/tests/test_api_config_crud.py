from __future__ import annotations

from pathlib import Path

import pytest

from app.models.api_config import DEFAULT_BASE_URLS, ProviderType
from app.providers.base import BaseProvider, ProviderError
from app.storage.encryption import decrypt_api_key
from app.storage.file_io import read_json


@pytest.mark.asyncio
async def test_create_returns_preview(async_client, sample_api_config) -> None:
    response = await async_client.post("/api-configs", json=sample_api_config)
    assert response.status_code == 201
    payload = response.json()
    assert "api_key_preview" in payload
    assert "api_key" not in payload
    assert "encrypted_key" not in payload
    assert payload["api_key_preview"].endswith("1234")


@pytest.mark.asyncio
async def test_list_returns_summaries(async_client, sample_api_config) -> None:
    await async_client.post("/api-configs", json=sample_api_config)
    await async_client.post(
        "/api-configs",
        json={**sample_api_config, "name": "Secondary", "api_key": "sk-test-9999"},
    )

    response = await async_client.get("/api-configs")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert set(data[0].keys()) == {"id", "name", "provider", "model"}


@pytest.mark.asyncio
async def test_get_detail_returns_preview(async_client, sample_api_config) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]

    response = await async_client.get(f"/api-configs/{config_id}")
    assert response.status_code == 200
    payload = response.json()
    assert payload["id"] == config_id
    assert payload["api_key_preview"].startswith("****")


@pytest.mark.asyncio
async def test_update_name_only_preserves_fields(async_client, sample_api_config) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]
    original = created.json()

    updated = await async_client.put(f"/api-configs/{config_id}", json={"name": "Renamed"})
    assert updated.status_code == 200
    payload = updated.json()
    assert payload["name"] == "Renamed"
    assert payload["provider"] == original["provider"]
    assert payload["base_url"] == original["base_url"]
    assert payload["model"] == original["model"]


@pytest.mark.asyncio
async def test_update_api_key_regenerates_preview(async_client, sample_api_config) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]

    updated = await async_client.put(
        f"/api-configs/{config_id}", json={"api_key": "sk-test-0000"}
    )
    assert updated.status_code == 200
    payload = updated.json()
    assert payload["api_key_preview"].endswith("0000")


@pytest.mark.asyncio
async def test_update_without_api_key_keeps_encrypted(
    async_client, sample_api_config, tmp_data_dir: Path
) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]

    stored = read_json(tmp_data_dir / "api_configs" / f"{config_id}.json")
    assert isinstance(stored, dict)
    encrypted_before = stored["encrypted_key"]
    plain_before = decrypt_api_key(encrypted_before)

    await async_client.put(f"/api-configs/{config_id}", json={"name": "Updated"})

    stored_after = read_json(tmp_data_dir / "api_configs" / f"{config_id}.json")
    assert isinstance(stored_after, dict)
    encrypted_after = stored_after["encrypted_key"]
    plain_after = decrypt_api_key(encrypted_after)

    assert plain_before == plain_after


@pytest.mark.asyncio
async def test_delete_removes_config(async_client, sample_api_config) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]

    deleted = await async_client.delete(f"/api-configs/{config_id}")
    assert deleted.status_code == 204

    missing = await async_client.get(f"/api-configs/{config_id}")
    assert missing.status_code == 404


@pytest.mark.asyncio
async def test_get_missing_returns_404(async_client) -> None:
    response = await async_client.get("/api-configs/missing")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_duplicate_name_returns_409(async_client, sample_api_config) -> None:
    await async_client.post("/api-configs", json=sample_api_config)
    duplicate = await async_client.post("/api-configs", json=sample_api_config)
    assert duplicate.status_code == 409


@pytest.mark.asyncio
async def test_base_url_defaults(async_client, sample_api_config) -> None:
    response = await async_client.post("/api-configs", json=sample_api_config)
    assert response.status_code == 201
    payload = response.json()
    assert payload["base_url"] == DEFAULT_BASE_URLS[ProviderType.OPENAI]


@pytest.mark.asyncio
async def test_temperature_is_normalized_when_stored(
    async_client, sample_api_config, tmp_data_dir: Path
) -> None:
    create_response = await async_client.post(
        "/api-configs",
        json={**sample_api_config, "temperature": 0.30000000000000004},
    )
    assert create_response.status_code == 201
    created_payload = create_response.json()
    assert created_payload["temperature"] == 0.3

    config_id = created_payload["id"]
    update_response = await async_client.put(
        f"/api-configs/{config_id}",
        json={"temperature": 0.35000000000000003},
    )
    assert update_response.status_code == 200
    updated_payload = update_response.json()
    assert updated_payload["temperature"] == 0.35

    stored = read_json(tmp_data_dir / "api_configs" / f"{config_id}.json")
    assert isinstance(stored, dict)
    assert stored["temperature"] == 0.35


class _StubProvider(BaseProvider):
    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        return ["m1", "m2"]

    async def chat(self, *args: object, **kwargs: object) -> object:
        raise NotImplementedError


class _FailingProvider(BaseProvider):
    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        raise ProviderError("boom")

    async def chat(self, *args: object, **kwargs: object) -> object:
        raise NotImplementedError


@pytest.mark.asyncio
async def test_models_endpoint_success(async_client, sample_api_config, monkeypatch) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]

    monkeypatch.setattr(
        "app.routers.api_configs.get_provider", lambda _: _StubProvider()
    )

    response = await async_client.get(f"/api-configs/{config_id}/models")
    assert response.status_code == 200
    payload = response.json()
    assert payload["models"] == ["m1", "m2"]


@pytest.mark.asyncio
async def test_models_endpoint_failure(async_client, sample_api_config, monkeypatch) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]

    monkeypatch.setattr(
        "app.routers.api_configs.get_provider", lambda _: _FailingProvider()
    )

    response = await async_client.get(f"/api-configs/{config_id}/models")
    assert response.status_code == 200
    payload = response.json()
    assert payload["models"] == []
    assert payload["error"] == "boom"


@pytest.mark.asyncio
async def test_delete_in_use_returns_409(async_client, sample_api_config) -> None:
    created = await async_client.post("/api-configs", json=sample_api_config)
    config_id = created.json()["id"]

    preset = await async_client.post("/presets", json={"name": "PresetForConfig"})
    preset_id = preset.json()["id"]

    session_payload = {
        "name": "SessionWithConfig",
        "mode": "RST",
        "main_api_config_id": config_id,
        "preset_id": preset_id,
    }
    session_response = await async_client.post("/sessions", json=session_payload)
    assert session_response.status_code == 201

    deleted = await async_client.delete(f"/api-configs/{config_id}")
    assert deleted.status_code == 409
