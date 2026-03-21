"""Optional long-term factual notes per user (preferences, reminders)."""
from __future__ import annotations

import os
from typing import Optional

import psycopg2

from app.db.sql_queries import GET_USER_AGENT_MEMORY_SUMMARY, UPSERT_USER_AGENT_MEMORY_SUMMARY

_MAX_SUMMARY_CHARS = 12_000


def get_memory_summary(user_id: int) -> str:
    if not user_id or user_id <= 0:
        return ""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return ""
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(GET_USER_AGENT_MEMORY_SUMMARY, (int(user_id),))
                row = cur.fetchone()
                if not row or row[0] is None:
                    return ""
                return str(row[0]).strip()
    finally:
        conn.close()


def append_memory_fact(user_id: int, fact: str) -> bool:
    """Append a bullet line to the user's memory blob."""
    if not user_id or user_id <= 0:
        return False
    fact = (fact or "").strip()
    if not fact:
        return False
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return False
    line = f"- {fact}"
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(GET_USER_AGENT_MEMORY_SUMMARY, (int(user_id),))
                row = cur.fetchone()
                prev = str(row[0]).strip() if row and row[0] else ""
                new = f"{prev}\n{line}".strip() if prev else line
                if len(new) > _MAX_SUMMARY_CHARS:
                    new = new[-_MAX_SUMMARY_CHARS:]
                cur.execute(UPSERT_USER_AGENT_MEMORY_SUMMARY, (int(user_id), new))
        return True
    finally:
        conn.close()
