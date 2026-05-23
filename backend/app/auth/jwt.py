import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

# Máximo representável em Unix timestamp int32 — 2038-01-19T03:14:07Z
_JWT_MAX_EXP = datetime(2038, 1, 19, 3, 14, 7, tzinfo=timezone.utc)

from jose import jwt

from app.config import settings
from app.db.models import User


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


# ---------------------------------------------------------------------------
# Access token (short-lived JWT, sent in Authorization header)
# ---------------------------------------------------------------------------

def create_access_token(user: User) -> str:
    """Issue a signed JWT access token for a user (60 min by default)."""
    now = _now()
    payload: dict[str, Any] = {
        "sub": str(user.id),
        "email": user.email,
        "scope": "user",
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_expire_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


# ---------------------------------------------------------------------------
# Refresh token (opaque UUID, stored hashed in DB)
# ---------------------------------------------------------------------------

def create_refresh_token() -> tuple[str, datetime]:
    """Generate an opaque refresh token and its expiry timestamp.

    Returns:
        (raw_token, expires_at) — raw_token is the UUID string to send to
        the client; the caller must hash it before persisting to the DB.
    """
    raw = str(uuid.uuid4())
    expires_at = _now() + timedelta(days=settings.jwt_refresh_expire_days)
    return raw, expires_at


# ---------------------------------------------------------------------------
# MQTT tokens
# ---------------------------------------------------------------------------

def create_mqtt_token(user: User, device_ids: list[str]) -> str:
    """Issue a short-lived JWT for the app to authenticate with the broker.

    The ``devices`` claim lists the device IDs the bearer is allowed to
    publish/subscribe to.  mosquitto-go-auth enforces this via /mqtt/acl.
    """
    now = _now()
    payload: dict[str, Any] = {
        "sub": str(user.id),
        "scope": "app",
        "devices": device_ids,
        "iat": now,
        "exp": now + timedelta(minutes=settings.mqtt_jwt_expire_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_device_jwt(device_id: str) -> str:
    """Issue a long-lived JWT for a device to authenticate with the broker.

    This token is stored in the ESP32's NVS and used as the MQTT username.
    The ``device_id`` claim is used by /mqtt/acl to restrict the device to
    its own topic namespace (vena/{device_id}/*).
    """
    now = _now()
    payload: dict[str, Any] = {
        "sub": device_id,
        "scope": "device",
        "device_id": device_id,
        "iat": now,
        "exp": _JWT_MAX_EXP if settings.device_jwt_expire_days == 0
        else now + timedelta(days=settings.device_jwt_expire_days),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


# ---------------------------------------------------------------------------
# Decode / verify
# ---------------------------------------------------------------------------

def decode_token(token: str) -> dict[str, Any]:
    """Decode and verify a JWT.  Raises ``jose.JWTError`` if invalid or expired."""
    return jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
