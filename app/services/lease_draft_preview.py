"""Human-readable preview text for a lease draft (chat + API)."""
from __future__ import annotations

from app.schemas.lease_write import LeaseWriteBody


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
    if body.tenant_phone:
        lines.append(f"- Tenant phone: {body.tenant_phone}")
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
