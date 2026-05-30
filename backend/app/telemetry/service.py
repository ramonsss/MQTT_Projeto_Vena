from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Device, TelemetryRaw
from app.telemetry.aggregation import (
    build_aggregate_sql,
    has_min_max,
    parse_metrics,
    parse_range,
    resolve_bucket,
)
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


async def get_device_history_aggregated(
    session: AsyncSession,
    device_id: str,
    range_: str,
    bucket: str,
    metric: str,
    limit: int,
) -> HistoryResponse:
    """Adaptive-bucket history endpoint (Phase 5).

    - `range_` is validated against the enum in `aggregation.RANGE_TO_TIMEDELTA`.
    - `bucket` accepts 'auto' | '5s' | '1m' | '1h' | '1d'.
    - `metric` is comma-separated or 'all'.
    - When `bucket == '5s'` we return raw rows ordered ts ASC for charting.
    """
    device = await session.get(Device, device_id)
    if device is None:
        raise DeviceNotFound(device_id)

    resolved_bucket = resolve_bucket(range_, bucket)
    metrics = parse_metrics(metric)
    span = parse_range(range_)

    now = datetime.now(tz=timezone.utc)
    start_ts = now - span
    end_ts = now

    if resolved_bucket == "5s":
        stmt = (
            select(TelemetryRaw)
            .where(TelemetryRaw.device_id == device_id)
            .where(TelemetryRaw.ts >= start_ts)
            .where(TelemetryRaw.ts < end_ts)
            .order_by(TelemetryRaw.ts.asc())
            .limit(limit)
        )
        rows = list((await session.scalars(stmt)).all())
        raw_samples = [
            TelemetrySample(
                ts=r.ts,
                ambient_t=r.ambient_t,
                ambient_h=r.ambient_h,
                diss_t=r.diss_t,
                diss_h=r.diss_h,
                setpoint=r.setpoint,
                pid_out=r.pid_out,
            )
            for r in rows
        ]
        return HistoryResponse(
            device_id=device_id,
            count=len(raw_samples),
            samples=raw_samples,
            bucket=resolved_bucket,
            range_start=start_ts,
            range_end=end_ts,
        )

    sql = build_aggregate_sql(resolved_bucket, metrics) + " LIMIT :row_limit"
    result = await session.execute(
        text(sql),
        {
            "device_id": device_id,
            "start_ts": start_ts,
            "end_ts": end_ts,
            "row_limit": limit,
        },
    )
    rows_mapped = result.mappings().all()

    agg_samples: list[TelemetrySample] = []
    for r in rows_mapped:
        kwargs: dict[str, object] = {
            "ts": r["bucket"],
            "sample_count": int(r["sample_count"]),
        }
        for m in metrics:
            avg_v = r[f"{m}_avg"]
            kwargs[m] = float(avg_v) if avg_v is not None else None
            if has_min_max(m):
                min_v = r[f"{m}_min"]
                max_v = r[f"{m}_max"]
                kwargs[f"{m}_min"] = float(min_v) if min_v is not None else None
                kwargs[f"{m}_max"] = float(max_v) if max_v is not None else None
        agg_samples.append(TelemetrySample(**kwargs))

    return HistoryResponse(
        device_id=device_id,
        count=len(agg_samples),
        samples=agg_samples,
        bucket=resolved_bucket,
        range_start=start_ts,
        range_end=end_ts,
    )


async def get_device_meta(
    session: AsyncSession, device_id: str
) -> dict | None:
    """Return the last `meta` payload published by a device, or None."""
    from app.db.models import DeviceMeta  # local import — DeviceMeta lives in Phase 5 migration

    device = await session.get(Device, device_id)
    if device is None:
        raise DeviceNotFound(device_id)

    row = await session.get(DeviceMeta, device_id)
    if row is None:
        return None
    return {
        "device_id": row.device_id,
        "payload": row.payload,
        "updated_at": row.updated_at,
    }
