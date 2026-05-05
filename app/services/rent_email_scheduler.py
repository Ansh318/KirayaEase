"""Scheduled tenant rent reminder emails via SMTP custom HTML (5, 3, 1, and 0 day reminders)."""

from __future__ import annotations

import logging
import os
from datetime import date
from typing import Any, Dict, List

import psycopg2
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import (
    GET_LEASES_FOR_PUSH_SCHEDULER,
    INSERT_RENT_EMAIL_REMINDER_LOG,
    UPDATE_RENT_EMAIL_REMINDER_LOG_STATUS,
)
from app.services.email_service import send_html_email
from app.services.rent_reminder_service import _format_due_date_human, _format_rent_amount_inr, days_until_next_due
from app.utils.templates import render_rent_due_email_html

logger = logging.getLogger(__name__)

REMINDER_DAY_OFFSETS = {5, 3, 1, 0}


def _claim_email_slot(
    conn,
    *,
    lease_id: int,
    reminder_type: str,
    period_key: str,
    tenant_email: str,
) -> int | None:
    with conn.cursor() as cur:
        cur.execute(
            INSERT_RENT_EMAIL_REMINDER_LOG,
            (lease_id, reminder_type, period_key, tenant_email, "claimed", ""),
        )
        row = cur.fetchone()
    if not row or row[0] is None:
        return None
    return int(row[0])


def _update_slot(conn, log_id: int, status: str, provider_message: str) -> None:
    with conn.cursor() as cur:
        cur.execute(
            UPDATE_RENT_EMAIL_REMINDER_LOG_STATUS,
            (status, provider_message[:3000], status, log_id),
        )


def run_scheduled_rent_email_reminders() -> Dict[str, int]:
    """Evaluate leases daily and send rent reminder emails at 5/3/1/0 days before due date."""
    stats = {"sent": 0, "skipped": 0, "failed": 0, "no_email": 0}
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        logger.warning("DATABASE_URL missing; skip rent email reminders")
        return stats

    today = date.today()
    with psycopg2.connect(database_url) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_LEASES_FOR_PUSH_SCHEDULER)
            leases: List[Dict[str, Any]] = [dict(r) for r in cur.fetchall()]

        for lease in leases:
            lease_id = int(lease["lease_id"])
            due_day = int(lease.get("due_day") or 1)
            next_due, days_left = days_until_next_due(due_day, today)
            if days_left not in REMINDER_DAY_OFFSETS:
                stats["skipped"] += 1
                continue

            tenant_email = (lease.get("tenant_email") or "").strip()
            if not tenant_email:
                stats["no_email"] += 1
                continue

            period_key = f"{lease_id}:{next_due.strftime('%Y-%m-%d')}:d{days_left}"
            reminder_type = "rent_due_email"
            log_id = _claim_email_slot(
                conn,
                lease_id=lease_id,
                reminder_type=reminder_type,
                period_key=period_key,
                tenant_email=tenant_email,
            )
            if log_id is None:
                stats["skipped"] += 1
                continue

            tenant_name = (lease.get("tenant_name") or "Tenant").strip()
            property_name = (lease.get("property_name") or "your apartment").strip()
            amount = _format_rent_amount_inr(lease.get("monthly_rent"))
            due_date_human = _format_due_date_human(next_due)

            rent_html = render_rent_due_email_html(
                tenant_name=tenant_name,
                apt_name=property_name,
                due_date=due_date_human,
                amount=amount,
                email=tenant_email,
            )
            result = send_html_email(
                to_email=tenant_email,
                subject=f"Rent reminder: {property_name} due in {days_left} day(s)",
                html_body=rent_html,
            )

            if result.get("ok"):
                _update_slot(conn, log_id, "sent", "smtp_custom_html")
                conn.commit()
                stats["sent"] += 1
            else:
                _update_slot(conn, log_id, "failed", str(result))
                conn.commit()
                stats["failed"] += 1

    logger.info("scheduled rent email reminders complete: %s", stats)
    print(f"[rent_email_scheduler] {stats}", flush=True)
    return stats

