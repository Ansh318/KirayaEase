"""Orchestrate DocuSeal signing for a lease (PDF from DB + persist submission id)."""

from __future__ import annotations

from typing import Any, Dict, Optional

from app.schemas.property_manager import PropertyManager
from app.services.docuseal_lease_store import (
    fetch_lease_pdf_for_owner,
    save_docuseal_submission_for_lease,
)
from app.services.docuseal_signing import (
    normalize_docuseal_submission_response,
    request_lease_pdf_signing,
)


def start_docuseal_signing_for_owner_lease(
    *,
    owner_id: int,
    lease_id: int,
    tenant_email: str,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    landlord_email: Optional[str] = None,
    landlord_name: Optional[str] = None,
    send_email: bool = True,
    send_sms: bool = False,
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

    if not tenant_phone and detail.get("tenant_phone"):
        tenant_phone = str(detail["tenant_phone"]).strip() or None

    raw = request_lease_pdf_signing(
        pdf_bytes,
        submission_name=submission_name,
        tenant_email=tenant_email,
        tenant_name=tenant_name,
        tenant_phone=tenant_phone,
        landlord_email=landlord_email,
        landlord_name=landlord_name,
        send_email=send_email,
        send_sms=send_sms,
        completed_redirect_url=completed_redirect_url,
        shared_link=shared_link,
    )

    sid = raw.get("id")
    if sid is None:
        raise RuntimeError("DocuSeal response missing submission id")

    out = normalize_docuseal_submission_response(raw)

    if not save_docuseal_submission_for_lease(
        lease_id,
        owner_id,
        int(sid),
        status="pending",
        submission_slug=(raw.get("slug") or out.get("docuseal_submission_slug")),
        shared_link=out.get("docuseal_shared_link"),
        signing_url=out.get("docuseal_signing_url"),
    ):
        raise RuntimeError("Could not persist DocuSeal submission id on lease")

    out["lease_id"] = lease_id
    out["message"] = (
        "Use `docuseal_signing_url` (or each submitter `embed_src`) in a WhatsApp message so the "
        "tenant can sign. When everyone has signed, the webhook stores the PDF in "
        "`docuseal_combined_document_url` on the lease."
    )
    return out
