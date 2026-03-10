"""Lease and property services for the current landlord (owner)."""
from fastapi import HTTPException
import os
from datetime import date, datetime
from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import GET_USER_FROM_SESSION, GET_LEASES_BY_OWNER, GET_RENT_CONFIRMATIONS_BY_OWNER
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
