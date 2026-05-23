from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.deps import get_current_user
from app.db.models import User
from app.db.session import get_session
from app.devices.schemas import (
    ClaimRequest,
    ClaimResponse,
    DeviceListResponse,
    DeviceUpdateRequest,
)
from app.devices.service import claim_device, list_user_devices, update_device_alias

router = APIRouter(prefix="/devices", tags=["devices"])


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
