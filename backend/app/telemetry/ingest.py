from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone

from sqlalchemy import insert, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.db.models import Device, TelemetryRaw
from app.db.session import async_session_factory
from app.mqtt.topics import parse_topic
from app.shared.logging import get_logger

log = get_logger(__name__)

_BATCH_SIZE = 100
_FLUSH_INTERVAL = 1.0  # seconds


class TelemetryIngestor:
    """Async task that drains the MQTT queue and batch-inserts into telemetry_raw."""

    def __init__(self, queue: asyncio.Queue[tuple[str, bytes]]) -> None:
        self._queue = queue
        self._task: asyncio.Task[None] | None = None

    def start(self) -> None:
        self._task = asyncio.create_task(self._run(), name="telemetry-ingestor")

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        # Drain remaining items
        remaining: list[dict] = []
        while not self._queue.empty():
            try:
                topic, payload = self._queue.get_nowait()
                row = self._parse(topic, payload)
                if row:
                    remaining.append(row)
            except asyncio.QueueEmpty:
                break
        if remaining:
            await self._flush(remaining)

    async def _run(self) -> None:
        batch: list[dict] = []
        last_flush = asyncio.get_event_loop().time()

        while True:
            timeout = _FLUSH_INTERVAL - (asyncio.get_event_loop().time() - last_flush)
            try:
                topic, payload = await asyncio.wait_for(
                    self._queue.get(), timeout=max(timeout, 0.05)
                )
                row = self._parse(topic, payload)
                if row:
                    batch.append(row)
            except asyncio.TimeoutError:
                pass

            should_flush = (
                len(batch) >= _BATCH_SIZE
                or (batch and asyncio.get_event_loop().time() - last_flush >= _FLUSH_INTERVAL)
            )
            if should_flush:
                await self._flush(batch)
                batch = []
                last_flush = asyncio.get_event_loop().time()

    def _parse(self, topic: str, payload: bytes) -> dict | None:
        parsed = parse_topic(topic)
        if parsed is None:
            return None
        device_id, msg_type = parsed

        if msg_type != "telemetry":
            return None

        try:
            data: dict = json.loads(payload)
        except json.JSONDecodeError:
            log.warning("Invalid JSON from {}: {}", topic, payload[:80])
            return None

        ts_raw = data.get("ts")
        if ts_raw is None:
            log.warning("Missing 'ts' field in telemetry from {}", device_id)
            return None

        try:
            ts = datetime.fromtimestamp(int(ts_raw) / 1000, tz=timezone.utc)
        except (ValueError, OSError):
            log.warning("Invalid 'ts' value {} from {}", ts_raw, device_id)
            return None

        return {
            "device_id": device_id,
            "ts": ts,
            "ambient_t": data.get("ambient_t"),
            "ambient_h": data.get("ambient_h"),
            "diss_t": data.get("diss_t"),
            "diss_h": data.get("diss_h"),
            "setpoint": data.get("setpoint"),
            "pid_out": data.get("pid_out"),
            "uptime_ms": data.get("uptime_ms"),
            "seq": data.get("seq"),
        }

    async def _flush(self, rows: list[dict]) -> None:
        if not rows:
            return

        device_ids = {r["device_id"] for r in rows}
        now = datetime.now(tz=timezone.utc)

        async with async_session_factory() as session:
            async with session.begin():
                # Auto-register unknown devices
                existing = set(
                    (await session.scalars(
                        select(Device.id).where(Device.id.in_(device_ids))
                    )).all()
                )
                new_device_ids = device_ids - existing
                for did in new_device_ids:
                    log.info("Auto-registering unknown device: {}", did)
                    await session.execute(
                        pg_insert(Device).values(
                            id=did,
                            pairing_code_hash="unprovisioned",
                            status="online",
                            first_seen_at=now,
                            last_seen_at=now,
                        ).on_conflict_do_nothing(index_elements=["id"])
                    )

                # Update last_seen_at for known devices
                for did in existing:
                    await session.execute(
                        update(Device)
                        .where(Device.id == did)
                        .values(last_seen_at=now, status="online")
                    )

                # Batch insert telemetry — ON CONFLICT DO NOTHING for idempotency
                stmt = pg_insert(TelemetryRaw).values(rows)
                stmt = stmt.on_conflict_do_nothing(index_elements=["device_id", "ts"])
                await session.execute(stmt)

        log.debug("Flushed {} telemetry rows for devices: {}", len(rows), device_ids)
