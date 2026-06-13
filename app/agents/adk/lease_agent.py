"""
Lease Agent — Google ADK sub-agent.

Handles all lease-related tasks: upload, extract, create, draft, generate
agreement, DocuSeal signing.
"""
from __future__ import annotations

from google.adk.agents import Agent

from app.agents.adk.tools.lease_tools import (
    tool_store_lease,
    tool_inquire_lease,
    tool_extract_lease_details,
    tool_create_property,
    tool_add_lease,
    tool_prepare_lease_draft,
    tool_open_lease_agreement_widget,
    tool_generate_lease_agreement,
    tool_save_generated_lease_agreement,
    tool_finalize_lease_creation,
    tool_send_lease_for_signature_docuseal,
)

LEASE_AGENT_INSTRUCTION = """
You are the Lease Agent for KirayaEase — responsible for all lease-related operations.

Your capabilities:
- Extract lease data from PDFs and store them (tool_store_lease)
- Answer questions about a specific lease using RAG (tool_inquire_lease)
- Create properties and leases manually via chat (tool_prepare_lease_draft → tool_generate_lease_agreement → tool_save_generated_lease_agreement)
- Open the lease agreement widget on the client (tool_open_lease_agreement_widget)
- Send leases for e-signature via DocuSeal (tool_send_lease_for_signature_docuseal)
- Legacy quick-save flow (tool_finalize_lease_creation)

Rules:
- Never claim a lease is saved until tool_save_generated_lease_agreement or tool_finalize_lease_creation succeeds.
- For multi-turn draft collection, merge fields progressively with tool_prepare_lease_draft.
- If status=partial, only ask for missing_fields — never re-ask already-answered fields.
- Always confirm what was saved using authoritative_lease_record from the tool response.
"""

lease_agent = Agent(
    name="lease_agent",
    model="gemini-2.0-flash",
    description="Handles lease upload, extraction, creation, drafting, agreement generation, and DocuSeal e-signing.",
    instruction=LEASE_AGENT_INSTRUCTION,
    tools=[
        tool_store_lease,
        tool_inquire_lease,
        tool_extract_lease_details,
        tool_create_property,
        tool_add_lease,
        tool_prepare_lease_draft,
        tool_open_lease_agreement_widget,
        tool_generate_lease_agreement,
        tool_save_generated_lease_agreement,
        tool_finalize_lease_creation,
        tool_send_lease_for_signature_docuseal,
    ],
)
