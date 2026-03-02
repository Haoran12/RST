from __future__ import annotations

import json

import pytest

from app.providers.base import BaseProvider, ProviderChatResult


class _ImportLlmStubProvider(BaseProvider):
    def __init__(self, text: str | list[str]) -> None:
        self._texts = [text] if isinstance(text, str) else text
        self.calls = 0

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
        self.calls += 1
        index = min(self.calls - 1, len(self._texts) - 1)
        return ProviderChatResult(
            text=self._texts[index],
            request={"messages": messages, "model": model},
            response={"choices": [{"finish_reason": "stop"}]},
        )


async def _create_api_config(async_client, sample_api_config: dict) -> str:
    response = await async_client.post("/api-configs", json=sample_api_config)
    assert response.status_code == 201
    return response.json()["id"]


async def _create_preset(async_client, name: str = "LoreConverterPreset") -> str:
    response = await async_client.post("/presets", json={"name": name})
    assert response.status_code == 201
    return response.json()["id"]


async def _create_session(
    async_client,
    name: str,
    main_config_id: str,
    preset_id: str,
    scheduler_config_id: str | None = None,
) -> None:
    payload = {
        "name": name,
        "mode": "RST",
        "main_api_config_id": main_config_id,
        "preset_id": preset_id,
        "scheduler_api_config_id": scheduler_config_id,
    }
    response = await async_client.post("/sessions", json=payload)
    assert response.status_code == 201


def _upload_payload(payload: dict) -> dict[str, tuple[str, bytes, str]]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    return {"file": ("legacy-lore.json", body, "application/json")}


@pytest.mark.asyncio
async def test_import_lore_converts_entries_and_characters(
    async_client,
    sample_api_config,
) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ImportLoreSession", config_id, preset_id, config_id)

    source_payload = {
        "scanDepth": 4,
        "entries": [
            {
                "id": "legacy-world-1",
                "name": "world_overview",
                "category": "world_base",
                "disable": False,
                "content": "This is world setup.",
                "constant": True,
                "key": ["world", "overview"],
            },
            {
                "id": "legacy-char-1",
                "name": "changli",
                "category": "characters",
                "disable": False,
                "content": (
                    "# YAML character setup\n"
                    "name: changli\n"
                    "race: human\n"
                    "identities: [governor]\n"
                    "relationships:\n"
                    "  - jinsi: ally\n"
                    "  - court_official: strategic rival\n"
                    "appearance:\n"
                    "  overall_impression: calm and restrained\n"
                    "abilities:\n"
                    "  - fire art\n"
                ),
                "constant": False,
                "key": ["character", "core"],
            },
        ],
    }

    response = await async_client.post(
        "/sessions/ImportLoreSession/lores/import",
        files=_upload_payload(source_payload),
    )
    assert response.status_code == 200
    report = response.json()

    assert report["statistics"]["total_source_entries"] == 2
    assert report["statistics"]["converted_entries"] == 1
    assert report["statistics"]["converted_characters"] == 1
    assert "legacy-world-1" in report["id_mapping"]
    assert "legacy-char-1" in report["id_mapping"]
    assert len(report["actions"]) == 2
    assert report["category_summary"]["world_base"] == 1
    assert report["category_summary"]["character"] == 1
    character_action = next(item for item in report["actions"] if item["source_id"] == "legacy-char-1")
    assert character_action["action"] == "character_structured_created"
    assert len(character_action["created_ids"]) == 1

    entries_response = await async_client.get(
        "/sessions/ImportLoreSession/lores/entries",
        params={"category": "world_base"},
    )
    assert entries_response.status_code == 200
    assert entries_response.json()["total"] == 1

    characters_response = await async_client.get("/sessions/ImportLoreSession/lores/characters")
    assert characters_response.status_code == 200
    assert characters_response.json()["total"] == 1
    character = characters_response.json()["characters"][0]
    assert character["strength"] == 10

    relationship_targets = [item["target"] for item in character["relationship"]]
    assert "jinsi" in relationship_targets
    assert "court_official" in relationship_targets
    assert character["forms"][0]["features"]


@pytest.mark.asyncio
async def test_import_lore_rejects_invalid_json(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ImportLoreInvalidJson", config_id, preset_id, config_id)

    response = await async_client.post(
        "/sessions/ImportLoreInvalidJson/lores/import",
        files={"file": ("broken.json", b"{invalid", "application/json")},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid JSON file"


@pytest.mark.asyncio
async def test_import_lore_rejects_closed_session(async_client, sample_api_config) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ImportLoreClosed", config_id, preset_id, config_id)

    closed = await async_client.put("/sessions/ImportLoreClosed", json={"is_closed": True})
    assert closed.status_code == 200
    assert closed.json()["is_closed"] is True

    payload = {"entries": []}
    response = await async_client.post(
        "/sessions/ImportLoreClosed/lores/import",
        files=_upload_payload(payload),
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Session is closed"


@pytest.mark.asyncio
async def test_import_lore_can_split_faction_embedded_characters(
    async_client,
    sample_api_config,
) -> None:
    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client)
    await _create_session(async_client, "ImportLoreSplitFaction", config_id, preset_id, config_id)

    source_payload = {
        "entries": [
            {
                "id": "legacy-faction-1",
                "name": "river_house_wu",
                "category": "factions",
                "disable": False,
                "constant": False,
                "key": ["house", "river"],
                "content": (
                    "overview: river house wu is an old local family.\n"
                    "name: wu_yue\n"
                    "race: human\n"
                    "personality: cautious\n"
                    "name: wu_xuan\n"
                    "race: human\n"
                    "personality: decisive\n"
                ),
            }
        ]
    }

    response = await async_client.post(
        "/sessions/ImportLoreSplitFaction/lores/import",
        params={"split_faction_characters": True},
        files=_upload_payload(source_payload),
    )
    assert response.status_code == 200
    report = response.json()
    assert report["statistics"]["converted_entries"] == 1
    assert report["statistics"]["converted_characters"] == 2
    assert any(item["action"] == "faction_split_into_characters" for item in report["actions"])
    assert report["category_summary"]["faction"] == 1
    assert report["category_summary"]["character"] == 2
    assert any(item["type"] == "faction_embedded_characters" for item in report["warnings"])

    characters_response = await async_client.get("/sessions/ImportLoreSplitFaction/lores/characters")
    assert characters_response.status_code == 200
    assert characters_response.json()["total"] == 2
    for character in characters_response.json()["characters"]:
        assert character["faction"] == "river_house_wu"


@pytest.mark.asyncio
async def test_import_lore_llm_fallback_can_parse_invalid_yaml(
    async_client,
    sample_api_config,
    monkeypatch,
) -> None:
    stub_provider = _ImportLlmStubProvider(
        json.dumps(
            {
                "species": "human",
                "identities": ["merchant", "traveler"],
                "personality": "friendly",
                "relationships": [{"wu_zhong": "village friend"}],
            },
            ensure_ascii=False,
        )
    )
    monkeypatch.setattr("app.services.lore_converter.get_provider", lambda _: stub_provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client, "ImportLoreLlmFallbackPreset")
    await _create_session(async_client, "ImportLoreLlmFallback", config_id, preset_id, config_id)

    source_payload = {
        "entries": [
            {
                "id": "legacy-char-llm-1",
                "name": "lin_mu",
                "category": "characters",
                "disable": False,
                "content": (
                    "# character profile\n"
                    "name: lin_mu\n"
                    "abilities:\n"
                    "  spirit_level: 4k\n"
                    "  masters basic sword and fire skills\n"
                ),
                "constant": False,
                "key": ["character"],
            }
        ]
    }

    response = await async_client.post(
        "/sessions/ImportLoreLlmFallback/lores/import",
        params={"llm_fallback": True},
        files=_upload_payload(source_payload),
    )
    assert response.status_code == 200
    report = response.json()

    action = next(item for item in report["actions"] if item["source_id"] == "legacy-char-llm-1")
    assert action["action"] == "character_llm_structured_created"
    assert all(item["type"] != "yaml_parse_error" for item in report["warnings"])

    characters_response = await async_client.get("/sessions/ImportLoreLlmFallback/lores/characters")
    assert characters_response.status_code == 200
    character = characters_response.json()["characters"][0]
    assert character["name"] == "lin_mu"
    assert character["race"] == "human"
    assert character["strength"] == 10
    assert character["relationship"][0]["target"] == "wu_zhong"


@pytest.mark.asyncio
async def test_import_lore_llm_fallback_batches_multiple_characters(
    async_client,
    sample_api_config,
    monkeypatch,
) -> None:
    stub_provider = _ImportLlmStubProvider(
        json.dumps(
            {
                "items": [
                    {
                        "source_id": "legacy-char-batch-1",
                        "parsed": {
                            "species": "human",
                            "identities": ["merchant"],
                            "personality": "friendly",
                        },
                    },
                    {
                        "source_id": "legacy-char-batch-2",
                        "parsed": {
                            "race": "elf",
                            "relationships": [{"lin_mu": "friend"}],
                        },
                    },
                ]
            },
            ensure_ascii=False,
        )
    )
    monkeypatch.setattr("app.services.lore_converter.get_provider", lambda _: stub_provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client, "ImportLoreLlmBatchPreset")
    await _create_session(async_client, "ImportLoreLlmBatch", config_id, preset_id, config_id)

    source_payload = {
        "entries": [
            {
                "id": "legacy-char-batch-1",
                "name": "lin_mu",
                "category": "characters",
                "disable": False,
                "content": (
                    "# profile\n"
                    "name: lin_mu\n"
                    "abilities:\n"
                    "  spirit_level: 4k\n"
                    "  masters basic sword and fire skills\n"
                ),
                "constant": False,
                "key": ["character"],
            },
            {
                "id": "legacy-char-batch-2",
                "name": "qing_he",
                "category": "characters",
                "disable": False,
                "content": (
                    "# profile\n"
                    "name: qing_he\n"
                    "abilities:\n"
                    "  spirit_level: 5k\n"
                    "  masters water and wind skills\n"
                ),
                "constant": False,
                "key": ["character"],
            },
        ]
    }

    response = await async_client.post(
        "/sessions/ImportLoreLlmBatch/lores/import",
        params={"llm_fallback": True},
        files=_upload_payload(source_payload),
    )
    assert response.status_code == 200
    report = response.json()

    assert stub_provider.calls == 1
    actions = [item for item in report["actions"] if item["target_category"] == "character"]
    assert len(actions) == 2
    assert all(item["action"] == "character_llm_structured_created" for item in actions)

    characters_response = await async_client.get("/sessions/ImportLoreLlmBatch/lores/characters")
    assert characters_response.status_code == 200
    assert characters_response.json()["total"] == 2
    by_name = {item["name"]: item for item in characters_response.json()["characters"]}
    assert by_name["lin_mu"]["race"] == "human"
    assert by_name["qing_he"]["race"] == "elf"
    assert by_name["qing_he"]["relationship"][0]["target"] == "lin_mu"


@pytest.mark.asyncio
async def test_import_lore_llm_fallback_still_keeps_raw_content_when_llm_output_invalid(
    async_client,
    sample_api_config,
    monkeypatch,
) -> None:
    stub_provider = _ImportLlmStubProvider("not-a-json-object")
    monkeypatch.setattr("app.services.lore_converter.get_provider", lambda _: stub_provider)

    config_id = await _create_api_config(async_client, sample_api_config)
    preset_id = await _create_preset(async_client, "ImportLoreLlmFallbackFailPreset")
    await _create_session(async_client, "ImportLoreLlmFallbackFail", config_id, preset_id, config_id)

    content = (
        "# character profile\n"
        "name: wu_zhong\n"
        "abilities:\n"
        "  spirit_level: 8k\n"
        "  masters basic sword and fire skills\n"
    )
    source_payload = {
        "entries": [
            {
                "id": "legacy-char-llm-2",
                "name": "wu_zhong",
                "category": "characters",
                "disable": False,
                "content": content,
                "constant": False,
                "key": ["character"],
            }
        ]
    }

    response = await async_client.post(
        "/sessions/ImportLoreLlmFallbackFail/lores/import",
        params={"llm_fallback": True},
        files=_upload_payload(source_payload),
    )
    assert response.status_code == 200
    report = response.json()

    action = next(item for item in report["actions"] if item["source_id"] == "legacy-char-llm-2")
    assert action["action"] == "character_yaml_fallback_created"
    warning_types = {item["type"] for item in report["warnings"]}
    assert "llm_parse_error" in warning_types
    assert "yaml_parse_error" in warning_types

    characters_response = await async_client.get("/sessions/ImportLoreLlmFallbackFail/lores/characters")
    assert characters_response.status_code == 200
    character = characters_response.json()["characters"][0]
    assert character["forms"][0]["features"] == content
