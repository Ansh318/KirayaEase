"""Lease and property services for the current landlord (owner)."""
import calendar
from datetime import date, datetime
import os

from fastapi import HTTPException
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

from app.db.sql_queries import (
    GET_USER_FROM_SESSION,
    GET_LEASES_BY_OWNER,
    GET_RENT_CONFIRMATIONS_BY_OWNER,
    GET_CONFIRMED_LEASE_MONTHS_BY_OWNER,
)
from app.schemas.property_manager import PropertyManager

load_dotenv()


class LeaseService:
    def __init__(self):
        self.database_url = os.getenv("DATABASE_URL")
        if not self.database_url:
            raise ValueError("DATABASE_URL not found in environment variables")

    def _get_connection(self):
        return psycopg2.connect(self.database_url)

    def get_leases_for_owner(self, session_token: str) -> list[dict]:
        """
        Returns all leases for the landlord identified by the session.
        Each item includes lease fields plus property name/address for display.
        """
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
                row = cur.fetchone()
                if not row:
                    raise HTTPException(
                        status_code=401,
                        detail="Invalid or expired session",
                    )
                user_id = row["user_id"]

                cur.execute(GET_LEASES_BY_OWNER, (user_id,))
                rows = cur.fetchall()

        out = []
        for r in rows:
            d = dict(r)
            # Serialize dates for JSON
            for key in ("lease_start", "lease_end", "lease_created_at"):
                v = d.get(key)
                if isinstance(v, (date, datetime)):
                    d[key] = v.isoformat()
            out.append(d)
        return out

    def get_upcoming_dues(self, session_token: str, limit: int = 3) -> list[dict]:
        """
        Returns the next `limit` upcoming rent due dates for the landlord (not yet confirmed).
        Each item has: due_date (ISO), property_name, tenant_name, monthly_rent, lease_id, month_ym.
        """
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
                row = cur.fetchone()
                if not row:
                    raise HTTPException(
                        status_code=401,
                        detail="Invalid or expired session",
                    )
                user_id = row["user_id"]

                cur.execute(GET_LEASES_BY_OWNER, (user_id,))
                leases = [dict(r) for r in cur.fetchall()]

                cur.execute(GET_CONFIRMED_LEASE_MONTHS_BY_OWNER, (user_id,))
                confirmed_set = set()
                for r in cur.fetchall():
                    lease_id = r["lease_id"]
                    month_val = r["month"]
                    if isinstance(month_val, date):
                        confirmed_set.add((lease_id, month_val))
                    elif isinstance(month_val, datetime):
                        confirmed_set.add((lease_id, month_val.date()))
                    elif month_val:
                        try:
                            d = date.fromisoformat(str(month_val)[:10])
                            confirmed_set.add((lease_id, d))
                        except (ValueError, TypeError):
                            pass

        today = date.today()
        upcoming = []

        def _parse_date(v):
            if v is None:
                return None
            if isinstance(v, date):
                return v
            if isinstance(v, datetime):
                return v.date()
            try:
                return date.fromisoformat(str(v)[:10])
            except (ValueError, TypeError):
                return None

        for lease in leases:
            lease_id = lease["lease_id"]
            due_day = int(lease.get("due_day") or 1)
            lease_start = _parse_date(lease.get("lease_start"))
            lease_end = _parse_date(lease.get("lease_end"))
            if not lease_start:
                continue
            due_day = max(1, min(31, due_day))

            start_year = today.year
            start_month = today.month
            if lease_start and (
                lease_start.year > start_year
                or (lease_start.year == start_year and lease_start.month > start_month)
            ):
                start_year = lease_start.year
                start_month = lease_start.month

            for i in range(12):
                y = start_year + (start_month + i - 1) // 12
                m = (start_month + i - 1) % 12 + 1
                month_first = date(y, m, 1)
                if lease_end and month_first > lease_end:
                    break
                if month_first < lease_start:
                    continue
                if (lease_id, month_first) in confirmed_set:
                    continue
                last_day = calendar.monthrange(y, m)[1]
                due_date = date(y, m, min(due_day, last_day))
                if due_date < today:
                    continue
                upcoming.append({
                    "due_date": due_date.isoformat(),
                    "property_name": (lease.get("property_name") or "").strip() or "Property",
                    "tenant_name": (lease.get("property_tenant_name") or "").strip() or "—",
                    "monthly_rent": int(lease.get("monthly_rent") or 0),
                    "lease_id": lease_id,
                    "month_ym": month_first.strftime("%Y-%m"),
                })
                if len(upcoming) >= limit * 2:
                    break
            if len(upcoming) >= limit * 2:
                break

        upcoming.sort(key=lambda x: x["due_date"])
        return upcoming[:limit]

    def get_properties_for_owner(self, session_token: str) -> list[dict]:
        """Returns all properties for the landlord identified by the session."""
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
                row = cur.fetchone()
                if not row:
                    raise HTTPException(
                        status_code=401,
                        detail="Invalid or expired session",
                    )
                user_id = row["user_id"]
        return PropertyManager().get_properties_by_owner(user_id)

    def get_payments_for_owner(self, session_token: str) -> list[dict]:
        """Returns all rent confirmations (payments) for the landlord identified by the session."""
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
                row = cur.fetchone()
                if not row:
                    raise HTTPException(
                        status_code=401,
                        detail="Invalid or expired session",
                    )
                user_id = row["user_id"]
                cur.execute(GET_RENT_CONFIRMATIONS_BY_OWNER, (user_id,))
                rows = cur.fetchall()
        out = []
        for r in rows:
            d = dict(r)
            for key in ("month", "confirmed_at", "created_at"):
                v = d.get(key)
                if isinstance(v, (date, datetime)):
                    d[key] = v.isoformat()
            out.append(d)
        return out
