from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Device, User, UserDevice
from app.devices.pairing import verify_pairing_code
from app.devices.schemas import ClaimResponse, DeviceItem, DeviceListResponse


async def claim_device(
    user: User,
    device_id: str,
    pairing_code: str,
    session: AsyncSession,
) -> ClaimResponse:
    
    result = await session.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if device is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")

    if not verify_pairing_code(pairing_code, device.pairing_code_hash):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid pairing code")

    result = await session.execute(
        select(UserDevice).where(
            UserDevice.user_id == user.id,
            UserDevice.device_id == device_id,
        )
    )
    if result.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Device already claimed by this user",
        )

    ud = UserDevice(user_id=user.id, device_id=device_id)
    session.add(ud)
    await session.commit()
    await session.refresh(ud)

    return ClaimResponse(device_id=device_id, alias=ud.alias, claimed_at=ud.claimed_at)


async def list_user_devices(user: User, session: AsyncSession) -> DeviceListResponse:
    result = await session.execute(
        select(UserDevice, Device)
        .join(Device, UserDevice.device_id == Device.id)
        .where(UserDevice.user_id == user.id)
    )
    rows = result.all()
    devices = [
        DeviceItem(
            device_id=device.id,
            alias=ud.alias,
            status=device.status,
            last_seen_at=device.last_seen_at,
            fw_version=device.fw_version,
        )
        for ud, device in rows
    ]
    return DeviceListResponse(devices=devices)


async def update_device_alias(
    user: User,
    device_id: str,
    alias: str,
    session: AsyncSession,
) -> ClaimResponse:
    result = await session.execute(
        select(UserDevice).where(
            UserDevice.user_id == user.id,
            UserDevice.device_id == device_id,
        )
    )
    ud = result.scalar_one_or_none()
    if ud is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Device not owned by this user",
        )

    ud.alias = alias
    await session.commit()
    await session.refresh(ud)

    return ClaimResponse(device_id=device_id, alias=ud.alias, claimed_at=ud.claimed_at)
