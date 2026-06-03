from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# Resolve root .env regardless of where the server process is started from
_ROOT_ENV = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ROOT_ENV, env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str = "postgresql+asyncpg://vena:vena_dev_local@localhost:5432/vena"
    # Direct (non-pooled) connection for Alembic DDL migrations.
    # Falls back to database_url when not set (local / TimescaleDB deployments).
    database_url_direct: str = ""

    # MQTT
    mqtt_host: str = "localhost"          # internal broker hostname (used by worker)
    mqtt_public_host: str = ""             # public hostname returned to app (defaults to mqtt_host)
    mqtt_port: int = 1883
    mqtt_public_port: int = 0              # public port returned to app (0 = same as mqtt_port)

    # Auth / JWT
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60
    jwt_refresh_expire_days: int = 30

    # Google OAuth
    google_client_id: str = ""

    # Pairing
    pairing_secret: str = "change-me-in-production"

    # MQTT JWT
    mqtt_jwt_expire_minutes: int = 60
    device_jwt_expire_days: int = 0  # 0 = sem expiração (usa 2038-01-19, máximo int32)


settings = Settings()
