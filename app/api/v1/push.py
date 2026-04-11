"""Register FCM tokens and send test pushes (authenticated)."""

import os
from typing import Dict, Optional, Tuple

import psycopg2
from fastapi import APIRouter, Header, HTTPException
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import GET_USER_FROM_SESSION, GET_USER_FCM_TOKEN, UPSERT_USER_FCM_TOKEN
from app.schemas.push import FcmTokenBody, LandlordPushPreviewBody
from app.services.fcm_service import send_fcm_notification, send_landlord_push_v1

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


def _first_fcm_token_for_user(user_id: int) -> str:
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
            detail=(
                f"No FCM token for user_id={user_id}. "
                "Log in on a physical device, allow notifications, and ensure the app posts /me/fcm-token."
            ),
        )
    return fcm_token


def _landlord_preview_copy(variant: str) -> Tuple[str, str, Dict[str, str]]:
    """Sample title, body, data (strings) matching production landlord pushes."""
    if variant == "rent_due_soon":
        return (
            "💰 Rent due soon",
            "Rent due in 2 days for Rahul – ₹25,000",
            {
                "lease_id": "0",
                "tenant_name": "Rahul",
                "property_name": "Sample flat",
                "due_date": "2026-04-03",
            },
        )
    if variant == "rent_overdue":
        return (
            "🚨 Rent overdue",
            "Rahul hasn't paid rent for March yet",
            {
                "lease_id": "0",
                "tenant_name": "Rahul",
                "property_name": "Sample flat",
                "due_date": "2026-03-05",
            },
        )
    if variant == "payment_confirmed":
        return (
            "✅ Payment recorded",
            "Payment recorded for Rahul – ₹25,000 (April 2026)",
            {
                "lease_id": "0",
                "tenant_name": "Rahul",
                "property_name": "Sample flat",
            },
        )
    if variant == "lease_expiring":
        return (
            "📄 Lease expiring soon",
            "Lease for Flat 302 expires in 30 days",
            {
                "lease_id": "0",
                "property_name": "Flat 302",
                "lease_end": "2026-05-01",
            },
        )
    raise HTTPException(status_code=400, detail="Unknown variant")


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
    print(
        f"[push] fcm_token stored user_id={user_id} platform={platform} len={len(token)}",
        flush=True,
    )
    return {"status": "ok", "platform": platform}


@router.post("/me/push-test")
def send_test_push_to_self(authorization: Optional[str] = Header(None)):
    """
    Minimal FCM connectivity check (generic title/body).
    To preview real landlord styling, use POST /me/push-test-landlord instead.
    """
    user_id = _require_user_id(authorization)
    fcm_token = _first_fcm_token_for_user(user_id)

    ok, msg = send_fcm_notification(
        fcm_token=fcm_token,
        title="KirayaEase",
        body="Test push — notifications are working.",
        data={"type": "test"},
    )
    if not ok:
        raise HTTPException(status_code=502, detail=msg)
    return {"status": "sent", "detail": msg}


@router.post("/me/push-test-landlord")
def send_landlord_style_preview(
    body: LandlordPushPreviewBody,
    authorization: Optional[str] = Header(None),
):
    """
    Send one sample landlord notification using the same FCM payload as production
    (Android color/priority, iOS thread-id). Does not touch push_notification_log.
    """
    user_id = _require_user_id(authorization)
    fcm_token = _first_fcm_token_for_user(user_id)
    title, preview_body, data = _landlord_preview_copy(body.variant)

    ok, msg = send_landlord_push_v1(
        fcm_token=fcm_token,
        title=title,
        body=preview_body,
        data=data,
        variant=body.variant,
    )
    if not ok:
        raise HTTPException(status_code=502, detail=msg)
    return {"status": "sent", "variant": body.variant, "detail": msg}
