"""
Workflow 5: Notice / Eviction Workflow (ADK Dynamic Workflow).

Steps:
  1. check_delinquency  — verify the lease has unpaid obligations (threshold: N months)
  2. generate_notice    — LLM-generate a formal rent demand / eviction notice
  3. store_notice       — persist notice text to DB (lease_text update or notice log)
  4. notify_landlord    — send push notification and/or email summary to landlord
"""
from __future__ import annotations

import logging
from datetime import date, datetime
from typing import Any, Dict, List, Optional

from psycopg2.extras import RealDictCursor

from app.db.cloud_sql import get_connection
from app.services.landlord_push_dispatch import dispatch_to_landlord

logger = logging.getLogger(__name__)

_NOTICE_LLM_PROMPT = """
You are a legal notice drafting assistant for Indian residential landlords.

Write a formal RENT DEMAND NOTICE based on these facts:
- Property: {property_name}
- Tenant: {tenant_name}
- Overdue months: {overdue_months_str}
- Total overdue amount: ₹{total_overdue}
- Landlord: {landlord_name}

The notice should:
1. State the outstanding amount clearly
2. Give 15 days to pay or vacate
3. Reference applicable provisions of the Transfer of Property Act, 1882
4. Be professional and formal in tone
5. Be under 400 words

Do NOT include personal contact details, only placeholders: [LANDLORD_ADDRESS], [LANDLORD_PHONE].
"""


def step_check_delinquency(
    *,
    owner_id: int,
    lease_id: int,
    min_overdue_months: int = 2,
) -> Dict[str, Any]:
    """
    Check if a lease has >= min_overdue_months unpaid obligations.

    Returns delinquency details or raises ValueError if threshold not met.
    """
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Lease + property info
            cur.execute(
                """
                SELECT l.id, l.monthly_rent, l.lease_start, l.lease_end,
                       p.owner_id, p.name AS property_name,
                       COALESCE(NULLIF(TRIM(p.tenant_name), ''), 'Tenant') AS tenant_name,
                       p.tenant_email, p.tenant_phone
                FROM leases l
                JOIN properties p ON p.id = l.property_id
                WHERE l.id = %s AND p.owner_id = %s
                LIMIT 1
                """,
                (lease_id, owner_id),
            )
            row = cur.fetchone()
            if not row:
                raise ValueError(f"Lease {lease_id} not found for owner {owner_id}")
            lease = dict(row)

            # Overdue months (pending or missing)
            today_str = date.today().isoformat()
            cur.execute(
                """
                SELECT month, amount, status
                FROM rent_confirmations
                WHERE lease_id = %s
                  AND status != 'confirmed'
                  AND month <= %s
                ORDER BY month ASC
                """,
                (lease_id, today_str),
            )
            overdue = [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()

    overdue_count = len(overdue)
    if overdue_count < min_overdue_months:
        raise ValueError(
            f"Lease {lease_id} has only {overdue_count} overdue month(s); "
            f"minimum threshold is {min_overdue_months} for a notice."
        )

    total_overdue = sum(int(r.get("amount") or lease["monthly_rent"]) for r in overdue)
    months_str = ", ".join(
        date.fromisoformat(r["month"][:10]).strftime("%B %Y") for r in overdue
    )

    logger.info(
        "[NoticeEviction] lease_id=%s overdue_count=%d total=₹%d",
        lease_id, overdue_count, total_overdue,
    )
    return {
        "is_delinquent": True,
        "lease_id": lease_id,
        "property_name": lease["property_name"],
        "tenant_name": lease["tenant_name"],
        "tenant_email": lease.get("tenant_email"),
        "overdue_months": [r["month"] for r in overdue],
        "overdue_months_str": months_str,
        "overdue_count": overdue_count,
        "total_overdue": total_overdue,
        "monthly_rent": lease["monthly_rent"],
    }


def step_generate_notice(
    *,
    property_name: str,
    tenant_name: str,
    overdue_months_str: str,
    total_overdue: int,
    landlord_name: str = "Landlord",
) -> Dict[str, Any]:
    """Generate a formal rent demand / eviction notice text using LLM."""
    try:
        from openai import OpenAI
        client = OpenAI()
        prompt = _NOTICE_LLM_PROMPT.format(
            property_name=property_name,
            tenant_name=tenant_name,
            overdue_months_str=overdue_months_str,
            total_overdue=f"{total_overdue:,}",
            landlord_name=landlord_name,
        )
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2,
            max_tokens=600,
        )
        notice_text = response.choices[0].message.content or ""
    except Exception as exc:
        logger.warning("[NoticeEviction] LLM generation failed: %s", exc)
        notice_text = (
            f"RENT DEMAND NOTICE\n\n"
            f"To: {tenant_name}\nProperty: {property_name}\n\n"
            f"This is to inform you that rent for {overdue_months_str} "
            f"(totalling ₹{total_overdue:,}) is overdue. "
            f"Please pay within 15 days or vacate the premises.\n\n"
            f"— {landlord_name}"
        )
    logger.info("[NoticeEviction] notice generated (%d chars)", len(notice_text))
    return {"notice_text": notice_text, "char_count": len(notice_text)}


def step_store_notice(
    *,
    owner_id: int,
    lease_id: int,
    notice_text: str,
) -> Dict[str, Any]:
    """Persist the notice text as a note on the lease record."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Append notice to lease_text (non-destructive)
            cur.execute(
                """
                UPDATE leases
                SET lease_text = COALESCE(lease_text, '') || E'\n\n--- NOTICE ---\n' || %s
                FROM properties p
                WHERE leases.id = %s
                  AND leases.property_id = p.id
                  AND p.owner_id = %s
                RETURNING leases.id
                """,
                (notice_text, lease_id, owner_id),
            )
            updated = cur.fetchone()
        conn.commit()
    finally:
        conn.close()

    if not updated:
        raise RuntimeError(f"Could not store notice for lease {lease_id}")

    logger.info("[NoticeEviction] notice stored on lease_id=%s", lease_id)
    return {"stored": True, "lease_id": lease_id}


def step_notify_landlord(
    *,
    owner_id: int,
    lease_id: int,
    property_name: str,
    tenant_name: str,
    total_overdue: int,
    overdue_count: int,
) -> Dict[str, Any]:
    """Send push notification to landlord about the generated notice."""
    try:
        dispatch_to_landlord(
            landlord_user_id=owner_id,
            lease_id=lease_id,
            notification_type="eviction_notice_generated",
            period_key=date.today().strftime("%Y-%m"),
            title="Notice Generated",
            body=(
                f"Rent demand notice generated for {property_name} ({tenant_name}). "
                f"{overdue_count} overdue month(s), ₹{total_overdue:,} outstanding."
            ),
        )
        push_sent = True
    except Exception as exc:
        logger.warning("[NoticeEviction] push notification failed: %s", exc)
        push_sent = False

    return {"landlord_notified": push_sent}


def run_notice_eviction_workflow(
    *,
    owner_id: int,
    lease_id: int,
    landlord_name: str = "Landlord",
    min_overdue_months: int = 2,
) -> Dict[str, Any]:
    """
    Execute the Notice / Eviction workflow for a delinquent lease.

    Raises ValueError if the lease does not meet the delinquency threshold.
    Returns the generated notice text and confirmation of all steps.
    """
    # Step 1: Check delinquency
    delinquency = step_check_delinquency(
        owner_id=owner_id, lease_id=lease_id, min_overdue_months=min_overdue_months
    )

    # Step 2: Generate notice
    notice = step_generate_notice(
        property_name=delinquency["property_name"],
        tenant_name=delinquency["tenant_name"],
        overdue_months_str=delinquency["overdue_months_str"],
        total_overdue=delinquency["total_overdue"],
        landlord_name=landlord_name,
    )

    # Step 3: Store notice
    store = step_store_notice(
        owner_id=owner_id, lease_id=lease_id, notice_text=notice["notice_text"]
    )

    # Step 4: Notify landlord
    notify = step_notify_landlord(
        owner_id=owner_id,
        lease_id=lease_id,
        property_name=delinquency["property_name"],
        tenant_name=delinquency["tenant_name"],
        total_overdue=delinquency["total_overdue"],
        overdue_count=delinquency["overdue_count"],
    )

    return {
        "status": "success",
        "lease_id": lease_id,
        "property_name": delinquency["property_name"],
        "tenant_name": delinquency["tenant_name"],
        "total_overdue": delinquency["total_overdue"],
        "overdue_months": delinquency["overdue_months"],
        "notice_text": notice["notice_text"],
        "steps": {
            "check_delinquency": delinquency,
            "generate_notice": {"char_count": notice["char_count"]},
            "store_notice": store,
            "notify_landlord": notify,
        },
    }
