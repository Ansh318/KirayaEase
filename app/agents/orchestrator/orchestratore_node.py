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
    response = llm_with_tools.invoke(full_messages)
    return {"messages": [response]}
