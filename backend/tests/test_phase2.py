"""
Integration tests — Phase 2: Auth, Devices, MQTT broker auth, TimescaleDB.

H1:  POST /auth/google with mocked Google token → access + refresh tokens + user in DB
H2:  POST /auth/refresh with valid refresh → new token pair, old token revoked
H3:  POST /auth/refresh with a revoked token → 401
H4:  POST /devices/{id}/claim with correct pairing_code → UserDevice created, 200
H5:  POST /devices/{id}/claim with wrong pairing_code → 403
H6:  GET /devices → authenticated user sees only their own devices
H7:  POST /mqtt/auth with valid JWT → 200; with expired JWT → 403
H8:  POST /mqtt/acl with device in claim → 200; device not in claim → 403
H9:  telemetry_raw is a TimescaleDB hypertable
H10: A retention policy is active for telemetry_raw

Requires Docker infra running (postgres + mosquitto).
"""
from __future__ import annotations

import hashlib
import time
import uuid
from contextlib import asynccontextmanager
from types import SimpleNamespace
from unittest import mock

import httpx
import pytest
from jose import jwt as jose_jwt
from sqlalchemy import select, text

from app.auth.google import GoogleUserInfo
from app.auth.jwt import create_access_token, create_backend_token, create_mqtt_token
from app.config import settings
from app.db.models import Device, RefreshToken, User, UserDevice
from app.db.session import async_session_factory
from app.devices.pairing import generate_pairing_code, hash_pairing_code
from app.main import app

# ── Helpers ─────────────────────────────────────────────────────────────────


def _client() -> httpx.AsyncClient:
    """Return an httpx async client backed by the ASGI app (no lifespan)."""
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    )


def _mock_google(sub: str, email: str):
    """Context manager that patches verify_google_token to return fake info."""
    return mock.patch(
        "app.auth.service.verify_google_token",
        return_value=GoogleUserInfo(sub=sub, email=email, name="Test User"),
    )


async def _login(client: httpx.AsyncClient, sub: str, email: str) -> dict:
    """POST /auth/google with a mocked Google token and return the JSON response."""
    with _mock_google(sub, email):
        r = await client.post("/auth/google", json={"id_token": "fake"})
    assert r.status_code == 200, r.text
    return r.json()


async def _seed_device(device_id: str, mac: str | None = None) -> str:
    """Insert a Device row into the DB and return the plaintext pairing code."""
    mac = mac or device_id  # use device_id as stand-in MAC for simplicity
    code = generate_pairing_code(mac)
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


def _fake_user() -> SimpleNamespace:
    """Minimal user-like object accepted by create_access_token / create_mqtt_token."""
    return SimpleNamespace(id=uuid.uuid4(), email="jwt-test@vena.test")


# ── H1: POST /auth/google ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_h1_google_login_creates_user_and_tokens():
    sub = f"sub-h1-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    async with _client() as client:
        tokens = await _login(client, sub, email)

    assert "access_token" in tokens
    assert "refresh_token" in tokens
    assert tokens["token_type"] == "bearer"
    assert tokens["user"]["email"] == email

    # User must be persisted in the DB
    async with async_session_factory() as session:
        user = (
            await session.execute(select(User).where(User.google_sub == sub))
        ).scalar_one()
        assert user.email == email

        # One non-revoked refresh token must exist
        rt = (
            await session.execute(
                select(RefreshToken).where(RefreshToken.user_id == user.id)
            )
        ).scalar_one()
        assert rt.revoked_at is None


# ── H2: POST /auth/refresh — valid token ──────────────────────────────────


@pytest.mark.asyncio
async def test_h2_refresh_returns_new_pair_and_revokes_old():
    sub = f"sub-h2-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    async with _client() as client:
        tokens = await _login(client, sub, email)
        old_refresh = tokens["refresh_token"]

        r = await client.post("/auth/refresh", json={"refresh_token": old_refresh})

    assert r.status_code == 200
    new_tokens = r.json()
    assert new_tokens["refresh_token"] != old_refresh

    # Old token must be marked as revoked
    old_hash = hashlib.sha256(old_refresh.encode()).hexdigest()
    async with async_session_factory() as session:
        rt = (
            await session.execute(
                select(RefreshToken).where(RefreshToken.token_hash == old_hash)
            )
        ).scalar_one()
        assert rt.revoked_at is not None


# ── H3: POST /auth/refresh — revoked token → 401 ─────────────────────────


@pytest.mark.asyncio
async def test_h3_revoked_refresh_returns_401():
    sub = f"sub-h3-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    async with _client() as client:
        tokens = await _login(client, sub, email)
        refresh = tokens["refresh_token"]

        # First use — valid rotation
        r1 = await client.post("/auth/refresh", json={"refresh_token": refresh})
        assert r1.status_code == 200

        # Second use with the same (now revoked) token — must fail
        r2 = await client.post("/auth/refresh", json={"refresh_token": refresh})

    assert r2.status_code == 401


# ── H4: POST /devices/{id}/claim — correct code ───────────────────────────


@pytest.mark.asyncio
async def test_h4_claim_correct_pairing_code():
    device_id = f"vena-h4-{uuid.uuid4().hex[:8]}"
    sub = f"sub-h4-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    pairing_code = await _seed_device(device_id)

    async with _client() as client:
        tokens = await _login(client, sub, email)

        r = await client.post(
            f"/devices/{device_id}/claim",
            json={"pairing_code": pairing_code},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )

    assert r.status_code == 200
    body = r.json()
    assert body["device_id"] == device_id

    # UserDevice row must exist in the DB
    async with async_session_factory() as session:
        user = (
            await session.execute(select(User).where(User.google_sub == sub))
        ).scalar_one()
        ud = (
            await session.execute(
                select(UserDevice).where(
                    UserDevice.user_id == user.id,
                    UserDevice.device_id == device_id,
                )
            )
        ).scalar_one()
        assert ud is not None


# ── H5: POST /devices/{id}/claim — wrong code → 403 ──────────────────────


@pytest.mark.asyncio
async def test_h5_claim_wrong_pairing_code_returns_403():
    device_id = f"vena-h5-{uuid.uuid4().hex[:8]}"
    sub = f"sub-h5-{uuid.uuid4().hex[:8]}"
    email = f"{sub}@vena.test"

    await _seed_device(device_id)

    async with _client() as client:
        tokens = await _login(client, sub, email)

        r = await client.post(
            f"/devices/{device_id}/claim",
            json={"pairing_code": "WRONG123"},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )

    assert r.status_code == 403


# ── H6: GET /devices — returns only the authenticated user's devices ───────


@pytest.mark.asyncio
async def test_h6_list_devices_returns_only_own_devices():
    device_id = f"vena-h6-{uuid.uuid4().hex[:8]}"
    sub_a = f"sub-h6a-{uuid.uuid4().hex[:8]}"
    sub_b = f"sub-h6b-{uuid.uuid4().hex[:8]}"

    pairing_code = await _seed_device(device_id)

    async with _client() as client:
        # User A claims the device
        tokens_a = await _login(client, sub_a, f"{sub_a}@vena.test")
        await client.post(
            f"/devices/{device_id}/claim",
            json={"pairing_code": pairing_code},
            headers={"Authorization": f"Bearer {tokens_a['access_token']}"},
        )

        # User B logs in fresh and queries their own device list
        tokens_b = await _login(client, sub_b, f"{sub_b}@vena.test")
        r = await client.get(
            "/devices",
            headers={"Authorization": f"Bearer {tokens_b['access_token']}"},
        )

    assert r.status_code == 200
    device_ids = [d["device_id"] for d in r.json()["devices"]]
    assert device_id not in device_ids


# ── H7: POST /mqtt/auth — valid JWT → 200; expired → 403 ─────────────────


@pytest.mark.asyncio
async def test_h7_mqtt_auth_valid_jwt_returns_200():
    token = create_access_token(_fake_user())

    async with _client() as client:
        r = await client.post(
            "/mqtt/auth",
            data={"username": token, "password": "", "clientid": "test-client"},
        )

    assert r.status_code == 200


@pytest.mark.asyncio
async def test_h7_mqtt_auth_expired_jwt_returns_403():
    user = _fake_user()
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "scope": "user",
        "exp": int(time.time()) - 10,  # already expired
    }
    expired_token = jose_jwt.encode(
        payload, settings.jwt_secret, algorithm=settings.jwt_algorithm
    )

    async with _client() as client:
        r = await client.post(
            "/mqtt/auth",
            data={"username": expired_token, "password": "", "clientid": "test-client"},
        )

    assert r.status_code == 403


# ── H8: POST /mqtt/acl — device in/out of claim ───────────────────────────


@pytest.mark.asyncio
async def test_h8_mqtt_acl_device_in_claim_returns_200():
    device_id = f"vena-h8-{uuid.uuid4().hex[:8]}"
    user = _fake_user()
    token = create_mqtt_token(user, [device_id])

    async with _client() as client:
        r = await client.post(
            "/mqtt/acl",
            data={
                "username": token,
                "topic": f"vena/{device_id}/telemetry",
                "clientid": "app-client",
                "acc": "1",
            },
        )

    assert r.status_code == 200


@pytest.mark.asyncio
async def test_h8_mqtt_acl_device_not_in_claim_returns_403():
    device_id = f"vena-h8x-{uuid.uuid4().hex[:8]}"
    user = _fake_user()
    token = create_mqtt_token(user, ["vena-other-device"])  # different device

    async with _client() as client:
        r = await client.post(
            "/mqtt/acl",
            data={
                "username": token,
                "topic": f"vena/{device_id}/telemetry",  # topic device ≠ claim device
                "clientid": "app-client",
                "acc": "1",
            },
        )

    assert r.status_code == 403


@pytest.mark.asyncio
async def test_h8_mqtt_acl_backend_scope_allows_all_vena_topics():
    token = create_backend_token()

    async with _client() as client:
        r = await client.post(
            "/mqtt/acl",
            data={
                "username": token,
                "topic": "vena/any-device/telemetry",
                "clientid": "vena-backend",
                "acc": "1",
            },
        )

    assert r.status_code == 200


# ── H9: telemetry_raw is a TimescaleDB hypertable ────────────────────────


@pytest.mark.asyncio
async def test_h9_telemetry_raw_is_hypertable():
    async with async_session_factory() as session:
        result = await session.execute(
            text(
                "SELECT hypertable_name "
                "FROM timescaledb_information.hypertables "
                "WHERE hypertable_name = 'telemetry_raw'"
            )
        )
        row = result.fetchone()

    assert row is not None, "telemetry_raw is not registered as a TimescaleDB hypertable"


# ── H10: Retention policy is active for telemetry_raw ────────────────────


@pytest.mark.asyncio
async def test_h10_retention_policy_active_for_telemetry_raw():
    async with async_session_factory() as session:
        result = await session.execute(
            text(
                "SELECT job_id "
                "FROM timescaledb_information.jobs "
                "WHERE proc_name = 'policy_retention' "
                "  AND hypertable_name = 'telemetry_raw'"
            )
        )
        row = result.fetchone()

    assert row is not None, "No active retention policy found for telemetry_raw"
