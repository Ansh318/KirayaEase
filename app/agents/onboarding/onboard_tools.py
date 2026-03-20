from langchain_core.tools import tool

from app.services.whatsapp_service import DEFAULT_TEMPLATE_NAME, send_whatsapp_template


@tool
def invite_tenant(phone_number: str):
    """Send tenant an invite to onboard onto their apartment via WhatsApp (Meta template)."""
    return send_whatsapp_template(phone_number, DEFAULT_TEMPLATE_NAME)


