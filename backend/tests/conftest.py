from __future__ import annotations

import sys
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient

# Ensure backend root is on sys.path for absolute imports like `app.*`
BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings
from app.main import create_app
from app.storage import encryption
from app.storage.init_dirs import ensure_data_dirs


@pytest.fixture()
def tmp_data_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setattr(settings, "rst_data_dir", str(tmp_path))
    monkeypatch.delenv("RST_ENCRYPTION_KEY", raising=False)
    encryption._cached_key = None
    ensure_data_dirs()
    return tmp_path


@pytest.fixture()
async def async_client(tmp_data_dir: Path):
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.fixture()
def sample_api_config() -> dict[str, object]:
    return {
        "name": "Primary",
        "provider": "openai",
        "api_key": "sk-test-1234",
        "model": "gpt-test",
    }
