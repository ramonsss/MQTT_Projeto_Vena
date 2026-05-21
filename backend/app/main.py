from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI

from app.shared.logging import get_logger

log = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    log.info("Vena backend starting up")
    yield
    log.info("Vena backend shutting down")


app = FastAPI(
    title="Vena API",
    version="0.1.0",
    description="IoT telemetry backend for Vena devices",
    lifespan=lifespan,
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "vena-backend"}
