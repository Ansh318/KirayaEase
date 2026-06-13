"""ADK tool wrappers for rent, payment and reminder operations."""
from __future__ import annotations

from typing import Optional

from app.schemas.property_manager import PropertyManager
from app.services.rent_service import (
    confirm_rent_payment as do_confirm,
    list_pending_rents as do_list_pending,
)
from app.services.rent_reminder_service import send_rent_reminder_for_lease


def tool_list_pending_rents(user_id: int) -> dict:
    """List all pending rent confirmations for the landlord."""
    items = do_list_pending(user_id)
    return {"pending": items, "count": len(items)}


def tool_confirm_rent_payment(lease_id: int, month: str, confirmed_by: int) -> dict:
    """Mark a rent payment as confirmed. month = YYYY-MM-01."""
    return do_confirm(lease_id, month, confirmed_by)


def tool_send_rent_reminder_whatsapp(
    landlord_user_id: int,
    lease_id: int,
    template_name: Optional[str] = None,
) -> dict:
    """Queue a WhatsApp rent reminder to the tenant for this lease."""
    return send_rent_reminder_for_lease(landlord_user_id, lease_id, template_name=template_name)


def tool_set_tenant_whatsapp_phone(
    landlord_user_id: int,
    property_id: int,
    phone_e164: str,
) -> dict:
    """Save the tenant's WhatsApp number for a property."""
    try:
        updated = PropertyManager().update_tenant_phone(
            owner_id=landlord_user_id, property_id=property_id, tenant_phone=phone_e164,
        )
        return {"status": "success", "property_id": property_id, "property": updated}
    except ValueError as e:
        return {"status": "error", "message": str(e)}
