# property_manager.py
from __future__ import annotations

import os
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Union
from dotenv import load_dotenv
load_dotenv()
import psycopg2
from psycopg2.extras import RealDictCursor
from app.db.sql_queries import (
    GET_PROPERTY,
    GET_PROPERTIES_BY_OWNER,
    ADD_PROPERTY,
    ADD_LEASE,
    GET_LEASE,
    DELETE_PROPERTY,
    DELETE_LEASE,
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

    # ---------- Properties ----------
    def add_property(
        self,
        *,
        owner_id: int,
        name: str,
        tenant_name: Optional[str] = None,
        address_line1: Optional[str] = None,
        city: Optional[str] = None,
        state: Optional[str] = None,
        postal_code: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Insert a property. Schema: owner_id, name, tenant_name, address_line1, city, state, postal_code."""
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    ADD_PROPERTY,
                    (owner_id, name, tenant_name, address_line1, city, state, postal_code),
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
        lease_start: Union[str, date],
        lease_end: Union[str, date],
        monthly_rent: int,
        security_deposit: Optional[int] = None,
        lock_in_period: Optional[int] = None,
        due_day: int,
    ) -> Dict[str, Any]:
        """Insert a lease. Schema: property_id, lease_text, lease_start, lease_end, monthly_rent, security_deposit, lock_in_period, due_day."""
        if not (1 <= due_day <= 31):
            raise ValueError("due_day must be between 1 and 31")
        start = lease_start.isoformat() if isinstance(lease_start, date) else lease_start
        end = lease_end.isoformat() if isinstance(lease_end, date) else lease_end
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    ADD_LEASE,
                    (property_id, lease_text, start, end, monthly_rent, security_deposit, lock_in_period, due_day),
                )
                row = cur.fetchone()
                lease_id = row[0] if row else None
            conn.commit()
        return self.get_lease(lease_id) if lease_id is not None else {}

    def get_lease(self, lease_id: int) -> Dict[str, Any]:
        with self._conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_LEASE, (lease_id,))
                row = cur.fetchone()
                return self._serialize_row(dict(row)) if row else {}

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