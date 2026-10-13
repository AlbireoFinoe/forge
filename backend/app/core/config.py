from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = BACKEND_ROOT.parent


class Settings(BaseSettings):
    database_url: str
    database_url_unpooled: str | None = None

    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 30

    model_config = SettingsConfigDict(
        env_file=(
            BACKEND_ROOT / ".env",
            PROJECT_ROOT / ".env.local",
        ),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()