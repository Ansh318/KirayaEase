"""
Workflow 2: Lease Creation Workflow (ADK Dynamic Workflow).

Steps:
  1. extract_details   — parse PDF or structured input into lease fields
  2. validate_fields   — check required fields and business rules
  3. generate_document — LLM-generate full lease agreement text
  4. store_lease       — persist property + lease + PDF to DB
  5. return_confirmation — return summary with lease_id and PDF URL
"""
from __future__ import annotations

import logging
import os
import tempfile
from typing import Any, Dict, List, Optional

from app.schemas.property_manager import PropertyManager
from app.services.lease_extractor import extract_from_pdf, read_pdf_text
from app.services.lease_agreement_llm import generate_lease_agreement_text
from app.services.lease_services import trigger_post_submit_onboarding
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.schemas.lease_write import LeaseWriteBody
from pydantic import ValidationError

logger = logging.getLogger(__name__)


def step_extract_details(
    *,
    pdf_path: Optional[str] = None,
    structured_input: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Extract lease details from PDF or use provided structured data."""
    if pdf_path:
        data = extract_from_pdf(pdf_path)
        logger.info("[LeaseCreation] extracted from PDF: %s", pdf_path)
        return {"source": "pdf", "data": data}
    if structured_input:
        logger.info("[LeaseCreation] using structured_input")
        return {"source": "structured", "data": structured_input}
    raise ValueError("Either pdf_path or structured_input must be provided")


def step_validate_fields(*, data: Dict[str, Any]) -> Dict[str, Any]:
    """Validate required lease fields and return missing ones."""
    missing: List[str] = []
    if not data.get("lease_start"):
        missing.append("lease_start")
    if not data.get("lease_end"):
        missing.append("lease_end")
    if data.get("monthly_rent") in (None, "", 0):
        missing.append("monthly_rent")
    if data.get("due_day") in (None, "", 0):
        missing.append("due_day")
    if data.get("name") in (None, "") and not any(
        [data.get("address_line1"), data.get("city"), data.get("state")]
    ):
        missing.append("property_address")
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(missing)}")
    logger.info("[LeaseCreation] validation passed")
    return {"valid": True, "missing": []}


def step_generate_document(
    *,
    data: Dict[str, Any],
    reference_prompt: Optional[str] = None,
) -> Dict[str, Any]:
    """Generate full lease agreement text using LLM."""
    try:
        lease_body = LeaseWriteBody.model_validate({
            "property_name": data.get("name") or "Property",
            "tenant_name": data.get("tenant_name"),
            "tenant_email": data.get("tenant_email"),
            "tenant_phone": data.get("tenant_phone"),
            "address_line1": data.get("address_line1"),
            "city": data.get("city"),
            "state": data.get("state"),
            "postal_code": data.get("postal_code"),
            "lease_start": str(data.get("lease_start", "")),
            "lease_end": str(data.get("lease_end", "")),
            "monthly_rent": int(data.get("monthly_rent") or 0),
            "due_day": int(data.get("due_day") or 1),
            "security_deposit": data.get("security_deposit"),
            "lock_in_period": data.get("lock_in_period"),
        })
        agreement_text = generate_lease_agreement_text(
            lease_body, reference_prompt=reference_prompt
        )
        logger.info("[LeaseCreation] agreement generated, chars=%d", len(agreement_text))
        return {"agreement_text": agreement_text, "char_count": len(agreement_text)}
    except (ValidationError, Exception) as e:
        logger.warning("[LeaseCreation] document generation failed: %s", e)
        return {"agreement_text": None, "error": str(e)}


def step_store_lease(
    *,
    owner_id: int,
    data: Dict[str, Any],
    agreement_text: Optional[str] = None,
    pdf_path: Optional[str] = None,
    public_base_url: str = "",
) -> Dict[str, Any]:
    """Persist property + lease to the database and index for RAG."""
    pm = PropertyManager()
    prop = pm.add_property(
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
        raise RuntimeError("Failed to create property")

    lease = pm.add_lease(
        property_id=property_id,
        lease_start=str(data["lease_start"]),
        lease_end=str(data["lease_end"]),
        monthly_rent=int(data.get("monthly_rent") or 0),
        security_deposit=int(data["security_deposit"]) if data.get("security_deposit") else None,
        lock_in_period=int(data["lock_in_period"]) if data.get("lock_in_period") else None,
        due_day=int(data.get("due_day") or 1),
        lease_text=agreement_text,
    )
    lease_id = lease.get("id")

    if lease_id:
        trigger_post_submit_onboarding(int(owner_id), int(lease_id))
        # Index for RAG
        if pdf_path:
            try:
                raw_text = read_pdf_text(pdf_path)
                LeaseDocumentProcessor().process_lease(str(lease_id), str(owner_id), raw_text)
            except Exception as exc:
                logger.warning("[LeaseCreation] RAG indexing failed: %s", exc)
        elif agreement_text:
            try:
                LeaseDocumentProcessor().process_lease(str(lease_id), str(owner_id), agreement_text)
            except Exception as exc:
                logger.warning("[LeaseCreation] RAG indexing (text) failed: %s", exc)

    logger.info("[LeaseCreation] stored lease_id=%s property_id=%s", lease_id, property_id)
    return {"property_id": property_id, "lease_id": lease_id}


def step_return_confirmation(
    *,
    owner_id: int,
    property_id: int,
    lease_id: int,
    data: Dict[str, Any],
) -> Dict[str, Any]:
    """Return a structured confirmation with authoritative DB record."""
    auth = PropertyManager().get_lease_detail_for_owner(int(lease_id), int(owner_id))
    return {
        "status": "success",
        "property_id": property_id,
        "lease_id": lease_id,
        "property_name": data.get("name") or "Property",
        "tenant_name": data.get("tenant_name"),
        "monthly_rent": data.get("monthly_rent"),
        "lease_start": str(data.get("lease_start", "")),
        "lease_end": str(data.get("lease_end", "")),
        "authoritative_lease_record": auth,
    }


def run_lease_creation_workflow(
    *,
    owner_id: int,
    pdf_path: Optional[str] = None,
    structured_input: Optional[Dict[str, Any]] = None,
    reference_prompt: Optional[str] = None,
    public_base_url: str = "",
) -> Dict[str, Any]:
    """
    Execute the full Lease Creation workflow.

    Provide either pdf_path (uploaded PDF) or structured_input (dict with lease fields).
    Returns a confirmation dict with lease_id and authoritative_lease_record.
    """
    # Step 1: Extract
    extract_result = step_extract_details(pdf_path=pdf_path, structured_input=structured_input)
    data = extract_result["data"]

    # Step 2: Validate
    step_validate_fields(data=data)

    # Step 3: Generate document (non-blocking — falls back gracefully)
    doc_result = step_generate_document(data=data, reference_prompt=reference_prompt)
    agreement_text = doc_result.get("agreement_text")

    # Step 4: Store
    store_result = step_store_lease(
        owner_id=owner_id,
        data=data,
        agreement_text=agreement_text,
        pdf_path=pdf_path,
        public_base_url=public_base_url,
    )

    # Step 5: Confirmation
    confirmation = step_return_confirmation(
        owner_id=owner_id,
        property_id=store_result["property_id"],
        lease_id=store_result["lease_id"],
        data=data,
    )
    return {
        **confirmation,
        "steps": {
            "extract_details": extract_result,
            "validate_fields": {"valid": True},
            "generate_document": doc_result,
            "store_lease": store_result,
        },
    }
