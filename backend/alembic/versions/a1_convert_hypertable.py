"""convert telemetry_raw to TimescaleDB hypertable with retention policy

Revision ID: a1b2c3d4e5f1
Revises: 5421ecc75138
Create Date: 2026-05-21 21:00:00.000000

Converts telemetry_raw to a TimescaleDB hypertable partitioned by ts (1-day
chunks) and registers a 90-day retention policy so old chunks are automatically
dropped by the TimescaleDB background worker.

NOT reversible — converting back from hypertable to plain table is unsupported
in production; it would require re-creating the table from scratch.
"""
import logging
from typing import Sequence, Union

from alembic import op
from sqlalchemy import text

log = logging.getLogger("alembic.runtime.migration")

revision: str = "a1b2c3d4e5f1"
down_revision: Union[str, None] = "5421ecc75138"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _timescaledb_available() -> bool:
    """Return True only if timescaledb is available on this server."""
    conn = op.get_bind()
    row = conn.execute(
        text(
            "SELECT COUNT(*) FROM pg_available_extensions "
            "WHERE name = 'timescaledb'"
        )
    ).scalar()
    return bool(row)


def upgrade() -> None:
    if not _timescaledb_available():
        log.warning(
            "[a1] TimescaleDB not available on this server — "
            "skipping hypertable conversion (Supabase/plain Postgres mode)."
        )
        return

    # Ensure TimescaleDB extension is active (it ships pre-installed in the
    # timescale/timescaledb Docker image; this is a no-op if already enabled).
    op.execute("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;")

    # Convert the existing regular table to a hypertable.
    # migrate_data => true  : moves existing rows into the new chunk structure.
    # chunk_time_interval   : 1 day per chunk — good balance for IoT write rate
    #                         (~1 row/5 s per device × N devices).
    # Explicit ::regclass / ::name casts are required because asyncpg uses the
    # extended query protocol (prepared statements), which leaves uncast string
    # literals as type "unknown" — TimescaleDB functions won't match on "unknown".
    op.execute(
        """
        SELECT create_hypertable(
            'telemetry_raw'::regclass,
            'ts'::name,
            migrate_data        => true,
            chunk_time_interval => INTERVAL '1 day',
            if_not_exists       => true
        );
        """
    )

    # Retention policy: chunks older than 90 days are dropped automatically
    # by the TimescaleDB background worker (runs roughly every hour).
    # Raw data is preserved in continuous aggregates (hourly / daily) beyond
    # this window.
    op.execute(
        """
        SELECT add_retention_policy(
            'telemetry_raw'::regclass,
            INTERVAL '90 days',
            if_not_exists => true
        );
        """
    )


def downgrade() -> None:
    raise NotImplementedError(
        "Downgrade from hypertable to plain table is not supported. "
        "To roll back, drop and re-create telemetry_raw manually."
    )
