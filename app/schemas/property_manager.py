# property_manager.py
from __future__ import annotations

import os
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Union
from dotenv import load_dotenv
load_dotenv()
import psycopg2
from psycopg2.extras import RealDictCursor
from app.services.whatsapp_service import normalize_whatsapp_e164

from app.db.sql_queries import (
    GET_PROPERTY,
    GET_PROPERTIES_BY_OWNER,
    ADD_PROPERTY,
    ADD_LEASE,
    GET_LEASE,
    UPDATE_LEASE_PDF_URL,
    DELETE_PROPERTY,
    DELETE_LEASE,
    FIND_LEASE_BY_OWNER_AND_PROPERTY,
    UPDATE_PROPERTY_TENANT_PHONE,
    GET_LEASE_DETAIL_FOR_OWNER,
    UPDATE_PROPERTY_FOR_OWNER,
    UPDATE_LEASE_FOR_OWNER,
    UPDATE_LEASE_TEXT_FOR_OWNER,
)

class PropertyManager:
    def __init__(self, database_url: Optional[str] = None) -> None:
        self.database_url = database_url or os.getenv("DATABASE_URL")
        if not self.database_url:
            raise ValueError("DATABASE_URL not set; cannot connect to Postgres.")

    def _conn(self):
        return psycopg2.connect(self.database_url)

    @staticmethod
    def _serialize_row(row: Dict[str, Any]) -> Dict[str, Any]:
        """Convert date/datetime to ISO strings for JSON."""
        out = dict(row)
        for k, v in out.items():
            if isinstance(v, (date, datetime)):
                out[k] = v.isoformat()
        return out

    @staticmethod
    def _normalize_tenant_email(value: Optional[str]) -> Optional[str]:
        if not value or not str(value).strip():
            return None
        s = str(value).strip().lower()
        if "@" not in s or len(s) > 320:
            return None
        return s

    # ---------- Properties ----------
    def add_property(
        self,
        *,
        owner_id: int,
        name: str,
        tenant_name: Optional[str] = None,
        tenant_phone: Optional[str] = None,
        tenant_email: Optional[str] = None,
        address_line1: Optional[str] = None,
        city: Optional[str] = None,
        state: Optional[str] = None,
        postal_code: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Insert a property. tenant_phone = WhatsApp; tenant_email = DocuSeal / signing."""
        phone_norm: Optional[str] = None
        if tenant_phone and str(tenant_phone).strip():
            phone_norm = normalize_whatsapp_e164(str(tenant_phone))
            if len(phone_norm) < 10:
                phone_norm = None
        email_norm = self._normalize_tenant_email(tenant_email)
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    ADD_PROPERTY,
                    (
                        owner_id,
                        name,
                        tenant_name,
                        phone_norm,
                        email_norm,
                        address_line1,
                        city,
                        state,
                        postal_code,
                    ),
                )
                row = cur.fetchone()
                property_id = row[0] if row else None
            conn.commit()
        return self.get_property(property_id) if property_id is not None else {}

    def get_property(self, property_id: int) -> Dict[str, Any]:
        with self._conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_PROPERTY, (property_id,))
                row = cur.fetchone()
                return self._serialize_row(dict(row)) if row else {}

    def update_tenant_phone(
        self,
        *,
        owner_id: int,
        property_id: int,
        tenant_phone: str,
    ) -> Dict[str, Any]:
        """Set WhatsApp number for the tenant on a property (must belong to owner_id)."""
        phone = normalize_whatsapp_e164(str(tenant_phone or "").strip())
        if not phone or len(phone) < 10:
            raise ValueError("tenant_phone is required (valid mobile with country code)")
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    UPDATE_PROPERTY_TENANT_PHONE,
                    (phone, property_id, owner_id),
                )
                row = cur.fetchone()
            conn.commit()
        if not row:
            raise ValueError("Property not found or not owned by this user")
        return self.get_property(property_id)

    def get_properties_by_owner(self, owner_id: int) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_PROPERTIES_BY_OWNER, (owner_id,))
                rows = cur.fetchall()
        return [self._serialize_row(dict(r)) for r in rows]

    # ---------- Leases ----------
    def add_lease(
        self,
        *,
        property_id: int,
        lease_text: Optional[str] = None,
        pdf_url: Optional[str] = None,
        lease_start: Union[str, date],
        lease_end: Union[str, date],
        monthly_rent: int,
        security_deposit: Optional[int] = None,
        lock_in_period: Optional[int] = None,
        due_day: int,
    ) -> Dict[str, Any]:
        """Insert a lease. Schema: property_id, lease_text, pdf_url, lease_start, lease_end, monthly_rent, security_deposit, lock_in_period, due_day."""
        if not (1 <= due_day <= 31):
            raise ValueError("due_day must be between 1 and 31")
        start = lease_start.isoformat() if isinstance(lease_start, date) else lease_start
        end = lease_end.isoformat() if isinstance(lease_end, date) else lease_end
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    ADD_LEASE,
                    (property_id, lease_text, pdf_url, start, end, monthly_rent, security_deposit, lock_in_period, due_day),
                )
                row = cur.fetchone()
                lease_id = row[0] if row else None
            conn.commit()
        return self.get_lease(lease_id) if lease_id is not None else {}

    def set_lease_pdf_url(self, lease_id: int, pdf_url: str) -> None:
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(UPDATE_LEASE_PDF_URL, (pdf_url, lease_id))
            conn.commit()

    def get_lease(self, lease_id: int) -> Dict[str, Any]:
        with self._conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_LEASE, (lease_id,))
                row = cur.fetchone()
                return self._serialize_row(dict(row)) if row else {}

    def get_lease_detail_for_owner(self, lease_id: int, owner_id: int) -> Dict[str, Any]:
        """Lease row joined with property fields; empty dict if not found or wrong owner."""
        with self._conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_LEASE_DETAIL_FOR_OWNER, (lease_id, owner_id))
                row = cur.fetchone()
                return self._serialize_row(dict(row)) if row else {}

    def update_property_for_owner(
        self,
        *,
        owner_id: int,
        property_id: int,
        name: str,
        tenant_name: Optional[str] = None,
        tenant_phone: Optional[str] = None,
        tenant_email: Optional[str] = None,
        address_line1: Optional[str] = None,
        city: Optional[str] = None,
        state: Optional[str] = None,
        postal_code: Optional[str] = None,
    ) -> Dict[str, Any]:
        phone_norm: Optional[str] = None
        if tenant_phone and str(tenant_phone).strip():
            phone_norm = normalize_whatsapp_e164(str(tenant_phone))
            if len(phone_norm) < 10:
                phone_norm = None
        email_norm = self._normalize_tenant_email(tenant_email)
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    UPDATE_PROPERTY_FOR_OWNER,
                    (
                        name,
                        tenant_name,
                        phone_norm,
                        email_norm,
                        address_line1,
                        city,
                        state,
                        postal_code,
                        property_id,
                        owner_id,
                    ),
                )
                row = cur.fetchone()
            conn.commit()
        if not row:
            raise ValueError("Property not found or not owned by this user")
        return self.get_property(property_id)

    def update_lease_for_owner(
        self,
        *,
        owner_id: int,
        lease_id: int,
        lease_start: Union[str, date],
        lease_end: Union[str, date],
        monthly_rent: int,
        security_deposit: Optional[int] = None,
        lock_in_period: Optional[int] = None,
        due_day: int,
    ) -> Dict[str, Any]:
        if not (1 <= due_day <= 31):
            raise ValueError("due_day must be between 1 and 31")
        start = lease_start.isoformat() if isinstance(lease_start, date) else lease_start
        end = lease_end.isoformat() if isinstance(lease_end, date) else lease_end
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    UPDATE_LEASE_FOR_OWNER,
                    (
                        start,
                        end,
                        monthly_rent,
                        security_deposit,
                        lock_in_period,
                        due_day,
                        lease_id,
                        owner_id,
                    ),
                )
                row = cur.fetchone()
            conn.commit()
        if not row:
            raise ValueError("Lease not found or not owned by this user")
        return self.get_lease(lease_id)

    def update_lease_text_for_owner(
        self,
        *,
        owner_id: int,
        lease_id: int,
        lease_text: str,
    ) -> None:
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    UPDATE_LEASE_TEXT_FOR_OWNER,
                    (lease_text, lease_id, owner_id),
                )
                row = cur.fetchone()
            conn.commit()
        if not row:
            raise ValueError("Lease not found or not owned by this user")

    def find_existing_lease_for_property(
        self,
        owner_id: int,
        name: Optional[str] = None,
        address_line1: Optional[str] = None,
        postal_code: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """Return an existing lease for this owner matching the property (by name or address+postal), or None."""
        name = (name or "").strip()
        address_line1 = (address_line1 or "").strip()
        postal_code = (postal_code or "").strip()
        if not name and not (address_line1 and postal_code):
            return None
        with self._conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    FIND_LEASE_BY_OWNER_AND_PROPERTY,
                    (owner_id, name, name, address_line1, postal_code, address_line1, postal_code),
                )
                row = cur.fetchone()
                return dict(row) if row else None

    def delete_property(self, property_id: int) -> None:
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(DELETE_PROPERTY, (property_id,))
            conn.commit()

    def delete_lease(self, lease_id: int) -> None:
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(DELETE_LEASE, (lease_id,))
            conn.commit()


# pm = PropertyManager()  # or PropertyManager(db_path="/abs/path/KE_db.db")

# # Create
# p = pm.add_property(name="Sunrise 204", address="123 Main St", city="Bengaluru", landlord_id=1)
# print("created:", p)

# # Read
# print("get:", pm.get_property(p["id"]))
# print("list:", pm.list_properties(landlord_id=1))

# # Update (partial)
# updated = pm.update_property(p["id"], city="Mumbai", name="Sunrise 204A")
# print("updated:", updated)

# # Delete
# print("deleted:", pm.delete_property(p["id"]))