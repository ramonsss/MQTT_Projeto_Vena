from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.telemetry.schemas import HistoryResponse
from app.telemetry.service import DeviceNotFound, get_device_history

router = APIRouter()


@router.get("/devices/{device_id}/history", response_model=HistoryResponse)
async def history(
    device_id: str,
    start: Annotated[datetime | None, Query(description="Start datetime (ISO 8601). Default: 24h ago.")] = None,
    end: Annotated[datetime | None, Query(description="End datetime (ISO 8601). Default: now.")] = None,
    limit: Annotated[int, Query(ge=1, le=5000, description="Max samples to return.")] = 500,
    offset: Annotated[int, Query(ge=0, description="Pagination offset.")] = 0,
    session: AsyncSession = Depends(get_session),
) -> HistoryResponse:
    try:
        return await get_device_history(session, device_id, start, end, limit, offset)
    except DeviceNotFound:
        raise HTTPException(status_code=404, detail=f"Device '{device_id}' not found")
