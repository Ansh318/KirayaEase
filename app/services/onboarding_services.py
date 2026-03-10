from fastapi import HTTPException
import os
from dotenv import load_dotenv
import psycopg2

from app.db.sql_queries import (
    GET_USER_FROM_SESSION,
    CHECK_ONBOARDED,
    MARK_USER_ONBOARDED,
    DELETE_SESSION,
    DELETE_USER
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
    # USER ONBOARDING
    # -------------------------------
    def handle_user_onboarding(
        self,
        session_token,
        first_name,
        last_name,
        dob,
        aadhaar,
        pan,
        role,
    ):
        # Step 1: Validate required fields
        if not first_name or not first_name.strip():
            raise HTTPException(status_code=400, detail="First name is required")

        if not last_name or not last_name.strip():
            raise HTTPException(status_code=400, detail="Last name is required")

        with self._get_connection() as conn:
            with conn.cursor() as cursor:

                # Step 2: Get user_id from session_token
                cursor.execute(GET_USER_FROM_SESSION, (session_token,))
                result = cursor.fetchone()

                if not result:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")

                user_id = result[0]

                # Step 3: Check if already onboarded
                cursor.execute(CHECK_ONBOARDED, (user_id,))
                onboarded_row = cursor.fetchone()

                if onboarded_row is not None and bool(onboarded_row[0]):
                    return {
                        "success": True,
                        "message": "User already onboarded",
                        "user_id": user_id,
                    }

                # Step 4: Duplication checks
                if aadhaar:
                    cursor.execute(CHECK_DUPLICATE_AADHAAR, (aadhaar,))
                    if cursor.fetchone():
                        raise HTTPException(status_code=409, detail="Aadhaar already in use")

                if pan:
                    cursor.execute(CHECK_DUPLICATE_PAN, (pan,))
                    if cursor.fetchone():
                        raise HTTPException(status_code=409, detail="PAN already in use")

                normalized_role = (role or "").strip().lower()
                if normalized_role not in ("tenant", "landlord"):
                    raise HTTPException(
                        status_code=400,
                        detail="Role must be either 'tenant' or 'landlord'",
                    )

                # Step 5: Insert profile + mark onboarded
                cursor.execute(
                    INSERT_USER_PROFILE,
                    (
                        user_id,
                        normalized_role,
                        first_name,
                        last_name,
                        aadhaar,
                        pan,
                        dob,
                    ),
                )

                cursor.execute(MARK_USER_ONBOARDED, (user_id,))

        return {
            "success": True,
            "message": "User onboarded successfully",
            "role": normalized_role,
        }

    # -------------------------------
    # GET USER BY SESSION TOKEN
    # -------------------------------
    def get_user_by_token(self, session_token):
        with self._get_connection() as conn:
            with conn.cursor() as cursor:

                cursor.execute(GET_USER_FROM_SESSION, (session_token,))
                result = cursor.fetchone()

                if not result:
                    raise HTTPException(status_code=401, detail="Invalid or expired session")

                user_id = result[0]

                cursor.execute(GET_USER_PROFILE, (user_id,))
                user_details = cursor.fetchone()

                if not user_details:
                    raise HTTPException(status_code=404, detail="User profile not found")

                first_name, last_name, aadhaar, pan, dob, role = user_details

                return {
                    "user_id": user_id,
                    "first_name": first_name,
                    "last_name": last_name,
                    "name": f"{first_name} {last_name}".strip(),
                    "aadhaar": aadhaar,
                    "pan": pan,
                    "dob": dob.isoformat() if dob else None,
                    "role": role,
                }
    
        # -------------------------------
    # DELETE USER ACCOUNT
    # -------------------------------
    def delete_user_account(self, session_token: str):
        with self._get_connection() as conn:
            with conn.cursor() as cursor:

                # Step 1: Get user_id from session
                cursor.execute(GET_USER_FROM_SESSION, (session_token,))
                result = cursor.fetchone()

                if not result:
                    raise HTTPException(
                        status_code=401,
                        detail="Invalid or expired session"
                    )

                user_id = result[0]

                # Step 2: Delete related records first (important!)
                # Adjust table names if different in your schema

                cursor.execute(DELETE_USER_PROFILE, (user_id,))
                cursor.execute(DELETE_SESSION, (user_id,))
                cursor.execute(DELETE_USER, (user_id,))

                conn.commit()

        return {
            "success": True,
            "message": "User account deleted successfully",
        }