from langchain_core.tools import tool
from app.agents.lease.talk2lease import TalkToLeaseRAG
from app.core.state import AgentState
from app.core.modelConfig import ModelConfigManager

llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()

@tool
def store_lease():
    "DocString"
    pass

@tool 
def inquire_lease(state: AgentState) -> dict:
    """Inquire about a lease"""
    rag = TalkToLeaseRAG(
        model_name="gpt-4o-mini",
        temperature=0,
        max_retries=3,
    )
    query = state["user_query"]
    lease_id = state["lease_id"]
    answer = rag.answer_question(query, lease_id)
    return {"answer": answer, "lease_id": lease_id}


def lease_agent(state: AgentState) -> dict:
    """Run lease agent and return messages."""

    system_prompt = """
    You are a lease agent with access to tools.

    Responsibilities:
    1. Extract lease details when required.
    2. Store lease records when appropriate.
    3. Answer lease-related questions using inquire_lease tool.
    4. Never fabricate lease data.
    5. Always use tools when factual data is required.
    """

    messages = [
        {"role": "system", "content": system_prompt},
        *state["messages"]
    ]
    lease_llm = llm.bind_tools([store_lease, inquire_lease])


    response = lease_llm.invoke(messages)

    return {
        "messages": [response]
    }