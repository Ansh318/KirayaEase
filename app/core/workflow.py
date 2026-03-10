
# All tools used by the agent
from app.agents.lease.lease_tools import extract_lease_details,store_lease,inquire_lease,create_property,create_property  
from app.agents.onboarding.onboard_tools import invite_tenant
from app.agents.insights.insights_tools import fetch_rent_data
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

from app.core.state import AgentState
from app.agents.orchestrator.orchestratore_node import orchestrator_node
from app.agents.orchestrator.route_tools import should_continue

from app.agents.lease.lease_tools import (
    extract_lease_details,
    store_lease,
    inquire_lease,
    create_property,
)

from app.agents.onboarding.onboard_tools import invite_tenant
from app.agents.insights.insights_tools import fetch_rent_data


def build_graph():
    workflow = StateGraph(AgentState)

    # Orchestrator (LLM reasoning)
    workflow.add_node("orchestrator", orchestrator_node)

    # Tools
    tools = [
        extract_lease_details,
        create_property,
        store_lease,
        invite_tenant,
        fetch_rent_data,
        inquire_lease,
    ]

    tool_node = ToolNode(tools)
    workflow.add_node("tools", tool_node)

    # Entry point
    workflow.set_entry_point("orchestrator")

    # Orchestrator decides: tool or finish
    workflow.add_conditional_edges(
        "orchestrator",
        should_continue,
        {
            "tools": "tools",
            "end": END,
        },
    )

    # After tool runs → back to orchestrator
    workflow.add_edge("tools", "orchestrator")

    return workflow.compile()


app_graph = build_graph()