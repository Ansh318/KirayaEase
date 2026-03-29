"""Orchestrator node: LLM with tools, routes to tool node or end."""

from langchain_core.messages import SystemMessage

from app.core.state import AgentState
from app.core.modelConfig import ModelConfigManager
from app.core.prompts import build_system_prompt
from app.agents.registry import get_all_tools

llm = ModelConfigManager("gpt-4o-mini", 0, 3).model()
llm_with_tools = llm.bind_tools(get_all_tools())


def orchestrator_node(state: AgentState):
    messages = state.get("messages", [])
    system_prompt = build_system_prompt(state)
    full_messages = [SystemMessage(content=system_prompt), *messages]
    print(
        "[AGENT][ORCHESTRATOR] "
        f"invoke llm | messages={len(messages)} | user_id={state.get('user_id')} "
        f"| scope={state.get('scope')} | lease_id={state.get('lease_id')}"
    )
    response = llm_with_tools.invoke(full_messages)
    tool_calls = getattr(response, "tool_calls", None) or []
    if tool_calls:
        names = [tc.get("name") for tc in tool_calls]
        print(f"[AGENT][ORCHESTRATOR] tool_calls={names}")
    else:
        content = getattr(response, "content", "")
        text = content if isinstance(content, str) else str(content)
        preview = text if len(text) <= 220 else text[:217] + "..."
        print(f"[AGENT][ORCHESTRATOR] final_response={preview!r}")
    return {"messages": [response]}
