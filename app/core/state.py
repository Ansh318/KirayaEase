from typing_extensions import TypedDict
from typing import Optional, List, Dict, Any, Annotated
from langchain_core.messages import BaseMessage
from langgraph.graph.message import add_messages

class AgentState(TypedDict, total=False):

    # -------------------------
    # Identity
    # -------------------------
    user_id: int
    role: str
    session_id: str
    api_public_base_url: Optional[str]  # e.g. https://app.herokuapp.com for lease PDF URLs from agent tools
    memory_summary: Optional[str]  # persisted user notes (remember_user_fact); injected into system prompt
    response_language: Optional[str]  # language instruction for assistant replies in this request

    # -------------------------
    # Property context (landlord)
    # -------------------------
    property_id: Optional[int]   # None = portfolio (all properties)
    scope: str                   # "portfolio" | "property"
    property_context: Optional[Dict[str, Any]]  # selected property summary for context

    # -------------------------
    # Conversation
    # -------------------------
    messages: Annotated[List[BaseMessage], add_messages]
    user_query: str
    answer: str

    # -------------------------
    # Planner
    # -------------------------
    plan: List[str]
    current_step: int

    # -------------------------
    # Lease workflow
    # -------------------------
    lease_id: int
    extracted_data: Dict[str, Any]
    uploaded_lease_path: Optional[str]

    # -------------------------
    # Query results
    # -------------------------
    query_result: Any
    insights_chart_spec: Optional[Dict[str, Any]]  # chart payload for frontend when fetch_rent_data is chartable
