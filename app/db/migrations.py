from __future__ import annotations

import os

import psycopg2


def ensure_runtime_migrations() -> None:
    """
    Apply tiny, idempotent Postgres migrations at runtime.

    This is intentionally lightweight (no external migration framework) and safe to run on each
    startup in Heroku.
    """

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return

    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    ALTER TABLE IF EXISTS leases
                    ADD COLUMN IF NOT EXISTS pdf_url TEXT;
                    """
                )
    finally:
        conn.close()
