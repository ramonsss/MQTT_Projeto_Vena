"""Phase 5 tests — adaptive bucket /history endpoint and /meta.

Unit tests cover aggregation helpers in isolation; integration tests reuse the
real DB engine fixture from conftest.
"""
from __future__ import annotations

import asyncio
import json
from datetime import datetime, timedelta, timezone

import httpx
import pytest
from sqlalchemy import text

from app.db.session import async_session_factory
from app.main import app
from app.telemetry.aggregation import (
    ALLOWED_BUCKETS,
    RANGE_TO_TIMEDELTA,
    build_aggregate_sql,
    choose_bucket,
    has_min_max,
    parse_metrics,
    parse_range,
    resolve_bucket,
)
from app.telemetry.ingest import TelemetryIngestor

TEST_DEVICE = "vena-phase500001"


# ──────────────────────────────────────────────
# T19 — unit: choose_bucket
# ──────────────────────────────────────────────


def test_t19_choose_bucket_mapping() -> None:
    assert choose_bucket("1h") == "5s"
    assert choose_bucket("6h") == "5s"
    assert choose_bucket("24h") == "1m"
    assert choose_bucket("7d") == "1h"
    assert choose_bucket("30d") == "1h"
    assert choose_bucket("90d") == "1d"
    assert choose_bucket("1y") == "1d"


def test_t19_resolve_bucket_auto_delegates_to_choose() -> None:
    assert resolve_bucket("24h", "auto") == "1m"


def test_t19_resolve_bucket_passthrough() -> None:
    assert resolve_bucket("24h", "1h") == "1h"


def test_t19_resolve_bucket_invalid_raises() -> None:
    with pytest.raises(ValueError):
        resolve_bucket("24h", "30s")


def test_t19_parse_range_valid() -> None:
    assert parse_range("24h") == timedelta(hours=24)
    assert parse_range("7d") == timedelta(days=7)


def test_t19_parse_range_invalid_raises() -> None:
    with pytest.raises(ValueError):
        parse_range("99d")


def test_t19_parse_metrics_all() -> None:
    metrics = parse_metrics("all")
    assert "ambient_t" in metrics
    assert "pid_out" in metrics


def test_t19_parse_metrics_subset() -> None:
    assert parse_metrics("ambient_t,diss_t") == ("ambient_t", "diss_t")


def test_t19_parse_metrics_unknown_raises() -> None:
    with pytest.raises(ValueError):
        parse_metrics("foo_bar")


def test_t19_has_min_max_humidity_yes_pid_no() -> None:
    assert has_min_max("ambient_h") is True
    assert has_min_max("pid_out") is False


def test_t19_build_aggregate_sql_contains_min_max_only_for_sensors() -> None:
    sql = build_aggregate_sql("1h", ("ambient_t", "pid_out"))
    assert "ambient_t_min" in sql
    assert "ambient_t_max" in sql
    assert "pid_out_avg" in sql
    assert "pid_out_min" not in sql
    assert "date_trunc('hour'" in sql


# ──────────────────────────────────────────────
# Integration fixtures
# ──────────────────────────────────────────────


@pytest.fixture(autouse=True)
async def clean_phase5_device():
    async def wipe() -> None:
        async with async_session_factory() as session:
            async with session.begin():
                await session.execute(
                    text("DELETE FROM device_meta WHERE device_id = :d"),
                    {"d": TEST_DEVICE},
                )
                await session.execute(
                    text("DELETE FROM telemetry_raw WHERE device_id = :d"),
                    {"d": TEST_DEVICE},
                )
                await session.execute(
                    text("DELETE FROM devices WHERE id = :d"),
                    {"d": TEST_DEVICE},
                )

    await wipe()
    yield
    await wipe()


@pytest.fixture()
async def http_client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app, raise_app_exceptions=True),
        base_url="http://test",
    ) as client:
        yield client


def make_msg(seq: int, ts: datetime) -> tuple[str, bytes]:
    return (
        f"vena/{TEST_DEVICE}/telemetry",
        json.dumps(
            {
                "ts": int(ts.timestamp() * 1000),
                "seq": seq,
                "ambient_t": 22.0 + (seq % 5) * 0.5,
                "ambient_h": 65.0,
                "diss_t": 18.0,
                "diss_h": 60.0,
                "setpoint": 18.0,
                "pid_out": 120.0,
            }
        ).encode(),
    )


async def seed_recent(n: int, spacing_seconds: int = 60) -> None:
    """Insert N rows ending NOW, going backwards by spacing_seconds."""
    now = datetime.now(tz=timezone.utc)
    messages = [
        make_msg(seq=i, ts=now - timedelta(seconds=spacing_seconds * (n - i)))
        for i in range(n)
    ]
    ingestor = TelemetryIngestor(asyncio.Queue())
    rows = [r for r in (ingestor._parse(t, p) for t, p in messages) if r is not None]
    await ingestor._flush(rows)


# ──────────────────────────────────────────────
# T20 — integration: aggregated /history
# ──────────────────────────────────────────────


async def test_t20_history_range_24h_returns_aggregated(
    http_client: httpx.AsyncClient,
) -> None:
    # 30 rows spaced 1min over the last 30 minutes → bucket=1m → ~30 buckets
    await seed_recent(n=30, spacing_seconds=60)

    r = await http_client.get(f"/devices/{TEST_DEVICE}/history?range=24h")
    assert r.status_code == 200
    body = r.json()
    assert body["device_id"] == TEST_DEVICE
    assert body["bucket"] == "1m"
    assert body["range_start"] is not None
    assert body["range_end"] is not None
    assert body["count"] >= 1
    # Aggregated samples MUST carry sample_count
    assert body["samples"][0]["sample_count"] >= 1
    # ambient_t has avg/min/max
    assert body["samples"][0]["ambient_t"] is not None
    assert body["samples"][0]["ambient_t_min"] is not None


async def test_t20_history_bucket_5s_returns_raw(
    http_client: httpx.AsyncClient,
) -> None:
    await seed_recent(n=5, spacing_seconds=5)

    r = await http_client.get(f"/devices/{TEST_DEVICE}/history?range=1h&bucket=5s")
    assert r.status_code == 200
    body = r.json()
    assert body["bucket"] == "5s"
    assert body["count"] == 5
    # Raw samples must NOT carry sample_count
    assert body["samples"][0]["sample_count"] is None


async def test_t20_history_invalid_range_returns_422(
    http_client: httpx.AsyncClient,
) -> None:
    r = await http_client.get(f"/devices/{TEST_DEVICE}/history?range=99y")
    assert r.status_code == 422


async def test_t20_history_legacy_start_end_still_works(
    http_client: httpx.AsyncClient,
) -> None:
    await seed_recent(n=3, spacing_seconds=5)
    r = await http_client.get(
        f"/devices/{TEST_DEVICE}/history"
        "?start=2025-01-01T00:00:00Z&end=2030-12-31T00:00:00Z&limit=10"
    )
    assert r.status_code == 200
    body = r.json()
    assert body["count"] == 3
    # Legacy mode doesn't set bucket field
    assert body.get("bucket") is None


async def test_t20_history_unknown_device_404(
    http_client: httpx.AsyncClient,
) -> None:
    r = await http_client.get("/devices/vena-doesnotexistt/history?range=24h")
    assert r.status_code == 404


# ──────────────────────────────────────────────
# T21 — integration: /meta UPSERT + retrieval
# ──────────────────────────────────────────────


async def test_t21_meta_endpoint_returns_last_payload(
    http_client: httpx.AsyncClient,
) -> None:
    payload = {
        "fw_version": "1.0.0-feira",
        "ble_max_conn": 3,
        "free_heap_boot": 142336,
        "free_heap_min_runtime": 98420,
        "wifi_rssi": -62,
        "ntp_synced": True,
        "boot_count": 17,
        "last_reset_reason": "ESP_RST_POWERON",
    }
    ingestor = TelemetryIngestor(asyncio.Queue())
    await ingestor._handle_meta(TEST_DEVICE, json.dumps(payload).encode())

    r = await http_client.get(f"/devices/{TEST_DEVICE}/meta")
    assert r.status_code == 200
    body = r.json()
    assert body["device_id"] == TEST_DEVICE
    assert body["payload"]["boot_count"] == 17
    assert body["payload"]["free_heap_min_runtime"] == 98420


async def test_t21_meta_upsert_replaces_previous(
    http_client: httpx.AsyncClient,
) -> None:
    ingestor = TelemetryIngestor(asyncio.Queue())
    await ingestor._handle_meta(
        TEST_DEVICE, json.dumps({"boot_count": 1, "fw_version": "0.9"}).encode()
    )
    await ingestor._handle_meta(
        TEST_DEVICE, json.dumps({"boot_count": 2, "fw_version": "1.0"}).encode()
    )

    r = await http_client.get(f"/devices/{TEST_DEVICE}/meta")
    assert r.status_code == 200
    body = r.json()
    assert body["payload"]["boot_count"] == 2
    assert body["payload"]["fw_version"] == "1.0"


async def test_t21_meta_404_when_never_published(
    http_client: httpx.AsyncClient,
) -> None:
    # Auto-register device via a single telemetry row (no meta).
    await seed_recent(n=1, spacing_seconds=5)
    r = await http_client.get(f"/devices/{TEST_DEVICE}/meta")
    assert r.status_code == 404
