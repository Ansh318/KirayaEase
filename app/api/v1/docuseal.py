"""DocuSeal webhook (public URL for their dashboard) + helpers."""

from __future__ import annotations

import logging
import os
from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException, Request

from app.services.docuseal_lease_store import (
    apply_docuseal_webhook_update,
    parse_docuseal_webhook,
    utcnow,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["docuseal"])


def _verify_webhook_optional(request: Request) -> None:
    # Preferred: DOCUSEAL_WEBHOOK_SECRET with ?secret=... or X-KirayaEase-Webhook-Secret
    secret = (os.getenv("DOCUSEAL_WEBHOOK_SECRET") or "").strip()
    # Backward-compatible alt naming:
    #   DOCUSEAL_WEBHOOK_KEY=<query/header key>, DOCUSEAL_WEBHOOK_VALUE=<expected value>
    alt_key = (os.getenv("DOCUSEAL_WEBHOOK_KEY") or "").strip()
    alt_val = (os.getenv("DOCUSEAL_WEBHOOK_VALUE") or "").strip()

    if not secret and not (alt_key and alt_val):
        return

    # Canonical secret path
    q_secret = (request.query_params.get("secret") or "").strip()
    h_secret = (request.headers.get("X-KirayaEase-Webhook-Secret") or "").strip()
    if secret and (q_secret == secret or h_secret == secret):
        return

    # Alternate key/value path: allow either query param with given key, or header with same key.
    if alt_key and alt_val:
        q_alt = (request.query_params.get(alt_key) or "").strip()
        h_alt = (request.headers.get(alt_key) or "").strip()
        if q_alt == alt_val or h_alt == alt_val:
            return

    raise HTTPException(status_code=401, detail="Invalid webhook secret")


@router.post("/webhooks/docuseal")
async def docuseal_webhook(request: Request) -> Dict[str, Any]:
    """
    Configure this URL in DocuSeal (append `?secret=...` if DOCUSEAL_WEBHOOK_SECRET is set).

    Handles submission.* and form.* events; updates `leases.docuseal_*` when possible.
    """
    _verify_webhook_optional(request)
    try:
        payload: Dict[str, Any] = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    spec = parse_docuseal_webhook(payload)
    if not spec:
        logger.info("DocuSeal webhook ignored: %s", payload.get("event_type"))
        return {"ok": True, "applied": False}

    sid = int(spec["submission_id"])
    lease_id: Optional[int] = None

    if spec.get("mark_completed"):
        lease_id = apply_docuseal_webhook_update(
            sid,
            status="signed",
            signed_at=utcnow(),
            combined_document_url=spec.get("combined_document_url"),
        )
    elif spec.get("interim_status"):
        lease_id = apply_docuseal_webhook_update(
            sid,
            status=spec["interim_status"],
            signed_at=None,
            combined_document_url=None,
        )

    logger.info(
        "DocuSeal webhook event=%s submission_id=%s lease_id=%s",
        payload.get("event_type"),
        sid,
        lease_id,
    )
    return {"ok": True, "applied": lease_id is not None, "lease_id": lease_id}
