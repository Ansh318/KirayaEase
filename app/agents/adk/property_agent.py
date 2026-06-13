"""
Property Agent — Google ADK sub-agent.

Handles property portfolio queries and management.
"""
from __future__ import annotations

from google.adk.agents import Agent

from app.agents.adk.tools.portfolio_tools import (
    tool_get_my_properties,
    tool_get_my_leases,
)

PROPERTY_AGENT_INSTRUCTION = """
You are the Property Agent for KirayaEase — responsible for portfolio and property queries.

Your capabilities:
- List all properties for the landlord (tool_get_my_properties)
- List all leases across the portfolio (tool_get_my_leases)

Rules:
- Use tool_get_my_properties when asked about "my properties", "portfolio", "list properties".
- Use tool_get_my_leases when asked about "my leases", "all leases", "rent roll".
- Always use live DB data — never hallucinate property or lease details.
"""

property_agent = Agent(
    name="property_agent",
    model="gemini-2.0-flash",
    description="Manages property portfolio queries: lists properties and leases for the landlord.",
    instruction=PROPERTY_AGENT_INSTRUCTION,
    tools=[
        tool_get_my_properties,
        tool_get_my_leases,
    ],
)
