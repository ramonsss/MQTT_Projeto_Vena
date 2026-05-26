"""
E2E Integration tests — Phase 4: BLE Provisioning endpoint (G1-G3).

P1: POST /devices/provision without auth header → 401
P2: POST /devices/provision with valid auth but unknown device_id → 404
P3: POST /devices/provision with valid device but wrong pairing code → 403
P4: POST /devices/provision with correct credentials → device_jwt with
    scope=device, sub=device_id, device_id=device_id claims
P5: The device_jwt returned by /provision passes /mqtt/auth (broker can
    verify it before the device even connects to Wi-Fi)
P6: Full wizard flow: login → provision → claim → device appears in GET /devices

Requires Docker infra running (postgres + mosquitto).
"""
from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest import mock

import httpx
import pytest
from jose import jwt as jose_jwt
from sqlalchemy import select

from app.auth.google import GoogleUserInfo
from app.config import settings
from app.db.models import Device, UserDevice
from app.db.session import async_session_factory
from app.devices.pairing import generate_pairing_code, hash_pairing_code
from app.main import app

# ── Helpers ────────────────────────────────────────────────────────────────────


def _client() -> httpx.AsyncClient:
    """Return an httpx async client backed by the ASGI app (no lifespan)."""
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    )


def _mock_google(sub: str, email: str):
    return mock.patch(
        "app.auth.service.verify_google_token",
        return_value=GoogleUserInfo(sub=sub, email=email, name="Test User"),
    )


async def _login(client: httpx.AsyncClient, sub: str, email: str) -> dict:
    """POST /auth/google with mocked token; returns the JSON response."""
    with _mock_google(sub, email):
        r = await client.post("/auth/google", json={"id_token": "fake"})
    assert r.status_code == 200, r.text
    return r.json()


async def _seed_device(device_id: str) -> str:
    """Insert a Device row into the DB and return the plaintext pairing code."""
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


# ── P1: unauthenticated → 401 ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_p1_provision_without_auth_returns_401():
    device_id = f"vena-p1-{uuid.uuid4().hex[:8]}"
    await _seed_device(device_id)

    async with _client() as client:
        r = await client.post(
            "/devices/provision",
            json={"device_id": device_id, "pairing_code": "FAKE0000"},
        )

    assert r.status_code == 401


# ── P2: unknown device → 404 ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_p2_provision_unknown_device_returns_404():
    sub = f"sub-p2-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    async with _client() as client:
        tokens = await _login(client, sub, email)
        r = await client.post(
            "/devices/provision",
            json={"device_id": "vena-does-not-exist", "pairing_code": "FAKE0000"},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )

    assert r.status_code == 404


# ── P3: wrong pairing code → 403 ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_p3_provision_wrong_code_returns_403():
    device_id = f"vena-p3-{uuid.uuid4().hex[:8]}"
    sub = f"sub-p3-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    await _seed_device(device_id)

    async with _client() as client:
        tokens = await _login(client, sub, email)
        r = await client.post(
            "/devices/provision",
            json={"device_id": device_id, "pairing_code": "XXXXXXXX"},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )

    assert r.status_code == 403


# ── P4: valid credentials → device_jwt with correct JWT claims ────────────────


@pytest.mark.asyncio
async def test_p4_provision_returns_device_jwt_with_correct_claims():
    device_id = f"vena-p4-{uuid.uuid4().hex[:8]}"
    sub = f"sub-p4-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    pairing_code = await _seed_device(device_id)

    async with _client() as client:
        tokens = await _login(client, sub, email)
        r = await client.post(
            "/devices/provision",
            json={"device_id": device_id, "pairing_code": pairing_code},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )

    assert r.status_code == 200
    body = r.json()
    assert "device_jwt" in body

    # Decode without verification first to inspect claims structure
    claims = jose_jwt.decode(
        body["device_jwt"],
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
    assert claims["scope"] == "device", "JWT must carry scope=device"
    assert claims["sub"] == device_id, "JWT sub must be the device_id"
    assert claims["device_id"] == device_id, "JWT must contain device_id claim"

    # Token must not be expired at issuance
    assert claims["exp"] > claims["iat"], "exp must be after iat"


# ── P5: device_jwt passes /mqtt/auth (broker auth endpoint) ───────────────────


@pytest.mark.asyncio
async def test_p5_device_jwt_passes_broker_auth():
    device_id = f"vena-p5-{uuid.uuid4().hex[:8]}"
    sub = f"sub-p5-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    pairing_code = await _seed_device(device_id)

    async with _client() as client:
        tokens = await _login(client, sub, email)

        # Obtain device JWT via /devices/provision
        prov = await client.post(
            "/devices/provision",
            json={"device_id": device_id, "pairing_code": pairing_code},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        assert prov.status_code == 200
        device_jwt = prov.json()["device_jwt"]

        # The device presents its JWT as the MQTT username.
        # /mqtt/auth must accept it (this is what the Mosquitto plugin calls).
        mqtt_auth = await client.post(
            "/mqtt/auth",
            data={
                "username": device_jwt,
                "password": "",
                "clientid": device_id,
            },
        )

    assert mqtt_auth.status_code == 200, (
        "device_jwt must be accepted by /mqtt/auth so the ESP32 "
        "can connect to the broker after provisioning"
    )


# ── P6: full wizard flow: provision → claim → device visible ──────────────────


@pytest.mark.asyncio
async def test_p6_full_flow_provision_claim_device_visible():
    """
    Mirrors the complete wizard sequence executed by the Flutter app:
      1. App calls POST /devices/provision → obtains device_jwt
      2. App (after ESP confirms Wi-Fi) calls POST /devices/{id}/claim
      3. GET /devices returns the newly paired device
    """
    device_id = f"vena-p6-{uuid.uuid4().hex[:8]}"
    sub = f"sub-p6-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    pairing_code = await _seed_device(device_id)

    async with _client() as client:
        tokens = await _login(client, sub, email)
        access = tokens["access_token"]

        # Step 1 — App gets device JWT (ESP will use it for MQTT auth)
        prov = await client.post(
            "/devices/provision",
            json={"device_id": device_id, "pairing_code": pairing_code},
            headers={"Authorization": f"Bearer {access}"},
        )
        assert prov.status_code == 200, prov.text

        # Step 2 — App claims the device after ESP confirms Wi-Fi connection
        claim = await client.post(
            f"/devices/{device_id}/claim",
            json={"pairing_code": pairing_code},
            headers={"Authorization": f"Bearer {access}"},
        )
        assert claim.status_code == 200, claim.text

        # Step 3 — Device must appear in the authenticated user's device list
        device_list = await client.get(
            "/devices",
            headers={"Authorization": f"Bearer {access}"},
        )

    assert device_list.status_code == 200
    device_ids = [d["device_id"] for d in device_list.json()["devices"]]
    assert device_id in device_ids, (
        f"Device {device_id!r} should appear in /devices after provision+claim"
    )

    # Confirm UserDevice row exists in DB with correct user ownership
    async with async_session_factory() as session:
        from app.db.models import User  # noqa: PLC0415

        user = (
            await session.execute(
                select(User).where(User.google_sub == sub)
            )
        ).scalar_one()
        ud = (
            await session.execute(
                select(UserDevice).where(
                    UserDevice.user_id == user.id,
                    UserDevice.device_id == device_id,
                )
            )
        ).scalar_one_or_none()
    assert ud is not None, "UserDevice row must exist after claim"
