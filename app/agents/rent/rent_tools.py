"""Rent confirmation and pending-rent tools for the agent."""
from langchain_core.tools import tool

from app.services.rent_service import confirm_rent_payment as do_confirm, list_pending_rents as do_list_pending


@tool
def list_pending_rents(user_id: int) -> dict:
    """List all pending rent confirmations for the landlord. Use the landlord's user_id (current user)."""
    items = do_list_pending(user_id)
    return {"pending": items, "count": len(items)}


@tool
def confirm_rent_payment(lease_id: int, month: str, confirmed_by: int) -> dict:
    """Mark a rent payment as confirmed for a lease and month. month must be YYYY-MM-01 (e.g. 2026-03-01 for March 2026). confirmed_by is the landlord's user_id."""
    return do_confirm(lease_id, month, confirmed_by)
