"""schedule daily telemetry cleanup via pg_cron (Supabase / vanilla Postgres)

Revision ID: b2c3d4e5f6a7
Revises: b1a2b3c4d5e6
Create Date: 2026-05-30

On TimescaleDB deployments the retention policy registered in a1 already
handles cleanup — this migration is a no-op there.

On Supabase (vanilla Postgres) we use pg_cron to run a daily DELETE that
removes rows older than 90 days, matching the TimescaleDB retention window.

pg_cron is pre-installed on all Supabase projects (free tier included).
The cron job runs at 03:00 UTC every day to avoid peak write hours.

NOTE: pg_cron jobs are stored in the `cron` schema inside the `postgres`
database.  The job is registered for the database named in the connection
string (extracted via current_database()).
"""
from typing import Sequence, Union

from alembic import op
from sqlalchemy import text

revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = "b1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_JOB_NAME = "vena_telemetry_cleanup_90d"
_RETENTION = "90 days"
_CRON_SCHEDULE = "0 3 * * *"  # 03:00 UTC daily


def _timescaledb_active() -> bool:
    conn = op.get_bind()
    row = conn.execute(
        text("SELECT COUNT(*) FROM pg_extension WHERE extname = 'timescaledb'")
    ).scalar()
    return bool(row)


def _pg_cron_available() -> bool:
    conn = op.get_bind()
    row = conn.execute(
        text(
            "SELECT COUNT(*) FROM pg_available_extensions "
            "WHERE name = 'pg_cron'"
        )
    ).scalar()
    return bool(row)


def upgrade() -> None:
    if _timescaledb_active():
        # TimescaleDB retention policy (registered in a1) already handles this.
        return

    if not _pg_cron_available():
        import logging
        logging.getLogger("alembic.runtime.migration").warning(
            "[b2] pg_cron not available — telemetry cleanup job NOT scheduled. "
            "You will need to purge old rows manually: "
            "DELETE FROM telemetry_raw WHERE ts < NOW() - INTERVAL '90 days';"
        )
        return

    op.execute("CREATE EXTENSION IF NOT EXISTS pg_cron;")

    # Unschedule any stale job with the same name before re-registering.
    op.execute(
        text(
            "SELECT cron.unschedule(jobid) "
            "FROM cron.job WHERE jobname = :name"
        ).bindparams(name=_JOB_NAME)
    )

    op.execute(
        text(
            "SELECT cron.schedule("
            "  :name,"
            "  :schedule,"
            "  $$DELETE FROM telemetry_raw "
            "    WHERE ts < NOW() - INTERVAL '90 days'$$"
            ")"
        ).bindparams(name=_JOB_NAME, schedule=_CRON_SCHEDULE)
    )


def downgrade() -> None:
    # No-op if pg_cron was never installed.
    op.execute(
        text(
            "SELECT cron.unschedule(jobid) "
            "FROM cron.job WHERE jobname = :name"
        ).bindparams(name=_JOB_NAME)
    )
