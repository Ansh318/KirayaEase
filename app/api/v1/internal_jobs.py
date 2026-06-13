"""
Internal job endpoints — invoked by Cloud Scheduler (replaces Heroku Scheduler).

These endpoints are authenticated via Cloud Run OIDC (scheduler service account
must have roles/run.invoker on the service). They are NOT exposed to the public
or to the Flutter app.

Routes (POST, no request body needed):
  /internal/jobs/landlord-push
  /internal/jobs/rent-email-reminders
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, Header, HTTPException, Request

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/internal/jobs", tags=["internal"])


def _verify_scheduler_token(request: Request) -> None:
    """
    Basic OIDC verification: Cloud Run validates the Bearer token automatically
    when `--no-allow-unauthenticated` is set on the service.  This function
    provides an additional check on the audience claim if needed.

    For full security, rely on Cloud Run's built-in IAM authentication —
    the scheduler service account must have roles/run.invoker.
    """
    # Cloud Run handles OIDC verification; no extra code needed here.
    # Keeping this hook for future custom audience checks.
    pass


@router.post("/landlord-push")
def run_landlord_push(request: Request):
    """
    Runs daily landlord push notifications:
    - Rent due in 2-3 days
    - Overdue rent
    - Lease expiring in 30 days

    Equivalent to: python -m app.jobs.run_landlord_push
    """
    _verify_scheduler_token(request)
    try:
        from app.services.landlord_push_scheduler import run_scheduled_landlord_pushes
        run_scheduled_landlord_pushes()
        logger.info("[Scheduler] landlord-push completed")
        return {"status": "ok", "job": "landlord-push"}
    except Exception as exc:
        logger.exception("[Scheduler] landlord-push failed: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/rent-email-reminders")
def run_rent_email_reminders(request: Request):
    """
    Runs daily rent email reminders to tenants for upcoming/overdue payments.

    Equivalent to the rent_email_scheduler step in run_landlord_push.
    """
    _verify_scheduler_token(request)
    try:
        from app.services.rent_email_scheduler import run_scheduled_rent_email_reminders
        run_scheduled_rent_email_reminders()
        logger.info("[Scheduler] rent-email-reminders completed")
        return {"status": "ok", "job": "rent-email-reminders"}
    except Exception as exc:
        logger.exception("[Scheduler] rent-email-reminders failed: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))
