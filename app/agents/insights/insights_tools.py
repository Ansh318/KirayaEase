from langchain_core.tools import tool

from app.agents.insights.text2sql import Text2SQLService


@tool
def fetch_rent_data(query: str, user_id: int) -> dict:
    """Run natural-language analytics on rent/portfolio data. Pass the user's question as query (e.g. 'total rent', 'rent by property', 'monthly rent summary'). user_id is the landlord's id for scoping data."""
    service = Text2SQLService()
    return service.query(question=query, landlord_id=user_id)

