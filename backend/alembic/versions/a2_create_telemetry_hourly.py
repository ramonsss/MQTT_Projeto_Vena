"""create telemetry_hourly continuous aggregate

Revision ID: a2b3c4d5e6f2
Revises: a1b2c3d4e5f1
Create Date: 2026-05-21 21:01:00.000000

Creates a TimescaleDB continuous aggregate 'telemetry_hourly' that computes
avg/min/max for every sensor column grouped by (device_id, 1-hour bucket).

Refresh policy: materialises the last 3 h every 30 min.
Retention policy: drop hourly data older than 2 years.

Downgrade: drops the aggregate, its refresh policy and its retention policy.
"""
from typing import Sequence, Union

from alembic import op


revision: str = "a2b3c4d5e6f2"
down_revision: Union[str, None] = "a1b2c3d4e5f1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # 1. Continuous aggregate view
    # ------------------------------------------------------------------
    # WITH NO DATA: do not back-fill on creation — the refresh policy below
    # handles incremental materialisation.  Run a manual CALL
    # refresh_continuous_aggregate('telemetry_hourly', NULL, NULL) once if
    # you need to populate historical data immediately.
    op.execute(
        """
        CREATE MATERIALIZED VIEW IF NOT EXISTS telemetry_hourly
        WITH (timescaledb.continuous) AS
        SELECT
            device_id,
            time_bucket('1 hour', ts)   AS bucket,
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
    # Materialises the window [now - 3h, now - 30min] every 30 minutes.
    # The 30-min end_offset ensures we never try to materialise data that
    # is still actively being written (avoids stale-chunk conflicts).
    op.execute(
        """
        SELECT add_continuous_aggregate_policy(
            'telemetry_hourly'::regclass,
            start_offset      => INTERVAL '3 hours',
            end_offset        => INTERVAL '30 minutes',
            schedule_interval => INTERVAL '30 minutes',
            if_not_exists     => true
        );
        """
    )

    # ------------------------------------------------------------------
    # 3. Retention policy on the aggregate
    # ------------------------------------------------------------------
    op.execute(
        """
        SELECT add_retention_policy(
            'telemetry_hourly'::regclass,
            INTERVAL '2 years',
            if_not_exists => true
        );
        """
    )


def downgrade() -> None:
    # Retention and refresh policies are dropped automatically when the
    # materialized view is dropped.
    op.execute("DROP MATERIALIZED VIEW IF EXISTS telemetry_hourly CASCADE;")
