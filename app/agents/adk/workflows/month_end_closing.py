"""
Workflow 4: Month-End Closing Workflow (ADK Dynamic Workflow).

Steps:
  1. calculate_rent_collected    — sum confirmed payments for the period
  2. calculate_outstanding       — identify pending/missing obligations
  3. generate_landlord_summary   — produce per-property breakdown
  4. create_reports              — return structured report payload
"""
from __future__ import annotations

import logging
from datetime import date, datetime
from typing import Any, Dict, List, Optional

from psycopg2.extras import RealDictCursor

from app.db.cloud_sql import get_connection

logger = logging.getLogger(__name__)


def _serialize(row: dict) -> dict:
    out = dict(row)
    for k, v in out.items():
        if isinstance(v, (date, datetime)):
            out[k] = v.isoformat()
    return out


def step_calculate_rent_collected(
    *, owner_id: int, period_start: str, period_end: str
) -> Dict[str, Any]:
    """Sum all confirmed rent payments in [period_start, period_end]."""
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                  rc.lease_id,
                  SUM(rc.amount) AS total_collected,
                  COUNT(*) AS months_confirmed,
                  p.name AS property_name,
                  p.tenant_name
                FROM rent_confirmations rc
                JOIN leases l ON l.id = rc.lease_id
                JOIN properties p ON p.id = l.property_id
                WHERE p.owner_id = %s
                  AND rc.status = 'confirmed'
                  AND rc.month >= %s
                  AND rc.month <= %s
                GROUP BY rc.lease_id, p.name, p.tenant_name
                ORDER BY p.name
                """,
                (owner_id, period_start, period_end),
            )
            rows = [_serialize(dict(r)) for r in cur.fetchall()]
    finally:
        conn.close()

    total = sum(int(r.get("total_collected") or 0) for r in rows)
    logger.info("[MonthEndClosing] collected ₹%d from %d leases", total, len(rows))
    return {"collected_by_lease": rows, "total_collected": total}


def step_calculate_outstanding(
    *, owner_id: int, period_start: str, period_end: str
) -> Dict[str, Any]:
    """Identify leases with pending or missing payments in the period."""
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                  rc.lease_id,
                  rc.month,
                  rc.amount,
                  rc.status,
                  p.name AS property_name,
                  p.tenant_name,
                  l.monthly_rent
                FROM rent_confirmations rc
                JOIN leases l ON l.id = rc.lease_id
                JOIN properties p ON p.id = l.property_id
                WHERE p.owner_id = %s
                  AND rc.status != 'confirmed'
                  AND rc.month >= %s
                  AND rc.month <= %s
                ORDER BY p.name, rc.month
                """,
                (owner_id, period_start, period_end),
            )
            outstanding_rows = [_serialize(dict(r)) for r in cur.fetchall()]
    finally:
        conn.close()

    total_outstanding = sum(int(r.get("monthly_rent") or 0) for r in outstanding_rows)
    logger.info(
        "[MonthEndClosing] outstanding ₹%d across %d records",
        total_outstanding, len(outstanding_rows),
    )
    return {"outstanding": outstanding_rows, "total_outstanding": total_outstanding}


def step_generate_landlord_summary(
    *,
    collected_by_lease: List[Dict],
    outstanding: List[Dict],
    total_collected: int,
    total_outstanding: int,
    period_start: str,
    period_end: str,
) -> Dict[str, Any]:
    """Produce a per-property breakdown summary for the landlord."""
    # Map outstanding by lease for easy lookup
    outstanding_map: Dict[int, List[Dict]] = {}
    for r in outstanding:
        lid = int(r["lease_id"])
        outstanding_map.setdefault(lid, []).append(r)

    property_summaries: List[Dict] = []
    for c in collected_by_lease:
        lid = int(c["lease_id"])
        property_summaries.append({
            "property_name": c["property_name"],
            "tenant_name": c["tenant_name"],
            "lease_id": lid,
            "collected": int(c.get("total_collected") or 0),
            "months_confirmed": int(c.get("months_confirmed") or 0),
            "outstanding_months": outstanding_map.get(lid, []),
        })

    # Properties with only outstanding (no confirmed)
    collected_ids = {int(c["lease_id"]) for c in collected_by_lease}
    for r in outstanding:
        lid = int(r["lease_id"])
        if lid not in collected_ids:
            collected_ids.add(lid)
            property_summaries.append({
                "property_name": r["property_name"],
                "tenant_name": r["tenant_name"],
                "lease_id": lid,
                "collected": 0,
                "months_confirmed": 0,
                "outstanding_months": outstanding_map.get(lid, []),
            })

    return {
        "period": {"start": period_start, "end": period_end},
        "total_collected": total_collected,
        "total_outstanding": total_outstanding,
        "property_summaries": property_summaries,
        "collection_rate": (
            round(total_collected / (total_collected + total_outstanding) * 100, 1)
            if (total_collected + total_outstanding) > 0 else 100.0
        ),
    }


def step_create_reports(*, summary: Dict[str, Any]) -> Dict[str, Any]:
    """Package the summary as a structured report payload."""
    period = summary.get("period", {})
    report = {
        "report_type": "month_end_closing",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "period_start": period.get("start"),
        "period_end": period.get("end"),
        "total_collected_inr": summary.get("total_collected", 0),
        "total_outstanding_inr": summary.get("total_outstanding", 0),
        "collection_rate_pct": summary.get("collection_rate", 0),
        "property_count": len(summary.get("property_summaries", [])),
        "property_summaries": summary.get("property_summaries", []),
        "narrative": (
            f"Month-end close for {period.get('start')} → {period.get('end')}: "
            f"₹{summary.get('total_collected', 0):,} collected "
            f"({summary.get('collection_rate', 0)}% collection rate). "
            f"₹{summary.get('total_outstanding', 0):,} outstanding."
        ),
    }
    logger.info(
        "[MonthEndClosing] report generated: collected=₹%d outstanding=₹%d rate=%.1f%%",
        report["total_collected_inr"], report["total_outstanding_inr"], report["collection_rate_pct"],
    )
    return {"status": "success", "report": report}


def run_month_end_closing_workflow(
    *,
    owner_id: int,
    period_start: str,
    period_end: str,
) -> Dict[str, Any]:
    """
    Execute the Month-End Closing workflow.

    period_start / period_end: YYYY-MM-01 strings bounding the reporting period.
    Returns a structured report with collection totals and per-property breakdown.
    """
    # Step 1
    collect_result = step_calculate_rent_collected(
        owner_id=owner_id, period_start=period_start, period_end=period_end
    )

    # Step 2
    outstanding_result = step_calculate_outstanding(
        owner_id=owner_id, period_start=period_start, period_end=period_end
    )

    # Step 3
    summary = step_generate_landlord_summary(
        collected_by_lease=collect_result["collected_by_lease"],
        outstanding=outstanding_result["outstanding"],
        total_collected=collect_result["total_collected"],
        total_outstanding=outstanding_result["total_outstanding"],
        period_start=period_start,
        period_end=period_end,
    )

    # Step 4
    report_result = step_create_reports(summary=summary)

    return {
        **report_result,
        "steps": {
            "calculate_rent_collected": {"total": collect_result["total_collected"]},
            "calculate_outstanding": {"total": outstanding_result["total_outstanding"]},
            "generate_landlord_summary": {"property_count": len(summary["property_summaries"])},
            "create_reports": {"status": "success"},
        },
    }
