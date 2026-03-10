from fastapi import APIRouter, Header, HTTPException

from app.services.lease_services import LeaseService

router = APIRouter()


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
