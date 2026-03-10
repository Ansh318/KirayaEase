from langchain_core.tools import tool
from app.agents.lease.talk2lease import TalkToLeaseRAG
from app.core.modelConfig import ModelConfigManager
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.services.lease_extractor import extract_from_pdf, read_pdf_text
from app.schemas.property_manager import PropertyManager
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
        processor.processs_lease(lease_id=lease_id, landlord_id=owner_id, text=raw_text)
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
    address_line1: str | None = None,
    city: str | None = None,
    state: str | None = None,
    postal_code: str | None = None,
) -> dict:
    """Create a property record in the database. name = property name (e.g. 'Maple Apartments #302')."""
    created = PropertyManager().add_property(
        owner_id=owner_id,
        name=name,
        tenant_name=tenant_name,
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

