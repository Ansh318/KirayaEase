"""
Scheduled landlord pushes: rent due (2–3 days), overdue, lease expiring (30 days).

Run daily via Heroku Scheduler or cron:
  python -m app.jobs.run_landlord_push
"""

from __future__ import annotations

import calendar
import logging
import os
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Set, Tuple

import psycopg2
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import GET_CONFIRMED_RENT_MONTHS_ALL, GET_LEASES_FOR_PUSH_SCHEDULER
from app.services.landlord_push_dispatch import _fmt_inr, dispatch_to_landlord

logger = logging.getLogger(__name__)


def _parse_date(v: Any) -> Optional[date]:
    if v is None:
        return None
    if isinstance(v, date) and not isinstance(v, datetime):
        return v
    if isinstance(v, datetime):
        return v.date()
    try:
        return date.fromisoformat(str(v)[:10])
    except (ValueError, TypeError):
        return None


def _month_first(d: date) -> date:
    return date(d.year, d.month, 1)


def _load_confirmed_set(conn) -> Set[Tuple[int, date]]:
    out: Set[Tuple[int, date]] = set()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(GET_CONFIRMED_RENT_MONTHS_ALL)
        for r in cur.fetchall():
            lid = int(r["lease_id"])
            m = r["month"]
            if isinstance(m, datetime):
                m = m.date()
            if isinstance(m, date):
                out.add((lid, _month_first(m)))
            else:
                try:
                    d = date.fromisoformat(str(m)[:10])
                    out.add((lid, _month_first(d)))
                except (ValueError, TypeError):
                    continue
    return out


def _iter_unpaid_rent_months(
    lease: Dict[str, Any],
    confirmed: Set[Tuple[int, date]],
    today: date,
) -> List[Tuple[date, date]]:
    """Returns list of (month_first, due_date) for unpaid rent months in range."""
    lease_id = int(lease["lease_id"])
    due_day = max(1, min(31, int(lease.get("due_day") or 1)))
    lease_start = _parse_date(lease.get("lease_start"))
    lease_end = _parse_date(lease.get("lease_end"))
    if not lease_start:
        return []

    start_year = today.year
    start_month = today.month
    if lease_start.year > start_year or (
        lease_start.year == start_year and lease_start.month > start_month
    ):
        start_year = lease_start.year
        start_month = lease_start.month

    rows: List[Tuple[date, date]] = []
    for i in range(48):
        y = start_year + (start_month + i - 1) // 12
        m = (start_month + i - 1) % 12 + 1
        month_first = date(y, m, 1)
        if lease_end and month_first > lease_end:
            break
        if month_first < date(lease_start.year, lease_start.month, 1):
            continue
        if (lease_id, month_first) in confirmed:
            continue
        last_day = calendar.monthrange(y, m)[1]
        due_date = date(y, m, min(due_day, last_day))
        if due_date < lease_start:
            continue
        rows.append((month_first, due_date))
    return rows


def run_scheduled_landlord_pushes() -> Dict[str, int]:
    """
    Evaluate all active leases; send idempotent pushes (DB log prevents duplicates).
    """
    stats = {"rent_due_soon": 0, "rent_overdue": 0, "lease_expiring": 0, "skipped": 0}
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        logger.warning("DATABASE_URL missing; skip scheduled pushes")
        return stats

    today = date.today()

    with psycopg2.connect(database_url) as conn:
        confirmed = _load_confirmed_set(conn)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_LEASES_FOR_PUSH_SCHEDULER)
            leases: List[Dict[str, Any]] = [dict(r) for r in cur.fetchall()]

    for lease in leases:
        lease_id = int(lease["lease_id"])
        landlord_id = int(lease["landlord_user_id"])
        tenant = (lease.get("tenant_name") or "Tenant").strip()
        prop = (lease.get("property_name") or "your property").strip()
        rent = lease.get("monthly_rent")

        unpaid = _iter_unpaid_rent_months(lease, confirmed, today)

        next_future: Optional[Tuple[date, date]] = None
        oldest_past: Optional[Tuple[date, date]] = None
        for month_first, due_date in unpaid:
            if due_date < today:
                if oldest_past is None or due_date < oldest_past[1]:
                    oldest_past = (month_first, due_date)
            else:
                if next_future is None or due_date < next_future[1]:
                    next_future = (month_first, due_date)

        # 1) Rent due in 2–3 days (next unpaid future installment)
        if next_future:
            mf, dd = next_future
            days = (dd - today).days
            if days in (2, 3):
                period_key = f"{lease_id}:{mf.strftime('%Y-%m')}:due_soon"
                day_word = "day" if days == 1 else "days"
                title = "💰 Rent due soon"
                body = f"Rent due in {days} {day_word} for {tenant} – {_fmt_inr(rent)}"
                if dispatch_to_landlord(
                    landlord_id,
                    title=title,
                    body=body,
                    data={
                        "lease_id": str(lease_id),
                        "tenant_name": tenant,
                        "property_name": prop,
                        "due_date": dd.isoformat(),
                    },
                    variant="rent_due_soon",
                    lease_id=lease_id,
                    notification_type="rent_due_soon",
                    period_key=period_key,
                ):
                    stats["rent_due_soon"] += 1
                else:
                    stats["skipped"] += 1

        # 2) Overdue: first unpaid month whose due date has passed
        if oldest_past:
            mf, dd = oldest_past
            if today > dd:
                month_name = mf.strftime("%B")
                period_key = f"{lease_id}:{mf.strftime('%Y-%m')}:overdue"
                title = "🚨 Rent overdue"
                body = f"{tenant} hasn't paid rent for {month_name} yet"
                if dispatch_to_landlord(
                    landlord_id,
                    title=title,
                    body=body,
                    data={
                        "lease_id": str(lease_id),
                        "tenant_name": tenant,
                        "property_name": prop,
                        "due_date": dd.isoformat(),
                    },
                    variant="rent_overdue",
                    lease_id=lease_id,
                    notification_type="rent_overdue",
                    period_key=period_key,
                ):
                    stats["rent_overdue"] += 1
                else:
                    stats["skipped"] += 1

        # 3) Lease expiring in exactly 30 days
        lease_end = _parse_date(lease.get("lease_end"))
        if lease_end:
            days_left = (lease_end - today).days
            if days_left == 30:
                period_key = f"{lease_id}:expiry30:{lease_end.isoformat()}"
                title = "📄 Lease expiring soon"
                body = f"Lease for {prop} expires in 30 days"
                if dispatch_to_landlord(
                    landlord_id,
                    title=title,
                    body=body,
                    data={
                        "lease_id": str(lease_id),
                        "property_name": prop,
                        "lease_end": lease_end.isoformat(),
                    },
                    variant="lease_expiring",
                    lease_id=lease_id,
                    notification_type="lease_expiring",
                    period_key=period_key,
                ):
                    stats["lease_expiring"] += 1
                else:
                    stats["skipped"] += 1

    logger.info("scheduled landlord pushes complete: %s", stats)
    print(f"[landlord_push_scheduler] {stats}", flush=True)
    return stats
