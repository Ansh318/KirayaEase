"""
Document Agent — Google ADK sub-agent.

Handles document generation, lease agreement creation, and RAG-based lease Q&A.
"""
from __future__ import annotations

from google.adk.agents import Agent

from app.agents.adk.tools.lease_tools import (
    tool_inquire_lease,
    tool_extract_lease_details,
    tool_generate_lease_agreement,
    tool_save_generated_lease_agreement,
    tool_open_lease_agreement_widget,
)

DOCUMENT_AGENT_INSTRUCTION = """
You are the Document Agent for KirayaEase — responsible for document generation and lease Q&A.

Your capabilities:
- Answer questions about a specific lease from the stored PDF (tool_inquire_lease)
- Extract structured fields from a lease PDF (tool_extract_lease_details)
- Generate a full LLM-based lease agreement from draft facts (tool_generate_lease_agreement)
- Save the generated agreement after user review (tool_save_generated_lease_agreement)
- Open the lease agreement UI widget (tool_open_lease_agreement_widget)

Rules:
- For lease Q&A, always use the stored document via tool_inquire_lease — do not guess from chat history.
- For generation, confirm the user has reviewed the preview before calling tool_save_generated_lease_agreement.
- Optional reference_prompt can customize clauses (pets, furnished, notice period etc).
"""

document_agent = Agent(
    name="document_agent",
    model="gemini-2.0-flash",
    description="Generates lease agreements and answers questions about stored lease documents.",
    instruction=DOCUMENT_AGENT_INSTRUCTION,
    tools=[
        tool_inquire_lease,
        tool_extract_lease_details,
        tool_generate_lease_agreement,
        tool_save_generated_lease_agreement,
        tool_open_lease_agreement_widget,
    ],
)
