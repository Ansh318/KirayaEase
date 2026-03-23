"""Rent confirmation and pending-rent tools for the agent."""
from langchain_core.tools import tool

from app.services.rent_service import confirm_rent_payment as do_confirm, list_pending_rents as do_list_pending
from app.services.rent_reminder_service import send_rent_reminder_for_lease
from app.schemas.property_manager import PropertyManager


@tool
def list_pending_rents(user_id: int) -> dict:
    """List all pending rent confirmations for the landlord. Use the landlord's user_id (current user)."""
    items = do_list_pending(user_id)
    return {"pending": items, "count": len(items)}


@tool
def confirm_rent_payment(lease_id: int, month: str, confirmed_by: int) -> dict:
    """Mark a rent payment as confirmed for a lease and month. Use when the user says rent was paid for [month], tenant paid for [month], or similar. month must be YYYY-MM-01 (e.g. 2026-03-01 for March 2026). When a single property/lease is selected in context, lease_id is injected; otherwise pass the lease_id from get_my_leases or list_pending_rents. confirmed_by is the landlord's user_id (injected)."""
    return do_confirm(lease_id, month, confirmed_by)


@tool
def send_rent_reminder_whatsapp(
    landlord_user_id: int,
    lease_id: int,
    template_name: str | None = None,
) -> dict:
    """Queue a WhatsApp rent reminder to the tenant for this lease (API-accepted; delivery is async). Uses Meta template ``kirayaeaseonboarding`` with body vars filled from the DB (tenant name, rent amount, property name, next due date). ALWAYS try this first when the user asks to remind the tenant - the number may already be on file. If it returns 'No tenant WhatsApp on file', ask for the number and use set_tenant_whatsapp_phone, then call this again. When one property is selected, lease_id is injected; otherwise use get_my_leases to pick lease_id. Optional template_name overrides the default."""
    return send_rent_reminder_for_lease(
        landlord_user_id,
        lease_id,
        template_name=template_name,
    )


@tool
def set_tenant_whatsapp_phone(
    landlord_user_id: int,
    property_id: int,
    phone_e164: str,
) -> dict:
    """Save the tenant's WhatsApp number for a property (country code + number, digits only or with +). Use when the landlord gives a tenant's number or before sending a reminder if no number is on file. When a single property is selected, property_id may be injected from context."""
    try:
        updated = PropertyManager().update_tenant_phone(
            owner_id=landlord_user_id,
            property_id=property_id,
            tenant_phone=phone_e164,
        )
        return {"status": "success", "property_id": property_id, "property": updated}
    except ValueError as e:
        return {"status": "error", "message": str(e)}
