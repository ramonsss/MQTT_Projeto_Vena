from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import create_device_jwt, create_mqtt_token
from app.config import settings
from app.db.models import User, UserDevice


@dataclass
class MqttCredentialsResponse:
    mqtt_token: str
    expires_in: int
    broker_host: str
    broker_port: int


@dataclass
class ProvisionResponse:
    device_jwt: str
    expires_in: int


async def get_mqtt_credentials(
    user: User, session: AsyncSession
) -> MqttCredentialsResponse:
    """List the user's devices, issue a short-lived MQTT JWT with the devices claim."""
    result = await session.execute(
        select(UserDevice.device_id).where(UserDevice.user_id == user.id)
    )
    device_ids = [row[0] for row in result.all()]

    token = create_mqtt_token(user, device_ids)

    public_host = settings.mqtt_public_host or settings.mqtt_host
    public_port = settings.mqtt_public_port if settings.mqtt_public_port > 0 else settings.mqtt_port
    return MqttCredentialsResponse(
        mqtt_token=token,
        expires_in=settings.mqtt_jwt_expire_minutes * 60,
        broker_host=public_host,
        broker_port=public_port,
    )


def provision_device(device_id: str) -> ProvisionResponse:
    """Issue a long-lived device JWT (scope=device) for NVS storage on ESP32."""
    from datetime import datetime, timezone

    token = create_device_jwt(device_id)

    if settings.device_jwt_expire_days == 0:
        # No-expiry mode: report seconds until 2038-01-19
        _max = datetime(2038, 1, 19, 3, 14, 7, tzinfo=timezone.utc)
        expires_in = int((_max - datetime.now(tz=timezone.utc)).total_seconds())
    else:
        expires_in = settings.device_jwt_expire_days * 86400

    return ProvisionResponse(device_jwt=token, expires_in=expires_in)
