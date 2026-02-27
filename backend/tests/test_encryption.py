from __future__ import annotations

from pathlib import Path

import pytest
from cryptography.fernet import Fernet

from app.storage import encryption


def test_key_generation_and_cache(tmp_data_dir: Path) -> None:
    encryption._cached_key = None
    key1 = encryption.get_or_create_key()
    keyfile = tmp_data_dir / ".keyfile"
    assert keyfile.exists()

    key2 = encryption.get_or_create_key()
    assert key1 == key2


def test_encrypt_decrypt_roundtrip(tmp_data_dir: Path) -> None:
    encryption._cached_key = None
    token = encryption.encrypt_api_key("secret-key")
    assert encryption.decrypt_api_key(token) == "secret-key"


def test_different_keys_cannot_decrypt(tmp_data_dir: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    first_key = Fernet.generate_key()
    second_key = Fernet.generate_key()

    monkeypatch.setenv("RST_ENCRYPTION_KEY", first_key.decode("utf-8"))
    encryption._cached_key = None
    token = encryption.encrypt_api_key("secret-key")

    monkeypatch.setenv("RST_ENCRYPTION_KEY", second_key.decode("utf-8"))
    encryption._cached_key = None
    with pytest.raises(encryption.EncryptionError):
        encryption.decrypt_api_key(token)
