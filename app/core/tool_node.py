"""Custom tool node that injects agent state into tool arguments before execution."""
import json
from typing import Any, Dict, List

from langchain_core.messages import AIMessage, BaseMessage, ToolMessage

from app.core.state import AgentState
from app.agents.insights.chart_spec import build_chart_spec

# Map: tool_name -> { param_name: state_key } for injection (state_key value is injected into param_name)
STATE_INJECTION: Dict[str, Dict[str, str]] = {
    "store_lease": {"owner_id": "user_id"},
    "fetch_rent_data": {"user_id": "user_id"},
    "list_pending_rents": {"user_id": "user_id"},
    "confirm_rent_payment": {"confirmed_by": "user_id", "lease_id": "lease_id"},
    "send_rent_reminder_whatsapp": {"landlord_user_id": "user_id", "lease_id": "lease_id"},
    "set_tenant_whatsapp_phone": {"landlord_user_id": "user_id", "property_id": "property_id"},
    "get_my_properties": {"user_id": "user_id"},
    "get_my_leases": {"user_id": "user_id"},
    "create_property": {"owner_id": "user_id"},
}


def _inject_state(tool_name: str, args: Dict[str, Any], state: AgentState) -> Dict[str, Any]:
    """Merge state-derived values into tool args for tools that need user_id/owner_id/etc."""
    injection = STATE_INJECTION.get(tool_name)
    if not injection:
        return args
    out = dict(args)
    for param_name, state_key in injection.items():
        if param_name not in out or out[param_name] is None:
            val = state.get(state_key)
            if val is not None:
                out[param_name] = val
    if tool_name == "fetch_rent_data" and (not out.get("query") and state.get("user_query")):
        out["query"] = state["user_query"]
    if tool_name == "store_lease" and not out.get("pdf_path") and state.get("uploaded_lease_path"):
        out["pdf_path"] = state["uploaded_lease_path"]
    return out


def create_tool_node(tools: List[Any]):
    """Create a tool node that injects state into tool arguments before calling each tool."""
    name_to_tool = {t.name: t for t in tools}

    def tool_node(state: AgentState) -> Dict[str, List[BaseMessage]]:
        last_message = state["messages"][-1]
        if not isinstance(last_message, AIMessage) or not last_message.tool_calls:
            return {"messages": []}
        tool_messages: List[BaseMessage] = []
        state_updates: Dict[str, Any] = {}
        for tc in last_message.tool_calls:
            name = tc["name"]
            args = dict(tc.get("args") or {})
            args = _inject_state(name, args, state)
            tool = name_to_tool.get(name)
            if tool:
                try:
                    result = tool.invoke(args)
                    if isinstance(result, dict):
                        # Allow tools to write back into graph state (so the agent can continue conversationally)
                        for k in ("extracted_data", "lease_id", "property_id", "query_result", "uploaded_lease_path"):
                            if k in result and result[k] is not None:
                                state_updates[k] = result[k]
                        # When fetch_rent_data returns chartable data, attach chart spec for frontend
                        if name == "fetch_rent_data" and result.get("success") and result.get("data"):
                            chart_spec = build_chart_spec(
                                result["data"],
                                state.get("user_query") or "",
                            )
                            if chart_spec:
                                state_updates["insights_chart_spec"] = chart_spec
                    if isinstance(result, dict):
                        content = json.dumps(result, default=str)
                    else:
                        content = result if isinstance(result, str) else str(result)
                except Exception as e:
                    content = json.dumps({"error": str(e)})
            else:
                content = json.dumps({"error": f"Unknown tool: {name}"})
            tool_messages.append(
                ToolMessage(content=content, tool_call_id=tc["id"])
            )
        return {"messages": tool_messages, **state_updates}

    return tool_node
