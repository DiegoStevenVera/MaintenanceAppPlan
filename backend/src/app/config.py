import os
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_ROOT = Path(__file__).resolve().parents[2]


def _environment_file() -> Path:
    configured_path = Path(
        os.environ.get("APP_ENV_FILE", "environments/local/.env")
    )
    return (
        configured_path
        if configured_path.is_absolute()
        else BACKEND_ROOT / configured_path
    )


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
    jwt_secret_key: str = "change-this-local-development-secret"
    jwt_issuer: str = "maintenance-app"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7
    attachment_storage_path: str = "storage/attachments"
    attachment_max_bytes: int = 10_000_000
    report_storage_path: str = "storage/reports"
    report_logo_path: str = "assets/Hitachi-Logo-v2.png"
    calibration_report_file_prefix: str = "Report_Calibration"

    @property
    def resolved_database_url(self) -> str:
        return (
            "postgresql+asyncpg://"
            f"{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def resolved_attachment_root(self) -> Path:
        path = Path(self.attachment_storage_path)
        return path if path.is_absolute() else BACKEND_ROOT / path

    @property
    def resolved_report_root(self) -> Path:
        path = Path(self.report_storage_path)
        return path if path.is_absolute() else BACKEND_ROOT / path

    @property
    def resolved_report_logo(self) -> Path:
        path = Path(self.report_logo_path)
        return path if path.is_absolute() else BACKEND_ROOT / path

    model_config = SettingsConfigDict(
        env_file=_environment_file(),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
