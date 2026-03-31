"""Human-readable preview text for a lease draft (chat + API)."""
from __future__ import annotations

from typing import Any, Dict

from app.schemas.lease_write import LeaseWriteBody


def _fmt_cell(v: Any, empty: str = "— (not set yet)") -> str:
    if v is None:
        return empty
    if isinstance(v, str) and not v.strip():
        return empty
    return str(v)


def format_lease_draft_preview(body: LeaseWriteBody) -> str:
    lines = [
        "**Lease preview** (not created yet — edit anything below, then Save)",
        f"- Property: {body.property_name}",
        f"- Lease: {body.lease_start} → {body.lease_end}",
        f"- Monthly rent: ₹{body.monthly_rent}",
        f"- Rent due day: {body.due_day}",
    ]
    if body.tenant_name:
        lines.append(f"- Tenant: {body.tenant_name}")
    if body.tenant_email:
        lines.append(f"- Tenant email: {body.tenant_email}")
    if body.tenant_phone:
        lines.append(f"- Tenant phone (WhatsApp): {body.tenant_phone}")
    addr = ", ".join(
        p
        for p in [body.address_line1, body.city, body.state, body.postal_code]
        if p
    )
    if addr:
        lines.append(f"- Address: {addr}")
    if body.security_deposit is not None:
        lines.append(f"- Security deposit: ₹{body.security_deposit}")
    if body.lock_in_period is not None:
        lines.append(f"- Lock-in: {body.lock_in_period} months")
    lines.append("")
    lines.append(
        "They should **change any field** (tell you new values, or use the app draft editor) "
        "until it’s right. **Only then** should they **Save** / say yes to create the lease."
    )
    return "\n".join(lines)


def format_partial_lease_draft_preview(merged: Dict[str, Any]) -> str:
    """Show collected fields for an in-progress draft (not yet valid LeaseWriteBody)."""
    lines = [
        "**Lease draft so far** (saved on the server — ask only for fields still missing)",
        f"- Property: {_fmt_cell(merged.get('property_name'))}",
        f"- Lease: {_fmt_cell(merged.get('lease_start'))} → {_fmt_cell(merged.get('lease_end'))}",
        f"- Monthly rent: {_fmt_cell(merged.get('monthly_rent'))}",
        f"- Rent due day: {_fmt_cell(merged.get('due_day'), '— (defaults to 1)')}",
    ]
    if merged.get("tenant_name"):
        lines.append(f"- Tenant: {_fmt_cell(merged.get('tenant_name'))}")
    if merged.get("tenant_email"):
        lines.append(f"- Tenant email: {_fmt_cell(merged.get('tenant_email'))}")
    if merged.get("tenant_phone"):
        lines.append(f"- Tenant phone (WhatsApp): {_fmt_cell(merged.get('tenant_phone'))}")
    addr = ", ".join(
        p
        for p in [
            merged.get("address_line1"),
            merged.get("city"),
            merged.get("state"),
            merged.get("postal_code"),
        ]
        if p
    )
    if addr:
        lines.append(f"- Address: {addr}")
    if merged.get("security_deposit") is not None:
        lines.append(f"- Security deposit: ₹{merged.get('security_deposit')}")
    if merged.get("lock_in_period") is not None:
        lines.append(f"- Lock-in: {merged.get('lock_in_period')} months")
    lines.append("")
    lines.append(
        "Do **not** re-ask for items already listed above unless the user wants to change them."
    )
    return "\n".join(lines)
