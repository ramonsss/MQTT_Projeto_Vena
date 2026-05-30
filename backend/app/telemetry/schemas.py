from __future__ import annotations

from datetime import datetime, timezone

from pydantic import BaseModel, field_validator


class TelemetrySample(BaseModel):
    ts: datetime
    ambient_t: float | None = None
    ambient_h: float | None = None
    diss_t: float | None = None
    diss_h: float | None = None
    setpoint: float | None = None
    pid_out: float | None = None

    # Aggregated extras (populated only when bucket != "5s").
    ambient_t_min: float | None = None
    ambient_t_max: float | None = None
    ambient_h_min: float | None = None
    ambient_h_max: float | None = None
    diss_t_min: float | None = None
    diss_t_max: float | None = None
    diss_h_min: float | None = None
    diss_h_max: float | None = None
    sample_count: int | None = None

    model_config = {"from_attributes": True}


class HistoryResponse(BaseModel):
    device_id: str
    count: int
    samples: list[TelemetrySample]

    # Phase 5 fields — optional so existing callers (start/end mode) stay valid.
    bucket: str | None = None
    range_start: datetime | None = None
    range_end: datetime | None = None


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
