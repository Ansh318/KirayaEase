"""
ADK workflow entry-point — replaces LangGraph StateGraph.

The root_agent is the single orchestrator. Callers use `run_agent()` to
invoke it via the ADK InMemoryRunner, which returns a structured result
compatible with the existing agent_chat API response shape.
"""
from __future__ import annotations

import asyncio
import logging
import uuid
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# ── Lazy import of ADK to keep startup fast in non-agent contexts ────────────
_runner = None


def _get_runner():
    global _runner
    if _runner is None:
        import os
        # Set Gemini API key for ADK before importing agents
        api_key = os.getenv("GOOGLE_API_KEY")
        if api_key:
            os.environ["GOOGLE_API_KEY"] = api_key
        from google.adk.runners import InMemoryRunner
        from app.agents.adk.root_agent import root_agent
        _runner = InMemoryRunner(agent=root_agent, app_name="KirayaEase")
    return _runner


def run_agent(
    *,
    message: str,
    user_id: int,
    session_id: str,
    role: str = "landlord",
    scope: str = "portfolio",
    property_id: Optional[int] = None,
    lease_id: Optional[int] = None,
    property_context: Optional[Dict[str, Any]] = None,
    memory_summary: Optional[str] = None,
    response_language: Optional[str] = None,
    landlord_lease_count: Optional[int] = None,
    api_public_base_url: str = "",
    prior_messages: Optional[List[Any]] = None,
) -> Dict[str, Any]:
    """
    Invoke the ADK root agent synchronously.

    Returns a dict shaped like the old LangGraph result:
      {
        "response": str,
        "client_action": str | None,
        "client_action_payload": dict | None,
        "chart": dict | None,
        "payment_order_id": str | None,
        "payment_amount": int | None,
      }
    """
    # Build enriched message with injected context so the root agent has
    # the same information the old system prompt injection provided.
    context_lines: List[str] = []
    if user_id:
        context_lines.append(f"[Context] landlord_user_id={user_id}")
    if scope:
        context_lines.append(f"[Context] scope={scope}")
    if property_id is not None:
        context_lines.append(f"[Context] property_id={property_id}")
    if lease_id is not None:
        context_lines.append(f"[Context] lease_id={lease_id}")
    if property_context:
        name = property_context.get("name") or property_context.get("property_name") or ""
        te = (property_context.get("tenant_email") or "").strip()
        if name:
            context_lines.append(f"[Context] property_name={name}")
        if te:
            context_lines.append(f"[Context] tenant_email_on_file={te}")
    if memory_summary:
        context_lines.append(f"[Memory] {memory_summary}")
    if response_language:
        context_lines.append(f"[Language] {response_language}")
    if landlord_lease_count is not None:
        context_lines.append(f"[Context] landlord_lease_count={landlord_lease_count}")
    if api_public_base_url:
        context_lines.append(f"[Context] api_public_base_url={api_public_base_url}")

    enriched = message
    if context_lines:
        prefix = "\n".join(context_lines)
        enriched = f"{prefix}\n\n{message}"

    runner = _get_runner()

    # ADK sessions are scoped per user
    adk_session_id = session_id or f"user-{user_id}-{uuid.uuid4().hex[:8]}"

    async def _invoke() -> Dict[str, Any]:
        from google.adk.sessions import InMemorySessionService
        from google.genai import types as genai_types

        session_service: InMemorySessionService = runner.session_service  # type: ignore[attr-defined]

        # Ensure session exists
        try:
            session = await session_service.get_session(
                app_name="KirayaEase",
                user_id=str(user_id),
                session_id=adk_session_id,
            )
        except Exception:
            session = None

        if session is None:
            session = await session_service.create_session(
                app_name="KirayaEase",
                user_id=str(user_id),
                session_id=adk_session_id,
            )

        # Run the agent
        response_text = ""
        client_action = None
        client_action_payload = None
        chart = None

        async for event in runner.run_async(
            user_id=str(user_id),
            session_id=adk_session_id,
            new_message=genai_types.Content(
                role="user",
                parts=[genai_types.Part(text=enriched)],
            ),
        ):
            # Extract final text response
            if event.is_final_response():
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        if hasattr(part, "text") and part.text:
                            response_text += part.text

            # Extract tool outputs embedded in events for client_action/chart
            if hasattr(event, "actions") and event.actions:
                for action in event.actions:
                    if hasattr(action, "tool_response") and action.tool_response:
                        payload = action.tool_response
                        if isinstance(payload, dict):
                            if payload.get("client_action") and not client_action:
                                client_action = payload["client_action"]
                                client_action_payload = payload.get("client_action_payload")
                            if payload.get("insights_chart_spec") and not chart:
                                chart = payload["insights_chart_spec"]
                            if payload.get("chart") and not chart:
                                chart = payload["chart"]

        return {
            "response": response_text.strip(),
            "client_action": client_action,
            "client_action_payload": client_action_payload,
            "chart": chart,
            "payment_order_id": None,
            "payment_amount": None,
        }

    # Run async in a sync context
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            # In an existing event loop (e.g. tests), use nest_asyncio
            import nest_asyncio
            nest_asyncio.apply()
            return loop.run_until_complete(_invoke())
        else:
            return loop.run_until_complete(_invoke())
    except Exception as exc:
        logger.exception("[ADK] Agent invocation failed: %s", exc)
        return {
            "response": "I encountered an error processing your request. Please try again.",
            "client_action": None,
            "client_action_payload": None,
            "chart": None,
            "payment_order_id": None,
            "payment_amount": None,
        }
