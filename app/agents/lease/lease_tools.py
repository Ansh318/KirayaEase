from datetime import date
from typing import Any, Dict, List, Optional

from langchain_core.tools import tool
from pydantic import ValidationError

from app.agents.lease.talk2lease import TalkToLeaseRAG
from app.core.client_actions import (
    OPEN_DOCUSEAL_SIGNING,
    OPEN_LEASE_AGREEMENT_PREVIEW,
    OPEN_LEASE_AGREEMENT_WIDGET,
)
from app.core.modelConfig import ModelConfigManager
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.services.lease_extractor import extract_from_pdf, read_pdf_text
from app.schemas.property_manager import PropertyManager
from app.schemas.lease_write import LeaseWriteBody
from app.services.lease_draft_preview import (
    format_lease_draft_preview,
    format_partial_lease_draft_preview,
)
from app.services.lease_services import (
    finalize_generated_lease_agreement,
    finalize_stored_lease_draft,
    generate_and_store_lease_agreement_preview,
)
from app.services.user_lease_draft_store import get_lease_draft, save_lease_draft
from app.services.docuseal_flow import start_docuseal_signing_for_owner_lease
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


def _lease_patch_from_tool_args(
    *,
    property_name: Optional[str] = None,
    lease_start: Optional[str] = None,
    lease_end: Optional[str] = None,
    monthly_rent: Optional[int] = None,
    due_day: Optional[int] = None,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
) -> Dict[str, Any]:
    """Only keys the model explicitly set (non-None) — merged with any draft already on the server."""
    patch: Dict[str, Any] = {}
    if property_name is not None and str(property_name).strip():
        patch["property_name"] = str(property_name).strip()
    if lease_start is not None and str(lease_start).strip():
        patch["lease_start"] = str(lease_start).strip()[:10]
    if lease_end is not None and str(lease_end).strip():
        patch["lease_end"] = str(lease_end).strip()[:10]
    if monthly_rent is not None:
        patch["monthly_rent"] = int(monthly_rent)
    if due_day is not None:
        patch["due_day"] = int(due_day)
    if tenant_name is not None and str(tenant_name).strip():
        patch["tenant_name"] = str(tenant_name).strip()
    if tenant_phone is not None and str(tenant_phone).strip():
        patch["tenant_phone"] = str(tenant_phone).strip()
    if address_line1 is not None and str(address_line1).strip():
        patch["address_line1"] = str(address_line1).strip()
    if city is not None and str(city).strip():
        patch["city"] = str(city).strip()
    if state is not None and str(state).strip():
        patch["state"] = str(state).strip()
    if postal_code is not None and str(postal_code).strip():
        patch["postal_code"] = str(postal_code).strip()
    if security_deposit is not None:
        patch["security_deposit"] = int(security_deposit)
    if lock_in_period is not None:
        patch["lock_in_period"] = int(lock_in_period)
    return patch


def _merge_lease_draft(existing: Optional[Dict[str, Any]], patch: Dict[str, Any]) -> Dict[str, Any]:
    base = dict(existing or {})
    for k, v in patch.items():
        base[k] = v
    return base


def _date_ok(v: Any) -> bool:
    if v is None:
        return False
    if isinstance(v, date):
        return True
    if isinstance(v, str) and v.strip():
        try:
            date.fromisoformat(v.strip()[:10])
            return True
        except ValueError:
            return False
    return False


def _missing_lease_field_labels(merged: Dict[str, Any]) -> List[str]:
    """Human-readable list of what is still needed for a complete manual lease."""
    missing: List[str] = []
    pn = merged.get("property_name")
    if not (isinstance(pn, str) and pn.strip()):
        missing.append("property name / unit label")
    if not _date_ok(merged.get("lease_start")):
        missing.append("lease start date (YYYY-MM-DD)")
    if not _date_ok(merged.get("lease_end")):
        missing.append("lease end date (YYYY-MM-DD)")
    mr = merged.get("monthly_rent")
    try:
        mri = int(mr) if mr is not None else 0
    except (TypeError, ValueError):
        mri = 0
    if mri < 1:
        missing.append("monthly rent in INR (whole number, at least 1)")
    if "due_day" in merged and merged["due_day"] is not None:
        try:
            d = int(merged["due_day"])
            if d < 1 or d > 31:
                missing.append("rent due day (1–31)")
        except (TypeError, ValueError):
            missing.append("rent due day (1–31)")
    return missing


@tool
def prepare_lease_draft(
    owner_id: int,
    property_name: Optional[str] = None,
    lease_start: Optional[str] = None,
    lease_end: Optional[str] = None,
    monthly_rent: Optional[int] = None,
    due_day: Optional[int] = None,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
) -> dict:
    """Update the landlord's lease draft on the server by **merging** these fields with anything already saved.

    **Critical for multi-turn chat:** After each user message, call this with **every field you understood** from
    the **entire conversation** (not only the latest sentence). Omitted parameters keep the previous saved value.
    When `status` is `partial`, only ask for `missing_fields` — do not re-ask for data already in `preview_partial`.
    When `status` is `validated`, show `preview` and wait for confirmation before **finalize_lease_creation**.
    Dates must be YYYY-MM-DD. `due_day` defaults to 1 if never set."""
    oid = int(owner_id)
    patch = _lease_patch_from_tool_args(
        property_name=property_name,
        lease_start=lease_start,
        lease_end=lease_end,
        monthly_rent=monthly_rent,
        due_day=due_day,
        tenant_name=tenant_name,
        tenant_phone=tenant_phone,
        address_line1=address_line1,
        city=city,
        state=state,
        postal_code=postal_code,
        security_deposit=security_deposit,
        lock_in_period=lock_in_period,
    )
    existing = get_lease_draft(oid)
    merged = _merge_lease_draft(existing, patch)

    if not patch and not existing:
        return {
            "status": "error",
            "message": (
                "No fields to save yet. Read the user's message(s), extract any lease details, "
                "and call again with those parameters. If they gave nothing concrete, ask one question at a time."
            ),
        }

    if not save_lease_draft(oid, merged):
        return {
            "status": "error",
            "message": "Could not persist lease draft (DATABASE_URL missing or DB error). Fix server config and retry.",
        }

    try:
        body = LeaseWriteBody.model_validate(merged)
    except ValidationError as e:
        missing = _missing_lease_field_labels(merged)
        return {
            "status": "partial",
            "missing_fields": missing,
            "preview_partial": format_partial_lease_draft_preview(merged),
            "draft_so_far": merged,
            "details": e.errors(),
            "message": (
                "Draft is incomplete or needs fixes. Show `preview_partial` and ask **only** for "
                "`missing_fields`. Then call prepare_lease_draft again with **all known fields** from the "
                "conversation plus any new answers (merge happens on the server)."
            ),
        }

    draft_body = body.model_dump(mode="json")
    if not save_lease_draft(oid, draft_body):
        return {
            "status": "error",
            "message": "Could not persist validated lease draft (DB error).",
        }
    return {
        "status": "validated",
        "preview": format_lease_draft_preview(body),
        "draft_body": draft_body,
        "missing_fields": [],
        "message": (
            "Draft complete and saved. Show `preview`. Next: call **generate_lease_agreement** "
            "(optional `reference_prompt`) to build the full agreement with the LLM, then after they confirm the "
            "preview call **save_generated_lease_agreement**. Legacy shortcut: **finalize_lease_creation** saves a "
            "short summary PDF only (no full LLM agreement)."
        ),
    }


@tool
def open_lease_agreement_widget() -> dict:
    """Tell the app to open the **lease agreement** UI (form: lease facts + optional reference prompt → generate → preview → save). Call when the landlord wants to create a lease using the widget, or asks to open the form / builder / “lease screen”. The client reads `client_action` from the chat API response."""
    return {
        "status": "ok",
        "client_action": OPEN_LEASE_AGREEMENT_WIDGET,
        "message": "Lease agreement widget should open on the client.",
    }


@tool
def generate_lease_agreement(
    owner_id: int,
    reference_prompt: Optional[str] = None,
) -> dict:
    """Use the LLM + default lease template to produce a **full** residential lease agreement text from the saved lease facts. Optional **reference_prompt** customizes clauses (e.g. pets allowed, furnished, notice period). Requires **prepare_lease_draft** to have returned **validated** first (or the widget saved a complete draft). Stores the result server-side for **preview** — user reviews in the lease widget, then **save_generated_lease_agreement**."""
    oid = int(owner_id)
    raw = get_lease_draft(oid)
    if not raw:
        return {
            "status": "error",
            "message": (
                "No lease facts on file. Use the lease builder widget or **prepare_lease_draft** until "
                "`status` is **validated**, then call this tool again."
            ),
        }
    try:
        body = LeaseWriteBody.model_validate(raw)
    except ValidationError as e:
        return {
            "status": "error",
            "message": "Lease facts incomplete. Finish **prepare_lease_draft** until validated, then generate.",
            "details": e.errors(),
        }
    try:
        out = generate_and_store_lease_agreement_preview(
            oid, body, reference_prompt=reference_prompt
        )
    except ValueError as e:
        return {"status": "error", "message": str(e)}
    except RuntimeError as e:
        return {"status": "error", "message": str(e)}
    full_text = out.get("agreement_text") or ""
    excerpt = full_text[:2400]
    return {
        "status": "generated",
        "char_count": out.get("char_count"),
        "preview_excerpt": excerpt + ("…" if len(full_text) > 2400 else ""),
        "client_action": OPEN_LEASE_AGREEMENT_PREVIEW,
        "client_action_payload": {"char_count": out.get("char_count")},
        "message": (
            "Full agreement generated. They should **preview** it in the app (GET /leases/agreement/preview) "
            "or read the excerpt. When they confirm, call **save_generated_lease_agreement**."
        ),
    }


@tool
def save_generated_lease_agreement(
    owner_id: int,
    public_base_url: str = "",
) -> dict:
    """After preview confirmation: save property + lease using the **LLM-generated** agreement text, PDF, and RAG."""
    base = (public_base_url or "").strip().rstrip("/")
    try:
        detail = finalize_generated_lease_agreement(int(owner_id), public_base_url=base)
    except ValueError as e:
        return {"status": "error", "message": str(e)}
    return {
        "status": "success",
        "lease_id": detail.get("lease_id"),
        "property_id": detail.get("property_id"),
        "property_name": detail.get("property_name"),
        "summary": detail,
        "message": "Lease saved with full agreement text and PDF.",
    }


@tool
def send_lease_for_signature_docuseal(
    owner_id: int,
    lease_id: int,
    tenant_email: Optional[str] = None,
    tenant_name: Optional[str] = None,
    tenant_phone: Optional[str] = None,
    landlord_email: Optional[str] = None,
    landlord_name: Optional[str] = None,
    send_email: bool = True,
    send_sms: bool = False,
    shared_link: bool = True,
) -> dict:
    """After a lease is saved with a PDF: start DocuSeal e-signing (DocuSeal `POST /submissions/pdf`). **tenant_email** is optional: if omitted, the server uses tenant phone on the property (synthetic DocuSeal email + shared links). Optional **landlord_email** for two-party order. Returns **docuseal** (id, slug, …) plus **docuseal_signing_url** for WhatsApp. Server needs **DOCUSEAL_API_KEY**; webhook `POST /webhooks/docuseal`."""
    try:
        te = (tenant_email or "").strip() or None
        out = start_docuseal_signing_for_owner_lease(
            owner_id=int(owner_id),
            lease_id=int(lease_id),
            tenant_email=te,
            tenant_name=(tenant_name or "").strip() or None,
            tenant_phone=(tenant_phone or "").strip() or None,
            landlord_email=(landlord_email or "").strip() or None,
            landlord_name=(landlord_name or "").strip() or None,
            send_email=bool(send_email),
            send_sms=bool(send_sms),
            shared_link=bool(shared_link),
            completed_redirect_url=None,
        )
    except ValueError as e:
        return {"status": "error", "message": str(e)}
    except RuntimeError as e:
        return {"status": "error", "message": str(e)}
    return {
        "status": "success",
        **out,
        "client_action": OPEN_DOCUSEAL_SIGNING,
        "client_action_payload": {
            "lease_id": int(lease_id),
            "submitters": out.get("submitters"),
            "docuseal_signing_url": out.get("docuseal_signing_url"),
            "docuseal_submitter_embeds": out.get("docuseal_submitter_embeds"),
            "docuseal": out.get("docuseal"),
        },
        "message": (
            "DocuSeal signing started. Share **docuseal_signing_url** (or submitter **embed_src**) via WhatsApp. "
            "When fully signed, the webhook saves the PDF URL on the lease for the app to show."
        ),
    }


@tool
def finalize_lease_creation(
    owner_id: int,
    public_base_url: str = "",
) -> dict:
    """**Legacy / quick save**: creates property + lease with a **short summary** PDF (no LLM full agreement). Prefer **generate_lease_agreement** → preview → **save_generated_lease_agreement** for the full document flow."""
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

