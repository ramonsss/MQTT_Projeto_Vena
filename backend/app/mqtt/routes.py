from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.deps import get_current_user
from app.db.models import User
from app.db.session import get_session
from app.mqtt.credentials import get_mqtt_credentials, provision_device

router = APIRouter(tags=["mqtt"])


@router.post("/mqtt/credentials")
async def mqtt_credentials(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> JSONResponse:
    result = await get_mqtt_credentials(user, session)
    return JSONResponse({
        "mqtt_token": result.mqtt_token,
        "expires_in": result.expires_in,
        "broker_host": result.broker_host,
        "broker_port": result.broker_port,
    })


@router.post("/devices/{device_id}/provision")
async def provision(
    device_id: str,
    user: User = Depends(get_current_user),
) -> JSONResponse:
    """Issue a long-lived device JWT for NVS storage on ESP32.

    In the MVP any authenticated user can provision any device.
    Fine-grained ownership check is deferred to a later phase.
    """
    result = provision_device(device_id)
    return JSONResponse({
        "device_jwt": result.device_jwt,
        "expires_in": result.expires_in,
    })
