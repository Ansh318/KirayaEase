"""Rent confirmations and pending rents for landlords."""
from __future__ import annotations

import logging
import os
from datetime import date, datetime
from typing import Any, Dict, List

import psycopg2
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import (
    GET_LEASE_OWNER_AND_LABELS,
    GET_PENDING_RENTS_BY_OWNER,
    UPSERT_CONFIRM_RENT_PAYMENT,
)
from app.services.landlord_push_dispatch import send_payment_confirmed_push

logger = logging.getLogger(__name__)


def _conn():
    return psycopg2.connect(os.getenv("DATABASE_URL"))


def _month_label_for_push(month: str) -> str:
    d = date.fromisoformat(month[:10])
    return d.strftime("%B %Y")


def _serialize(row: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(row)
    for k, v in out.items():
        if isinstance(v, (date, datetime)):
            out[k] = v.isoformat()
    return out


def list_pending_rents(owner_id: int) -> List[Dict[str, Any]]:
    """List pending rent confirmations for the landlord (owner_id)."""
    with _conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_PENDING_RENTS_BY_OWNER, (owner_id,))
            rows = cur.fetchall()
    return [_serialize(dict(r)) for r in rows]


def confirm_rent_payment(lease_id: int, month: str, confirmed_by: int) -> Dict[str, Any]:
    """Mark rent as confirmed for the given lease and month. month format: YYYY-MM-01."""
    with _conn() as conn:
        with conn.cursor() as cur:
            # Upsert so confirmations are persisted even if the row didn't exist yet.
            cur.execute(UPSERT_CONFIRM_RENT_PAYMENT, (lease_id, confirmed_by, month, lease_id))
            conn.commit()
    try:
        with _conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_LEASE_OWNER_AND_LABELS, (lease_id,))
                row = cur.fetchone()
        if row:
            owner_id = int(row["landlord_user_id"])
            if owner_id == confirmed_by:
                send_payment_confirmed_push(
                    lease_id,
                    owner_id,
                    tenant_name=(row.get("tenant_name") or "Tenant").strip(),
                    property_name=(row.get("property_name") or "Property").strip(),
                    monthly_rent=row.get("monthly_rent"),
                    month_label=_month_label_for_push(month),
                )
    except Exception:
        logger.exception("payment_confirmed push failed lease_id=%s", lease_id)
    return {"status": "confirmed", "lease_id": lease_id, "month": month}
