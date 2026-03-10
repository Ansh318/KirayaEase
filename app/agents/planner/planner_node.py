from app.core.state import AgentState
from langchain_core.messages import HumanMessage, SystemMessage
from app.core.modelConfig import ModelConfigManager
import json

llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()

def planner_node(state: AgentState):

    user_message = state["messages"][-1].content

    system_prompt = """
You are a workflow planner for an AI property management system.

Your job is to create a step-by-step plan using available tools.

Available tools:
- extract_lease_details
- create_property
- add_lease
- invite_tenant
- fetch_rent_data
- inquire_lease
- store_lease

Return ONLY a JSON array of tool names in execution order.

Example:
["extract_lease_details", "create_property", "add_lease", "invite_tenant"]
"""

    response = llm.invoke(
        [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_message),
        ]
    )

    try:
        plan = json.loads(response.content)
    except Exception:
        plan = []

    return {
        "plan": plan,
        "current_step": 0
    }