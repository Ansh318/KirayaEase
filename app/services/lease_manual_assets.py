"""Persist synthetic PDF + Pinecone RAG for manually created/edited leases."""
from __future__ import annotations

import logging
import os

import psycopg2

from app.db.sql_queries import UPSERT_LEASE_FILE
from app.db.vector_db_lease import LeaseDocumentProcessor
from app.schemas.lease_write import LeaseWriteBody
from app.schemas.property_manager import PropertyManager
from app.services.lease_synthetic_document import (
    render_lease_document_text,
    render_lease_pdf_bytes,
)

logger = logging.getLogger(__name__)


def persist_manual_lease_pdf_and_rag(
    *,
    lease_id: int,
    owner_id: int,
    body: LeaseWriteBody,
    public_base_url: str,
) -> None:
    """
    Store generated PDF in lease_files, set pdf_url, update lease_text, reindex Pinecone.
    Best-effort: logs and continues if PDF/RAG fails (lease row still valid).
    """
    text = render_lease_document_text(body)
    try:
        pdf_bytes = render_lease_pdf_bytes(body)
    except Exception as e:
        logger.exception("render_lease_pdf_bytes failed: %s", e)
        pdf_bytes = b""

    pm = PropertyManager()
    try:
        pm.update_lease_text_for_owner(owner_id=owner_id, lease_id=lease_id, lease_text=text)
    except Exception as e:
        logger.exception("update_lease_text_for_owner failed: %s", e)

    if pdf_bytes:
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            try:
                conn = psycopg2.connect(database_url)
                try:
                    with conn:
                        with conn.cursor() as cur:
                            cur.execute(
                                UPSERT_LEASE_FILE,
                                (
                                    int(lease_id),
                                    psycopg2.Binary(pdf_bytes),
                                    "application/pdf",
                                ),
                            )
                finally:
                    conn.close()
            except Exception as e:
                logger.exception("UPSERT_LEASE_FILE failed: %s", e)

        base = (public_base_url or "").rstrip("/")
        if base:
            try:
                pm.set_lease_pdf_url(int(lease_id), f"{base}/leases/{lease_id}/pdf")
            except Exception as e:
                logger.exception("set_lease_pdf_url failed: %s", e)

    try:
        proc = LeaseDocumentProcessor()
        proc.reindex_lease(str(lease_id), str(owner_id), text)
    except Exception as e:
        logger.exception("Lease RAG reindex failed: %s", e)
