from __future__ import annotations

from collections import Counter
from pathlib import Path

from app.config import settings
from app.models import generate_id
from app.models.preset import (
    Preset,
    PresetCreate,
    PresetEntry,
    PresetRename,
    PresetResponse,
    PresetSummary,
    PresetUpdate,
    SYSTEM_ENTRIES,
)
from app.storage.file_io import read_json, write_json

DEFAULT_PRESET_ENTRIES = [
    PresetEntry(name="Main_Prompt", role="system", content="You are a helpful assistant."),
    PresetEntry(name="lores", role="system", content=""),
    PresetEntry(name="user_description", role="system", content=""),
    PresetEntry(name="chat_history", role="system", content=""),
    PresetEntry(name="scene", role="system", content=""),
    PresetEntry(name="user_input", role="user", content=""),
]

_DEFAULT_ENTRY_MAP = {entry.name: entry for entry in DEFAULT_PRESET_ENTRIES}


class PresetNotFoundError(RuntimeError):
    def __init__(self, preset_id: str) -> None:
        super().__init__(f"Preset '{preset_id}' not found")
        self.preset_id = preset_id


class PresetNameExistsError(RuntimeError):
    def __init__(self, name: str) -> None:
        super().__init__(f"Preset name '{name}' already exists")
        self.name = name


class PresetInUseError(RuntimeError):
    def __init__(self, preset_id: str, session_names: list[str]) -> None:
        names = ", ".join(session_names)
        super().__init__(f"Preset '{preset_id}' is used by sessions: {names}")
        self.preset_id = preset_id
        self.session_names = session_names


class PresetValidationError(RuntimeError):
    def __init__(self, detail: str) -> None:
        super().__init__(detail)


def _presets_dir() -> Path:
    return settings.data_path / "presets"


def _preset_path(preset_id: str) -> Path:
    return _presets_dir() / f"{preset_id}.json"


def _load_preset(preset_id: str) -> Preset:
    data = read_json(_preset_path(preset_id))
    if data is None:
        raise PresetNotFoundError(preset_id)
    return Preset.model_validate(data)


def _write_preset(preset: Preset) -> None:
    write_json(_preset_path(preset.id), preset.model_dump(mode="json"))


def _ensure_unique_name(name: str, ignore_id: str | None = None) -> None:
    presets_dir = _presets_dir()
    presets_dir.mkdir(parents=True, exist_ok=True)
    for path in presets_dir.glob("*.json"):
        data = read_json(path)
        if not isinstance(data, dict):
            continue
        if data.get("name") == name and data.get("id") != ignore_id:
            raise PresetNameExistsError(name)


def _to_response(preset: Preset) -> PresetResponse:
    return PresetResponse(
        id=preset.id,
        name=preset.name,
        entries=preset.entries,
        version=preset.version,
    )


def _validate_and_normalize_entries(entries: list[PresetEntry]) -> list[PresetEntry]:
    """
    Validate and ensure system entries exist.
    - Ensure each SYSTEM_ENTRIES appears at most once
    - Custom entries cannot reuse system names
    - Missing system entries are appended at the end
    """
    names = [entry.name for entry in entries]
    counts = Counter(names)
    for name, count in counts.items():
        if name in SYSTEM_ENTRIES and count > 1:
            raise PresetValidationError(
                f"Entry name '{name}' conflicts with system entry"
            )

    normalized = list(entries)
    existing_names = set(names)
    for name in SYSTEM_ENTRIES:
        if name not in existing_names:
            default = _DEFAULT_ENTRY_MAP[name]
            normalized.append(
                PresetEntry(
                    name=default.name,
                    role=default.role,
                    content=default.content,
                    disabled=default.disabled,
                    comment=default.comment,
                )
            )
    return normalized


def ensure_default_preset(data_dir: Path) -> str:
    """Ensure a default preset exists and return its id."""
    presets_dir = data_dir / "presets"
    presets_dir.mkdir(parents=True, exist_ok=True)

    for path in sorted(presets_dir.glob("*.json")):
        data = read_json(path)
        if isinstance(data, dict) and isinstance(data.get("id"), str):
            return data["id"]

    preset_id = generate_id()
    preset = Preset(id=preset_id, name="Default", entries=DEFAULT_PRESET_ENTRIES)
    write_json(presets_dir / f"{preset_id}.json", preset.model_dump(mode="json"))
    return preset_id


def create_preset(payload: PresetCreate) -> PresetResponse:
    _ensure_unique_name(payload.name)
    preset_id = generate_id()
    preset = Preset(id=preset_id, name=payload.name, entries=DEFAULT_PRESET_ENTRIES)
    _write_preset(preset)
    return _to_response(preset)


def list_presets() -> list[PresetSummary]:
    presets_dir = _presets_dir()
    presets_dir.mkdir(parents=True, exist_ok=True)
    summaries: list[PresetSummary] = []
    for path in presets_dir.glob("*.json"):
        data = read_json(path)
        if not isinstance(data, dict):
            continue
        try:
            preset = Preset.model_validate(data)
        except Exception:
            continue
        summaries.append(PresetSummary(id=preset.id, name=preset.name))
    return sorted(summaries, key=lambda item: item.name.lower())


def get_preset(preset_id: str) -> PresetResponse:
    preset = _load_preset(preset_id)
    return _to_response(preset)


def get_preset_storage(preset_id: str) -> Preset:
    return _load_preset(preset_id)


def update_preset(preset_id: str, payload: PresetUpdate) -> PresetResponse:
    preset = _load_preset(preset_id)
    entries = _validate_and_normalize_entries(payload.entries)
    updated = preset.model_copy(update={"entries": entries, "version": preset.version + 1})
    _write_preset(updated)
    return _to_response(updated)


def _sessions_dir() -> Path:
    return settings.data_path / "sessions"


def _session_meta_paths() -> list[Path]:
    sessions_dir = _sessions_dir()
    sessions_dir.mkdir(parents=True, exist_ok=True)
    return [path / "session.json" for path in sessions_dir.iterdir() if path.is_dir()]


def delete_preset(preset_id: str) -> None:
    path = _preset_path(preset_id)
    if not path.exists():
        raise PresetNotFoundError(preset_id)

    in_use_by: list[str] = []
    for session_path in _session_meta_paths():
        data = read_json(session_path)
        if isinstance(data, dict) and data.get("preset_id") == preset_id:
            name = data.get("name")
            if isinstance(name, str):
                in_use_by.append(name)

    if in_use_by:
        raise PresetInUseError(preset_id, sorted(in_use_by))

    path.unlink()


def rename_preset(preset_id: str, payload: PresetRename) -> PresetResponse:
    preset = _load_preset(preset_id)
    if payload.new_name == preset.name:
        return _to_response(preset)
    _ensure_unique_name(payload.new_name, ignore_id=preset_id)
    updated = preset.model_copy(update={"name": payload.new_name, "version": preset.version + 1})
    _write_preset(updated)
    return _to_response(updated)


__all__ = [
    "DEFAULT_PRESET_ENTRIES",
    "PresetNotFoundError",
    "PresetNameExistsError",
    "PresetInUseError",
    "PresetValidationError",
    "create_preset",
    "list_presets",
    "get_preset",
    "get_preset_storage",
    "update_preset",
    "delete_preset",
    "rename_preset",
    "ensure_default_preset",
]

