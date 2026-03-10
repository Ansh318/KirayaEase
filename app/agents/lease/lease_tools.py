from langchain_core.tools import tool
from app.agents.lease.talk2lease import TalkToLeaseRAG
from app.core.state import AgentState
from app.core.modelConfig import ModelConfigManager
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.services.lease_extractor import extract_from_pdf
from app.schemas.property_manager import PropertyManager
# llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()
import json

@tool
def store_lease(lease_id_num, landlord_id_num, lease_text):
    "DocString"
    processor = LeaseDocumentProcessor()

    processor.processs_lease(
        lease_id = lease_id_num,
        landlord_id = landlord_id_num,
        text = lease_text
    )
    extract_text =  extract_from_pdf(lease_text)

    #Step 2 - Store record in SQL 
    #Return success 
    pass

@tool 
def inquire_lease(state: AgentState) -> dict:
    """Inquire about a lease"""
    rag = TalkToLeaseRAG(
        model_name="gpt-4o-mini",
        temperature=0,
        max_retries=3,
    )
    query = state["user_query"]
    lease_id = state["lease_id"]
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

