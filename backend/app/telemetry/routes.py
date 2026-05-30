from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.telemetry.aggregation import ALLOWED_BUCKETS, RANGE_TO_TIMEDELTA
from app.telemetry.schemas import HistoryResponse
from app.telemetry.service import (
    DeviceNotFound,
    get_device_history,
    get_device_history_aggregated,
    get_device_meta,
)

router = APIRouter()

_RANGE_LITERALS = sorted(RANGE_TO_TIMEDELTA.keys())


@router.get("/devices/{device_id}/history", response_model=HistoryResponse)
async def history(
    device_id: str,
    start: Annotated[datetime | None, Query(description="Start datetime (ISO 8601). Legacy mode.")] = None,
    end: Annotated[datetime | None, Query(description="End datetime (ISO 8601). Legacy mode.")] = None,
    range: Annotated[
        str | None,
        Query(
            alias="range",
            description=f"Time window. One of {_RANGE_LITERALS}.",
        ),
    ] = None,
    bucket: Annotated[
        str,
        Query(description=f"Aggregation bucket. One of {list(ALLOWED_BUCKETS)}."),
    ] = "auto",
    metric: Annotated[
        str,
        Query(description="Comma-separated metric names, or 'all'."),
    ] = "all",
    limit: Annotated[int, Query(ge=1, le=5000, description="Max samples to return.")] = 500,
    offset: Annotated[int, Query(ge=0, description="Pagination offset (legacy mode only).")] = 0,
    session: AsyncSession = Depends(get_session),
) -> HistoryResponse:
    """Adaptive-bucket history (Phase 5).

    - Default: `?range=24h&bucket=auto` → aggregated rows.
    - Legacy: `?start=...&end=...` keeps the original raw-row behavior.
    """
    if start is not None or end is not None:
        try:
            return await get_device_history(session, device_id, start, end, limit, offset)
        except DeviceNotFound:
            raise HTTPException(status_code=404, detail=f"Device '{device_id}' not found")

    resolved_range = range or "24h"
    if resolved_range not in RANGE_TO_TIMEDELTA:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid range '{resolved_range}'. Allowed: {_RANGE_LITERALS}",
        )
    if bucket not in ALLOWED_BUCKETS:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid bucket '{bucket}'. Allowed: {list(ALLOWED_BUCKETS)}",
        )

    try:
        return await get_device_history_aggregated(
            session,
            device_id,
            range_=resolved_range,
            bucket=bucket,
            metric=metric,
            limit=limit,
        )
    except DeviceNotFound:
        raise HTTPException(status_code=404, detail=f"Device '{device_id}' not found")
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))


@router.get("/devices/{device_id}/meta")
async def device_meta(
    device_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Return the last `meta` payload published by an ESP32 (Phase 5)."""
    try:
        meta = await get_device_meta(session, device_id)
    except DeviceNotFound:
        raise HTTPException(status_code=404, detail=f"Device '{device_id}' not found")
    if meta is None:
        raise HTTPException(
            status_code=404,
            detail=f"No meta published yet for device '{device_id}'",
        )
    return meta
