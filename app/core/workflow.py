"""LangGraph workflow: single orchestrator agent with multiple tools."""
from langgraph.graph import StateGraph, END

from app.core.state import AgentState
from app.core.tool_node import create_tool_node
from app.agents.orchestrator.orchestratore_node import orchestrator_node
from app.agents.orchestrator.route_tools import should_continue
from app.agents.registry import get_all_tools


def build_graph():
    workflow = StateGraph(AgentState)
    tools = get_all_tools()

    workflow.add_node("orchestrator", orchestrator_node)
    workflow.add_node("tools", create_tool_node(tools))

    workflow.set_entry_point("orchestrator")
    workflow.add_conditional_edges("orchestrator", should_continue, {"tools": "tools", "end": END})
    workflow.add_edge("tools", "orchestrator")

    return workflow.compile()


app_graph = build_graph()
