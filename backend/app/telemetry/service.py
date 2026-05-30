from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Device, TelemetryRaw
from app.telemetry.schemas import HistoryResponse, TelemetrySample


class DeviceNotFound(Exception):
    pass


async def get_device_history(
    session: AsyncSession,
    device_id: str,
    start: datetime | None,
    end: datetime | None,
    limit: int,
    offset: int,
) -> HistoryResponse:
    device = await session.get(Device, device_id)
    if device is None:
        raise DeviceNotFound(device_id)

    now = datetime.now(tz=timezone.utc)
    resolved_end = end if end is not None else now
    resolved_start = start if start is not None else now - timedelta(hours=24)

    stmt = (
        select(TelemetryRaw)
        .where(TelemetryRaw.device_id == device_id)
        .where(TelemetryRaw.ts >= resolved_start)
        .where(TelemetryRaw.ts <= resolved_end)
        .order_by(TelemetryRaw.ts.desc())
        .limit(limit)
        .offset(offset)
    )

    rows = list((await session.scalars(stmt)).all())

    samples = [
        TelemetrySample(
            ts=row.ts,
            ambient_t=row.ambient_t,
            ambient_h=row.ambient_h,
            diss_t=row.diss_t,
            diss_h=row.diss_h,
            setpoint=row.setpoint,
            pid_out=row.pid_out,
        )
        for row in rows
    ]

    return HistoryResponse(device_id=device_id, count=len(samples), samples=samples)
