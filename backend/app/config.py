from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# Resolve root .env regardless of where the server process is started from
_ROOT_ENV = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ROOT_ENV, env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str = "postgresql+asyncpg://vena:vena_dev_local@localhost:5432/vena"

    # MQTT
    mqtt_host: str = "localhost"
    mqtt_port: int = 1883

    # Auth / JWT
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60


settings = Settings()
