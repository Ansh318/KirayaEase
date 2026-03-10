from fastapi import HTTPException
import os
from dotenv import load_dotenv
import psycopg2

from app.db.sql_queries import (
    GET_USER_FROM_SESSION,
    CHECK_ONBOARDED,
    MARK_USER_ONBOARDED,
    UPDATE_USER_ONBOARDING,
    GET_USER_BY_ID,
    DELETE_SESSION,
    DELETE_USER,
)

load_dotenv()


class UserService:
    def __init__(self):
        self.database_url = os.getenv("DATABASE_URL")
        if not self.database_url:
            raise Exception("DATABASE_URL not found in environment variables")

    def _get_connection(self):
        return psycopg2.connect(self.database_url)

    # -------------------------------
    # USER ONBOARDING (users table only: first_name, last_name, onboarded)
    # -------------------------------
    def handle_user_onboarding(self, session_token, first_name, last_name, role):
        if not first_name or not first_name.strip():
            raise HTTPException(status_code=400, detail="First name is required")
        if not last_name or not last_name.strip():
            raise HTTPException(status_code=400, detail="Last name is required")

        normalized_role = (role or "").strip().lower()
        if normalized_role not in ("tenant", "landlord"):
            raise HTTPException(
                status_code=400,
                detail="Role must be either 'tenant' or 'landlord'",
            )

        with self._get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(GET_USER_FROM_SESSION, (session_token,))
                result = cursor.fetchone()
                if not result:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")
                user_id = result[0]

                cursor.execute(CHECK_ONBOARDED, (user_id,))
                onboarded_row = cursor.fetchone()
                if onboarded_row is not None and bool(onboarded_row[0]):
                    return {
                        "success": True,
                        "message": "User already onboarded",
                        "user_id": user_id,
                    }

                cursor.execute(UPDATE_USER_ONBOARDING, (first_name.strip(), last_name.strip(), user_id))
                cursor.execute(MARK_USER_ONBOARDED, (user_id,))
                conn.commit()

        return {
            "success": True,
            "message": "User onboarded successfully",
            "role": normalized_role,
        }

    # -------------------------------
    # GET USER BY SESSION TOKEN (from users table only)
    # -------------------------------
    def get_user_by_token(self, session_token):
        with self._get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(GET_USER_FROM_SESSION, (session_token,))
                result = cursor.fetchone()
                if not result:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")
                user_id = result[0]

                cursor.execute(GET_USER_BY_ID, (user_id,))
                row = cursor.fetchone()
                if not row:
                    raise HTTPException(status_code=404, detail="User not found")

                _id, email, first_name, last_name, onboarded = row
                name = f"{(first_name or '')} {(last_name or '')}".strip() or None

                return {
                    "user_id": user_id,
                    "email": email,
                    "first_name": first_name,
                    "last_name": last_name,
                    "name": name,
                    "onboarded": bool(onboarded),
                }

    # -------------------------------
    # DELETE USER ACCOUNT
    # -------------------------------
    def delete_user_account(self, session_token: str):
        with self._get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(GET_USER_FROM_SESSION, (session_token,))
                result = cursor.fetchone()
                if not result:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")
                user_id = result[0]

                cursor.execute(DELETE_SESSION, (user_id,))
                cursor.execute(DELETE_USER, (user_id,))
                conn.commit()

        return {
            "success": True,
            "message": "User account deleted successfully",
        }
