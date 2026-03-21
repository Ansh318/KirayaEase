"""Persist pending lease draft per landlord across chat turns (preview → confirm)."""
from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional

import psycopg2
from psycopg2.extras import Json

from app.db.sql_queries import DELETE_USER_LEASE_DRAFT, GET_USER_LEASE_DRAFT, UPSERT_USER_LEASE_DRAFT


def save_lease_draft(user_id: int, draft_body: Dict[str, Any]) -> bool:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return False
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(UPSERT_USER_LEASE_DRAFT, (user_id, Json(draft_body)))
        return True
    finally:
        conn.close()


def get_lease_draft(user_id: int) -> Optional[Dict[str, Any]]:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return None
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(GET_USER_LEASE_DRAFT, (user_id,))
                row = cur.fetchone()
                if not row or row[0] is None:
                    return None
                data = row[0]
                if isinstance(data, dict):
                    return data
                if isinstance(data, str):
                    return json.loads(data)
                return dict(data)
    finally:
        conn.close()


def delete_lease_draft(user_id: int) -> None:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(DELETE_USER_LEASE_DRAFT, (user_id,))
    finally:
        conn.close()
