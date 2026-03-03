from langchain_core.tools import tool
from langchain_core.messages import HumanMessage, AIMessage, ToolMessage
from dotenv import load_dotenv
from app.services.lease_extractor import extract_from_pdf
import json
import requests
from app.schemas.property_manager import PropertyManager
from langchain.agents import create_agent
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
    """Run lease agent and return messages + final answer."""
    agent = create_agent(
        llm,
        [store_lease, inquire_lease],
        system_prompt=(
            "You are a lease agent with access to tools to carry out lease-related tasks. "
            "1. Extract Lease Details 2. Invite Tenant, 3. Creating and Storing records for uploaded lease documents."
        ),
    )
    result = agent.invoke({"messages": state["user_query"]})
    messages = result.get("messages", [])
    answer = messages[-1].content if messages else ""
    return {"messages": messages, "answer": answer}