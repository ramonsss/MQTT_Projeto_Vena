from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth.routes import router as auth_router
from app.broker_auth.routes import router as broker_auth_router
from app.devices.routes import router as devices_router
from app.mqtt.routes import router as mqtt_router
from app.mqtt.worker import MqttWorker
from app.shared.logging import get_logger
from app.telemetry.ingest import TelemetryIngestor
from app.telemetry.routes import router as telemetry_router

log = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    log.info("Vena backend starting up")

    queue: asyncio.Queue[tuple[str, bytes]] = asyncio.Queue(maxsize=10_000)
    loop = asyncio.get_event_loop()

    worker = MqttWorker(queue=queue, loop=loop)
    ingestor = TelemetryIngestor(queue=queue)

    worker.start()
    ingestor.start()

    yield

    log.info("Vena backend shutting down")
    worker.stop()
    await ingestor.stop()


app = FastAPI(
    title="Vena API",
    version="0.1.0",
    description="IoT telemetry backend for Vena devices",
    lifespan=lifespan,
)

# CORS — qualquer porta localhost em dev + domínio de produção
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://localhost(:\d+)?",
    allow_origins=["https://app.vena.farm"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "vena-backend"}


# ── Routers ────────────────────────────────────────────────────────────────
app.include_router(auth_router)         # POST /auth/google, /auth/refresh
app.include_router(devices_router)      # POST /devices/{id}/claim, GET /devices, PATCH /devices/{id}
app.include_router(mqtt_router)         # POST /mqtt/credentials, /devices/{id}/provision
app.include_router(broker_auth_router)  # POST /mqtt/auth, /mqtt/acl, /mqtt/superuser
app.include_router(telemetry_router)    # GET  /telemetry/*
