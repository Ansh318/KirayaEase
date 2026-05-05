"""Orchestrate DocuSeal signing for a lease (PDF from DB + persist submission id)."""

from __future__ import annotations

from typing import Any, Dict, Optional

from app.schemas.property_manager import PropertyManager
from app.services.docuseal_lease_store import (
    fetch_lease_pdf_for_owner,
    fetch_owner_profile_for_docuseal,
    save_docuseal_submission_for_lease,
)
from app.services.docuseal_signing import (
    normalize_docuseal_submission_response,
    request_lease_pdf_signing,
)
from app.services.email_service import send_html_email
from app.utils.templates import render_tenant_welcome_email_html

def start_docuseal_signing_for_owner_lease(
    *,
    owner_id: int,
    lease_id: int,
    tenant_email: str,
    tenant_name: Optional[str] = None,
    landlord_email: Optional[str] = None,
    landlord_name: Optional[str] = None,
    send_email: bool = True,
    completed_redirect_url: Optional[str] = None,
    shared_link: Optional[bool] = None,
) -> Dict[str, Any]:
    pm = PropertyManager()
    detail = pm.get_lease_detail_for_owner(lease_id, owner_id)
    if not detail:
        raise ValueError("Lease not found or not owned by this user")

    row = fetch_lease_pdf_for_owner(lease_id, owner_id)
    if not row:
        raise ValueError(
            "No PDF is stored for this lease yet. Save or upload the lease PDF first."
        )
    pdf_bytes, _ct = row

    prop_name = (detail.get("property_name") or "").strip() or f"Lease {lease_id}"
    submission_name = prop_name[:240]

    if not tenant_name and detail.get("property_tenant_name"):
        tenant_name = str(detail["property_tenant_name"]).strip() or None

    le = (landlord_email or "").strip() or None
    ln = (landlord_name or "").strip() or None
    if not le:
        auto_email, auto_name = fetch_owner_profile_for_docuseal(owner_id)
        le = auto_email
        if auto_name and not ln:
            ln = auto_name

    te = (tenant_email or "").strip()
    if not te:
        db_email = (detail.get("tenant_email") or "").strip()
        if db_email:
            te = db_email
    if not te:
        raise ValueError(
            "tenant_email is required for DocuSeal signing. Add the tenant's email on the property "
            "or pass tenant_email when starting signing."
        )
    if le and te.lower() == le.lower():
        # Same person as tenant + landlord — single-party submission
        le = None
        ln = None

    raw = request_lease_pdf_signing(
        pdf_bytes,
        submission_name=submission_name,
        tenant_email=te,
        tenant_name=tenant_name,
        landlord_email=le,
        landlord_name=ln,
        send_email=bool(send_email),
        completed_redirect_url=completed_redirect_url,
        shared_link=shared_link,
    )

    sid = raw.get("id")
    if sid is None:
        raise RuntimeError("DocuSeal response missing submission id")

    out = normalize_docuseal_submission_response(raw)
    embeds = out.get("docuseal_submitter_embeds")
    if not isinstance(embeds, dict):
        embeds = {}

    if not save_docuseal_submission_for_lease(
        lease_id,
        owner_id,
        int(sid),
        status="pending",
        submission_slug=(raw.get("slug") or out.get("docuseal_submission_slug")),
        shared_link=out.get("docuseal_shared_link"),
        signing_url=out.get("docuseal_signing_url"),
        submitter_embeds={str(k): str(v) for k, v in embeds.items() if v},
    ):
        raise RuntimeError("Could not persist DocuSeal submission id on lease")

    # Best-effort: warm tenant onboarding welcome email.
    # Do not block DocuSeal onboarding if the email provider fails.
    tenant_display_name = (tenant_name or detail.get("property_tenant_name") or "Tenant")
    welcome_html = render_tenant_welcome_email_html(
        tenant_name=tenant_display_name,
        apt_name=prop_name,
        email=te,
    )
    welcome_email_result = send_html_email(
        to_email=te,
        subject=f"Welcome to {prop_name} - lease signing link coming soon",
        html_body=welcome_html,
    )

    out["lease_id"] = lease_id
    out["tenant_welcome_email"] = (
        {"status": "sent", "provider": "smtp_custom_html"}
        if welcome_email_result.get("ok")
        else {"status": "skipped_or_failed", "detail": welcome_email_result}
    )
    out["message"] = (
        "Landlord can tap **Sign as landlord** in the app (embed URL). "
        "Share **docuseal_signing_url** with the tenant for WhatsApp. "
        "Each party fills **Agreement Date** and signature in DocuSeal. "
        "When fully signed, the webhook stores the PDF — **View PDF** shows the signed file."
    )
    return out
