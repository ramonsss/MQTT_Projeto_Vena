from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI

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


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "vena-backend"}


app.include_router(telemetry_router)
