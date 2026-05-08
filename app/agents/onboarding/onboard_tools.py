from typing import Optional

from langchain_core.tools import tool

from app.core.client_actions import OPEN_DOCUSEAL_SIGNING
from app.schemas.property_manager import PropertyManager
from app.services.docuseal_flow import start_docuseal_signing_for_owner_lease
from app.services.lease_services import trigger_tenant_welcome_email


@tool
def invite_tenant(
    landlord_user_id: int,
    lease_id: Optional[int] = None,
    tenant_email: Optional[str] = None,
) -> dict:
    """
    Onboard tenant by starting DocuSeal signing for the selected lease.

    Requires **tenant_email** only — never ask for phone for this flow.
    """
    if lease_id is None:
        return {
            "status": "error",
            "message": (
                "No lease selected. Ask the landlord to pick a property in the app header, "
                "or call get_my_leases and use the correct lease_id, then call invite_tenant again."
            ),
        }
    te = (tenant_email or "").strip()
    if not te:
        pm = PropertyManager()
        detail = pm.get_lease_detail_for_owner(int(lease_id), int(landlord_user_id))
        if detail:
            te = (detail.get("tenant_email") or "").strip()
    if not te:
        return {
            "status": "error",
            "message": (
                "tenant_email is required for DocuSeal. Add the tenant's email in Properties / lease form, "
                "or pass tenant_email to this tool."
            ),
        }
    welcome_email_result = trigger_tenant_welcome_email(
        int(landlord_user_id),
        int(lease_id),
        tenant_email=te,
    )
    try:
        out = start_docuseal_signing_for_owner_lease(
            owner_id=int(landlord_user_id),
            lease_id=int(lease_id),
            tenant_email=te,
            tenant_name=None,
            landlord_email=None,
            landlord_name=None,
            send_email=True,
            completed_redirect_url=None,
            shared_link=True,
        )
    except ValueError as e:
        return {"status": "error", "message": str(e)}
    except RuntimeError as e:
        return {"status": "error", "message": str(e)}
    return {
        "status": "success",
        **out,
        "welcome_email": welcome_email_result,
        "client_action": OPEN_DOCUSEAL_SIGNING,
        "client_action_payload": {
            "lease_id": int(lease_id),
            "submitters": out.get("submitters"),
            "docuseal_signing_url": out.get("docuseal_signing_url"),
            "docuseal_submitter_embeds": out.get("docuseal_submitter_embeds"),
            "docuseal": out.get("docuseal"),
        },
        "message": (
            "Welcome email sent (if tenant email is available), then tenant onboarding started with DocuSeal. "
            "Share docuseal_signing_url (or embed_src) with the tenant. "
            "The lease card will show Signed when webhook completion arrives."
        ),
    }
