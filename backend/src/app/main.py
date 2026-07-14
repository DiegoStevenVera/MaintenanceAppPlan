from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import settings
from app.database import async_session_factory, uses_postgres
from modules.app_state.interfaces.router import router as app_state_router
from modules.asset_management.interfaces.router import router as asset_router
from modules.identity_access.interfaces.router import router as identity_router
from modules.maintenance_execution.interfaces.router import router as maintenance_router


def create_app() -> FastAPI:
    app = FastAPI(title=settings.app_name, version="0.1.0")

    origins = [
        origin.strip()
        for origin in settings.backend_cors_origins.split(",")
        if origin.strip()
    ]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins or ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/health", tags=["system"])
    async def health() -> dict[str, str]:
        return {"status": "ok", "environment": settings.environment}

    @app.get("/health/db", tags=["system"])
    async def database_health() -> dict[str, str]:
        if not uses_postgres():
            return {"status": "skipped", "repository_backend": settings.repository_backend}

        async with async_session_factory() as session:
            await session.execute(text("select 1"))
        return {"status": "ok", "repository_backend": settings.repository_backend}

    app.include_router(identity_router, prefix=settings.api_v1_prefix)
    app.include_router(app_state_router, prefix=settings.api_v1_prefix)
    app.include_router(asset_router, prefix=settings.api_v1_prefix)
    app.include_router(maintenance_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
