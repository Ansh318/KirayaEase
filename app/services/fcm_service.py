"""Send FCM v1 messages using a Firebase service account (server-side)."""

from __future__ import annotations

import json
import logging
import os
from typing import Any, Dict, Optional, Tuple

import httpx
from google.auth.transport.requests import Request
from google.oauth2 import service_account

logger = logging.getLogger(__name__)

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


def _load_credentials():
    raw = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    path = (
        os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
        or os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
    )
    if raw:
        try:
            info = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.warning("FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: %s", e)
            return None
        return service_account.Credentials.from_service_account_info(
            info,
            scopes=[_FCM_SCOPE],
        )
    if path and os.path.isfile(path):
        return service_account.Credentials.from_service_account_file(
            path,
            scopes=[_FCM_SCOPE],
        )
    return None


def _access_token() -> Optional[str]:
    creds = _load_credentials()
    if not creds:
        return None
    creds.refresh(Request())
    return creds.token


def _project_id() -> str:
    return (
        os.getenv("FIREBASE_PROJECT_ID", "").strip()
        or os.getenv("GCP_PROJECT", "").strip()
        or "kirayaease-26f1b"
    )


def send_fcm_notification(
    *,
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
) -> Tuple[bool, str]:
    """
    Send one notification via FCM HTTP v1.
    Returns (ok, message_or_error_detail).
    """
    token = _access_token()
    if not token:
        return False, "FCM not configured: set FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS"

    project = _project_id()
    url = f"https://fcm.googleapis.com/v1/projects/{project}/messages:send"
    message: Dict[str, Any] = {
        "token": fcm_token,
        "notification": {"title": title, "body": body},
        "apns": {
            "payload": {
                "aps": {
                    "sound": "default",
                    "badge": 1,
                }
            }
        },
    }
    if data:
        message["data"] = {k: str(v) for k, v in data.items()}

    payload = {"message": message}

    try:
        resp = httpx.post(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=30.0,
        )
    except httpx.HTTPError as e:
        logger.exception("FCM request failed: %s", e)
        return False, str(e)

    if resp.status_code == 200:
        return True, "sent"

    detail = resp.text[:500]
    try:
        err = resp.json()
        detail = str(err.get("error", err))
    except Exception:
        pass
    return False, f"FCM {resp.status_code}: {detail}"
