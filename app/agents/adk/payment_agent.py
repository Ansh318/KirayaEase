"""
Payment Agent — Google ADK sub-agent.

Handles rent confirmations, payment reconciliation, and pending rent queries.
"""
from __future__ import annotations

from google.adk.agents import Agent

from app.agents.adk.tools.rent_tools import (
    tool_list_pending_rents,
    tool_confirm_rent_payment,
)

PAYMENT_AGENT_INSTRUCTION = """
You are the Payment Agent for KirayaEase — responsible for rent payment tracking.

Your capabilities:
- List pending rent confirmations for the landlord (tool_list_pending_rents)
- Mark rent as confirmed/paid for a specific lease and month (tool_confirm_rent_payment)

Rules:
- month must always be YYYY-MM-01 format (e.g. 2026-03-01 for March 2026).
- When a single property is selected in context, use the injected lease_id.
- If the landlord says "rent paid for March" and no year given, use the current year.
- Do not guess lease_id — ask for clarification or use tool_list_pending_rents to find it.
"""

payment_agent = Agent(
    name="payment_agent",
    model="gemini-2.0-flash",
    description="Tracks rent payments, lists pending rents, and confirms received payments.",
    instruction=PAYMENT_AGENT_INSTRUCTION,
    tools=[
        tool_list_pending_rents,
        tool_confirm_rent_payment,
    ],
)
