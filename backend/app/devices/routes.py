from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.deps import get_current_user
from app.db.models import User
from app.db.session import get_session
from app.auth.jwt import create_device_jwt
from app.devices.pairing import verify_pairing_code
from app.devices.schemas import (
    ClaimRequest,
    ClaimResponse,
    DeviceListResponse,
    DeviceUpdateRequest,
    ProvisionRequest,
    ProvisionResponse,
)
from app.devices.service import claim_device, get_device_or_404, list_user_devices, update_device_alias

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/provision", response_model=ProvisionResponse)
async def provision(
    body: ProvisionRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ProvisionResponse:
    """Return a device JWT for use by the ESP32.

    The app calls this during the BLE pairing wizard after scanning the QR.
    The pairing_code is validated against the stored bcrypt hash so only the
    physical owner of the device can request its JWT.
    """
    device = await get_device_or_404(body.device_id, session)
    if not verify_pairing_code(body.pairing_code, device.pairing_code_hash):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid pairing code",
        )
    return ProvisionResponse(device_jwt=create_device_jwt(body.device_id))


@router.post("/{device_id}/claim", response_model=ClaimResponse)
async def claim(
    device_id: str,
    body: ClaimRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ClaimResponse:
    return await claim_device(user, device_id, body.pairing_code, session)


@router.get("", response_model=DeviceListResponse)
async def list_devices(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> DeviceListResponse:
    return await list_user_devices(user, session)


@router.patch("/{device_id}", response_model=ClaimResponse)
async def update_alias(
    device_id: str,
    body: DeviceUpdateRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ClaimResponse:
    return await update_device_alias(user, device_id, body.alias, session)
