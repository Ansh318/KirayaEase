import tempfile
import os
from typing import Optional

from fastapi import APIRouter, File, Form, Header, HTTPException, UploadFile, Request, Query
from fastapi.responses import Response

from app.db.sql_queries import GET_USER_FROM_SESSION
from app.db.sql_queries import CHECK_LEASE_OWNERSHIP, GET_LEASE_FILE_FOR_OWNER, UPSERT_LEASE_FILE
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.schemas.property_manager import PropertyManager
from app.services.lease_extractor import extract_from_pdf, read_pdf_text
import psycopg2
from psycopg2.extras import RealDictCursor

from app.services.lease_services import LeaseService

router = APIRouter()

_UPLOADS_DIR = os.path.abspath(os.path.join(os.getcwd(), "uploads", "leases"))
os.makedirs(_UPLOADS_DIR, exist_ok=True)


def _get_user_id_from_session(session_token: str) -> Optional[int]:
    conn = psycopg2.connect(os.getenv("DATABASE_URL"))
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_USER_FROM_SESSION, (session_token.strip(),))
            row = cur.fetchone()
            return int(row["user_id"]) if row else None
    finally:
        conn.close()


def _build_pdf_url(request: Request, lease_id: int) -> str:
    # Always prefer a stable API URL over filesystem paths (Heroku dynos are ephemeral).
    return str(request.base_url).rstrip("/") + f"/leases/{lease_id}/pdf"


def _extracted_to_frontend_fields(data: dict) -> dict:
    """Map extractor output to frontend field names (LeaseData.fromExtractedFields)."""
    name = data.get("name") or ""
    addr = data.get("address_line1") or ""
    city = data.get("city") or ""
    property_address = name or (f"{addr}, {city}".strip(", ") if (addr or city) else "Unknown Property")
    return {
        "property_address": property_address,
        "name": name,
        "tenant_name": data.get("tenant_name"),
        "address_line1": data.get("address_line1"),
        "city": data.get("city"),
        "state": data.get("state"),
        "postal_code": data.get("postal_code"),
        "property_pincode": data.get("postal_code"),
        "lease_start": data.get("lease_start"),
        "lease_end": data.get("lease_end"),
        "start_date": data.get("lease_start"),
        "end_date": data.get("lease_end"),
        "monthly_rent": data.get("monthly_rent"),
        "rent_amount_inr": data.get("monthly_rent"),
        "security_deposit": data.get("security_deposit"),
        "lock_in_period": data.get("lock_in_period"),
        "due_day": data.get("due_day"),
        "landlord_name": None,
    }


@router.post("/extract-lease-content")
async def extract_lease_content(
    request: Request,
    file: UploadFile = File(...),
    query: Optional[str] = Form(None),
    authorization: Optional[str] = Header(None),
):
    """Extract lease data from uploaded PDF. If authenticated, also creates property + lease and indexes for RAG."""
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="A PDF file is required")
    session_token = (authorization or "").replace("Bearer ", "").strip()
    user_id = _get_user_id_from_session(session_token) if session_token else None

    with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
        try:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Failed to save file: {e}")

    try:
        data = extract_from_pdf(tmp_path)
        fields = _extracted_to_frontend_fields(data)
        agent_response = None
        # If key fields are missing, ask the user to clarify BEFORE storing.
        missing: list[str] = []
        if not data.get("lease_start"):
            missing.append("start date (lease_start)")
        if not data.get("lease_end"):
            missing.append("end date (lease_end)")
        if data.get("monthly_rent") in (None, "", 0):
            missing.append("monthly rent (monthly_rent)")
        if data.get("due_day") in (None, "", 0):
            missing.append("rent due day (due_day)")
        if (data.get("name") in (None, "") and not any([data.get("address_line1"), data.get("city"), data.get("state"), data.get("postal_code")])):
            missing.append("property address / name")

        if user_id and not missing:
            name = data.get("name") or "Property"
            # Avoid duplicate: same property/lease already uploaded?
            existing = PropertyManager().find_existing_lease_for_property(
                owner_id=user_id,
                name=data.get("name"),
                address_line1=data.get("address_line1"),
                postal_code=data.get("postal_code"),
            )
            if existing:
                lease_id_existing = existing.get("lease_id")
                agent_response = (
                    "This lease has already been uploaded. "
                    "You can view it in the **Leases** section (Settings → Lease manager)."
                )
                return {
                    "fields": fields,
                    "agent_response": agent_response,
                    "missing_fields": missing,
                    "duplicate": True,
                    "lease_id": lease_id_existing,
                }
            prop = PropertyManager().add_property(
                owner_id=user_id,
                name=name,
                tenant_name=data.get("tenant_name"),
                address_line1=data.get("address_line1"),
                city=data.get("city"),
                state=data.get("state"),
                postal_code=data.get("postal_code"),
            )
            property_id = prop.get("id")
            if property_id:
                lease = PropertyManager().add_lease(
                    property_id=property_id,
                    lease_start=str(data["lease_start"]),
                    lease_end=str(data["lease_end"]),
                    monthly_rent=int(data.get("monthly_rent") or 0),
                    security_deposit=int(data["security_deposit"]) if data.get("security_deposit") is not None else None,
                    lock_in_period=int(data["lock_in_period"]) if data.get("lock_in_period") is not None else None,
                    due_day=int(data.get("due_day") or 1),
                )
                lease_id = lease.get("id")
                if lease_id:
                    # Persist the PDF into Postgres (durable on Heroku) and expose a stable URL.
                    try:
                        conn = psycopg2.connect(os.getenv("DATABASE_URL"))
                        try:
                            with conn:
                                with conn.cursor() as cur:
                                    cur.execute(
                                        UPSERT_LEASE_FILE,
                                        (
                                            int(lease_id),
                                            psycopg2.Binary(content),
                                            file.content_type or "application/pdf",
                                        ),
                                    )
                        finally:
                            conn.close()
                        pdf_url = _build_pdf_url(request, int(lease_id))
                        PropertyManager().set_lease_pdf_url(int(lease_id), pdf_url)
                        fields["pdf_url"] = pdf_url
                    except Exception:
                        # If PDF persistence fails, still keep the lease; user can re-upload.
                        pass
                    try:
                        raw_text = read_pdf_text(tmp_path)
                        processor = LeaseDocumentProcessor()
                        processor.processs_lease(lease_id=lease_id, landlord_id=user_id, text=raw_text)
                    except Exception:
                        pass
                    agent_response = (
                        f"Lease stored successfully. Property: {name}, Lease ID: {lease_id}. "
                        f"Rent: ₹{data.get('monthly_rent', 'N/A')}/month. "
                        "You can ask questions about this lease or view it in Leases."
                    )
        if agent_response is None:
            if missing:
                missing_text = "\n".join([f"- {m}" for m in missing])
                agent_response = (
                    "I extracted your lease, but I'm missing a few key details before I can save it.\n\n"
                    f"Please reply with:\n{missing_text}\n\n"
                    "Once you share those, I’ll store the lease and set up your rent tracking."
                )
            else:
                agent_response = (
                    "Lease details extracted. "
                    f"Property: {fields.get('property_address', 'N/A')}, "
                    f"Rent: ₹{fields.get('rent_amount_inr', 'N/A')}/month, "
                    f"Tenant: {fields.get('tenant_name') or 'N/A'}. "
                    + ("Sign in and upload again to save this lease to your portfolio." if not user_id else "")
                )
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass

    return {"fields": fields, "agent_response": agent_response, "missing_fields": missing}


@router.get("/leases/{lease_id}/pdf")
def get_lease_pdf(
    lease_id: int,
    authorization: Optional[str] = Header(None),
    session: Optional[str] = Query(None),
):
    """Return the stored lease PDF for the authenticated landlord."""
    session_token = ((authorization or "").replace("Bearer ", "").strip()) or (session or "").strip()
    if not session_token:
        raise HTTPException(status_code=401, detail="Missing authorization")
    owner_id = _get_user_id_from_session(session_token)
    if owner_id is None:
        raise HTTPException(status_code=401, detail="Invalid or expired session")

    conn = psycopg2.connect(os.getenv("DATABASE_URL"))
    try:
        with conn.cursor() as cur:
            cur.execute(GET_LEASE_FILE_FOR_OWNER, (lease_id, owner_id))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="PDF not found for this lease")
            content, content_type = row[0], row[1]
            return Response(content=content, media_type=content_type, headers={"Content-Disposition": "inline; filename=lease.pdf"})
    finally:
        conn.close()


@router.delete("/leases/{lease_id}")
def delete_lease(lease_id: int, authorization: str = Header(...)):
    """Delete a lease owned by the authenticated landlord."""
    session_token = authorization.replace("Bearer ", "").strip()
    if not session_token:
        raise HTTPException(status_code=401, detail="Missing authorization")
    owner_id = _get_user_id_from_session(session_token)
    if owner_id is None:
        raise HTTPException(status_code=401, detail="Invalid or expired session")

    conn = psycopg2.connect(os.getenv("DATABASE_URL"))
    try:
        with conn.cursor() as cur:
            cur.execute(CHECK_LEASE_OWNERSHIP, (lease_id, owner_id))
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Lease not found")
        PropertyManager().delete_lease(lease_id)
        return {"ok": True}
    finally:
        conn.close()


@router.get("/leases")
def get_leases(authorization: str = Header(...)):
    """Return all leases for the authenticated landlord (owner)."""
    session_token = authorization.replace("Bearer ", "").strip()
    if not session_token:
        raise HTTPException(status_code=401, detail="Missing authorization")
    return LeaseService().get_leases_for_owner(session_token)


@router.get("/properties")
def get_properties(authorization: str = Header(...)):
    """Return all properties for the authenticated landlord (owner)."""
    session_token = authorization.replace("Bearer ", "").strip()
    if not session_token:
        raise HTTPException(status_code=401, detail="Missing authorization")
    return LeaseService().get_properties_for_owner(session_token)


@router.get("/payments")
def get_payments(authorization: str = Header(...)):
    """Return all rent confirmations (payments) for the authenticated landlord."""
    session_token = authorization.replace("Bearer ", "").strip()
    if not session_token:
        raise HTTPException(status_code=401, detail="Missing authorization")
    return LeaseService().get_payments_for_owner(session_token)
