#!/usr/bin/env python3
"""
E2E Smoke Test — Vena Phase 2

Validates the full auth + device claim + MQTT auth flow against a running
backend (localhost:8000) and broker (localhost:1883).

Run with Docker infra UP and the backend server running:

    # Terminal 1 (infra):
    cd infra && docker-compose up -d

    # Terminal 2 (backend):
    cd backend && uvicorn app.main:app --reload

    # Terminal 3 (smoke test):
    cd backend && python scripts/smoke_test.py
"""
from __future__ import annotations

import asyncio
import sys
import threading
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# Allow importing app modules from the backend directory.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import httpx
from jose import jwt as jose_jwt
from sqlalchemy import select, text

from app.config import settings
from app.db.models import Device, User
from app.db.session import async_session_factory
from app.devices.pairing import generate_pairing_code, hash_pairing_code

BASE_URL = "http://localhost:8000"
BROKER_HOST = "localhost"
BROKER_PORT = 1883

# ── Pre-flight checks ────────────────────────────────────────────────────────


def _preflight() -> None:
    """Abort early with actionable messages if the required services are down."""
    import socket

    errors: list[str] = []

    # Backend reachable on localhost:8000
    try:
        s = socket.create_connection(("localhost", 8000), timeout=2)
        s.close()
    except OSError:
        errors.append(
            "Backend not reachable at localhost:8000.\n"
            "  Start with: venv\\Scripts\\uvicorn app.main:app --reload --host 0.0.0.0"
        )

    # Backend must also be reachable from Docker (host.docker.internal:8000)
    try:
        s = socket.create_connection(("host.docker.internal", 8000), timeout=2)
        s.close()
    except OSError:
        errors.append(
            "Backend not reachable at host.docker.internal:8000 (needed by the broker).\n"
            "  Restart uvicorn binding all interfaces: --host 0.0.0.0"
        )

    # MQTT broker reachable on localhost:1883
    try:
        s = socket.create_connection(("localhost", 1883), timeout=2)
        s.close()
    except OSError:
        errors.append(
            "MQTT broker not reachable at localhost:1883.\n"
            "  Start infra: cd infra && docker-compose up -d"
        )

    if errors:
        print("\n\u274c Pre-flight failed:\n")
        for e in errors:
            print(f"  \u2022 {e}\n")
        sys.exit(1)




def _make_token(user_id: str, email: str) -> str:
    """Create a valid access token directly using the JWT secret (bypasses Google)."""
    now = datetime.now(tz=timezone.utc)
    payload: dict[str, Any] = {
        "sub": user_id,
        "email": email,
        "scope": "user",
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_expire_minutes),
    }
    return jose_jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


async def _seed_user(user_id: uuid.UUID, email: str, google_sub: str) -> None:
    async with async_session_factory() as session:
        existing = (
            await session.execute(select(User).where(User.id == user_id))
        ).scalar_one_or_none()
        if existing is None:
            session.add(User(id=user_id, google_sub=google_sub, email=email))
            await session.commit()


async def _seed_device(device_id: str) -> str:
    """Insert a Device row and return the plaintext pairing code."""
    code = generate_pairing_code(device_id)
    hash_ = hash_pairing_code(code)
    async with async_session_factory() as session:
        existing = (
            await session.execute(select(Device).where(Device.id == device_id))
        ).scalar_one_or_none()
        if existing is None:
            session.add(
                Device(id=device_id, pairing_code_hash=hash_, status="never_connected")
            )
            await session.commit()
    return code


def ok(label: str, detail: str = "") -> None:
    suffix = f"  ({detail})" if detail else ""
    print(f"  \u2705 {label}{suffix}")


def fail(label: str, detail: str = "") -> None:
    suffix = f"  ({detail})" if detail else ""
    print(f"  \u274c {label}{suffix}")
    sys.exit(1)


def check(label: str, cond: bool, detail: str = "") -> None:
    if cond:
        ok(label, detail)
    else:
        fail(label, detail)


# ── MQTT helpers ─────────────────────────────────────────────────────────────


def _mqtt_connect_test(token: str, expected_rc: int = 0) -> int:
    """Try connecting to the broker with *token* as username.

    Returns the CONNACK result code (0 = accepted).
    """
    import paho.mqtt.client as paho  # type: ignore[import]

    result: dict[str, int] = {"rc": -1}
    event = threading.Event()

    def on_connect(client, userdata, flags, rc, *args):
        result["rc"] = rc
        event.set()

    # Support both Paho v1 and v2 callback API
    try:
        c = paho.Client(paho.CallbackAPIVersion.VERSION2, client_id=f"smoke-{uuid.uuid4().hex[:6]}")
    except AttributeError:
        c = paho.Client(client_id=f"smoke-{uuid.uuid4().hex[:6]}")

    c.username_pw_set(token, "vena")  # go-auth rejects empty password before calling HTTP backend
    c.on_connect = on_connect
    try:
        c.connect(BROKER_HOST, BROKER_PORT, keepalive=5)
        c.loop_start()
        event.wait(timeout=5)
        c.loop_stop()
        c.disconnect()
    except Exception as exc:
        print(f"    [MQTT] connection error: {exc}")
        return -1
    return result["rc"]


# ── Main smoke test ───────────────────────────────────────────────────────────


async def main() -> None:
    _preflight()
    print("\n====  Vena Phase 2 — Smoke Test  ====\n")

    run_id = uuid.uuid4().hex[:8]
    user_id = uuid.uuid4()
    email = f"smoke-{run_id}@vena.test"
    google_sub = f"google-smoke-{run_id}"
    device_id = f"vena-sm{run_id}"

    # ── Seed test data ──────────────────────────────────────────────────────
    print("[1/8] Seeding test user and device in DB…")
    await _seed_user(user_id, email, google_sub)
    pairing_code = await _seed_device(device_id)
    ok("User and device seeded", f"device_id={device_id}")

    access_token = _make_token(str(user_id), email)
    headers = {"Authorization": f"Bearer {access_token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, timeout=10) as client:

        # ── 2: List devices (empty) ─────────────────────────────────────────
        print("[2/8] GET /devices — expect empty list…")
        r = await client.get("/devices", headers=headers)
        check("GET /devices → 200", r.status_code == 200, r.text)
        ids_before = [d["device_id"] for d in r.json()["devices"]]
        check("Device not yet claimed", device_id not in ids_before)

        # ── 3: Claim device ─────────────────────────────────────────────────
        print("[3/8] POST /devices/{id}/claim — correct pairing code…")
        r = await client.post(
            f"/devices/{device_id}/claim",
            json={"pairing_code": pairing_code},
            headers=headers,
        )
        check("Claim → 200", r.status_code == 200, r.text)

        print("      POST /devices/{id}/claim — wrong pairing code → 403…")
        r_bad = await client.post(
            f"/devices/{device_id}/claim",
            json={"pairing_code": "BADCODE1"},
            headers=headers,
        )
        check("Wrong pairing code → 403", r_bad.status_code == 403, r_bad.text)

        print("      POST /devices/{id}/claim — correct code again → 409 (duplicate)…")
        r_dup = await client.post(
            f"/devices/{device_id}/claim",
            json={"pairing_code": pairing_code},
            headers=headers,
        )
        check("Re-claim same device → 409", r_dup.status_code == 409, r_dup.text)

        # ── 4: List devices (claimed) ───────────────────────────────────────
        print("[4/8] GET /devices — expect claimed device…")
        r = await client.get("/devices", headers=headers)
        ids_after = [d["device_id"] for d in r.json()["devices"]]
        check("Device appears in list after claim", device_id in ids_after)

        # ── 5: MQTT credentials ─────────────────────────────────────────────
        print("[5/8] POST /mqtt/credentials — expect token with devices claim…")
        r = await client.post("/mqtt/credentials", headers=headers)
        check("POST /mqtt/credentials → 200", r.status_code == 200, r.text)
        mqtt_token = r.json()["mqtt_token"]
        decoded = jose_jwt.decode(
            mqtt_token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
        check(
            "MQTT token contains claimed device",
            device_id in decoded.get("devices", []),
            f"devices={decoded.get('devices')}",
        )

        # ── 6: Broker auth endpoints ─────────────────────────────────────────
        print("[6/8] Testing /mqtt/auth and /mqtt/acl endpoints…")
        r = await client.post(
            "/mqtt/auth",
            data={"username": mqtt_token, "password": "", "clientid": "smoke"},
        )
        check("POST /mqtt/auth valid token → 200", r.status_code == 200)

        r = await client.post(
            "/mqtt/auth",
            data={"username": "not-a-jwt", "password": "", "clientid": "smoke"},
        )
        check("POST /mqtt/auth invalid token → 403", r.status_code == 403)

        r = await client.post(
            "/mqtt/acl",
            data={
                "username": mqtt_token,
                "topic": f"vena/{device_id}/telemetry",
                "clientid": "smoke",
                "acc": "2",
            },
        )
        check("POST /mqtt/acl own device → 200", r.status_code == 200)

        r = await client.post(
            "/mqtt/acl",
            data={
                "username": mqtt_token,
                "topic": "vena/foreign-device/telemetry",
                "clientid": "smoke",
                "acc": "2",
            },
        )
        check("POST /mqtt/acl foreign device → 403", r.status_code == 403)

    # ── 7: Live MQTT broker test ────────────────────────────────────────────
    print("[7/8] Connecting to MQTT broker at localhost:1883…")
    rc = _mqtt_connect_test(mqtt_token)
    check("Broker accepts valid JWT (CONNACK rc=0)", rc == 0, f"rc={rc}")

    # ── 8: TimescaleDB checks ────────────────────────────────────────────────
    print("[8/8] Verifying TimescaleDB hypertable and retention policy…")
    async with async_session_factory() as session:
        row = (
            await session.execute(
                text(
                    "SELECT hypertable_name FROM timescaledb_information.hypertables "
                    "WHERE hypertable_name = 'telemetry_raw'"
                )
            )
        ).fetchone()
        check("telemetry_raw is a hypertable", row is not None)

        row = (
            await session.execute(
                text(
                    "SELECT job_id FROM timescaledb_information.jobs "
                    "WHERE proc_name = 'policy_retention' "
                    "  AND hypertable_name = 'telemetry_raw'"
                )
            )
        ).fetchone()
        check("Retention policy active for telemetry_raw (90 days)", row is not None)

    print("\n====  All checks passed — Phase 2 smoke test OK  ====\n")


if __name__ == "__main__":
    asyncio.run(main())
