"""
Workflow 3: Payment Reconciliation Workflow (ADK Dynamic Workflow).

Steps:
  1. fetch_payment_data     — load all rent_confirmations for the landlord
  2. match_obligations      — compute expected vs actual per lease per month
  3. reconcile_ledger       — mark confirmed months, flag discrepancies
  4. generate_exceptions    — return list of mismatches / overdue records
"""
from __future__ import annotations

import logging
from datetime import date, datetime
from typing import Any, Dict, List, Tuple

from psycopg2.extras import RealDictCursor

from app.db.cloud_sql import get_connection

logger = logging.getLogger(__name__)


def _serialize_row(row: dict) -> dict:
    out = dict(row)
    for k, v in out.items():
        if isinstance(v, (date, datetime)):
            out[k] = v.isoformat()
    return out


def step_fetch_payment_data(*, owner_id: int) -> Dict[str, Any]:
    """Fetch all rent confirmations and lease obligations for the landlord."""
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # All leases for this landlord
            cur.execute(
                """
                SELECT l.id AS lease_id, l.monthly_rent, l.due_day,
                       l.lease_start, l.lease_end, l.status AS lease_status,
                       p.name AS property_name, p.tenant_name
                FROM leases l
                JOIN properties p ON p.id = l.property_id
                WHERE p.owner_id = %s
                ORDER BY l.id
                """,
                (owner_id,),
            )
            leases = [_serialize_row(dict(r)) for r in cur.fetchall()]

            # All rent confirmations for those leases
            cur.execute(
                """
                SELECT rc.lease_id, rc.month, rc.amount, rc.status, rc.confirmed_at
                FROM rent_confirmations rc
                JOIN leases l ON l.id = rc.lease_id
                JOIN properties p ON p.id = l.property_id
                WHERE p.owner_id = %s
                ORDER BY rc.lease_id, rc.month
                """,
                (owner_id,),
            )
            confirmations = [_serialize_row(dict(r)) for r in cur.fetchall()]
    finally:
        conn.close()

    return {"leases": leases, "confirmations": confirmations}


def _months_in_range(start: str, end: str, until: date) -> List[str]:
    """All YYYY-MM-01 strings from start through min(end, until)."""
    from dateutil.relativedelta import relativedelta
    s = date.fromisoformat(start[:10])
    e = min(date.fromisoformat(end[:10]), until)
    months = []
    current = date(s.year, s.month, 1)
    while current <= date(e.year, e.month, 1):
        months.append(current.isoformat())
        current += relativedelta(months=1)
    return months


def step_match_obligations(
    *, leases: List[Dict], confirmations: List[Dict]
) -> Dict[str, Any]:
    """Compute expected rent months vs. confirmed months per lease."""
    today = date.today()
    # Build lookup: lease_id → set of confirmed months
    confirmed_map: Dict[int, Dict[str, Dict]] = {}
    for c in confirmations:
        lid = int(c["lease_id"])
        confirmed_map.setdefault(lid, {})[c["month"][:10]] = c

    obligations: List[Dict[str, Any]] = []
    for lease in leases:
        lid = int(lease["lease_id"])
        expected_months = _months_in_range(
            lease["lease_start"], lease["lease_end"], today
        )
        lease_confirmations = confirmed_map.get(lid, {})
        for month in expected_months:
            conf = lease_confirmations.get(month)
            obligations.append({
                "lease_id": lid,
                "property_name": lease["property_name"],
                "tenant_name": lease["tenant_name"],
                "month": month,
                "expected_amount": lease["monthly_rent"],
                "actual_amount": conf["amount"] if conf else None,
                "status": conf["status"] if conf else "missing",
                "confirmed_at": conf.get("confirmed_at") if conf else None,
            })
    return {"obligations": obligations}


def step_reconcile_ledger(*, obligations: List[Dict]) -> Dict[str, Any]:
    """
    Classify each obligation as confirmed, pending, or missing.
    Returns reconciled ledger rows.
    """
    reconciled: List[Dict[str, Any]] = []
    totals = {"confirmed": 0, "pending": 0, "missing": 0, "amount_confirmed": 0}

    for ob in obligations:
        status = ob["status"]
        row = {**ob, "reconciled_status": status}
        if status == "confirmed":
            totals["confirmed"] += 1
            totals["amount_confirmed"] += ob.get("expected_amount") or 0
        elif status == "pending":
            totals["pending"] += 1
        else:
            totals["missing"] += 1
        reconciled.append(row)

    logger.info(
        "[PaymentReconciliation] confirmed=%d pending=%d missing=%d",
        totals["confirmed"], totals["pending"], totals["missing"],
    )
    return {"reconciled": reconciled, "totals": totals}


def step_generate_exceptions(*, reconciled: List[Dict], totals: Dict) -> Dict[str, Any]:
    """Surface all non-confirmed rows as exceptions for landlord review."""
    exceptions = [r for r in reconciled if r["reconciled_status"] != "confirmed"]
    return {
        "exceptions": exceptions,
        "exception_count": len(exceptions),
        "totals": totals,
        "summary": (
            f"Reconciliation complete. "
            f"Confirmed: {totals['confirmed']} month(s) (₹{totals['amount_confirmed']:,}). "
            f"Pending: {totals['pending']}. Missing: {totals['missing']}."
        ),
    }


def run_payment_reconciliation_workflow(*, owner_id: int) -> Dict[str, Any]:
    """
    Execute full Payment Reconciliation workflow for a landlord.

    Returns a reconciliation report with confirmed/pending/missing entries.
    """
    # Step 1
    fetch_result = step_fetch_payment_data(owner_id=owner_id)

    # Step 2
    match_result = step_match_obligations(
        leases=fetch_result["leases"],
        confirmations=fetch_result["confirmations"],
    )

    # Step 3
    reconcile_result = step_reconcile_ledger(obligations=match_result["obligations"])

    # Step 4
    exceptions_result = step_generate_exceptions(
        reconciled=reconcile_result["reconciled"],
        totals=reconcile_result["totals"],
    )

    return {
        "status": "success",
        "owner_id": owner_id,
        **exceptions_result,
        "steps": {
            "fetch_payment_data": {"leases_count": len(fetch_result["leases"])},
            "match_obligations": {"obligations_count": len(match_result["obligations"])},
            "reconcile_ledger": {"totals": reconcile_result["totals"]},
            "generate_exceptions": {"exception_count": exceptions_result["exception_count"]},
        },
    }
