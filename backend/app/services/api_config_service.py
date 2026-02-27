from __future__ import annotations

from pathlib import Path

from app.config import settings
from app.models import generate_id
from app.models.api_config import (
    ApiConfig,
    ApiConfigCreate,
    ApiConfigResponse,
    ApiConfigSummary,
    ApiConfigUpdate,
    DEFAULT_BASE_URLS,
)
from app.storage.encryption import EncryptionError, decrypt_api_key, encrypt_api_key
from app.storage.file_io import read_json, write_json


class ApiConfigNotFoundError(RuntimeError):
    """Raised when an API config cannot be found."""

    def __init__(self, config_id: str) -> None:
        super().__init__(f"API config '{config_id}' not found")
        self.config_id = config_id


class ApiConfigNameExistsError(RuntimeError):
    """Raised when a config name already exists."""

    def __init__(self, name: str) -> None:
        super().__init__(f"API config name '{name}' already exists")
        self.name = name


class ApiConfigInUseError(RuntimeError):
    def __init__(self, config_id: str, session_names: list[str]) -> None:
        names = ", ".join(session_names)
        super().__init__(f"API config '{config_id}' is used by sessions: {names}")
        self.config_id = config_id
        self.session_names = session_names


def _configs_dir() -> Path:
    return settings.data_path / "api_configs"


def _config_path(config_id: str) -> Path:
    return _configs_dir() / f"{config_id}.json"


def _api_key_preview(plain_key: str) -> str:
    tail = plain_key[-4:] if len(plain_key) >= 4 else plain_key
    return f"****{tail}"


def _load_config(config_id: str) -> ApiConfig:
    data = read_json(_config_path(config_id))
    if data is None:
        raise ApiConfigNotFoundError(config_id)
    return ApiConfig.model_validate(data)


def _write_config(config: ApiConfig) -> None:
    write_json(_config_path(config.id), config.model_dump(mode="json"))


def _ensure_unique_name(name: str, ignore_id: str | None = None) -> None:
    configs_dir = _configs_dir()
    configs_dir.mkdir(parents=True, exist_ok=True)
    for path in configs_dir.glob("*.json"):
        data = read_json(path)
        if not isinstance(data, dict):
            continue
        if data.get("name") == name and data.get("id") != ignore_id:
            raise ApiConfigNameExistsError(name)


def _to_response(config: ApiConfig) -> ApiConfigResponse:
    plain_key = decrypt_api_key(config.encrypted_key)
    return ApiConfigResponse(
        id=config.id,
        name=config.name,
        provider=config.provider,
        base_url=config.base_url,
        api_key_preview=_api_key_preview(plain_key),
        model=config.model,
        temperature=config.temperature,
        max_tokens=config.max_tokens,
        stream=config.stream,
        version=config.version,
    )


def create_api_config(payload: ApiConfigCreate) -> ApiConfigResponse:
    _ensure_unique_name(payload.name)
    config_id = generate_id()
    base_url = payload.base_url or DEFAULT_BASE_URLS[payload.provider]
    encrypted_key = encrypt_api_key(payload.api_key)
    config = ApiConfig(
        id=config_id,
        name=payload.name,
        provider=payload.provider,
        base_url=base_url,
        encrypted_key=encrypted_key,
        model=payload.model,
        temperature=payload.temperature,
        max_tokens=payload.max_tokens,
        stream=payload.stream,
    )
    _write_config(config)
    return _to_response(config)


def list_api_configs() -> list[ApiConfigSummary]:
    configs_dir = _configs_dir()
    configs_dir.mkdir(parents=True, exist_ok=True)
    summaries: list[ApiConfigSummary] = []
    for path in configs_dir.glob("*.json"):
        data = read_json(path)
        if not isinstance(data, dict):
            continue
        try:
            config = ApiConfig.model_validate(data)
        except Exception:
            continue
        summaries.append(
            ApiConfigSummary(
                id=config.id,
                name=config.name,
                provider=config.provider,
                model=config.model,
            )
        )
    return sorted(summaries, key=lambda item: item.name.lower())


def get_api_config(config_id: str) -> ApiConfigResponse:
    config = _load_config(config_id)
    return _to_response(config)


def get_api_config_storage(config_id: str) -> ApiConfig:
    return _load_config(config_id)


def update_api_config(config_id: str, payload: ApiConfigUpdate) -> ApiConfigResponse:
    config = _load_config(config_id)
    if payload.name and payload.name != config.name:
        _ensure_unique_name(payload.name, ignore_id=config_id)

    provider = payload.provider or config.provider
    if payload.base_url is not None:
        base_url = payload.base_url
    elif payload.provider is not None:
        base_url = DEFAULT_BASE_URLS[provider]
    else:
        base_url = config.base_url

    encrypted_key = config.encrypted_key
    if payload.api_key is not None:
        encrypted_key = encrypt_api_key(payload.api_key)

    updated = config.model_copy(
        update={
            "name": payload.name if payload.name is not None else config.name,
            "provider": provider,
            "base_url": base_url,
            "encrypted_key": encrypted_key,
            "model": payload.model if payload.model is not None else config.model,
            "temperature": (
                payload.temperature if payload.temperature is not None else config.temperature
            ),
            "max_tokens": payload.max_tokens if payload.max_tokens is not None else config.max_tokens,
            "stream": payload.stream if payload.stream is not None else config.stream,
        }
    )
    _write_config(updated)
    return _to_response(updated)


def delete_api_config(config_id: str) -> None:
    path = _config_path(config_id)
    if not path.exists():
        raise ApiConfigNotFoundError(config_id)
    sessions_dir = settings.data_path / "sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)
    in_use_by: list[str] = []
    for session_dir in sessions_dir.iterdir():
        if not session_dir.is_dir():
            continue
        data = read_json(session_dir / "session.json")
        if not isinstance(data, dict):
            continue
        if data.get("main_api_config_id") == config_id or data.get(
            "scheduler_api_config_id"
        ) == config_id:
            name = data.get("name")
            if isinstance(name, str):
                in_use_by.append(name)

    if in_use_by:
        raise ApiConfigInUseError(config_id, sorted(in_use_by))
    path.unlink()


__all__ = [
    "ApiConfigNotFoundError",
    "ApiConfigNameExistsError",
    "ApiConfigInUseError",
    "EncryptionError",
    "create_api_config",
    "list_api_configs",
    "get_api_config",
    "get_api_config_storage",
    "update_api_config",
    "delete_api_config",
]
