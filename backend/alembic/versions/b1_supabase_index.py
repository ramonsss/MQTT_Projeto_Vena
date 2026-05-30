"""add plain index on telemetry_raw (Supabase / vanilla Postgres compat)

Revision ID: b1a2b3c4d5e6
Revises: e734d2061ada
Create Date: 2026-06-02

Creates the composite index used by telemetry queries on vanilla Postgres /
Supabase.  On a TimescaleDB deployment the hypertable already manages its own
chunk-level indexes; this migration is a no-op there (CREATE INDEX IF NOT
EXISTS is idempotent).

The index supports:
  SELECT … FROM telemetry_raw WHERE device_id = $1 ORDER BY ts DESC LIMIT …
which is the hot path for the dashboard and the demo SQL tool.
"""
from typing import Sequence, Union

from alembic import op

revision: str = "b1a2b3c4d5e6"
down_revision: Union[str, None] = "e734d2061ada"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_telemetry_device_ts
            ON telemetry_raw (device_id, ts DESC);
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_telemetry_device_ts;")
