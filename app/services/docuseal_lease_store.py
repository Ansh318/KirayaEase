"""Persist DocuSeal submission ids on leases + apply webhook updates."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

import psycopg2

from app.db.sql_queries import (
    GET_LEASE_FILE_FOR_OWNER,
    UPDATE_LEASE_DOCUSEAL_FROM_WEBHOOK,
    UPDATE_LEASE_DOCUSEAL_SUBMISSION_FOR_OWNER,
)


def fetch_lease_pdf_for_owner(lease_id: int, owner_id: int) -> Optional[Tuple[bytes, str]]:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return None
    conn = psycopg2.connect(database_url)
    try:
        with conn.cursor() as cur:
            cur.execute(GET_LEASE_FILE_FOR_OWNER, (lease_id, owner_id))
            row = cur.fetchone()
            if not row:
                return None
            return row[0], row[1]
    finally:
        conn.close()


def _committing_execute(query: str, params: tuple) -> Optional[Any]:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return None
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                return cur.fetchone()
    finally:
        conn.close()


def save_docuseal_submission_for_lease(
    lease_id: int,
    owner_id: int,
    submission_id: int,
    status: str = "pending",
    *,
    submission_slug: Optional[str] = None,
    shared_link: Optional[bool] = None,
    signing_url: Optional[str] = None,
) -> bool:
    row = _committing_execute(
        UPDATE_LEASE_DOCUSEAL_SUBMISSION_FOR_OWNER,
        (
            submission_id,
            status,
            submission_slug,
            shared_link,
            signing_url,
            lease_id,
            owner_id,
        ),
    )
    return row is not None


def apply_docuseal_webhook_update(
    submission_id: int,
    *,
    status: str,
    signed_at: Optional[datetime] = None,
    combined_document_url: Optional[str] = None,
) -> Optional[int]:
    """
    Update lease row matched by docuseal_submission_id.
    Pass signed_at=None to leave existing; url None to leave existing.
    """
    row = _committing_execute(
        UPDATE_LEASE_DOCUSEAL_FROM_WEBHOOK,
        (status, signed_at, combined_document_url, submission_id),
    )
    if not row:
        return None
    return int(row[0])


def parse_docuseal_webhook(payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Normalize DocuSeal webhook JSON (form.* or submission.*) into an update spec.

    Returns dict with keys: submission_id, mark_completed, combined_document_url, interim_status
    or None if nothing to apply.
    """
    event_type = (payload.get("event_type") or "").strip()
    data = payload.get("data")
    if not isinstance(data, dict):
        return None

    submission_id: Optional[int] = None
    sub = data.get("submission")
    if isinstance(sub, dict) and sub.get("id") is not None:
        try:
            submission_id = int(sub["id"])
        except (TypeError, ValueError):
            submission_id = None
    # form.* payloads use data.id for the *submitter* — never use that as submission id
    if submission_id is None and str(event_type).startswith("submission."):
        if data.get("id") is not None:
            try:
                submission_id = int(data["id"])
            except (TypeError, ValueError):
                submission_id = None

    if submission_id is None:
        return None

    def _pick_signed_url() -> Optional[str]:
        if isinstance(sub, dict):
            u = sub.get("combined_document_url") or sub.get("audit_log_url")
            if u:
                return str(u)
            docs = sub.get("documents")
            if isinstance(docs, list):
                for d in docs:
                    if isinstance(d, dict) and d.get("url"):
                        return str(d["url"])
        u = data.get("combined_document_url") or data.get("audit_log_url")
        if u:
            return str(u)
        docs = data.get("documents")
        if isinstance(docs, list):
            for d in docs:
                if isinstance(d, dict) and d.get("url"):
                    return str(d["url"])
        return None

    combined = _pick_signed_url()

    sub_status = None
    if isinstance(sub, dict):
        sub_status = (sub.get("status") or "").strip().lower()

    mark_completed = False
    interim_status: Optional[str] = None

    if event_type == "submission.completed":
        mark_completed = True
    elif event_type == "form.completed":
        if sub_status == "completed":
            mark_completed = True
        else:
            interim_status = "in_progress"

    if event_type == "submission.expired":
        interim_status = "expired"
    if event_type in ("form.declined",):
        interim_status = "declined"

    if mark_completed:
        return {
            "submission_id": submission_id,
            "mark_completed": True,
            "combined_document_url": combined,
            "interim_status": None,
        }

    if interim_status:
        return {
            "submission_id": submission_id,
            "mark_completed": False,
            "combined_document_url": None,
            "interim_status": interim_status,
        }

    # submission.created, etc. — optional touch
    if event_type == "submission.created":
        return {
            "submission_id": submission_id,
            "mark_completed": False,
            "combined_document_url": None,
            "interim_status": "pending",
        }

    return None


def utcnow() -> datetime:
    return datetime.now(timezone.utc)
