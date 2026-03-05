from app.agents.insights.text2sql import Text2SQLService
from app.core.state import AgentState
from langchain_core.tools import tool
from app.core.modelConfig import ModelConfigManager
llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()

@tool
def fetch_rent_data(state: AgentState) -> dict:
    """Fetch rent data from the database"""
    service = Text2SQLService()
    result = service.query(state["user_query"], state["user_id"])   
    return result

def insights_agent(state: AgentState) -> dict:
    """Analyze rent data and provide insights"""

    system_prompt = """
    You are an insights agent with access to tools.

    Responsibilities:
    1. Use the fetch_rent_data tool when database information is required.
    2. Never fabricate data.
    3. After retrieving data, analyze it and provide clear,
       structured, human-readable insights.
    """

    # Bind tool once (outside function ideally, but safe here)
    llm_with_tools = llm.bind_tools([fetch_rent_data])

    messages = [
        {"role": "system", "content": system_prompt},
        *state["messages"]
    ]

    response = llm_with_tools.invoke(messages)

    return {
        "messages": [response]
    }