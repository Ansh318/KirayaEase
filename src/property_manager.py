# property_manager.py
from __future__ import annotations

import os
import sqlite3
from typing import Any, Dict, Iterable, List, Optional
from dotenv import load_dotenv
load_dotenv()
from sql_queries import GET_PROPERTIES, ADD_PROPERTY, DELETE_PROPERTY

class PropertyManager:
    def __init__(self, db_path: Optional[str] = None) -> None:
        self.db_path = db_path or os.getenv("DATABASE_PATH")

    # ---------- internal helpers ----------
    def _conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        print(conn)
        conn.row_factory = sqlite3.Row
        # Enforce FKs in SQLite
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    @staticmethod
    def _row_to_dict(row: sqlite3.Row) -> Dict[str, Any]:
        return {k: row[k] for k in row.keys()} if row else {}

    # ---------- CRUD ----------
    def add_property(
        self,
        *,
        name: str,
        address: str,
        city: Optional[str],
        landlord_id: int,
        status: str
    ) -> Dict[str, Any]:
        """
        Inserts a new property. Returns the inserted row as a dict.
        Raises sqlite3.IntegrityError if landlord_id doesn't exist.
        """
        with self._conn() as conn:
            cur = conn.execute(
                ADD_PROPERTY,
                (name, address, city, landlord_id),
            )
            pid = cur.lastrowid
            return self.get_property(pid)

    def get_property(self, property_id: int) -> Dict[str, Any]:
        with self._conn() as conn:
            row = conn.execute(
                GET_PROPERTIES,
                (property_id,),
            ).fetchone()
            return self._row_to_dict(row)

    def list_properties(
        self,
        *,
        landlord_id: Optional[int] = None,
        limit: int = 100,
        offset: int = 0,
        order_by: str = "created_at DESC",
    ) -> List[Dict[str, Any]]:
        """
        List properties; filter by landlord_id if provided.
        order_by is a whitelist to avoid SQL injection.
        """
        allowed_order = {"created_at DESC", "created_at ASC", "name ASC", "name DESC", "id ASC", "id DESC"}
        if order_by not in allowed_order:
            order_by = "created_at DESC"

        with self._conn() as conn:
            if landlord_id is not None:
                rows = conn.execute(
                    f"""
                    SELECT * FROM properties
                    WHERE landlord_id = ?
                    ORDER BY {order_by}
                    LIMIT ? OFFSET ?
                    """,
                    (landlord_id, limit, offset),
                ).fetchall()
            else:
                rows = conn.execute(
                    f"""
                    SELECT * FROM properties
                    ORDER BY {order_by}
                    LIMIT ? OFFSET ?
                    """,
                    (limit, offset),
                ).fetchall()
            return [self._row_to_dict(r) for r in rows]

    def update_property(
        self,
        property_id: int,
        *,
        name: Optional[str] = None,
        address: Optional[str] = None,
        city: Optional[str] = None,
        landlord_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Partially updates a property. Returns updated row.
        Raises sqlite3.IntegrityError if new landlord_id violates FK.
        """
        fields: List[str] = []
        values: List[Any] = []
        if name is not None:
            fields.append("name = ?")
            values.append(name)
        if address is not None:
            fields.append("address = ?")
            values.append(address)
        if city is not None:
            fields.append("city = ?")
            values.append(city)
        if landlord_id is not None:
            fields.append("landlord_id = ?")
            values.append(landlord_id)

        if not fields:
            # nothing to update; return current row
            return self.get_property(property_id)

        values.append(property_id)

        with self._conn() as conn:
            conn.execute(
                f"UPDATE properties SET {', '.join(fields)} WHERE id = ?",
                tuple(values),
            )
            return self.get_property(property_id)

    def delete_property(self, property_id: int) -> bool:
        """
        Deletes a property. Returns True if a row was deleted.
        Will fail if child rows exist (e.g., leases) due to FK constraints.
        """
        with self._conn() as conn:
            cur = conn.execute(DELETE_PROPERTY, (property_id,))
            return cur.rowcount > 0


pm = PropertyManager()  # or PropertyManager(db_path="/abs/path/KE_db.db")

# Create
p = pm.add_property(name="Sunrise 204", address="123 Main St", city="Bengaluru", landlord_id=1)
print("created:", p)

# Read
print("get:", pm.get_property(p["id"]))
print("list:", pm.list_properties(landlord_id=1))

# Update (partial)
updated = pm.update_property(p["id"], city="Mumbai", name="Sunrise 204A")
print("updated:", updated)

# Delete
print("deleted:", pm.delete_property(p["id"]))