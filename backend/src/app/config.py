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
    jwt_secret_key: str = "change-this-local-development-secret"
    jwt_issuer: str = "maintenance-app"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7
    attachment_storage_path: str = "backend/storage/attachments"
    attachment_max_bytes: int = 10_000_000
    report_storage_path: str = "backend/storage/reports"
    report_logo_path: str = "docs/OldVersionApp/Formats/img/Hitachi-Logo.png"
    preventive_report_format_code: str = "ML2-STS-FOR-040-ES"
    preventive_report_revision: str = "0"
    corrective_report_format_code: str = "ML2-STS-FOR-041-ES"
    corrective_report_revision: str = "0"
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
        return path if path.is_absolute() else PROJECT_ROOT / path

    @property
    def resolved_report_root(self) -> Path:
        path = Path(self.report_storage_path)
        return path if path.is_absolute() else PROJECT_ROOT / path

    @property
    def resolved_report_logo(self) -> Path:
        path = Path(self.report_logo_path)
        return path if path.is_absolute() else PROJECT_ROOT / path

    model_config = SettingsConfigDict(
        env_file=(BACKEND_ROOT / ".env", PROJECT_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
