"""
Google Secret Manager integration.

Secrets are loaded once at startup (or on first access) and cached in memory.
Falls back to environment variables so local development requires no changes.

Secret naming convention in Secret Manager:
    KIRAYA_EASE_{ENV_VAR_NAME}   e.g. KIRAYA_EASE_DATABASE_URL
where ENV_VAR_NAME matches the existing environment variable name.

If GOOGLE_CLOUD_PROJECT is not set, this module is a no-op and the caller
falls through to os.getenv() as before.
"""
from __future__ import annotations

import logging
import os
from functools import lru_cache
from typing import Optional

logger = logging.getLogger(__name__)

# ── Optional import — not available in local dev without installing the SDK ──
try:
    from google.cloud import secretmanager  # type: ignore
    _HAS_SECRET_MANAGER = True
except ImportError:
    _HAS_SECRET_MANAGER = False


_SECRET_PREFIX = "KIRAYA_EASE_"
_SECRET_VERSION = "latest"


@lru_cache(maxsize=128)
def _fetch_secret(project_id: str, secret_id: str) -> Optional[str]:
    """Fetch one secret from Secret Manager (cached per process)."""
    if not _HAS_SECRET_MANAGER:
        return None
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{_SECRET_VERSION}"
    try:
        response = client.access_secret_version(request={"name": name})
        return response.payload.data.decode("utf-8").strip()
    except Exception as exc:
        logger.warning("Secret Manager: could not fetch %s — %s", secret_id, exc)
        return None


def get_secret(env_var: str) -> Optional[str]:
    """
    Return the value for `env_var`, checking Secret Manager first.

    Resolution order:
      1. Direct environment variable (highest priority — allows local override)
      2. Google Secret Manager under key KIRAYA_EASE_{env_var}
      3. None
    """
    val = os.getenv(env_var)
    if val:
        return val

    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project_id:
        return None

    secret_id = f"{_SECRET_PREFIX}{env_var}"
    return _fetch_secret(project_id, secret_id)


# ── Secrets loaded at app startup ─────────────────────────────────────────────
_SECRETS_TO_LOAD = [
    "GOOGLE_API_KEY",
    "DATABASE_URL",
    "CLOUD_SQL_INSTANCE",
    "DB_NAME",
    "DB_USER",
    "DB_PASSWORD",
    "OPENAI_API_KEY",
    "PINECONE_API_KEY",
    "RAZORPAY_TEST_KEY_ID",
    "RAZORPAY_KEY_SECRET",
    "DOCUSEAL_API_KEY",
    "DOCUSEAL_WEBHOOK_SECRET",
    "WHATSAPP_TOKEN",
    "WHATSAPP_PHONE_ID",
    "RESEND_API_KEY",
    "GOOGLE_APPLICATION_CREDENTIALS",
    "FCM_PROJECT_ID",
    "FIREBASE_SERVICE_ACCOUNT_JSON",
    "DIGIO_CLIENT_ID",
    "DIGIO_CLIENT_SECRET",
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
]


def load_secrets_into_env() -> None:
    """
    Pull all known secrets from Secret Manager and inject into os.environ.

    Call once at application startup (before any service reads env vars).
    Environment variables already set take priority — they are not overwritten.
    """
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project_id:
        logger.debug("GOOGLE_CLOUD_PROJECT not set — skipping Secret Manager load")
        return

    if not _HAS_SECRET_MANAGER:
        logger.warning(
            "google-cloud-secret-manager not installed; secrets must be in env vars"
        )
        return

    loaded = 0
    for var in _SECRETS_TO_LOAD:
        if os.getenv(var):
            continue  # already in env — don't overwrite
        secret_id = f"{_SECRET_PREFIX}{var}"
        value = _fetch_secret(project_id, secret_id)
        if value is not None:
            os.environ[var] = value
            loaded += 1

    logger.info("Secret Manager: loaded %d secret(s) into env", loaded)
