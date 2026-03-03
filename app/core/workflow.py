from langgraph.graph import StateGraph, END

from app.core.state import AgentState

# from agents.router import router_node, route_by_intent
from app.agents.lease.lease_agent import lease_agent
from app.agents.onboarding.onboard_agent import onboarding_agent
from app.agents.router.router_node import router_node, route_by_intent
# from agents.reminders.reminder_agent import reminder_agent
# from agents.payments.payment_agent import payments_agent
# from agents.insights.insights_agent import insights_agent


def build_graph():
    workflow = StateGraph(AgentState)

    # --- Add Nodes ---
    workflow.add_node("router", router_node)
    workflow.add_node("lease_agent", lease_agent)
    workflow.add_node("onboard_agent", onboarding_agent)
    # workflow.add_node("reminder_agent", reminder_agent)
    # workflow.add_node("payments_agent", payments_agent)
    # workflow.add_node("insights_agent", insights_agent)

    # --- Entry ---
    workflow.set_entry_point("router")

    # --- Routing ---
    workflow.add_conditional_edges(
        "router",
        route_by_intent,
        {
            "lease": "lease_agent",
            "onboarding": "onboard_agent",
        },
    )

    # --- Exit Edges ---
    workflow.add_edge("lease_agent", END)
    workflow.add_edge("onboard_agent", END)

    return workflow.compile()


# Compile once
app_graph = build_graph()