"""Helpers for the adaptive bucket /history endpoint (Phase 5).

Pure functions — no DB access. Tested in isolation by ``test_history.py``.
"""
from __future__ import annotations

from datetime import timedelta

# Allowed range tokens accepted by ?range=
RANGE_TO_TIMEDELTA: dict[str, timedelta] = {
    "1h":  timedelta(hours=1),
    "6h":  timedelta(hours=6),
    "24h": timedelta(hours=24),
    "7d":  timedelta(days=7),
    "30d": timedelta(days=30),
    "90d": timedelta(days=90),
    "1y":  timedelta(days=365),
}

# Allowed bucket tokens accepted by ?bucket=
ALLOWED_BUCKETS: tuple[str, ...] = ("auto", "5s", "1m", "1h", "1d")

# Mapping of our public bucket token → Postgres date_trunc field.
# "5s" is special: it means "no aggregation, return raw rows".
_BUCKET_TO_DATE_TRUNC: dict[str, str] = {
    "1m": "minute",
    "1h": "hour",
    "1d": "day",
}

# All metric columns that may appear in `?metric=`.
ALL_METRICS: tuple[str, ...] = (
    "ambient_t",
    "ambient_h",
    "diss_t",
    "diss_h",
    "setpoint",
    "pid_out",
)

# Metrics that expose avg/min/max. The rest only expose avg.
_MIN_MAX_METRICS: frozenset[str] = frozenset(
    {"ambient_t", "ambient_h", "diss_t", "diss_h"}
)


def choose_bucket(range_: str) -> str:
    """Pick the default bucket for a given range when ?bucket=auto."""
    return {
        "1h":  "5s",
        "6h":  "5s",
        "24h": "1m",
        "7d":  "1h",
        "30d": "1h",
        "90d": "1d",
        "1y":  "1d",
    }[range_]


def parse_range(range_: str) -> timedelta:
    if range_ not in RANGE_TO_TIMEDELTA:
        raise ValueError(f"invalid range: {range_!r}")
    return RANGE_TO_TIMEDELTA[range_]


def resolve_bucket(range_: str, bucket: str) -> str:
    """Validate user input and return the concrete bucket token."""
    if bucket not in ALLOWED_BUCKETS:
        raise ValueError(f"invalid bucket: {bucket!r}")
    if bucket == "auto":
        return choose_bucket(range_)
    return bucket


def date_trunc_field(bucket: str) -> str:
    """Return the Postgres date_trunc field for a non-raw bucket."""
    if bucket not in _BUCKET_TO_DATE_TRUNC:
        raise ValueError(f"bucket {bucket!r} is not aggregatable")
    return _BUCKET_TO_DATE_TRUNC[bucket]


def parse_metrics(metric: str) -> tuple[str, ...]:
    """Validate ?metric=foo,bar and return the requested columns."""
    if metric == "all":
        return ALL_METRICS
    requested = tuple(m.strip() for m in metric.split(",") if m.strip())
    if not requested:
        raise ValueError("metric must not be empty")
    unknown = [m for m in requested if m not in ALL_METRICS]
    if unknown:
        raise ValueError(f"unknown metric(s): {unknown}")
    return requested


def has_min_max(metric: str) -> bool:
    return metric in _MIN_MAX_METRICS


def build_aggregate_sql(bucket: str, metrics: tuple[str, ...]) -> str:
    """Build the SQL for an aggregated /history query.

    `bucket` is validated to be one of '1m'|'1h'|'1d' (interpolated safely
    because asyncpg treats date_trunc's first argument as a literal, not a
    bind parameter — see Armadilhas in phase5 prompt).
    """
    field = date_trunc_field(bucket)
    select_parts: list[str] = [f"date_trunc('{field}', ts) AS bucket"]
    for m in metrics:
        select_parts.append(f"AVG({m}) AS {m}_avg")
        if has_min_max(m):
            select_parts.append(f"MIN({m}) AS {m}_min")
            select_parts.append(f"MAX({m}) AS {m}_max")
    select_parts.append("COUNT(*) AS sample_count")

    return (
        "SELECT " + ", ".join(select_parts) + " "
        "FROM telemetry_raw "
        "WHERE device_id = :device_id "
        "  AND ts >= :start_ts "
        "  AND ts <  :end_ts "
        "GROUP BY 1 "
        "ORDER BY 1"
    )
