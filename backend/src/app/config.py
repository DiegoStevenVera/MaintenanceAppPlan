from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    app_name: str = "MaintenanceApp API"
    environment: str = "local"
    api_v1_prefix: str = "/api/v1"
    backend_cors_origins: str = ""
    repository_backend: str = "seed"
    postgres_db: str = "maintenance_app"
    postgres_user: str = "maintenance_user"
    postgres_password: str = "maintenance_password"
    postgres_host: str = "localhost"
    postgres_port: int = 5432

    @property
    def resolved_database_url(self) -> str:
        return (
            "postgresql+asyncpg://"
            f"{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    model_config = SettingsConfigDict(
        env_file=(BACKEND_ROOT / ".env", PROJECT_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
