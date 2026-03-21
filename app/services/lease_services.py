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
from app.schemas.lease_write import LeaseWriteBody
from app.services.lease_manual_assets import persist_manual_lease_pdf_and_rag
from app.services.lease_synthetic_document import render_lease_document_text

load_dotenv()


def _serialize_lease_detail_row(detail: dict) -> dict:
    """ISO-format dates for JSON / tool responses."""
    out = dict(detail)
    for key in ("lease_start", "lease_end", "lease_created_at"):
        v = out.get(key)
        if isinstance(v, (date, datetime)):
            out[key] = v.isoformat()
    return out


def create_lease_manual_from_body(
    user_id: int,
    body: LeaseWriteBody,
    *,
    public_base_url: str,
) -> dict:
    """
    Create property + lease, synthetic PDF, Pinecone RAG (same as POST /leases).
    Returns serialized lease detail. Raises ValueError on invalid dates / DB errors.
    """
    if body.lease_end < body.lease_start:
        raise ValueError("lease_end must be after lease_start")
    doc_text = render_lease_document_text(body)
    pm = PropertyManager()
    prop = pm.add_property(
        owner_id=user_id,
        name=body.property_name.strip(),
        tenant_name=body.tenant_name.strip() if body.tenant_name else None,
        tenant_phone=body.tenant_phone.strip() if body.tenant_phone else None,
        address_line1=body.address_line1.strip() if body.address_line1 else None,
        city=body.city.strip() if body.city else None,
        state=body.state.strip() if body.state else None,
        postal_code=body.postal_code.strip() if body.postal_code else None,
    )
    pid = prop.get("id")
    if not pid:
        raise ValueError("Failed to create property")
    lease = pm.add_lease(
        property_id=int(pid),
        lease_text=doc_text,
        pdf_url=None,
        lease_start=body.lease_start.isoformat(),
        lease_end=body.lease_end.isoformat(),
        monthly_rent=body.monthly_rent,
        security_deposit=body.security_deposit,
        lock_in_period=body.lock_in_period,
        due_day=body.due_day,
    )
    lid = lease.get("id")
    if not lid:
        raise ValueError("Failed to create lease")
    persist_manual_lease_pdf_and_rag(
        lease_id=int(lid),
        owner_id=user_id,
        body=body,
        public_base_url=public_base_url,
    )
    detail = pm.get_lease_detail_for_owner(int(lid), user_id)
    if not detail:
        raise ValueError("Lease created but could not load detail")
    return _serialize_lease_detail_row(detail)


def finalize_stored_lease_draft(user_id: int, *, public_base_url: str) -> dict:
    """
    Load the landlord's pending lease draft from DB, create property + lease (same as POST /leases),
    then delete the draft. Use after the user has finished editing the draft and taps Save / confirms.
    """
    from pydantic import ValidationError

    from app.services.user_lease_draft_store import delete_lease_draft, get_lease_draft

    draft_body = get_lease_draft(int(user_id))
    if not draft_body or not isinstance(draft_body, dict):
        raise ValueError("No lease draft found. Create or update a draft first.")
    try:
        body = LeaseWriteBody.model_validate(draft_body)
    except ValidationError:
        raise ValueError(
            "Lease draft is invalid. Fix it in the draft editor or run prepare_lease_draft again."
        ) from None
    base = (public_base_url or "").strip().rstrip("/")
    detail = create_lease_manual_from_body(user_id, body, public_base_url=base)
    delete_lease_draft(int(user_id))
    return detail


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

    def get_lease_detail(self, session_token: str, lease_id: int) -> dict:
        """Single lease + property row for the editor; raises 401/404."""
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
                row = cur.fetchone()
                if not row:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")
                user_id = row["user_id"]
        detail = PropertyManager().get_lease_detail_for_owner(lease_id, int(user_id))
        if not detail:
            raise HTTPException(status_code=404, detail="Lease not found")
        return _serialize_lease_detail_row(detail)

    def create_lease_manual(
        self,
        session_token: str,
        body: LeaseWriteBody,
        *,
        public_base_url: str,
    ) -> dict:
        """Create property + lease from manual entry; generate PDF + RAG like uploaded leases."""
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
                row = cur.fetchone()
                if not row:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")
                user_id = int(row["user_id"])
        try:
            return create_lease_manual_from_body(
                user_id, body, public_base_url=public_base_url
            )
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e

    def update_lease_manual(
        self,
        session_token: str,
        lease_id: int,
        body: LeaseWriteBody,
        *,
        public_base_url: str,
    ) -> dict:
        """Update property + lease; regenerate synthetic PDF + RAG."""
        with self._get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
                row = cur.fetchone()
                if not row:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")
                user_id = int(row["user_id"])
        if body.lease_end < body.lease_start:
            raise HTTPException(status_code=400, detail="lease_end must be after lease_start")
        pm = PropertyManager()
        detail = pm.get_lease_detail_for_owner(lease_id, user_id)
        if not detail:
            raise HTTPException(status_code=404, detail="Lease not found")
        property_id = int(detail["property_id"])
        try:
            pm.update_property_for_owner(
                owner_id=user_id,
                property_id=property_id,
                name=body.property_name.strip(),
                tenant_name=body.tenant_name.strip() if body.tenant_name else None,
                tenant_phone=body.tenant_phone.strip() if body.tenant_phone else None,
                address_line1=body.address_line1.strip() if body.address_line1 else None,
                city=body.city.strip() if body.city else None,
                state=body.state.strip() if body.state else None,
                postal_code=body.postal_code.strip() if body.postal_code else None,
            )
            pm.update_lease_for_owner(
                owner_id=user_id,
                lease_id=lease_id,
                lease_start=body.lease_start.isoformat(),
                lease_end=body.lease_end.isoformat(),
                monthly_rent=body.monthly_rent,
                security_deposit=body.security_deposit,
                lock_in_period=body.lock_in_period,
                due_day=body.due_day,
            )
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e
        persist_manual_lease_pdf_and_rag(
            lease_id=lease_id,
            owner_id=user_id,
            body=body,
            public_base_url=public_base_url,
        )
        return self.get_lease_detail(session_token, lease_id)

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
