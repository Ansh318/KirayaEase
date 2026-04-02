"""Register FCM tokens and send test pushes (authenticated)."""

import os
from typing import Optional

import psycopg2
from fastapi import APIRouter, Header, HTTPException
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import GET_USER_FROM_SESSION, GET_USER_FCM_TOKEN, UPSERT_USER_FCM_TOKEN
from app.schemas.push import FcmTokenBody
from app.services.fcm_service import send_fcm_notification

router = APIRouter()


def _require_user_id(authorization: Optional[str]) -> int:
    session_token = (authorization or "").replace("Bearer ", "").strip()
    if not session_token:
        raise HTTPException(status_code=401, detail="Missing authorization")
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise HTTPException(status_code=503, detail="Database not configured")
    with psycopg2.connect(database_url) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_USER_FROM_SESSION, (session_token,))
            row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    return int(row["user_id"])


@router.post("/me/fcm-token")
def register_fcm_token(
    body: FcmTokenBody,
    authorization: Optional[str] = Header(None),
):
    """Store or update the caller's FCM token (one row per user + platform)."""
    user_id = _require_user_id(authorization)
    platform = body.normalized_platform()
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise HTTPException(status_code=503, detail="Database not configured")
    token = body.fcm_token.strip()
    if len(token) < 10:
        raise HTTPException(status_code=400, detail="Invalid fcm_token")

    with psycopg2.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(UPSERT_USER_FCM_TOKEN, (user_id, platform, token))
        conn.commit()
    return {"status": "ok", "platform": platform}


@router.post("/me/push-test")
def send_test_push_to_self(authorization: Optional[str] = Header(None)):
    """
    Send one test notification to the authenticated user's stored FCM token (ios preferred).
    Requires server-side FCM credentials (service account).
    """
    user_id = _require_user_id(authorization)
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise HTTPException(status_code=503, detail="Database not configured")

    fcm_token: Optional[str] = None
    with psycopg2.connect(database_url) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_USER_FCM_TOKEN, (user_id, "ios"))
            row = cur.fetchone()
            if row and row.get("fcm_token"):
                fcm_token = str(row["fcm_token"]).strip()
            if not fcm_token:
                cur.execute(GET_USER_FCM_TOKEN, (user_id, "android"))
                row = cur.fetchone()
                if row and row.get("fcm_token"):
                    fcm_token = str(row["fcm_token"]).strip()

    if not fcm_token:
        raise HTTPException(
            status_code=400,
            detail="No FCM token on file. Open the app on a device after login so it can register.",
        )

    ok, msg = send_fcm_notification(
        fcm_token=fcm_token,
        title="KirayaEase",
        body="Test push — notifications are working.",
        data={"type": "test"},
    )
    if not ok:
        raise HTTPException(status_code=502, detail=msg)
    return {"status": "sent", "detail": msg}
