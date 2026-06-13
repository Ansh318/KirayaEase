"""
ADK tool wrappers for lease operations.

All business logic lives in app.agents.lease.lease_tools and app.services.*
These are thin adapters that expose the same logic as google.adk FunctionTool
callables (plain Python functions — ADK wraps them automatically).
"""
from __future__ import annotations

from typing import Any, Dict, Optional

from app.schemas.property_manager import PropertyManager
from app.schemas.lease_write import LeaseWriteBody
from app.services.lease_extractor import extract_from_pdf, read_pdf_text
from app.services.lease_services import (
    finalize_generated_lease_agreement,
    finalize_stored_lease_draft,
    generate_and_store_lease_agreement_preview,
    trigger_post_submit_onboarding,
)
from app.services.user_lease_draft_store import get_lease_draft, save_lease_draft
from app.services.docuseal_flow import start_docuseal_signing_for_owner_lease
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.agents.lease.talk2lease import TalkToLeaseRAG
from app.core.client_actions import (
    OPEN_DOCUSEAL_SIGNING,
    OPEN_LEASE_AGREEMENT_PREVIEW,
    OPEN_LEASE_AGREEMENT_WIDGET,
)
from pydantic import ValidationError
import json


def _authoritative_lease_record(owner_id: int, lease_id: int | None) -> dict | None:
    if lease_id is None:
        return None
    row = PropertyManager().get_lease_detail_for_owner(int(lease_id), int(owner_id))
    return row if row else None


def tool_store_lease(owner_id: int, pdf_path: str) -> dict:
    """Extract lease data from PDF, create property + lease in DB, index for RAG."""
    data = extract_from_pdf(pdf_path)
    missing = []
    if not data.get("lease_start"):
        missing.append("lease_start")
    if not data.get("lease_end"):
        missing.append("lease_end")
    if data.get("monthly_rent") in (None, "", 0):
        missing.append("monthly_rent")
    if data.get("due_day") in (None, "", 0):
        missing.append("due_day")
    if data.get("name") in (None, "") and not any(
        [data.get("address_line1"), data.get("city"), data.get("state"), data.get("postal_code")]
    ):
        missing.append("property_address")

    if missing:
        return {
            "status": "needs_clarification",
            "missing_fields": missing,
            "extracted_data": data,
            "message": f"Missing: {', '.join(missing)}. Please provide these values.",
        }

    prop = PropertyManager().add_property(
        owner_id=owner_id,
        name=data.get("name") or "Property",
        tenant_name=data.get("tenant_name"),
        tenant_phone=data.get("tenant_phone"),
        tenant_email=data.get("tenant_email"),
        address_line1=data.get("address_line1"),
        city=data.get("city"),
        state=data.get("state"),
        postal_code=data.get("postal_code"),
    )
    property_id = prop.get("id")
    if not property_id:
        return {"status": "error", "message": "Failed to create property"}

    lease = PropertyManager().add_lease(
        property_id=property_id,
        lease_start=str(data["lease_start"]),
        lease_end=str(data["lease_end"]),
        monthly_rent=int(data.get("monthly_rent") or 0),
        security_deposit=int(data["security_deposit"]) if data.get("security_deposit") else None,
        lock_in_period=int(data["lock_in_period"]) if data.get("lock_in_period") else None,
        due_day=int(data.get("due_day") or 1),
    )
    lease_id = lease.get("id")
    if lease_id:
        trigger_post_submit_onboarding(int(owner_id), int(lease_id))
        try:
            raw_text = read_pdf_text(pdf_path)
            LeaseDocumentProcessor().process_lease(str(lease_id), str(owner_id), raw_text)
        except Exception:
            pass

    auth = _authoritative_lease_record(owner_id, lease_id)
    return {"status": "success", "property_id": property_id, "lease_id": lease_id, "authoritative_lease_record": auth}


def tool_inquire_lease(query: str, lease_id: int) -> dict:
    """Answer a question about a specific lease using stored RAG document."""
    rag = TalkToLeaseRAG(model_name="gpt-4o-mini", temperature=0, max_retries=3)
    answer = rag.answer_question(query, lease_id)
    return {"answer": answer, "lease_id": lease_id}


def tool_extract_lease_details(pdf_path: str) -> str:
    """Extract lease fields from a PDF without storing."""
    result = extract_from_pdf(pdf_path)
    return json.dumps(result, ensure_ascii=False, indent=2)


def tool_create_property(
    owner_id: int,
    name: str,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    tenant_email: Optional[str] = None,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
) -> dict:
    """Create a property record."""
    created = PropertyManager().add_property(
        owner_id=owner_id, name=name, tenant_name=tenant_name,
        tenant_phone=tenant_phone, tenant_email=tenant_email,
        address_line1=address_line1, city=city, state=state, postal_code=postal_code,
    )
    return {"property_id": created.get("id"), "property": created, "status": "success"}


def tool_add_lease(
    property_id: int,
    lease_start: str,
    lease_end: str,
    monthly_rent: int,
    due_day: int,
    lease_text: Optional[str] = None,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
) -> dict:
    """Create a lease record for an existing property."""
    created = PropertyManager().add_lease(
        property_id=property_id, lease_text=lease_text,
        lease_start=lease_start, lease_end=lease_end, monthly_rent=monthly_rent,
        security_deposit=security_deposit, lock_in_period=lock_in_period, due_day=due_day,
    )
    lid = created.get("id")
    prop = PropertyManager().get_property(int(property_id)) if property_id else {}
    oid = prop.get("owner_id")
    auth = _authoritative_lease_record(int(oid), int(lid)) if oid and lid else None
    return {"lease_id": lid, "lease": created, "status": "success", "authoritative_lease_record": auth}


def tool_prepare_lease_draft(
    owner_id: int,
    property_name: Optional[str] = None,
    lease_start: Optional[str] = None,
    lease_end: Optional[str] = None,
    monthly_rent: Optional[int] = None,
    due_day: Optional[int] = None,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    tenant_email: Optional[str] = None,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
) -> dict:
    """Merge lease draft fields server-side; returns status=partial or validated."""
    patch: Dict[str, Any] = {}
    for k, v in {
        "property_name": property_name, "lease_start": lease_start, "lease_end": lease_end,
        "monthly_rent": monthly_rent, "due_day": due_day, "tenant_name": tenant_name,
        "tenant_phone": tenant_phone, "tenant_email": tenant_email, "address_line1": address_line1,
        "city": city, "state": state, "postal_code": postal_code,
        "security_deposit": security_deposit, "lock_in_period": lock_in_period,
    }.items():
        if v is not None:
            patch[k] = v

    existing = get_lease_draft(int(owner_id))
    merged = {**(existing or {}), **patch}

    if not save_lease_draft(int(owner_id), merged):
        return {"status": "error", "message": "Could not persist draft (DB error)"}

    try:
        body = LeaseWriteBody.model_validate(merged)
        save_lease_draft(int(owner_id), body.model_dump(mode="json"))
        return {"status": "validated", "draft_body": body.model_dump(mode="json"), "missing_fields": []}
    except ValidationError:
        return {"status": "partial", "draft_so_far": merged, "missing_fields": list(patch.keys())}


def tool_generate_lease_agreement(owner_id: int, reference_prompt: Optional[str] = None) -> dict:
    """LLM-generate a full lease agreement from saved draft facts."""
    raw = get_lease_draft(int(owner_id))
    if not raw:
        return {"status": "error", "message": "No draft on file. Use prepare_lease_draft first."}
    try:
        body = LeaseWriteBody.model_validate(raw)
    except ValidationError as e:
        return {"status": "error", "message": "Draft incomplete", "details": e.errors()}
    try:
        out = generate_and_store_lease_agreement_preview(int(owner_id), body, reference_prompt=reference_prompt)
    except (ValueError, RuntimeError) as e:
        return {"status": "error", "message": str(e)}
    full_text = out.get("agreement_text") or ""
    return {
        "status": "generated",
        "char_count": out.get("char_count"),
        "preview_excerpt": full_text[:2400] + ("…" if len(full_text) > 2400 else ""),
        "client_action": OPEN_LEASE_AGREEMENT_PREVIEW,
    }


def tool_save_generated_lease_agreement(owner_id: int, public_base_url: str = "") -> dict:
    """Persist property + lease from the LLM-generated agreement preview."""
    try:
        detail = finalize_generated_lease_agreement(int(owner_id), public_base_url=public_base_url.rstrip("/"))
    except ValueError as e:
        return {"status": "error", "message": str(e)}
    lid = detail.get("lease_id")
    auth = _authoritative_lease_record(int(owner_id), int(lid) if lid else None) or detail
    return {"status": "success", "lease_id": lid, "authoritative_lease_record": auth}


def tool_finalize_lease_creation(owner_id: int, public_base_url: str = "") -> dict:
    """Legacy quick-save: creates property + lease with short summary PDF."""
    try:
        detail = finalize_stored_lease_draft(int(owner_id), public_base_url=public_base_url.rstrip("/"))
    except ValueError as e:
        return {"status": "error", "message": str(e)}
    lid = detail.get("lease_id")
    auth = _authoritative_lease_record(int(owner_id), int(lid) if lid else None) or detail
    return {"status": "success", "lease_id": lid, "authoritative_lease_record": auth}


def tool_open_lease_agreement_widget() -> dict:
    """Tell client to open the lease agreement UI widget."""
    return {"status": "ok", "client_action": OPEN_LEASE_AGREEMENT_WIDGET}


def tool_send_lease_for_signature_docuseal(
    owner_id: int,
    lease_id: int,
    tenant_email: Optional[str] = None,
    tenant_name: Optional[str] = None,
    landlord_email: Optional[str] = None,
    landlord_name: Optional[str] = None,
    send_email: bool = True,
    shared_link: bool = True,
) -> dict:
    """Start DocuSeal e-signing on the saved lease PDF."""
    try:
        out = start_docuseal_signing_for_owner_lease(
            owner_id=int(owner_id), lease_id=int(lease_id),
            tenant_email=(tenant_email or "").strip(),
            tenant_name=(tenant_name or "").strip() or None,
            landlord_email=(landlord_email or "").strip() or None,
            landlord_name=(landlord_name or "").strip() or None,
            send_email=send_email, shared_link=shared_link, completed_redirect_url=None,
        )
    except (ValueError, RuntimeError) as e:
        return {"status": "error", "message": str(e)}
    return {
        "status": "success", **out,
        "client_action": OPEN_DOCUSEAL_SIGNING,
        "client_action_payload": {
            "lease_id": int(lease_id),
            "submitters": out.get("submitters"),
            "docuseal_signing_url": out.get("docuseal_signing_url"),
        },
    }
