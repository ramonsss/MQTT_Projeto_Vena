from fastapi import APIRouter, Depends
from fastapi.responses import Response
from jose import JWTError

from app.auth.jwt import decode_token
from app.broker_auth.schemas import AclForm, AuthForm

router = APIRouter(tags=["broker-auth"])

_403 = Response(status_code=403)
_200 = Response(status_code=200)


@router.post("/mqtt/auth")
async def mqtt_auth(form: AuthForm = Depends()) -> Response:
    """Validate the JWT passed as MQTT username.

    Called by mosquitto-go-auth on every CONNECT.
    Returns 200 if the token is valid and not expired, 403 otherwise.
    """
    try:
        decode_token(form.username)
        return _200
    except JWTError:
        return _403


@router.post("/mqtt/acl")
async def mqtt_acl(form: AclForm = Depends()) -> Response:
    """Enforce topic-level ACL based on JWT claims.

    Topic format expected: vena/{device_id}/{...}

    - scope=app  : device_id must be in the ``devices`` claim list.
    - scope=device: ``device_id`` claim must match the topic's device_id.
    """
    try:
        payload = decode_token(form.username)
    except JWTError:
        return _403

    parts = form.topic.split("/")
    if len(parts) < 2 or parts[0] != "vena":
        return _403

    topic_device_id = parts[1]
    scope = payload.get("scope")

    if scope == "app":
        allowed: list[str] = payload.get("devices", [])
        return _200 if topic_device_id in allowed else _403

    if scope == "device":
        return _200 if payload.get("device_id") == topic_device_id else _403

    return _403


@router.post("/mqtt/superuser")
async def mqtt_superuser() -> Response:
    """Always deny superuser — no client gets blanket broker access."""
    return _403
