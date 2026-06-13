"""
Application configuration — GCP-aware.

Secrets are resolved from Google Secret Manager when running on Cloud Run
(GOOGLE_CLOUD_PROJECT set), and fall back to plain environment variables for
local development.  The secrets module injects values into os.environ at
startup so pydantic-settings picks them up transparently.
"""
from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── Razorpay ─────────────────────────────────────────────────────────────
    RAZORPAY_TEST_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""

    # ── OpenAI ───────────────────────────────────────────────────────────────
    OPENAI_API_KEY: str = ""

    # ── Pinecone ─────────────────────────────────────────────────────────────
    PINECONE_API_KEY: str = ""

    # ── DocuSeal ─────────────────────────────────────────────────────────────
    DOCUSEAL_API_KEY: str = ""
    DOCUSEAL_WEBHOOK_SECRET: str = ""

    # ── WhatsApp (Meta) ───────────────────────────────────────────────────────
    WHATSAPP_TOKEN: str = ""
    WHATSAPP_PHONE_ID: str = ""

    # ── Email (Resend) ────────────────────────────────────────────────────────
    RESEND_API_KEY: str = ""

    # ── Firebase / FCM ────────────────────────────────────────────────────────
    FCM_PROJECT_ID: str = ""
    FIREBASE_SERVICE_ACCOUNT_JSON: str = ""

    # ── Google OAuth ──────────────────────────────────────────────────────────
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    # ── Database / Cloud SQL ─────────────────────────────────────────────────
    DATABASE_URL: str = ""          # local dev fallback
    CLOUD_SQL_INSTANCE: str = ""    # e.g. my-project:asia-south1:kiraya-ease-db
    DB_NAME: str = "kirayaease"
    DB_USER: str = ""
    DB_PASSWORD: str = ""

    # ── GCP ───────────────────────────────────────────────────────────────────
    GOOGLE_CLOUD_PROJECT: str = ""
    CLOUD_RUN_SERVICE: str = "kiraya-ease-api"
    CLOUD_RUN_REGION: str = "asia-south1"

    # ── Digio ────────────────────────────────────────────────────────────────
    DIGIO_CLIENT_ID: str = ""
    DIGIO_CLIENT_SECRET: str = ""

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
