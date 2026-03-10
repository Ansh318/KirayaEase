from langchain_core.messages import AIMessage, SystemMessage
from app.core.state import AgentState
from app.core.modelConfig import ModelConfigManager
from app.agents.lease.lease_tools import extract_lease_details,create_property,store_lease,inquire_lease
from app.agents.onboarding.onboard_tools import invite_tenant
from app.agents.insights.insights_tools import fetch_rent_data
llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()

llm_with_tools = llm.bind_tools([
    extract_lease_details,
    create_property,
    store_lease,
    invite_tenant,
    fetch_rent_data,
    inquire_lease
])
def _build_system_prompt(state: AgentState) -> str:
    base = """
You are KirayaEase, an AI property management assistant.

You help landlords manage properties, leases, and tenants.

You can use tools to:
- extract lease details
- create properties
- add leases
- invite tenants
- fetch rent insights

Guidelines:
- Speak conversationally and professionally.
- When you need to perform an action, explain briefly what you are doing.
- Then call the appropriate tool.
- After a tool result, explain the outcome clearly to the user.
"""
    scope = state.get("scope") or "portfolio"
    property_id = state.get("property_id")
    property_context = state.get("property_context") or {}

    if scope == "property" and property_id is not None:
        name = property_context.get("name") or property_context.get("property_name") or f"Property #{property_id}"
        base += f"""

Current context: The landlord is asking about a SPECIFIC PROPERTY.
- Property ID: {property_id}
- Property name: {name}
Answer questions in the context of this property only (leases, rent, tenant for this property).
"""
    else:
        base += """

Current context: The landlord is asking at PORTFOLIO level (all properties).
Answer questions across their entire portfolio (e.g. total rent, all tenants, comparison across properties).
"""
    return base.strip()


def orchestrator_node(state: AgentState):

    messages = state.get("messages", [])
    system_prompt = _build_system_prompt(state)

    full_messages = [
        SystemMessage(content=system_prompt),
        *messages
    ]

    response = llm_with_tools.invoke(full_messages)

    return {
        "messages": messages + [response]
    }