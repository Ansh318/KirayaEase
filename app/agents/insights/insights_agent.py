from app.agents.insights.text2sql import Text2SQLService
from app.core.state import AgentState
from langchain_core.tools import tool
from langchain.agents import create_agent
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
    agent = create_agent(
        llm,
        [fetch_rent_data],
        system_prompt=(
            "You are a insights agent with access to tools to carry out insights-related tasks. "
            "1. Fetch rent data from the database"
            "2. Analyze rent data and provide insights in a clear and human readable format."
        ),
    )
    result = agent.invoke({"messages": state["user_query"]})
    messages = result.get("messages", [])
    answer = messages[-1].content if messages else ""
    return {"messages": messages, "answer": answer}