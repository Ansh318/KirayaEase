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
                    ALTER TABLE properties
                    ADD COLUMN IF NOT EXISTS tenant_email TEXT;
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
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS agent_chat_messages (
                      id          BIGSERIAL PRIMARY KEY,
                      thread_key  TEXT NOT NULL,
                      user_id     BIGINT REFERENCES users(id) ON DELETE SET NULL,
                      role        TEXT NOT NULL CHECK (role IN ('human','assistant')),
                      content     TEXT NOT NULL,
                      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
                    );
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_agent_chat_messages_thread_id
                    ON agent_chat_messages(thread_key, id DESC);
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS user_agent_memory (
                      user_id     BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                      summary     TEXT NOT NULL DEFAULT '',
                      updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
                    );
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS user_lease_agreement_previews (
                      user_id           BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                      agreement_text    TEXT NOT NULL,
                      lease_fields_json JSONB NOT NULL,
                      reference_prompt  TEXT,
                      updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
                    );
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_submission_id BIGINT;
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_status TEXT;
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_signed_at TIMESTAMPTZ;
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_combined_document_url TEXT;
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_submission_slug TEXT;
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_shared_link BOOLEAN;
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_signing_url TEXT;
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE leases
                    ADD COLUMN IF NOT EXISTS docuseal_submitter_embeds JSONB;
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS user_fcm_tokens (
                      user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                      platform   TEXT NOT NULL DEFAULT 'ios',
                      fcm_token  TEXT NOT NULL,
                      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                      PRIMARY KEY (user_id, platform)
                    );
                    """
                )
    finally:
        conn.close()
