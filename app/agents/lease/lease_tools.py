from typing import Optional

from langchain_core.tools import tool
from pydantic import ValidationError

from app.agents.lease.talk2lease import TalkToLeaseRAG
from app.core.modelConfig import ModelConfigManager
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.services.lease_extractor import extract_from_pdf, read_pdf_text
from app.schemas.property_manager import PropertyManager
from app.schemas.lease_write import LeaseWriteBody
from app.services.lease_draft_preview import format_lease_draft_preview
from app.services.lease_services import finalize_stored_lease_draft
from app.services.user_lease_draft_store import save_lease_draft
import json


@tool
def store_lease(owner_id: int, pdf_path: str) -> dict:
    """Extract lease data from a PDF and, if complete, create the property and lease in the DB and index for RAG.

    If critical fields are missing, this tool will return `status='needs_clarification'` and list missing fields
    so the agent can ask the user before proceeding.
    """
    data = extract_from_pdf(pdf_path)
    name = data.get("name") or "Property"
    tenant_name = data.get("tenant_name")
    address_line1 = data.get("address_line1")
    city = data.get("city")
    state = data.get("state")
    postal_code = data.get("postal_code")
    lease_start = data.get("lease_start")
    lease_end = data.get("lease_end")
    monthly_rent = data.get("monthly_rent") or 0
    security_deposit = data.get("security_deposit")
    lock_in_period = data.get("lock_in_period")
    due_day = data.get("due_day") or 1

    missing: list[str] = []
    if not lease_start:
        missing.append("lease_start")
    if not lease_end:
        missing.append("lease_end")
    # monthly_rent=0 can be a fallback; treat as missing if extractor couldn't find it
    if data.get("monthly_rent") in (None, "", 0):
        missing.append("monthly_rent")
    if data.get("due_day") in (None, "", 0):
        missing.append("due_day")
    if (data.get("name") in (None, "") and not any([address_line1, city, state, postal_code])):
        missing.append("property_address")

    if missing:
        pretty = ", ".join(missing)
        return {
            "status": "needs_clarification",
            "missing_fields": missing,
            "extracted_data": data,
            "message": (
                "I extracted most of your lease, but I'm missing a few key details "
                f"({pretty}). Please tell me those values and I'll save the lease to your portfolio."
            ),
        }

    prop = PropertyManager().add_property(
        owner_id=owner_id,
        name=name,
        tenant_name=tenant_name,
        tenant_phone=data.get("tenant_phone"),
        address_line1=address_line1,
        city=city,
        state=state,
        postal_code=postal_code,
    )
    property_id = prop.get("id")
    if not property_id:
        return {"status": "error", "message": "Failed to create property"}

    lease = PropertyManager().add_lease(
        property_id=property_id,
        lease_start=str(lease_start),
        lease_end=str(lease_end),
        monthly_rent=int(monthly_rent),
        security_deposit=int(security_deposit) if security_deposit is not None else None,
        lock_in_period=int(lock_in_period) if lock_in_period is not None else None,
        due_day=int(due_day),
    )
    lease_id = lease.get("id")

    try:
        raw_text = read_pdf_text(pdf_path)
        processor = LeaseDocumentProcessor()
        processor.process_lease(str(lease_id), str(owner_id), raw_text)
    except Exception:
        pass

    return {
        "status": "success",
        "property_id": property_id,
        "lease_id": lease_id,
        "extracted_data": data,
    }


@tool
def inquire_lease(query: str, lease_id: int) -> dict:
    """Answer a question about a specific lease using the stored lease document. Pass the user's question and the lease id."""
    rag = TalkToLeaseRAG(
        model_name="gpt-4o-mini",
        temperature=0,
        max_retries=3,
    )
    answer = rag.answer_question(query, lease_id)
    return {"answer": answer, "lease_id": lease_id}

@tool
def extract_lease_details(pdf_path: str) -> str:
    """Extracts lease details from a PDF file"""
    result = extract_from_pdf(pdf_path)
    return json.dumps(result, ensure_ascii=False, indent=2)

@tool
def create_property(
    owner_id: int,
    name: str,
    tenant_name: str | None = None,
    tenant_phone: str | None = None,
    address_line1: str | None = None,
    city: str | None = None,
    state: str | None = None,
    postal_code: str | None = None,
) -> dict:
    """Create a property record in the database. name = property name (e.g. 'Maple Apartments #302'). tenant_phone optional (digits / +91)."""
    created = PropertyManager().add_property(
        owner_id=owner_id,
        name=name,
        tenant_name=tenant_name,
        tenant_phone=tenant_phone,
        address_line1=address_line1,
        city=city,
        state=state,
        postal_code=postal_code,
    )
    return {
        "property_id": created.get("id"),
        "property": created,
        "status": "success",
    }


@tool
def add_lease(
    property_id: int,
    lease_start: str,
    lease_end: str,
    monthly_rent: int,
    due_day: int,
    lease_text: str | None = None,
    security_deposit: int | None = None,
    lock_in_period: int | None = None,
) -> dict:
    """Create a lease record for a property. Dates as YYYY-MM-DD. due_day is 1-31."""
    created = PropertyManager().add_lease(
        property_id=property_id,
        lease_text=lease_text,
        lease_start=lease_start,
        lease_end=lease_end,
        monthly_rent=monthly_rent,
        security_deposit=security_deposit,
        lock_in_period=lock_in_period,
        due_day=due_day,
    )
    return {
        "lease_id": created.get("id"),
        "lease": created,
        "status": "success",
    }


def _lease_fields_dict(
    property_name: str,
    lease_start: str,
    lease_end: str,
    monthly_rent: int,
    due_day: int = 1,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
) -> dict:
    return {
        "property_name": property_name.strip(),
        "lease_start": lease_start.strip()[:10],
        "lease_end": lease_end.strip()[:10],
        "monthly_rent": monthly_rent,
        "due_day": due_day,
        "tenant_name": tenant_name.strip() if tenant_name else None,
        "tenant_phone": tenant_phone.strip() if tenant_phone else None,
        "address_line1": address_line1.strip() if address_line1 else None,
        "city": city.strip() if city else None,
        "state": state.strip() if state else None,
        "postal_code": postal_code.strip() if postal_code else None,
        "security_deposit": security_deposit,
        "lock_in_period": lock_in_period,
    }


@tool
def prepare_lease_draft(
    owner_id: int,
    property_name: str,
    lease_start: str,
    lease_end: str,
    monthly_rent: int,
    due_day: int = 1,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
) -> dict:
    """Validate lease details and show a **preview** — no property/lease row yet; draft is **saved server-side** so they can **edit** (new values → call this again) until happy, then **finalize_lease_creation** = **Save** creates the lease. Required: property_name, lease_start, lease_end (YYYY-MM-DD), monthly_rent, due_day (1-31)."""
    try:
        body = LeaseWriteBody.model_validate(
            _lease_fields_dict(
                property_name,
                lease_start,
                lease_end,
                monthly_rent,
                due_day,
                tenant_name,
                tenant_phone,
                address_line1,
                city,
                state,
                postal_code,
                security_deposit,
                lock_in_period,
            )
        )
    except ValidationError as e:
        return {
            "status": "error",
            "message": "Validation failed. Use YYYY-MM-DD for dates; monthly_rent >= 1; due_day 1-31.",
            "details": e.errors(),
        }
    draft_body = body.model_dump(mode="json")
    if not save_lease_draft(int(owner_id), draft_body):
        return {
            "status": "error",
            "message": "Could not persist lease draft (DATABASE_URL missing or DB error). Fix server config and retry.",
        }
    return {
        "status": "validated",
        "preview": format_lease_draft_preview(body),
        "draft_body": draft_body,
        "message": (
            "Draft saved. Show `preview`. They should fix any mistakes **before** Save — "
            "gather corrections and call prepare_lease_draft again if needed. "
            "Only after they explicitly want to **create/save** the lease, call finalize_lease_creation."
        ),
    }


@tool
def finalize_lease_creation(
    owner_id: int,
    public_base_url: str = "",
) -> dict:
    """**Save** the lease: writes property + lease, PDF, RAG — only after the landlord finished **editing the draft** and wants to create it. Loads the server draft from **prepare_lease_draft** (or the app draft editor). If something is still wrong, they should **not** finalize — use **prepare_lease_draft** again with fixes instead."""
    base = (public_base_url or "").strip().rstrip("/")
    try:
        detail = finalize_stored_lease_draft(int(owner_id), public_base_url=base)
    except ValueError as e:
        return {"status": "error", "message": str(e)}
    return {
        "status": "success",
        "lease_id": detail.get("lease_id"),
        "property_id": detail.get("property_id"),
        "property_name": detail.get("property_name"),
        "summary": detail,
        "message": (
            "Lease **saved** to the portfolio. They can open **Properties** to view the PDF. "
            "Edits **before** creation should already be done; only minor post-create fixes use edit + Save there."
        ),
    }

