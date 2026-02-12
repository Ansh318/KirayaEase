from fastapi import HTTPException
import os
from dotenv import load_dotenv
load_dotenv()
import psycopg2

from sql_queries import (
    GET_USER_FROM_SESSION,
    CHECK_ONBOARDED,
    CHECK_DUPLICATE_AADHAAR,
    CHECK_DUPLICATE_PAN,
    INSERT_USER_PROFILE,
    MARK_USER_ONBOARDED,
    GET_USER_PROFILE
)

def handle_user_onboarding(session_token, first_name, last_name, dob, aadhaar, pan):
    # Step 1: Validate required fields
    if not (aadhaar or pan):
        raise HTTPException(status_code=400, detail="Aadhaar or PAN required")

    with psycopg2.connect(os.getenv("DATABASE_URL")) as conn:
        with conn.cursor() as cursor:
            # Step 2: Get user_id from session_token
            cursor.execute(GET_USER_FROM_SESSION, (session_token,))
            result = cursor.fetchone()
            if not result:
                raise HTTPException(status_code=401, detail="Invalid or expired session")

            user_id = result[0]

            # Step 3: Check if user already onboarded
            cursor.execute(CHECK_ONBOARDED, (user_id,))
            if cursor.fetchone():
                return {"success": True, "message": "User already onboarded", "user_id": user_id}

            # Step 4: Aadhaar/PAN duplication checks
            if aadhaar:
                cursor.execute(CHECK_DUPLICATE_AADHAAR, (aadhaar,))
                if cursor.fetchone():
                    raise HTTPException(status_code=409, detail="Aadhaar already in use")

            if pan:
                cursor.execute(CHECK_DUPLICATE_PAN, (pan,))
                if cursor.fetchone():
                    raise HTTPException(status_code=409, detail="PAN already in use")

            # Step 5: Insert new user_profile + mark onboarded
            cursor.execute(INSERT_USER_PROFILE, (user_id, first_name, last_name, aadhaar, pan, dob))
            cursor.execute(MARK_USER_ONBOARDED, (user_id,))

    return {"success": True, "message": "User onboarded successfully"}


def get_user_by_token(session_token):
    with psycopg2.connect(os.getenv("DATABASE_URL")) as conn:
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

            first_name, last_name, aadhaar, pan, dob = user_details
            return {
                "first_name": first_name,
                "last_name": last_name,
                "name": f"{first_name} {last_name}".strip(),
                "aadhaar": aadhaar,
                "pan": pan,
                "dob": str(dob),
            }

