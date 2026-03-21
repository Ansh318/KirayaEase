"""Persist LLM-generated lease agreement + lease fields for preview → save."""
from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional

import psycopg2
from psycopg2.extras import Json, RealDictCursor

from app.db.sql_queries import (
    DELETE_USER_LEASE_AGREEMENT_PREVIEW,
    GET_USER_LEASE_AGREEMENT_PREVIEW,
    UPSERT_USER_LEASE_AGREEMENT_PREVIEW,
)


def save_agreement_preview(
    user_id: int,
    *,
    agreement_text: str,
    lease_fields: Dict[str, Any],
    reference_prompt: Optional[str] = None,
) -> bool:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return False
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    UPSERT_USER_LEASE_AGREEMENT_PREVIEW,
                    (
                        int(user_id),
                        agreement_text,
                        Json(lease_fields),
                        (reference_prompt or "").strip() or None,
                    ),
                )
        return True
    finally:
        conn.close()


def get_agreement_preview(user_id: int) -> Optional[Dict[str, Any]]:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return None
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_LEASE_AGREEMENT_PREVIEW, (int(user_id),))
                row = cur.fetchone()
                if not row:
                    return None
                lf = row["lease_fields_json"]
                if isinstance(lf, str):
                    lf = json.loads(lf)
                return {
                    "agreement_text": row["agreement_text"],
                    "lease_fields": dict(lf) if isinstance(lf, dict) else lf,
                    "reference_prompt": row.get("reference_prompt"),
                    "updated_at": row["updated_at"].isoformat() if row.get("updated_at") else None,
                }
    finally:
        conn.close()


def delete_agreement_preview(user_id: int) -> None:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(DELETE_USER_LEASE_AGREEMENT_PREVIEW, (int(user_id),))
    finally:
        conn.close()
