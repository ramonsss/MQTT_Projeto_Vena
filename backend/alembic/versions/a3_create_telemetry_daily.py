"""create telemetry_daily continuous aggregate

Revision ID: a3c4d5e6f7a3
Revises: a2b3c4d5e6f2
Create Date: 2026-05-21 21:02:00.000000

Creates a TimescaleDB continuous aggregate 'telemetry_daily' that computes
avg/min/max for every sensor column grouped by (device_id, 1-day bucket).

Refresh policy: materialises the last 2 days every 6 hours.
No retention policy — daily summaries are kept indefinitely.

Downgrade: drops the aggregate and its refresh policy.
"""
import logging
from typing import Sequence, Union

from alembic import op
from sqlalchemy import text

log = logging.getLogger("alembic.runtime.migration")

revision: str = "a3c4d5e6f7a3"
down_revision: Union[str, None] = "a2b3c4d5e6f2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _timescaledb_active() -> bool:
    """Return True only if timescaledb extension is already enabled."""
    conn = op.get_bind()
    row = conn.execute(
        text("SELECT COUNT(*) FROM pg_extension WHERE extname = 'timescaledb'")
    ).scalar()
    return bool(row)


def upgrade() -> None:
    if not _timescaledb_active():
        log.warning(
            "[a3] TimescaleDB not active — "
            "skipping telemetry_daily continuous aggregate."
        )
        return

    # ------------------------------------------------------------------
    # 1. Continuous aggregate view
    # ------------------------------------------------------------------
    op.execute(
        """
        CREATE MATERIALIZED VIEW IF NOT EXISTS telemetry_daily
        WITH (timescaledb.continuous) AS
        SELECT
            device_id,
            time_bucket('1 day', ts)    AS bucket,
            AVG(ambient_t)              AS ambient_t_avg,
            MIN(ambient_t)              AS ambient_t_min,
            MAX(ambient_t)              AS ambient_t_max,
            AVG(ambient_h)              AS ambient_h_avg,
            MIN(ambient_h)              AS ambient_h_min,
            MAX(ambient_h)              AS ambient_h_max,
            AVG(diss_t)                 AS diss_t_avg,
            MIN(diss_t)                 AS diss_t_min,
            MAX(diss_t)                 AS diss_t_max,
            AVG(diss_h)                 AS diss_h_avg,
            MIN(diss_h)                 AS diss_h_min,
            MAX(diss_h)                 AS diss_h_max,
            AVG(setpoint)               AS setpoint_avg,
            AVG(pid_out)                AS pid_out_avg,
            COUNT(*)                    AS sample_count
        FROM telemetry_raw
        GROUP BY device_id, bucket
        WITH NO DATA;
        """
    )

    # ------------------------------------------------------------------
    # 2. Automatic refresh policy
    # ------------------------------------------------------------------
    # start_offset - end_offset must span ≥ 2 bucket widths (2 × 1 day = 2 days).
    # 3 days − 1 day = 2 days → satisfies the requirement.
    op.execute(
        """
        SELECT add_continuous_aggregate_policy(
            'telemetry_daily'::regclass,
            start_offset      => INTERVAL '3 days',
            end_offset        => INTERVAL '1 day',
            schedule_interval => INTERVAL '6 hours',
            if_not_exists     => true
        );
        """
    )

    # No retention policy — daily aggregates are kept indefinitely.


def downgrade() -> None:
    op.execute("DROP MATERIALIZED VIEW IF EXISTS telemetry_daily CASCADE;")
