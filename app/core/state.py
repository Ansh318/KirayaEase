from typing import TypedDict, Optional, List, Dict, Any


class AgentState(TypedDict, total=False):
    # Core identity
    user_id: int
    role: str
    session_id: str

    # Conversation
    messages: List[Dict[str, str]]
    user_query: str
    answer: str

    # Routing
    intent: str

    # Lease flow
    lease_id: int
    extracted_data: Dict[str, Any]

    # Query results
    query_result: Any