"""
Agent chat API — Google ADK backend.

All request/response contracts are unchanged from the LangGraph version.
The only internal change is replacing `build_graph().invoke(state)` with
`run_agent(...)` from app.core.workflow (ADK InMemoryRunner).
"""
from typing import Optional, Any, List

from fastapi import APIRouter, HTTPException, Header, Body, Request

from app.core.workflow import run_agent
from app.services.chat_thread_memory import (
    append_exchange,
    build_thread_key,
    load_thread_messages,
)
from app.services.language_pref import response_language_instruction
from app.services.onboarding_services import UserService
from app.services.user_agent_memory_store import get_memory_summary

router = APIRouter()


def _get_profile(session_token: str | None):
    if not session_token:
        return {"user_id": 0}
    try:
        return UserService().get_user_by_token(session_token)
    except Exception:
        return {"user_id": 0}


@router.post("/agent-chat")
def agent_chat(
    request: Request,
    body: dict = Body(...),
    authorization: Optional[str] = Header(None),
):
    """
    Main agent chat endpoint.

    Request body (unchanged):
      message, session_id, property_id, active_scope, property_context,
      user_role, language, lease_id, landlord_lease_count, conversation_id

    Response (unchanged):
      response, action, client_action, action_payload, client_action_payload,
      payment_order_id, payment_amount, chart
    """
    message = body.get("message") or body.get("text") or ""
    session_id = body.get("session_id") or ""
    property_id = body.get("property_id")
    scope = body.get("active_scope") or body.get("scope") or "portfolio"
    property_context = body.get("property_context")
    role = body.get("user_role")
    preferred_language = body.get("language") or body.get("preferred_language")
    lease_id = body.get("lease_id")
    raw_lease_count = body.get("landlord_lease_count")

    landlord_lease_count: int | None = None
    if raw_lease_count is not None:
        try:
            landlord_lease_count = int(raw_lease_count)
        except (TypeError, ValueError):
            landlord_lease_count = None

    if lease_id is not None:
        try:
            lease_id = int(lease_id)
        except (TypeError, ValueError):
            lease_id = None

    if not message:
        raise HTTPException(status_code=400, detail="message is required")

    session_token = (authorization or "").replace("Bearer ", "").strip() or session_id
    profile = _get_profile(session_token)
    uid = int(profile.get("user_id") or 0)

    conversation_id = body.get("conversation_id") or body.get("chat_session_id")
    thread_key = build_thread_key(
        uid,
        conversation_id=conversation_id,
        anon_session_token=session_token or session_id,
    )
    prior = load_thread_messages(thread_key)
    mem = get_memory_summary(uid) if uid else ""

    # Resolve lease_id from scope when not explicitly provided
    resolved_lease_id = lease_id
    if resolved_lease_id is None and scope == "property" and property_id is not None:
        resolved_lease_id = property_id

    resolved_role = (role or "").strip().lower() or "tenant"
    if resolved_role not in ("tenant", "landlord"):
        resolved_role = "tenant"

    msg_preview = message if len(message) <= 220 else message[:217] + "..."
    print(
        "[AGENT][CHAT_IN] "
        f"user_id={uid} session_id={session_id or '-'} scope={scope} "
        f"property_id={property_id} lease_id={resolved_lease_id} "
        f"role={resolved_role} message={msg_preview!r}"
    )

    result = run_agent(
        message=message,
        user_id=uid,
        session_id=session_token or session_id or f"anon-{uid}",
        role=resolved_role,
        scope=scope,
        property_id=property_id,
        lease_id=resolved_lease_id,
        property_context=property_context,
        memory_summary=mem or None,
        response_language=response_language_instruction(message, preferred_language),
        landlord_lease_count=landlord_lease_count,
        api_public_base_url=str(request.base_url).rstrip("/"),
        prior_messages=prior,
    )

    response_text = result.get("response") or ""

    if response_text:
        append_exchange(thread_key, uid if uid else None, message, response_text)

    rt_preview = response_text if len(response_text) <= 220 else response_text[:217] + "..."
    print(
        "[AGENT][CHAT_OUT] "
        f"user_id={uid} action={result.get('client_action')} "
        f"response={rt_preview!r}"
    )

    # Response shape identical to LangGraph version
    return {
        "response": response_text,
        "action": result.get("client_action"),
        "client_action": result.get("client_action"),
        "action_payload": result.get("client_action_payload"),
        "client_action_payload": result.get("client_action_payload"),
        "payment_order_id": result.get("payment_order_id"),
        "payment_amount": result.get("payment_amount"),
        "chart": result.get("chart"),
    }
