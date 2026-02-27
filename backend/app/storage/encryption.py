from __future__ import annotations

import os
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken

from app.config import settings
from app.storage.file_io import atomic_write

_cached_key: bytes | None = None


class EncryptionError(RuntimeError):
    """Raised when encryption or decryption fails."""


def _validate_key(key: bytes) -> bytes:
    try:
        Fernet(key)
    except Exception as exc:
        raise EncryptionError("Invalid encryption key") from exc
    return key


def _read_keyfile(path: Path) -> bytes | None:
    if not path.exists():
        return None
    data = path.read_bytes().strip()
    return data or None


def get_or_create_key() -> bytes:
    """Load the Fernet key from env or keyfile, otherwise create one."""
    global _cached_key
    if _cached_key is not None:
        return _cached_key

    env_value = os.getenv("RST_ENCRYPTION_KEY")
    if env_value:
        _cached_key = _validate_key(env_value.encode("utf-8"))
        return _cached_key

    keyfile_path = settings.data_path / ".keyfile"
    file_key = _read_keyfile(keyfile_path)
    if file_key:
        _cached_key = _validate_key(file_key)
        return _cached_key

    new_key = Fernet.generate_key()
    keyfile_path.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(keyfile_path, new_key)
    _cached_key = new_key
    return new_key


def encrypt_api_key(plain_key: str) -> str:
    """Encrypt API Key and return a base64 token string."""
    key = get_or_create_key()
    fernet = Fernet(key)
    return fernet.encrypt(plain_key.encode("utf-8")).decode("utf-8")


def decrypt_api_key(encrypted_key: str) -> str:
    """Decrypt API Key and return plaintext."""
    key = get_or_create_key()
    fernet = Fernet(key)
    try:
        return fernet.decrypt(encrypted_key.encode("utf-8")).decode("utf-8")
    except InvalidToken as exc:
        raise EncryptionError("Invalid encrypted key") from exc
