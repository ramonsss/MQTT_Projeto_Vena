"""
Test configuration: patches the shared DB engine to use NullPool.

The engine is created INSIDE the session-scoped event loop (not at import time)
so asyncpg Futures are bound to the correct loop. All tests share that same
session loop (asyncio_default_test_loop_scope = "session" in pyproject.toml),
avoiding cross-loop connection errors on Windows.
"""
from __future__ import annotations

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

import app.db.session as db_module
import app.telemetry.ingest as ingest_module
from app.config import settings


@pytest.fixture(scope="session", autouse=True)
async def null_pool_engine():
    """
    Creates a NullPool engine inside the running session event loop so that
    asyncpg protocol Futures are attached to the same loop used by all tests.
    Patches every module that holds a direct reference to async_session_factory.
    """
    # Lazy import: test module is already collected at this point, no circular issue.
    import tests.test_telemetry_integration as test_module  # noqa: PLC0415

    engine = create_async_engine(settings.database_url, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    _orig = {
        "db_engine": db_module.engine,
        "db_factory": db_module.async_session_factory,
        "ingest": ingest_module.async_session_factory,
        "test": test_module.async_session_factory,
    }

    db_module.engine = engine
    db_module.async_session_factory = factory
    ingest_module.async_session_factory = factory
    test_module.async_session_factory = factory

    yield factory

    db_module.engine = _orig["db_engine"]
    db_module.async_session_factory = _orig["db_factory"]
    ingest_module.async_session_factory = _orig["ingest"]
    test_module.async_session_factory = _orig["test"]
    await engine.dispose()
