import os
import uuid
from datetime import datetime, timedelta, timezone

import psycopg2
import requests as http_requests
from dotenv import load_dotenv
from fastapi import HTTPException
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from jose import jwt, jwk
# Load environment variables
load_dotenv()

# How long DB sessions stay valid (login required again after this). Override with SESSION_EXPIRY_DAYS (1–365).
try:
    _raw_days = int(os.getenv("SESSION_EXPIRY_DAYS", "30"))
except ValueError:
    _raw_days = 30
SESSION_EXPIRY_DAYS = max(1, min(_raw_days, 365))

from app.db.sql_queries import (
    CREATE_USER,
    FETCH_USER,
    AUTH_SESSION,
    CHECK_ONBOARDED,
)

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

class AuthManager:
    def __init__(self):
        self.db_url = os.getenv("DATABASE_URL")
        self.google_client_id = os.getenv("GOOGLE_CLIENT_ID")
        self.apple_client_id = os.getenv("APPLE_CLIENT_ID")

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
        expires_at = datetime.now(timezone.utc) + timedelta(days=SESSION_EXPIRY_DAYS)

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

    def apple_login(self, id_token_from_client: str):
        if not self.apple_client_id:
            raise HTTPException(
                status_code=500,
                detail="APPLE_CLIENT_ID is not configured on the server",
            )

        try:
            jwks_response = http_requests.get(APPLE_JWKS_URL, timeout=5)
            jwks_response.raise_for_status()
            jwks = jwks_response.json()

            unverified_header = jwt.get_unverified_header(id_token_from_client)
            kid = unverified_header.get("kid")

            key_data = next(
                (k for k in jwks.get("keys", []) if k.get("kid") == kid), None
            )
            if not key_data:
                raise HTTPException(status_code=401, detail="Invalid Apple token key")

            public_key = jwk.construct(key_data)
            decoded = jwt.decode(
                id_token_from_client,
                public_key.to_pem().decode("utf-8"),
                algorithms=[key_data.get("alg", "RS256")],
                audience=self.apple_client_id,
                issuer="https://appleid.apple.com",
            )

            email = decoded.get("email")
            if not email:
                raise HTTPException(
                    status_code=400, detail="Apple token did not contain an email"
                )

            user_id = self.create_fetch_user(email)
            session_id = self.create_login_session(user_id)
            onboarded = self.check_onboarding(user_id)

            return {
                "session_id": session_id,
                "user_id": user_id,
                "email": email,
                "onboarded": onboarded,
            }

        except HTTPException:
            raise
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid Apple token")
