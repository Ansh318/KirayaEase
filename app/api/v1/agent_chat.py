import tempfile
import os
from typing import Optional, Any

from fastapi import APIRouter, HTTPException, Header, File, UploadFile, Form, Body
from app.core.workflow import build_graph
from app.services.onboarding_services import UserService

router = APIRouter()


def _get_profile(session_token: str | None):
    if not session_token:
        return {"user_id": 0, "role": "tenant"}
    try:
        return UserService().get_user_by_token(session_token)
    except Exception:
        return {"user_id": 0, "role": "tenant"}


def build_initial_state(
    message: str,
    session_id: str = "",
    authorization: Optional[str] = None,
    uploaded_lease_path: Optional[str] = None,
    property_id: Optional[int] = None,
    scope: Optional[str] = None,
    property_context: Optional[dict[str, Any]] = None,
):
    session_token = (authorization or "").replace("Bearer ", "").strip() or session_id
    profile = _get_profile(session_token)
    state = {
        "messages": [{"role": "user", "content": message}],
        "user_id": profile["user_id"],
        "role": profile["role"],
        "session_id": session_token,
        "intent": None,
        "query_result": None,
        "uploaded_lease_path": uploaded_lease_path,
    }
    if scope is not None:
        state["scope"] = scope
    if property_id is not None:
        state["property_id"] = property_id
    if property_context is not None:
        state["property_context"] = property_context
    return state


@router.post("/agent-chat")
def agent_chat(
    body: dict = Body(...),
    authorization: Optional[str] = Header(None),
):
    message = body.get("message") or body.get("text") or ""
    session_id = body.get("session_id") or ""
    session_token = (authorization or "").replace("Bearer ", "").strip() or session_id
    property_id = body.get("property_id")
    scope = body.get("active_scope") or body.get("scope") or "portfolio"
    property_context = body.get("property_context")

    if not message:
        raise HTTPException(status_code=400, detail="message is required")

    state = build_initial_state(
        message=message,
        session_id=session_id,
        authorization=authorization,
        property_id=property_id,
        scope=scope,
        property_context=property_context,
    )
    result = build_graph().invoke(state)
    # Frontend expects "response" with the assistant reply text
    messages = result.get("messages") or []
    response_text = ""
    if messages:
        last = messages[-1]
        if hasattr(last, "content") and last.content:
            response_text = last.content if isinstance(last.content, str) else str(last.content)
    return {
        "response": response_text,
        "payment_order_id": result.get("payment_order_id"),
        "payment_amount": result.get("payment_amount"),
    }