"""
Integration tests — Phase 1 telemetry E2E (E1–E4).

Strategy:
- Directly drive TelemetryIngestor._parse() + _flush() to avoid needing a live
  MQTT broker in CI. This tests the full ingest path (parse → auto-register → batch insert).
- Use httpx.AsyncClient with ASGITransport for REST endpoint tests. The lifespan
  (MQTT worker) is NOT started — the /history route only needs get_session, which
  creates its own DB session independently.

Requires Docker infra running (postgres + mosquitto).
"""
from __future__ import annotations

import asyncio
import json

import httpx
import pytest
from sqlalchemy import func, select, text

from app.db.models import Device, TelemetryRaw
from app.db.session import async_session_factory
from app.main import app
from app.telemetry.ingest import TelemetryIngestor

# ──────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────

TEST_DEVICE = "vena-test00000001"
BASE_TS_MS = 1_748_822_400_000  # 2026-02-01 00:00:00 UTC in ms — fixed for reproducibility


# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────


def make_mqtt_message(seq: int, ts_ms: int | None = None) -> tuple[str, bytes]:
    """Build a (topic, payload_bytes) pair as the MQTT worker would receive."""
    topic = f"vena/{TEST_DEVICE}/telemetry"
    payload = json.dumps(
        {
            "ts": ts_ms if ts_ms is not None else BASE_TS_MS + seq * 5000,
            "seq": seq,
            "ambient_t": round(22.0 + seq * 0.1, 2),
            "ambient_h": 65.0,
            "diss_t": 18.0,
            "diss_h": 60.0,
            "setpoint": 18.0,
            "pid_out": 120.0,
            "uptime_ms": seq * 5000,
        }
    ).encode()
    return topic, payload


async def flush(messages: list[tuple[str, bytes]]) -> None:
    """Parse messages and flush them through the ingestor to the DB."""
    ingestor = TelemetryIngestor(asyncio.Queue())
    rows = [ingestor._parse(topic, payload) for topic, payload in messages]
    valid_rows = [r for r in rows if r is not None]
    await ingestor._flush(valid_rows)


async def count_telemetry() -> int:
    async with async_session_factory() as session:
        result = await session.scalar(
            select(func.count())
            .select_from(TelemetryRaw)
            .where(TelemetryRaw.device_id == TEST_DEVICE)
        )
        return result or 0


# ──────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────


@pytest.fixture(autouse=True)
async def clean_test_device():
    """Wipe the test device before and after each test for isolation."""
    async def wipe() -> None:
        async with async_session_factory() as session:
            async with session.begin():
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


# ──────────────────────────────────────────────
# E1 — 5 messages → 5 rows persisted
# ──────────────────────────────────────────────


async def test_e1_five_messages_persisted() -> None:
    messages = [make_mqtt_message(seq=i) for i in range(5)]
    await flush(messages)

    assert await count_telemetry() == 5


# ──────────────────────────────────────────────
# E2 — duplicate (same device_id + ts) → idempotent
# ──────────────────────────────────────────────


async def test_e2_duplicate_message_is_idempotent() -> None:
    # First insert
    messages = [make_mqtt_message(seq=i) for i in range(5)]
    await flush(messages)
    assert await count_telemetry() == 5

    # Re-send the same first message
    await flush([messages[0]])

    assert await count_telemetry() == 5, "Duplicate insert should not increase row count"


# ──────────────────────────────────────────────
# E3 — GET /history returns samples ordered by ts DESC within range
# ──────────────────────────────────────────────


async def test_e3_history_endpoint_returns_ordered_samples(
    http_client: httpx.AsyncClient,
) -> None:
    # Seed DB with 5 rows (device auto-registered by _flush)
    messages = [make_mqtt_message(seq=i) for i in range(5)]
    await flush(messages)

    response = await http_client.get(
        f"/devices/{TEST_DEVICE}/history?limit=5&start=2025-01-01T00:00:00Z&end=2026-12-31T00:00:00Z"
    )

    assert response.status_code == 200
    body = response.json()
    assert body["device_id"] == TEST_DEVICE
    assert body["count"] == 5

    timestamps = [s["ts"] for s in body["samples"]]
    assert timestamps == sorted(timestamps, reverse=True), "Samples must be ordered ts DESC"


async def test_e3_history_endpoint_returns_404_for_unknown_device(
    http_client: httpx.AsyncClient,
) -> None:
    response = await http_client.get("/devices/vena-doesnotexist/history")

    assert response.status_code == 404


# ──────────────────────────────────────────────
# E4 — unknown device is auto-registered on first telemetry
# ──────────────────────────────────────────────


async def test_e4_unknown_device_is_auto_registered() -> None:
    # Confirm device does not exist yet
    async with async_session_factory() as session:
        device_before = await session.get(Device, TEST_DEVICE)
    assert device_before is None

    await flush([make_mqtt_message(seq=0)])

    async with async_session_factory() as session:
        device_after = await session.get(Device, TEST_DEVICE)

    assert device_after is not None
    assert device_after.status == "online"
    assert device_after.pairing_code_hash == "unprovisioned"
    assert device_after.first_seen_at is not None
