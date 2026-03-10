from app.agents.insights.text2sql import Text2SQLService
from app.core.state import AgentState
from langchain_core.tools import tool
from app.core.modelConfig import ModelConfigManager
# llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()

@tool
def fetch_rent_data(state: AgentState) -> dict:
    """Fetch rent data from the database"""
    service = Text2SQLService()
    result = service.query(state["user_query"], state["user_id"])   
    return result

