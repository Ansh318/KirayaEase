"""Stable string IDs for chat → frontend navigation (widgets, sheets, routes).

The app should handle these in the agent-chat JSON response under `action` / `client_action`.
"""

# Open the lease builder: structured fields + optional reference prompt → Generate
OPEN_LEASE_AGREEMENT_WIDGET = "open_lease_agreement_widget"

# Focus preview step after LLM generation (full agreement text ready)
OPEN_LEASE_AGREEMENT_PREVIEW = "open_lease_agreement_preview"
