from __future__ import annotations

from pathlib import Path
from typing import Any

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def find_project_root(start: Path) -> Path:
    current = start.resolve()
    for parent in [current, *current.parents]:
        # Prefer a repo root that contains frontend/ or .env
        if (parent / "frontend").is_dir() or (parent / ".env").is_file():
            return parent
    # Fallback to a stable ancestor when markers are missing
    return current.parents[2] if len(current.parents) > 2 else current


PROJECT_ROOT = find_project_root(Path(__file__))
ENV_FILE = PROJECT_ROOT / ".env"


class Settings(BaseSettings):
    # Environment variables are read from repo .env with no prefix
    rst_data_dir: str = Field(default="./data", alias="RST_DATA_DIR")
    rst_logs_dir: str = Field(default="./logs", alias="RST_LOGS_DIR")
    rst_backend_port: int = Field(default=18080, alias="RST_BACKEND_PORT")
    rst_backend_reload: bool = Field(default=False, alias="RST_BACKEND_RELOAD")
    rst_serve_frontend: bool = Field(default=False, alias="RST_SERVE_FRONTEND")
    rst_frontend_dist: str = Field(default="./frontend/dist", alias="RST_FRONTEND_DIST")
    vite_dev_port: int = Field(default=15173, alias="VITE_DEV_PORT")

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_prefix="",
        extra="ignore",
    )

    @field_validator("rst_backend_reload", "rst_serve_frontend", mode="before")
    @classmethod
    def parse_bool_like_env(cls, value: Any) -> Any:
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"1", "true", "yes", "on"}:
                return True
            if normalized in {"0", "false", "no", "off"}:
                return False
            return normalized
        return value

    @property
    def data_path(self) -> Path:
        # Normalize to an absolute path rooted at the repo
        path = Path(self.rst_data_dir)
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        return path.resolve()

    @property
    def frontend_dist_path(self) -> Path:
        path = Path(self.rst_frontend_dist)
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        return path.resolve()

    @property
    def logs_path(self) -> Path:
        path = Path(self.rst_logs_dir)
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        return path.resolve()


settings = Settings()
