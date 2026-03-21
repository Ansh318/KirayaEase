"""Build plain-text + PDF from manual lease form data (for RAG + in-app PDF viewer)."""
from __future__ import annotations

from io import BytesIO
from typing import List

from app.schemas.lease_write import LeaseWriteBody


def render_lease_document_text(body: LeaseWriteBody) -> str:
    """Structured text used for DB `lease_text` and Pinecone chunks."""
    lines: List[str] = [
        "RESIDENTIAL LEASE SUMMARY",
        "(Generated from KirayaEase manual entry — not a legal substitute for a full agreement.)",
        "",
        "PROPERTY",
        f"Name / unit: {body.property_name}",
    ]
    if body.address_line1:
        lines.append(f"Address: {body.address_line1}")
    parts = [p for p in [body.city, body.state, body.postal_code] if p]
    if parts:
        lines.append(f"Location: {', '.join(parts)}")
    lines.extend(["", "TENANT"])
    if body.tenant_name:
        lines.append(f"Name: {body.tenant_name}")
    if body.tenant_phone:
        lines.append(f"Contact (WhatsApp / phone): {body.tenant_phone}")
    lines.extend(
        [
            "",
            "LEASE TERMS",
            f"Start date: {body.lease_start.isoformat()}",
            f"End date: {body.lease_end.isoformat()}",
            f"Monthly rent: INR {body.monthly_rent}",
            f"Rent due day of month: {body.due_day}",
        ]
    )
    if body.security_deposit is not None:
        lines.append(f"Security deposit: INR {body.security_deposit}")
    if body.lock_in_period is not None:
        lines.append(f"Lock-in period: {body.lock_in_period} months")
    lines.extend(["", "The tenant agrees to pay rent on the due day each month for the term above."])
    return "\n".join(lines)


def render_lease_pdf_bytes(body: LeaseWriteBody) -> bytes:
    """Single-page (or multi-page) PDF summary for `GET /leases/{id}/pdf`."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import cm
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )
    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "T",
        parent=styles["Heading1"],
        fontSize=16,
        spaceAfter=12,
    )
    h2 = ParagraphStyle(
        "H2",
        parent=styles["Heading2"],
        fontSize=12,
        spaceBefore=10,
        spaceAfter=6,
    )
    normal = ParagraphStyle("N", parent=styles["Normal"], fontSize=10, leading=14)

    def esc(s: str) -> str:
        return (
            (s or "")
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )

    story: List = [
        Paragraph(esc("Residential lease summary (KirayaEase)"), title),
        Paragraph(
            esc(
                "This PDF was generated from your saved lease details. "
                "It is a summary for your records and in-app Q&A — not legal advice."
            ),
            normal,
        ),
        Spacer(1, 0.4 * cm),
        Paragraph(esc("Property"), h2),
        Paragraph(esc(body.property_name), normal),
    ]
    if body.address_line1:
        story.append(Paragraph(esc(body.address_line1), normal))
    loc = ", ".join(p for p in [body.city, body.state, body.postal_code] if p)
    if loc:
        story.append(Paragraph(esc(loc), normal))

    story.append(Paragraph(esc("Tenant"), h2))
    if body.tenant_name:
        story.append(Paragraph(esc(f"Name: {body.tenant_name}"), normal))
    if body.tenant_phone:
        story.append(Paragraph(esc(f"Phone: {body.tenant_phone}"), normal))

    story.append(Paragraph(esc("Terms"), h2))
    story.append(
        Paragraph(
            esc(
                f"Lease period: {body.lease_start.isoformat()} to {body.lease_end.isoformat()}"
            ),
            normal,
        )
    )
    story.append(Paragraph(esc(f"Monthly rent: ₹{body.monthly_rent}"), normal))
    story.append(Paragraph(esc(f"Rent due day: {body.due_day} of each month"), normal))
    if body.security_deposit is not None:
        story.append(Paragraph(esc(f"Security deposit: ₹{body.security_deposit}"), normal))
    if body.lock_in_period is not None:
        story.append(Paragraph(esc(f"Lock-in: {body.lock_in_period} months"), normal))

    doc.build(story)
    return buf.getvalue()


def render_plain_agreement_pdf_bytes(agreement_text: str) -> bytes:
    """Multi-page PDF from arbitrary plain-text agreement (LLM output)."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import cm
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )
    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "T",
        parent=styles["Heading1"],
        fontSize=14,
        spaceAfter=10,
    )
    normal = ParagraphStyle("N", parent=styles["Normal"], fontSize=9, leading=12)

    def esc(s: str) -> str:
        return (
            (s or "")
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )

    story: List = [
        Paragraph(esc("Residential lease agreement (KirayaEase)"), title),
        Paragraph(
            esc(
                "Generated text for your records and in-app Q&A. Not legal advice. "
                "Review with a qualified lawyer before signing."
            ),
            normal,
        ),
        Spacer(1, 0.3 * cm),
    ]
    for line in (agreement_text or "").split("\n"):
        if not line.strip():
            story.append(Spacer(1, 0.15 * cm))
        else:
            story.append(Paragraph(esc(line), normal))

    doc.build(story)
    return buf.getvalue()
