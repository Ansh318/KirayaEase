import os
import uuid
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv
from fastapi import HTTPException
import psycopg2
# Load environment variables
load_dotenv()

from db.sql_queries import (
    CREATE_USER,
    FETCH_USER,
    AUTH_SESSION,
    CHECK_ONBOARDED
)

class AuthManager:
    def __init__(self):
        self.db_url = os.getenv("DATABASE_URL")
        self.google_client_id = os.getenv("GOOGLE_CLIENT_ID")

    def _get_connection(self):
        return psycopg2.connect(self.db_url)

    def create_fetch_user(self, email):
        conn = self._get_connection()
        cursor = conn.cursor()

        # Try insert
        cursor.execute(CREATE_USER, (email,))
        result = cursor.fetchone()

        if result:
            # New user created
            user_id = result[0]
            conn.commit()
            cursor.close()
            conn.close()
            return user_id

        # If no row returned → user already exists → fetch it
        cursor.execute(FETCH_USER, (email,))
        result = cursor.fetchone()

        conn.commit()
        cursor.close()
        conn.close()

        if not result:
            raise ValueError("User fetch failed")

        return result[0]


    def create_login_session(self, user_id):
        session_id = str(uuid.uuid4())
        expires_at = datetime.now(timezone.utc) + timedelta(days=7)

        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute(AUTH_SESSION, (session_id, user_id, expires_at))
        conn.commit()

        cursor.close()
        conn.close()

        return session_id

        # -------------------------
    # CHECK ONBOARDING
    # -------------------------
    def check_onboarding(self, user_id):
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute(CHECK_ONBOARDED, (user_id,))
        result = cursor.fetchone()

        cursor.close()
        conn.close()

        return bool(result[0]) if result is not None else False

    def google_login(self, id_token_from_client: str):
        try:
            idinfo = id_token.verify_oauth2_token(
                id_token_from_client,
                google_requests.Request(),
                self.google_client_id
            )

            email = idinfo["email"]

            user_id = self.create_fetch_user(email)
            session_id = self.create_login_session(user_id)
            onboarded = self.check_onboarding(user_id)

            return {
                "session_id": session_id,
                "user_id": user_id,
                "email": email,
                "onboarded": onboarded
            }

        except ValueError:
            raise HTTPException(status_code=401, detail="Invalid Google token")



    

