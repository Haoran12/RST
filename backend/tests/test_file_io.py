from __future__ import annotations

from pathlib import Path

import pytest

from app.storage import file_io


def test_atomic_write_creates_backup(tmp_path: Path) -> None:
    path = tmp_path / "sample.json"
    path.write_text("old", encoding="utf-8")

    file_io.atomic_write(path, b"new")

    assert path.read_text(encoding="utf-8") == "new"
    backup = path.with_suffix(".bak")
    assert backup.exists()
    assert backup.read_text(encoding="utf-8") == "old"


def test_atomic_write_preserves_original_on_failure(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    path = tmp_path / "data.json"
    path.write_text("stable", encoding="utf-8")

    def broken_replace(self: Path, target: Path) -> None:
        raise OSError("rename failed")

    monkeypatch.setattr(file_io.Path, "replace", broken_replace)

    with pytest.raises(OSError):
        file_io.atomic_write(path, b"new")

    assert path.read_text(encoding="utf-8") == "stable"


def test_read_json_returns_none_when_missing(tmp_path: Path) -> None:
    assert file_io.read_json(tmp_path / "missing.json") is None


def test_write_json_creates_parent_dirs(tmp_path: Path) -> None:
    path = tmp_path / "nested" / "data.json"
    payload = {"hello": "world"}

    file_io.write_json(path, payload)

    assert path.exists()
    assert file_io.read_json(path) == payload
