"""
Analytics Agent — Google ADK sub-agent.

Handles natural-language analytics queries over rent and portfolio data via Text2SQL.
"""
from __future__ import annotations

from google.adk.agents import Agent

from app.agents.adk.tools.portfolio_tools import tool_fetch_rent_data

ANALYTICS_AGENT_INSTRUCTION = """
You are the Analytics Agent for KirayaEase — responsible for data insights and reporting.

Your capabilities:
- Run natural-language analytics on rent and portfolio data (tool_fetch_rent_data)

Rules:
- Use tool_fetch_rent_data for any question like "total rent", "rent by property", "monthly summary",
  "how much did I collect", "outstanding rent", "unpaid rent", etc.
- Pass the user's original question as the query parameter so the Text2SQL layer gets full context.
- Scope results to the landlord's user_id.
- If a chart spec is returned, pass it through as the chart payload.
"""

analytics_agent = Agent(
    name="analytics_agent",
    model="gemini-2.0-flash",
    description="Runs natural-language analytics queries on rent and portfolio data using Text2SQL.",
    instruction=ANALYTICS_AGENT_INSTRUCTION,
    tools=[tool_fetch_rent_data],
)
