from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.core.secrets import load_secrets_into_env  # GCP Secret Manager bootstrap
from app.api.v1 import auth, onboarding, agent_chat, leases, docuseal, push, internal_jobs
from app.db.migrations import ensure_runtime_migrations
from app.db.cloud_sql import close_pool


@asynccontextmanager
async def _lifespan(app: FastAPI):
    # 1. Pull secrets from GCP Secret Manager before anything else touches env
    load_secrets_into_env()
    # 2. Run idempotent DB migrations (safe to run on every startup)
    ensure_runtime_migrations()
    yield
    # 3. Graceful shutdown — return all pooled connections
    close_pool()


app = FastAPI(lifespan=_lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production via Cloud Run env var
    allow_credentials=True,
    allow_methods=["*"],
)
app.include_router(auth.router)
app.include_router(onboarding.router)
app.include_router(agent_chat.router)
app.include_router(leases.router)
app.include_router(docuseal.router)
app.include_router(push.router)
app.include_router(internal_jobs.router)  # Cloud Scheduler job endpoints

# Serve uploaded PDFs. On Cloud Run, /uploads is ephemeral — use GCS for
# durable storage. The lease PDF endpoint (/leases/{id}/pdf) reads from
# Cloud SQL (lease_files table) which is durable.
_uploads_dir = os.path.abspath(os.path.join(os.getcwd(), "uploads"))
os.makedirs(_uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads_dir), name="uploads")


@app.get("/")
def health_check():
    return {"status": "KirayaEase API running", "backend": "Google Cloud Run + ADK"}


@app.get("/health")
def health():
    """Cloud Run health probe endpoint."""
    return {"ok": True}
