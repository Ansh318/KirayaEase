# property_manager.py
from __future__ import annotations

import os
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv
load_dotenv()
import psycopg2
from psycopg2.extras import RealDictCursor
from app.db.sql_queries import GET_PROPERTIES, ADD_PROPERTY

class PropertyManager:
    def __init__(self, database_url: Optional[str] = None) -> None:
        self.database_url = database_url or os.getenv("DATABASE_URL")
        if not self.database_url:
            raise ValueError("DATABASE_URL not set; cannot connect to Postgres.")

    # ---------- internal helpers ----------
    def _conn(self):
        return psycopg2.connect(self.database_url)

    # ---------- CRUD ----------
    def add_property(
        self,
        *,
        owner_id: int,
        landlord_name: str,
        name: str,
        address_line1: Optional[str] = None,
        city: Optional[str] = None,
        state: Optional[str] = None,
        postal_code: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Inserts a new property into Postgres and returns the inserted row.
        """
        with self._conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    ADD_PROPERTY,
                    (owner_id, landlord_name, name, address_line1, city, state, postal_code),
                )
                row = cur.fetchone()
                property_id = row[0] if row else None
            conn.commit()

        return self.get_property(property_id) if property_id is not None else {}

    def get_property(self, property_id: int) -> Dict[str, Any]:
        with self._conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(GET_PROPERTIES, (property_id,))
                row = cur.fetchone()
                return dict(row) if row else {}


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