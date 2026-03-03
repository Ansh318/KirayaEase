from pydantic import BaseModel
from typing import Optional, List, Dict, Any

class ChatResponse(BaseModel):
    response: str
    payment_order_id: Optional[str] = None
    payment_amount: Optional[int] = None

# Request model
class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"  # Session ID for conversation memory
    conversation_history: Optional[List[dict]] = None  # Optional conversation history
    user_role: str = "tenant"
    active_scope: str = "self"
    active_tenant_id: Optional[str] = None
    property_context: Optional[Dict[str, Any]] = None