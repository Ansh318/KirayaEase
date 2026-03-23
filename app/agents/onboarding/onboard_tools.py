from typing import Optional

from langchain_core.tools import tool

from app.services.rent_reminder_service import send_rent_reminder_for_lease


@tool
def invite_tenant(landlord_user_id: int, lease_id: Optional[int] = None) -> dict:
    """
    Send the tenant a WhatsApp message using the **kirayaeaseonboarding** template (same as rent
    reminders: tenant name, amount, property, due date — filled from the database).

    When the landlord has a **property selected** in the app, **lease_id** is injected automatically.
    **Do not ask for the phone number** if this tool can run — use **get_my_leases** only if
    lease_id is missing (portfolio context).
    """
    if lease_id is None:
        return {
            "status": "error",
            "message": (
                "No lease selected. Ask the landlord to pick a property in the app header, "
                "or call get_my_leases and use the right lease_id, then call invite_tenant again."
            ),
        }
    return send_rent_reminder_for_lease(int(landlord_user_id), int(lease_id))
