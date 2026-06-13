"""
Workflow 1: Tenant Onboarding Workflow (ADK Dynamic Workflow).

Steps:
  1. create_tenant      — upsert property + tenant details
  2. validate_details   — check required fields are present
  3. generate_lease     — create lease record (or use existing)
  4. configure_reminders — schedule rent reminder preferences
  5. create_rent_schedule — seed rent_confirmations table for upcoming months

This workflow is deterministic: run as an ADK SequentialAgent that executes
each step in order, halting if any step fails.
"""
from __future__ import annotations

import logging
from datetime import date
from dateutil.relativedelta import relativedelta
from typing import Any, Dict, List, Optional

from app.db.cloud_sql import get_connection
from app.schemas.property_manager import PropertyManager
from app.db.sql_queries import CREATE_RENT_CONFIRMATION
from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)


# ── Step functions ────────────────────────────────────────────────────────────

def step_create_tenant(
    *,
    owner_id: int,
    tenant_name: str,
    tenant_email: str,
    tenant_phone: Optional[str] = None,
    property_name: str,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
) -> Dict[str, Any]:
    """Create or upsert property with tenant details."""
    pm = PropertyManager()
    prop = pm.add_property(
        owner_id=owner_id,
        name=property_name,
        tenant_name=tenant_name,
        tenant_phone=tenant_phone,
        tenant_email=tenant_email,
        address_line1=address_line1,
        city=city,
        state=state,
        postal_code=postal_code,
    )
    logger.info("[TenantOnboarding] created property id=%s", prop.get("id"))
    return {"property_id": prop.get("id"), "property": prop}


def step_validate_details(
    *,
    property_id: int,
    tenant_email: str,
    lease_start: str,
    lease_end: str,
    monthly_rent: int,
    due_day: int,
) -> Dict[str, Any]:
    """Validate all required fields are present and sane."""
    errors: List[str] = []
    if not tenant_email or "@" not in tenant_email:
        errors.append("tenant_email is required and must be valid")
    try:
        s = date.fromisoformat(lease_start)
        e = date.fromisoformat(lease_end)
        if e <= s:
            errors.append("lease_end must be after lease_start")
    except (ValueError, TypeError):
        errors.append("lease_start and lease_end must be YYYY-MM-DD dates")
    if monthly_rent < 1:
        errors.append("monthly_rent must be a positive integer (INR)")
    if not (1 <= due_day <= 31):
        errors.append("due_day must be between 1 and 31")
    if errors:
        raise ValueError(f"Validation failed: {'; '.join(errors)}")
    logger.info("[TenantOnboarding] validation passed for property_id=%s", property_id)
    return {"valid": True}


def step_generate_lease(
    *,
    property_id: int,
    lease_start: str,
    lease_end: str,
    monthly_rent: int,
    due_day: int,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
    lease_text: Optional[str] = None,
) -> Dict[str, Any]:
    """Create the lease record in the database."""
    pm = PropertyManager()
    lease = pm.add_lease(
        property_id=property_id,
        lease_start=lease_start,
        lease_end=lease_end,
        monthly_rent=monthly_rent,
        security_deposit=security_deposit,
        lock_in_period=lock_in_period,
        due_day=due_day,
        lease_text=lease_text,
    )
    logger.info("[TenantOnboarding] created lease id=%s", lease.get("id"))
    return {"lease_id": lease.get("id"), "lease": lease}


def step_configure_reminders(
    *,
    owner_id: int,
    lease_id: int,
    tenant_email: str,
    tenant_name: str,
) -> Dict[str, Any]:
    """
    Reminder configuration hook.

    In production, this would write to a reminders config table.
    Cloud Scheduler picks up all active leases nightly, so no additional
    record is needed — the lease row is sufficient.
    """
    logger.info(
        "[TenantOnboarding] reminders configured for lease_id=%s owner_id=%s",
        lease_id, owner_id,
    )
    return {
        "reminders_configured": True,
        "note": (
            "Scheduled reminders (2–3 days before due, overdue, lease expiry) "
            "are handled by Cloud Scheduler via app.jobs.run_landlord_push."
        ),
    }


def step_create_rent_schedule(
    *,
    owner_id: int,
    lease_id: int,
    monthly_rent: int,
    lease_start: str,
    lease_end: str,
    due_day: int,
    months_ahead: int = 3,
) -> Dict[str, Any]:
    """
    Seed rent_confirmations rows (status='pending') for upcoming months.

    Creates entries from lease_start up to min(lease_end, now + months_ahead).
    Existing rows are skipped (ON CONFLICT DO NOTHING).
    """
    start = date.fromisoformat(lease_start)
    end = date.fromisoformat(lease_end)
    today = date.today()
    until = min(end, today + relativedelta(months=months_ahead))

    months_created: List[str] = []
    current = date(start.year, start.month, 1)

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            while current <= until:
                month_str = current.isoformat()
                try:
                    cur.execute(
                        """
                        INSERT INTO rent_confirmations (lease_id, confirmed_by, month, amount, status)
                        VALUES (%s, %s, %s, %s, 'pending')
                        ON CONFLICT (lease_id, month) DO NOTHING
                        """,
                        (lease_id, owner_id, month_str, monthly_rent),
                    )
                    months_created.append(month_str)
                except Exception as exc:
                    logger.warning(
                        "[TenantOnboarding] rent_confirmation upsert failed month=%s: %s",
                        month_str, exc,
                    )
                current += relativedelta(months=1)
        conn.commit()
    finally:
        conn.close()

    logger.info(
        "[TenantOnboarding] created %d pending rent months for lease_id=%s",
        len(months_created), lease_id,
    )
    return {"months_created": months_created, "count": len(months_created)}


# ── Workflow entry-point ───────────────────────────────────────────────────────

def run_tenant_onboarding_workflow(
    *,
    owner_id: int,
    tenant_name: str,
    tenant_email: str,
    property_name: str,
    lease_start: str,
    lease_end: str,
    monthly_rent: int,
    due_day: int,
    tenant_phone: Optional[str] = None,
    address_line1: Optional[str] = None,
    city: Optional[str] = None,
    state: Optional[str] = None,
    postal_code: Optional[str] = None,
    security_deposit: Optional[int] = None,
    lock_in_period: Optional[int] = None,
) -> Dict[str, Any]:
    """
    Execute the full Tenant Onboarding workflow sequentially.

    Raises ValueError on validation failure. Returns a dict with lease_id,
    property_id, and confirmation of all steps.
    """
    # Step 1: Create tenant/property
    create_result = step_create_tenant(
        owner_id=owner_id,
        tenant_name=tenant_name,
        tenant_email=tenant_email,
        tenant_phone=tenant_phone,
        property_name=property_name,
        address_line1=address_line1,
        city=city,
        state=state,
        postal_code=postal_code,
    )
    property_id = create_result["property_id"]

    # Step 2: Validate
    step_validate_details(
        property_id=property_id,
        tenant_email=tenant_email,
        lease_start=lease_start,
        lease_end=lease_end,
        monthly_rent=monthly_rent,
        due_day=due_day,
    )

    # Step 3: Generate lease
    lease_result = step_generate_lease(
        property_id=property_id,
        lease_start=lease_start,
        lease_end=lease_end,
        monthly_rent=monthly_rent,
        due_day=due_day,
        security_deposit=security_deposit,
        lock_in_period=lock_in_period,
    )
    lease_id = lease_result["lease_id"]

    # Step 4: Configure reminders
    reminder_result = step_configure_reminders(
        owner_id=owner_id,
        lease_id=lease_id,
        tenant_email=tenant_email,
        tenant_name=tenant_name,
    )

    # Step 5: Create rent schedule
    schedule_result = step_create_rent_schedule(
        owner_id=owner_id,
        lease_id=lease_id,
        monthly_rent=monthly_rent,
        lease_start=lease_start,
        lease_end=lease_end,
        due_day=due_day,
    )

    return {
        "status": "success",
        "property_id": property_id,
        "lease_id": lease_id,
        "steps": {
            "create_tenant": create_result,
            "validate_details": {"valid": True},
            "generate_lease": lease_result,
            "configure_reminders": reminder_result,
            "create_rent_schedule": schedule_result,
        },
    }
