from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers.api_configs import router as api_configs_router
from app.routers.chat import router as chat_router
from app.routers.health import router as health_router
from app.routers.logs import router as logs_router
from app.routers.presets import router as presets_router
from app.routers.sessions import router as sessions_router
from app.services.preset_service import ensure_default_preset
from app.storage.encryption import get_or_create_key
from app.storage.init_dirs import ensure_data_dirs


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    # Initialize storage and encryption before serving requests
    data_dir = ensure_data_dirs()
    get_or_create_key()
    ensure_default_preset(data_dir)
    yield


def create_app() -> FastAPI:
    # Factory to keep tests isolated from global app state
    app = FastAPI(title="RST API", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            f"http://localhost:{settings.vite_dev_port}",
            f"http://127.0.0.1:{settings.vite_dev_port}",
        ],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health_router)
    app.include_router(api_configs_router, prefix="/api-configs", tags=["API Configs"])
    app.include_router(sessions_router, prefix="/sessions", tags=["Sessions"])
    app.include_router(presets_router, prefix="/presets", tags=["Presets"])
    app.include_router(chat_router, tags=["Chat"])
    app.include_router(logs_router, tags=["Logs"])
    return app


app = create_app()


def main() -> None:
    # Entry point for `python -m app.main`
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=settings.rst_backend_port,
        reload=True,
    )


if __name__ == "__main__":
    main()
