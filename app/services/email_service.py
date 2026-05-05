"""SMTP email sender for custom HTML emails."""

from __future__ import annotations

import os
import smtplib
from email.message import EmailMessage
from typing import Any, Dict


def send_html_email(
    *,
    to_email: str,
    subject: str,
    html_body: str,
) -> Dict[str, Any]:
    host = (os.getenv("SMTP_HOST") or "").strip()
    port_raw = (os.getenv("SMTP_PORT") or "587").strip()
    username = (os.getenv("SMTP_USERNAME") or "").strip()
    password = (os.getenv("SMTP_PASSWORD") or "").strip()
    from_email = (os.getenv("SMTP_FROM_EMAIL") or "").strip()
    use_tls = (os.getenv("SMTP_USE_TLS") or "true").strip().lower() in {"1", "true", "yes"}

    if not host or not from_email:
        return {
            "error": "missing_config",
            "detail": "Set SMTP_HOST and SMTP_FROM_EMAIL for custom HTML email sending.",
        }

    try:
        port = int(port_raw)
    except ValueError:
        return {"error": "invalid_config", "detail": "SMTP_PORT must be a valid integer."}

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_email
    msg["To"] = to_email
    msg.set_content("Please view this email in an HTML-capable client.")
    msg.add_alternative(html_body, subtype="html")

    try:
        with smtplib.SMTP(host, port, timeout=30) as server:
            if use_tls:
                server.starttls()
            if username:
                server.login(username, password)
            server.send_message(msg)
        return {"ok": True}
    except Exception as exc:
        return {"error": "smtp_send_failed", "detail": str(exc)}

