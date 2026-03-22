"""Build DocuSeal PDF submissions: signature fields on the last page + submitters.

DocuSeal `POST /submissions/pdf` example response shape (see official docs):
  id, name, submitters[], source, submitters_order, status, schema[], fields[],
  expire_at, created_at, documents[], slug, shared_link, …
"""

from __future__ import annotations

import os
from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple

from pypdf import PdfReader

from app.services.docuseal_client import create_submission_from_pdf, get_submission


def _last_page_number(pdf_bytes: bytes) -> int:
    reader = PdfReader(BytesIO(pdf_bytes))
    n = len(reader.pages)
    return max(1, n)


def build_signature_fields(
    *,
    last_page: int,
    include_landlord: bool,
    include_tenant: bool,
) -> List[Dict[str, Any]]:
    """
    Normalized 0–1 coordinates (DocuSeal convention). Boxes on the last page, bottom area.
    Tune via DOCUSEAL_SIG_* env vars if defaults don't match your PDF layout.
    """
    lx = float(os.getenv("DOCUSEAL_SIG_LANDLORD_X", "0.08"))
    ly = float(os.getenv("DOCUSEAL_SIG_LANDLORD_Y", "0.82"))
    lw = float(os.getenv("DOCUSEAL_SIG_LANDLORD_W", "0.38"))
    lh = float(os.getenv("DOCUSEAL_SIG_LANDLORD_H", "0.06"))

    tx = float(os.getenv("DOCUSEAL_SIG_TENANT_X", "0.08"))
    ty = float(os.getenv("DOCUSEAL_SIG_TENANT_Y", "0.90"))
    tw = float(os.getenv("DOCUSEAL_SIG_TENANT_W", "0.38"))
    th = float(os.getenv("DOCUSEAL_SIG_TENANT_H", "0.06"))

    fields: List[Dict[str, Any]] = []
    if include_landlord:
        fields.append(
            {
                "name": "Landlord Signature",
                "type": "signature",
                "role": "Landlord",
                "required": True,
                "areas": [{"x": lx, "y": ly, "w": lw, "h": lh, "page": last_page}],
            }
        )
    if include_tenant:
        fields.append(
            {
                "name": "Tenant Signature",
                "type": "signature",
                "role": "Tenant",
                "required": True,
                "areas": [{"x": tx, "y": ty, "w": tw, "h": th, "page": last_page}],
            }
        )
    return fields


def build_submitters(
    *,
    tenant_email: str,
    tenant_name: Optional[str],
    tenant_phone: Optional[str],
    landlord_email: Optional[str],
    landlord_name: Optional[str],
) -> Tuple[List[Dict[str, Any]], bool, bool]:
    submitters: List[Dict[str, Any]] = []
    has_landlord = bool(landlord_email and str(landlord_email).strip())
    has_tenant = bool(tenant_email and str(tenant_email).strip())

    if has_landlord:
        sd: Dict[str, Any] = {
            "role": "Landlord",
            "email": str(landlord_email).strip(),
            "order": 0,
        }
        if landlord_name and str(landlord_name).strip():
            sd["name"] = str(landlord_name).strip()
        submitters.append(sd)

    if has_tenant:
        st: Dict[str, Any] = {
            "role": "Tenant",
            "email": str(tenant_email).strip(),
            "order": 1 if has_landlord else 0,
        }
        if tenant_name and str(tenant_name).strip():
            st["name"] = str(tenant_name).strip()
        tp = (tenant_phone or "").strip()
        if tp:
            st["phone"] = tp
        submitters.append(st)

    if not submitters:
        raise ValueError("At least tenant_email (or landlord_email) is required")

    return submitters, has_landlord, has_tenant


def _submission_shared_link_default() -> bool:
    v = (os.getenv("DOCUSEAL_SUBMISSION_SHARED_LINK") or "true").strip().lower()
    return v in ("1", "true", "yes", "on")


def _merge_submitter_embed_src(partial: Dict[str, Any], full: Dict[str, Any]) -> Dict[str, Any]:
    """Preserve embed_src / slug from create response if GET strips them."""
    psubs = [s for s in (partial.get("submitters") or []) if isinstance(s, dict)]
    by_email = {(s.get("email") or "").lower().strip(): s for s in psubs}
    by_id = {s.get("id"): s for s in psubs if s.get("id") is not None}
    out: List[Dict[str, Any]] = []
    for s in full.get("submitters") or []:
        if not isinstance(s, dict):
            continue
        m = dict(s)
        pid = m.get("id")
        em = (m.get("email") or "").lower().strip()
        donor = by_id.get(pid) or by_email.get(em)
        if donor:
            if not m.get("embed_src") and donor.get("embed_src"):
                m["embed_src"] = donor["embed_src"]
            if not m.get("slug") and donor.get("slug"):
                m["slug"] = donor["slug"]
        out.append(m)
    merged = dict(full)
    merged["submitters"] = out
    if not merged.get("slug") and partial.get("slug"):
        merged["slug"] = partial["slug"]
    if merged.get("shared_link") is None and partial.get("shared_link") is not None:
        merged["shared_link"] = partial["shared_link"]
    return merged


def fetch_submission_detail_or_use(partial: Dict[str, Any]) -> Dict[str, Any]:
    """Prefer `GET /submissions/{id}` so response includes slug, url, full schema/fields."""
    sid = partial.get("id")
    if sid is None:
        return partial
    try:
        full = get_submission(int(sid))
    except Exception:
        return partial
    return _merge_submitter_embed_src(partial, full)


def request_lease_pdf_signing(
    pdf_bytes: bytes,
    *,
    submission_name: str,
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
    sl = _submission_shared_link_default() if shared_link is None else bool(shared_link)

    submitters, inc_l, inc_t = build_submitters(
        tenant_email=tenant_email,
        tenant_name=tenant_name,
        tenant_phone=tenant_phone,
        landlord_email=landlord_email,
        landlord_name=landlord_name,
    )
    last_page = _last_page_number(pdf_bytes)
    fields = build_signature_fields(
        last_page=last_page, include_landlord=inc_l, include_tenant=inc_t
    )
    if not fields:
        raise ValueError("No signature fields — provide at least one signer email")

    partial = create_submission_from_pdf(
        pdf_bytes=pdf_bytes,
        submission_name=submission_name,
        submitters=submitters,
        fields=fields,
        send_email=send_email,
        send_sms=send_sms,
        order="preserved",
        completed_redirect_url=completed_redirect_url,
        shared_link=sl,
    )
    return fetch_submission_detail_or_use(partial)


def _pick_primary_signing_url(submitters: List[Dict[str, Any]]) -> Optional[str]:
    """Prefer Tenant / First Party embed_src for WhatsApp sharing."""
    for role in ("Tenant", "First Party"):
        for s in submitters:
            if not isinstance(s, dict):
                continue
            if (s.get("role") or "").strip() == role:
                u = s.get("embed_src")
                if u:
                    return str(u).strip()
    for s in submitters:
        if not isinstance(s, dict):
            continue
        u = s.get("embed_src")
        if u:
            return str(u).strip()
    return None


def normalize_docuseal_submission_response(raw: Dict[str, Any]) -> Dict[str, Any]:
    """
    Align with DocuSeal docs sample for POST /submissions/pdf (id, slug, schema, fields,
    submitters with uuid/embed_src, documents, shared_link, status, …).
    """
    shared_req = _submission_shared_link_default()
    submitters_out: List[Dict[str, Any]] = []
    for s in raw.get("submitters") or []:
        if not isinstance(s, dict):
            continue
        submitters_out.append(
            {
                "id": s.get("id"),
                "uuid": s.get("uuid"),
                "email": s.get("email"),
                "slug": s.get("slug"),
                "name": s.get("name"),
                "phone": s.get("phone"),
                "role": s.get("role"),
                "status": s.get("status"),
                "embed_src": s.get("embed_src"),
                "sent_at": s.get("sent_at"),
                "opened_at": s.get("opened_at"),
                "completed_at": s.get("completed_at"),
                "declined_at": s.get("declined_at"),
                "values": s.get("values"),
                "preferences": s.get("preferences"),
                "metadata": s.get("metadata"),
                "external_id": s.get("external_id"),
            }
        )

    shared = raw.get("shared_link")
    if shared is None:
        shared = shared_req

    docuseal: Dict[str, Any] = {
        "id": raw.get("id"),
        "slug": raw.get("slug"),
        "name": raw.get("name"),
        "schema": raw.get("schema"),
        "fields": raw.get("fields"),
        "submitters": submitters_out,
        "source": raw.get("source"),
        "submitters_order": raw.get("submitters_order"),
        "status": raw.get("status"),
        "expire_at": raw.get("expire_at"),
        "created_at": raw.get("created_at"),
        "updated_at": raw.get("updated_at"),
        "archived_at": raw.get("archived_at"),
        "documents": raw.get("documents"),
        "shared_link": bool(shared),
    }

    signing_url = _pick_primary_signing_url(submitters_out)

    out: Dict[str, Any] = {
        "docuseal": docuseal,
        "docuseal_submission_id": raw.get("id"),
        "docuseal_submission_slug": raw.get("slug"),
        "docuseal_signing_url": signing_url,
        "docuseal_shared_link": bool(shared),
        # Flatten for older clients / agent tools
        "docuseal_submission_status": raw.get("status"),
        "submitters": submitters_out,
    }
    return out
