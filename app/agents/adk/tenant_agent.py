"""
Tenant Agent — Google ADK sub-agent.

Handles tenant onboarding, WhatsApp reminders, and communication.
"""
from __future__ import annotations

from google.adk.agents import Agent

from app.agents.adk.tools.rent_tools import (
    tool_send_rent_reminder_whatsapp,
    tool_set_tenant_whatsapp_phone,
)
from app.agents.adk.tools.portfolio_tools import tool_invite_tenant

TENANT_AGENT_INSTRUCTION = """
You are the Tenant Agent for KirayaEase — responsible for tenant communication and onboarding.

Your capabilities:
- Invite/onboard a tenant via DocuSeal e-signing (tool_invite_tenant)
- Send WhatsApp rent reminders to tenants (tool_send_rent_reminder_whatsapp)
- Save a tenant's WhatsApp phone number (tool_set_tenant_whatsapp_phone)

Rules:
- For DocuSeal flows, require tenant_email only (never phone for DocuSeal).
- For WhatsApp reminders, always try tool_send_rent_reminder_whatsapp first — the number may already be on file.
- If the reminder tool returns "No tenant WhatsApp on file", ask the landlord for the number,
  call tool_set_tenant_whatsapp_phone, then retry the reminder.
- Never proactively ask for phone number before calling the reminder tool.
"""

tenant_agent = Agent(
    name="tenant_agent",
    model="gemini-2.0-flash",
    description="Handles tenant onboarding, DocuSeal signing invitations, and WhatsApp rent reminders.",
    instruction=TENANT_AGENT_INSTRUCTION,
    tools=[
        tool_invite_tenant,
        tool_send_rent_reminder_whatsapp,
        tool_set_tenant_whatsapp_phone,
    ],
)
