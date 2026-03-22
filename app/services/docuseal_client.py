"""Low-level HTTP client for DocuSeal API (US/EU cloud or self-hosted).

Env:
  DOCUSEAL_API_KEY   — required for signing requests
  DOCUSEAL_API_BASE  — default https://api.docuseal.com (use https://api.docuseal.eu for EU)

See: https://www.docuseal.com/docs/api#create-a-submission-from-pdf
"""

from __future__ import annotations

import base64
import os
from typing import Any, Dict, List, Optional, Tuple

import httpx


def _api_key_and_base() -> Tuple[str, str]:
    api_key = os.getenv("DOCUSEAL_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("DOCUSEAL_API_KEY is not configured")
    base = os.getenv("DOCUSEAL_API_BASE", "https://api.docuseal.com").rstrip("/")
    return api_key, base


def get_submission(submission_id: int) -> Dict[str, Any]:
    """GET /submissions/{id} — full submission (slug, url, submitters, schema, fields, …)."""
    api_key, base = _api_key_and_base()
    url = f"{base}/submissions/{int(submission_id)}"
    with httpx.Client(timeout=60.0) as client:
        resp = client.get(
            url,
            headers={"X-Auth-Token": api_key, "Accept": "application/json"},
        )
    if resp.status_code >= 400:
        raise RuntimeError(
            f"DocuSeal GET submission error {resp.status_code}: {resp.text[:2000]}"
        )
    return resp.json()


def create_submission_from_pdf(
    *,
    pdf_bytes: bytes,
    submission_name: str,
    submitters: List[Dict[str, Any]],
    document_display_name: str = "Lease agreement",
    fields: Optional[List[Dict[str, Any]]] = None,
    send_email: bool = True,
    send_sms: bool = False,
    order: str = "preserved",
    completed_redirect_url: Optional[str] = None,
    shared_link: bool = True,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    POST /submissions/pdf — one-off submission from a PDF + optional field definitions.

    Returns the JSON body from DocuSeal (includes submission id and submitter embed_src URLs).
    """
    api_key, base = _api_key_and_base()
    url = f"{base}/submissions/pdf"

    doc: Dict[str, Any] = {
        "name": document_display_name,
        "file": base64.b64encode(pdf_bytes).decode("ascii"),
    }
    if fields:
        doc["fields"] = fields

    body: Dict[str, Any] = {
        "name": submission_name,
        "send_email": send_email,
        "send_sms": send_sms,
        "order": order,
        "documents": [doc],
        "submitters": submitters,
        # DocuSeal templates use shared_link; we send it for PDF submissions so signing
        # URLs stay shareable (e.g. WhatsApp). Ignored safely if the API omits support.
        "shared_link": shared_link,
    }
    if completed_redirect_url:
        body["completed_redirect_url"] = completed_redirect_url
    if extra:
        body.update(extra)

    with httpx.Client(timeout=120.0) as client:
        resp = client.post(
            url,
            headers={
                "X-Auth-Token": api_key,
                "Content-Type": "application/json",
            },
            json=body,
        )

    if resp.status_code >= 400:
        raise RuntimeError(
            f"DocuSeal API error {resp.status_code}: {resp.text[:4000]}"
        )

    return resp.json()
