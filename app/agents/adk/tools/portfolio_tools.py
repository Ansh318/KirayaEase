"""ADK tool wrappers for portfolio, property, analytics and memory operations."""
from __future__ import annotations

from datetime import date, datetime
from typing import Any, Dict

from app.schemas.property_manager import PropertyManager
from app.agents.insights.text2sql import Text2SQLService
from app.services.user_agent_memory_store import append_memory_fact
from app.db.sql_queries import GET_LEASES_BY_OWNER
from app.db.cloud_sql import get_connection
from psycopg2.extras import RealDictCursor


def _serialize(d: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(d)
    for k, v in out.items():
        if isinstance(v, (date, datetime)):
            out[k] = v.isoformat()
    return out


def tool_get_my_properties(user_id: int) -> dict:
    """List all properties owned by the landlord."""
    items = PropertyManager().get_properties_by_owner(user_id)
    return {"properties": items, "count": len(items)}


def tool_get_my_leases(user_id: int) -> dict:
    """List all leases for the landlord across all their properties."""
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(GET_LEASES_BY_OWNER, (user_id,))
            rows = cur.fetchall()
    finally:
        conn.close()
    out = [_serialize(dict(r)) for r in rows]
    return {"leases": out, "count": len(out)}


def tool_fetch_rent_data(query: str, user_id: int) -> dict:
    """Run natural-language analytics on rent/portfolio data (Text2SQL)."""
    service = Text2SQLService()
    return service.query(question=query, landlord_id=user_id)


def tool_remember_user_fact(user_id: int, fact: str) -> dict:
    """Persist a short, stable fact about this user for future chats."""
    ok = append_memory_fact(int(user_id), fact)
    if not ok:
        return {"status": "error", "message": "Could not save memory (missing user or DB error)"}
    return {"status": "saved", "message": "Fact saved to long-term memory."}


def tool_invite_tenant(
    landlord_user_id: int,
    lease_id: int | None = None,
    tenant_email: str | None = None,
) -> dict:
    """Onboard tenant by starting DocuSeal signing for the selected lease."""
    from app.services.docuseal_flow import start_docuseal_signing_for_owner_lease
    from app.services.lease_services import trigger_tenant_welcome_email
    from app.core.client_actions import OPEN_DOCUSEAL_SIGNING

    if lease_id is None:
        return {"status": "error", "message": "No lease selected. Pick a property or pass lease_id."}
    te = (tenant_email or "").strip()
    if not te:
        detail = PropertyManager().get_lease_detail_for_owner(int(lease_id), int(landlord_user_id))
        if detail:
            te = (detail.get("tenant_email") or "").strip()
    if not te:
        return {"status": "error", "message": "tenant_email is required for DocuSeal signing."}

    trigger_tenant_welcome_email(int(landlord_user_id), int(lease_id), tenant_email=te)
    try:
        out = start_docuseal_signing_for_owner_lease(
            owner_id=int(landlord_user_id), lease_id=int(lease_id), tenant_email=te,
            tenant_name=None, landlord_email=None, landlord_name=None,
            send_email=True, completed_redirect_url=None, shared_link=True,
        )
    except (ValueError, RuntimeError) as e:
        return {"status": "error", "message": str(e)}
    return {
        "status": "success", **out,
        "client_action": OPEN_DOCUSEAL_SIGNING,
        "client_action_payload": {
            "lease_id": int(lease_id),
            "submitters": out.get("submitters"),
            "docuseal_signing_url": out.get("docuseal_signing_url"),
        },
    }
