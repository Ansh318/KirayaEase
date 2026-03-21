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
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS lease_files (
                      lease_id      BIGINT PRIMARY KEY REFERENCES leases(id) ON DELETE CASCADE,
                      content       BYTEA NOT NULL,
                      content_type  TEXT NOT NULL DEFAULT 'application/pdf',
                      created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
                      updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
                    );
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE properties
                    ADD COLUMN IF NOT EXISTS tenant_phone TEXT;
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS user_lease_drafts (
                      user_id     BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                      draft_json  JSONB NOT NULL,
                      updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
                    );
                    """
                )
    finally:
        conn.close()
