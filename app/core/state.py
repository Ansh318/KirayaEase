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
