from typing import Optional, Any, List

from fastapi import APIRouter, HTTPException, Header, Body, Request
from langchain_core.messages import AIMessage, HumanMessage

from app.core.workflow import build_graph
from app.services.chat_thread_memory import (
    append_exchange,
    build_thread_key,
    load_thread_messages,
)
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


def _extract_final_assistant_text(messages) -> str:
    """Last assistant reply without tool calls (final natural-language answer)."""
    for msg in reversed(messages or []):
        if isinstance(msg, AIMessage):
            if getattr(msg, "tool_calls", None):
                continue
            c = getattr(msg, "content", None)
            if c is not None and str(c).strip():
                return c if isinstance(c, str) else str(c)
    return ""


def build_initial_state(
    message: str,
    session_id: str = "",
    authorization: Optional[str] = None,
    uploaded_lease_path: Optional[str] = None,
    property_id: Optional[int] = None,
    scope: Optional[str] = None,
    property_context: Optional[dict[str, Any]] = None,
    role: Optional[str] = None,
    lease_id: Optional[int] = None,
    api_public_base_url: Optional[str] = None,
    prior_messages: Optional[List[Any]] = None,
    memory_summary: Optional[str] = None,
):
    session_token = (authorization or "").replace("Bearer ", "").strip() or session_id
    profile = _get_profile(session_token)
    # Role is not stored in DB anymore; use request body (user_role) or default
    resolved_role = (role or "").strip().lower() or "tenant"
    if resolved_role not in ("tenant", "landlord"):
        resolved_role = "tenant"
    msgs: List[Any] = []
    if prior_messages:
        msgs.extend(prior_messages)
    msgs.append(HumanMessage(content=message))
    state = {
        "messages": msgs,
        "user_query": message,
        "user_id": profile.get("user_id", 0),
        "role": resolved_role,
        "session_id": session_token,
        "query_result": None,
        "uploaded_lease_path": uploaded_lease_path,
    }
    if memory_summary:
        state["memory_summary"] = memory_summary
    if scope is not None:
        state["scope"] = scope
    if property_id is not None:
        state["property_id"] = property_id
    if property_context is not None:
        state["property_context"] = property_context
    # Lease ID from frontend (property/lease selector); use for confirm_rent_payment
    if lease_id is not None:
        state["lease_id"] = lease_id
    elif scope == "property" and state.get("property_id") is not None:
        # Frontend often sends lease_id as property_id when one lease is selected
        state["lease_id"] = state["property_id"]
    if api_public_base_url:
        state["api_public_base_url"] = str(api_public_base_url).rstrip("/")
    return state


@router.post("/agent-chat")
def agent_chat(
    request: Request,
    body: dict = Body(...),
    authorization: Optional[str] = Header(None),
):
    message = body.get("message") or body.get("text") or ""
    session_id = body.get("session_id") or ""
    property_id = body.get("property_id")
    scope = body.get("active_scope") or body.get("scope") or "portfolio"
    property_context = body.get("property_context")
    role = body.get("user_role")
    lease_id = body.get("lease_id")
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

    state = build_initial_state(
        message=message,
        session_id=session_id,
        authorization=authorization,
        property_id=property_id,
        scope=scope,
        property_context=property_context,
        role=role,
        lease_id=lease_id,
        api_public_base_url=str(request.base_url).rstrip("/"),
        prior_messages=prior,
        memory_summary=mem or None,
    )
    result = build_graph().invoke(state)
    # Frontend expects "response" with the assistant reply text
    messages = result.get("messages") or []
    response_text = ""
    if messages:
        response_text = _extract_final_assistant_text(messages)
        if not response_text:
            last = messages[-1]
            if hasattr(last, "content") and last.content:
                response_text = (
                    last.content if isinstance(last.content, str) else str(last.content)
                )
    if response_text:
        append_exchange(thread_key, uid if uid else None, message, response_text)
    return {
        "response": response_text,
        "payment_order_id": result.get("payment_order_id"),
        "payment_amount": result.get("payment_amount"),
        "chart": result.get("insights_chart_spec"),
    }