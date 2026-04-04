"""Send landlord-facing FCM notifications (rent, lease, payment)."""

from __future__ import annotations

import logging
import os
from typing import Any, Dict, List, Optional, Tuple

import psycopg2
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import (
    DELETE_PUSH_NOTIFICATION_LOG,
    GET_LANDLORD_FCM_TOKENS,
    INSERT_PUSH_NOTIFICATION_LOG,
)
from app.services.fcm_service import send_landlord_push_v1

logger = logging.getLogger(__name__)


def _conn():
    return psycopg2.connect(os.getenv("DATABASE_URL"))


def _fmt_inr(amount: Any) -> str:
    try:
        n = int(amount)
    except (TypeError, ValueError):
        return f"₹{amount}"
    return f"₹{n:,}"


def try_claim_push_slot(
    landlord_user_id: int,
    lease_id: int,
    notification_type: str,
    period_key: str,
) -> Optional[int]:
    """
    Reserve a one-time send slot. Returns log row id if newly claimed, else None.
    """
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return None
    with psycopg2.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                INSERT_PUSH_NOTIFICATION_LOG,
                (landlord_user_id, lease_id, notification_type, period_key),
            )
            row = cur.fetchone()
        conn.commit()
    if not row or row[0] is None:
        return None
    return int(row[0])


def release_push_slot(log_id: int) -> None:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return
    with psycopg2.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(DELETE_PUSH_NOTIFICATION_LOG, (log_id,))
        conn.commit()


def get_landlord_device_tokens(landlord_user_id: int) -> List[Tuple[str, str]]:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return []
    with psycopg2.connect(database_url) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_LANDLORD_FCM_TOKENS, (landlord_user_id,))
            rows = cur.fetchall()
    out: List[Tuple[str, str]] = []
    for r in rows:
        plat = (r.get("platform") or "ios").strip()
        tok = (r.get("fcm_token") or "").strip()
        if tok:
            out.append((plat, tok))
    return out


def dispatch_to_landlord(
    landlord_user_id: int,
    *,
    title: str,
    body: str,
    data: Dict[str, Any],
    variant: str,
    lease_id: int,
    notification_type: str,
    period_key: str,
) -> bool:
    """
    Claim idempotency slot, send to all registered FCM tokens for landlord.
    Releases slot if no tokens or all sends fail.
    """
    log_id = try_claim_push_slot(
        landlord_user_id, lease_id, notification_type, period_key
    )
    if log_id is None:
        return False

    tokens = get_landlord_device_tokens(landlord_user_id)
    if not tokens:
        logger.info(
            "push skip no device tokens landlord_user_id=%s type=%s",
            landlord_user_id,
            notification_type,
        )
        release_push_slot(log_id)
        return False

    str_data = {k: str(v) for k, v in data.items() if v is not None}
    str_data.setdefault("lease_id", str(lease_id))
    str_data["type"] = variant

    any_ok = False
    for _platform, fcm_token in tokens:
        ok, msg = send_landlord_push_v1(
            fcm_token=fcm_token,
            title=title,
            body=body,
            data=str_data,
            variant=variant,
        )
        if ok:
            any_ok = True
            logger.info(
                "push sent landlord_user_id=%s lease_id=%s variant=%s",
                landlord_user_id,
                lease_id,
                variant,
            )
        else:
            logger.warning(
                "push failed landlord_user_id=%s lease_id=%s: %s",
                landlord_user_id,
                lease_id,
                msg,
            )

    if not any_ok:
        release_push_slot(log_id)
        return False
    return True


def send_payment_confirmed_push(
    lease_id: int,
    landlord_user_id: int,
    *,
    tenant_name: str,
    property_name: str,
    monthly_rent: Any,
    month_label: str,
) -> None:
    """Immediate push when rent is marked paid (no scheduler)."""
    title = "✅ Payment recorded"
    body = f"Payment recorded for {tenant_name} – {_fmt_inr(monthly_rent)} ({month_label})"
    period_key = f"payment_ok:{lease_id}:{month_label}"
    dispatch_to_landlord(
        landlord_user_id,
        title=title,
        body=body,
        data={
            "lease_id": str(lease_id),
            "tenant_name": tenant_name,
            "property_name": property_name,
        },
        variant="payment_confirmed",
        lease_id=lease_id,
        notification_type="payment_confirmed",
        period_key=period_key,
    )
