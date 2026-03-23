"""On-demand WhatsApp rent reminders (agent-triggered only)."""
from __future__ import annotations

import calendar
import os
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

import psycopg2
from psycopg2.extras import RealDictCursor

from app.db.sql_queries import GET_LEASE_WITH_PROPERTY_FOR_OWNER
from app.services.whatsapp_service import send_whatsapp_template


def _conn():
    return psycopg2.connect(os.getenv("DATABASE_URL"))


def default_rent_template_name() -> str:
    """Meta utility template for rent reminders (body: tenant_name, amount, property_name, due_date)."""
    return (
        os.getenv("WHATSAPP_RENT_REMINDER_TEMPLATE", "kirayaeaseonboarding").strip()
        or "kirayaeaseonboarding"
    )


def rent_reminder_template_language() -> str:
    """Must match the language code of the approved template in Meta (often ``en`` or ``en_US``)."""
    return (os.getenv("WHATSAPP_RENT_REMINDER_LANG") or "en").strip() or "en"


def _rent_reminder_body_use_named_params() -> bool:
    """
    Meta templates may use named body variables (parameter_name) or positional only.
    Default ``named`` matches templates defined with {{tenant_name}}, {{amount}}, etc.
    Set WHATSAPP_RENT_REMINDER_BODY_STYLE=positional if Graph API rejects named params.
    """
    v = (os.getenv("WHATSAPP_RENT_REMINDER_BODY_STYLE") or "named").strip().lower()
    return v not in ("positional", "position", "ordered", "order", "0", "false", "no", "off")


def _format_rent_amount_inr(monthly_rent: Any) -> str:
    """Digits only for body var ``amount`` (template already includes ₹), e.g. ``75000``."""
    if monthly_rent is None:
        return "0"
    try:
        n = int(monthly_rent)
        return str(n)
    except (TypeError, ValueError):
        return str(monthly_rent).strip() or "0"


def _format_due_date_human(d: date) -> str:
    """e.g. 5 Jun 2026 — readable in EN; adjust template language in Meta if needed."""
    return f"{d.day} {d.strftime('%b %Y')}"


def next_rent_due_date(due_day: int, ref: date) -> date:
    """Next calendar due date on or after `ref`, clamping day to month length."""
    y, m = ref.year, ref.month
    last = calendar.monthrange(y, m)[1]
    d = min(max(1, due_day), last)
    cand = date(y, m, d)
    if cand < ref:
        if m == 12:
            y, m = y + 1, 1
        else:
            m += 1
        last = calendar.monthrange(y, m)[1]
        d = min(max(1, due_day), last)
        cand = date(y, m, d)
    return cand


def days_until_next_due(due_day: int, today: date) -> Tuple[date, int]:
    nd = next_rent_due_date(due_day, today)
    return nd, (nd - today).days


def send_rent_reminder_for_lease(
    landlord_user_id: int,
    lease_id: int,
    *,
    template_name: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Verify ownership, load tenant WhatsApp, send template (when landlord/agent requests a reminder).
    Fills template body variables from DB: tenant_name, monthly_rent (as amount), property_name,
    next rent due date (as due_date). Template defaults to ``kirayaeaseonboarding``.
    """
    tpl = template_name or default_rent_template_name()
    lang = rent_reminder_template_language()
    today = date.today()
    body_parameters: List[Dict[str, str]] = []

    with _conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                GET_LEASE_WITH_PROPERTY_FOR_OWNER,
                (lease_id, landlord_user_id),
            )
            row = cur.fetchone()
            if not row:
                return {
                    "status": "error",
                    "message": "Lease not found or you do not own this property.",
                }
            row = dict(row)
            phone = (row.get("tenant_phone") or "").strip()
            if not phone:
                return {
                    "status": "error",
                    "message": "No tenant WhatsApp on file for this property. Ask the landlord to add it (set_tenant_whatsapp_phone) or update the property in the app.",
                }
            if row.get("lease_status") != "active":
                return {"status": "error", "message": "Lease is not active."}
            lease_end = row.get("lease_end")
            if isinstance(lease_end, datetime):
                lease_end = lease_end.date()
            if isinstance(lease_end, date) and lease_end < today:
                return {"status": "error", "message": "Lease has ended."}

            nd, days_left = days_until_next_due(int(row["due_day"]), today)

            tenant_nm = (row.get("tenant_name") or "").strip() or "there"
            amount_str = _format_rent_amount_inr(row.get("monthly_rent"))
            prop_nm = (row.get("property_name") or "").strip() or "your property"
            due_str = _format_due_date_human(nd)
            use_named = _rent_reminder_body_use_named_params()
            if use_named:
                body_parameters = [
                    {"parameter_name": "tenant_name", "text": tenant_nm},
                    {"parameter_name": "amount", "text": amount_str},
                    {"parameter_name": "property_name", "text": prop_nm},
                    {"parameter_name": "due_date", "text": due_str},
                ]
            else:
                body_parameters = [
                    {"text": tenant_nm},
                    {"text": amount_str},
                    {"text": prop_nm},
                    {"text": due_str},
                ]

    result = send_whatsapp_template(
        phone,
        tpl,
        language_code=lang,
        body_parameters=body_parameters,
    )
    if result.get("ok"):
        return {
            "status": "queued",
            "delivery_note": "Accepted by WhatsApp API; handset delivery is asynchronous.",
            "lease_id": lease_id,
            "property_name": row.get("property_name"),
            "tenant_name": row.get("tenant_name"),
            "to": phone,
            "template": tpl,
            "wa_message_id": result.get("message_id"),
            "wa_message_status": result.get("message_status"),
            "template_variables": {
                "tenant_name": body_parameters[0]["text"],
                "amount": body_parameters[1]["text"],
                "property_name": body_parameters[2]["text"],
                "due_date": body_parameters[3]["text"],
            },
            "next_due_date": nd.isoformat(),
            "days_until_due": days_left,
            "graph": result.get("body"),
        }
    return {
        "status": "error",
        "message": "WhatsApp API error",
        "detail": result,
    }
