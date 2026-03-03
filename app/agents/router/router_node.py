from app.core.state import AgentState
from langchain_core.messages import HumanMessage
from app.core.modelConfig import ModelConfigManager

llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()

def router_node(state: AgentState) -> AgentState:
    """Route based on the user's intent derived from the query.

    Uses the LLM to classify the incoming `user_query` into one of two
    intents:
    - "lease"       → handled by `lease_agent`
    - "onboarding"  → handled by `onboarding_agent`

    It writes the chosen intent into the graph state so that
    `route_by_intent` can send the flow to the right node.
    """
    user_query = state.get("user_query", "")

    if not user_query:
        # Fallback: if no query, keep existing intent or default
        intent = state.get("intent", "onboarding")
    else:
        classification_prompt = (
            "You are an intent classifier for a property management assistant.\n"
            "Decide whether the user query is about lease-related tasks "
            "(like extracting details, signing, stamping, or storing a lease) "
            "or about general onboarding tasks (like inviting tenants, "
            "creating a property, or account setup).\n"
            "Respond with exactly one word: 'lease' or 'onboarding'.\n\n"
            f"User query: {user_query}"
        )

        response = llm.invoke([HumanMessage(content=classification_prompt)])
        intent = getattr(response, "content", "").strip().lower()

        if intent not in ("lease", "onboarding"):
            intent = "onboarding"

    return {"intent": intent}


def route_by_intent(state: AgentState):
    return state["intent"]