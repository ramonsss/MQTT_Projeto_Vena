from __future__ import annotations

from datetime import datetime, timezone

from pydantic import BaseModel, field_validator


class TelemetrySample(BaseModel):
    ts: datetime
    ambient_t: float | None
    ambient_h: float | None
    diss_t: float | None
    diss_h: float | None
    setpoint: float | None
    pid_out: float | None

    model_config = {"from_attributes": True}


class HistoryResponse(BaseModel):
    device_id: str
    count: int
    samples: list[TelemetrySample]


class HistoryQuery(BaseModel):
    start: datetime | None = None
    end: datetime | None = None
    limit: int = 500
    offset: int = 0

    @field_validator("limit")
    @classmethod
    def limit_range(cls, v: int) -> int:
        if not 1 <= v <= 5000:
            raise ValueError("limit must be between 1 and 5000")
        return v

    @field_validator("offset")
    @classmethod
    def offset_non_negative(cls, v: int) -> int:
        if v < 0:
            raise ValueError("offset must be >= 0")
        return v
