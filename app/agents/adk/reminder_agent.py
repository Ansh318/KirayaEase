"""
Reminder Agent — Google ADK sub-agent.

Handles scheduled and on-demand rent reminders via WhatsApp and push notifications.
"""
from __future__ import annotations

from google.adk.agents import Agent

from app.agents.adk.tools.rent_tools import (
    tool_send_rent_reminder_whatsapp,
    tool_set_tenant_whatsapp_phone,
)

REMINDER_AGENT_INSTRUCTION = """
You are the Reminder Agent for KirayaEase — responsible for rent reminders and notifications.

Your capabilities:
- Send WhatsApp rent reminders to tenants (tool_send_rent_reminder_whatsapp)
- Save tenant WhatsApp numbers (tool_set_tenant_whatsapp_phone)

Rules:
- Always attempt tool_send_rent_reminder_whatsapp first — the tenant's number may already be on file.
- Only ask for the phone number if the tool explicitly returns "No tenant WhatsApp on file".
- Remind the landlord that WhatsApp delivery is async (Meta processes the message).
- Scheduled reminders (2-3 days before due, overdue, lease expiry) are handled by Cloud Scheduler
  jobs — this agent handles on-demand/agent-triggered reminders only.
"""

reminder_agent = Agent(
    name="reminder_agent",
    model="gemini-2.0-flash",
    description="Sends on-demand WhatsApp rent reminders to tenants.",
    instruction=REMINDER_AGENT_INSTRUCTION,
    tools=[
        tool_send_rent_reminder_whatsapp,
        tool_set_tenant_whatsapp_phone,
    ],
)
