from functools import cached_property
from urllib.parse import quote_plus

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings, loaded from environment variables / backend/.env."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Stock Adviser API"
    environment: str = "dev"  # dev | test | prod
    debug: bool = False
    api_v1_prefix: str = "/api/v1"

    # Own database + dedicated user only; the MySQL server is shared with the evolution project.
    db_host: str = "127.0.0.1"
    db_port: int = 3306
    db_user: str = "stock_advisor"
    db_password: str = ""
    db_name: str = "stock_advisor_dev"
    db_pool_size: int = 5
    db_max_overflow: int = 5

    cors_origins: list[str] = Field(
        default_factory=lambda: ["http://localhost:8210", "http://127.0.0.1:8210"]
    )

    # Auth
    jwt_secret: str = ""
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    email_verify_token_hours: int = 48
    password_reset_token_minutes: int = 60

    # Google Sign-In: OAuth client IDs accepted as ID-token audience (web + android).
    google_client_ids: list[str] = Field(default_factory=list)

    # Links in emails point to the Flutter web app.
    frontend_url: str = "http://localhost:8210"

    # Email: "outbox" writes .eml files to email_outbox_dir (dev), "smtp" sends, "memory" (tests).
    email_backend: str = "outbox"
    email_from: str = "Stock Adviser <no-reply@localhost>"
    email_outbox_dir: str = "var/outbox"
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_starttls: bool = True

    @cached_property
    def database_url(self) -> str:
        return (
            f"mysql+aiomysql://{quote_plus(self.db_user)}:{quote_plus(self.db_password)}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}?charset=utf8mb4"
        )


settings = Settings()

if len(settings.jwt_secret) < 32:
    raise RuntimeError("JWT_SECRET must be set in backend/.env (at least 32 characters)")
