"""WhatsApp Cloud API (Meta) — send template messages. Credentials from env."""
from __future__ import annotations

import logging
import os
from typing import Any, Dict, Optional

import requests

logger = logging.getLogger(__name__)

DEFAULT_GRAPH_VERSION = "v24.0"
# Heroku: WHATSAPP_PAT_TOKEN + PHONE_ID. Legacy fallbacks supported.
DEFAULT_TEMPLATE_NAME = "hello_world"


def _whatsapp_token() -> str:
    return (os.getenv("WHATSAPP_PAT_TOKEN") or os.getenv("WHATSAPP_TOKEN") or "").strip()


def _phone_number_id() -> str:
    return (os.getenv("PHONE_ID") or os.getenv("WHATSAPP_PHONE_NUMBER_ID") or "").strip()


def normalize_whatsapp_to_number(raw: str) -> str:
    """Keep digits only for Meta `to` field (E.164 without +)."""
    if not raw:
        return ""
    return "".join(c for c in raw.strip() if c.isdigit())


def normalize_whatsapp_e164(raw: str) -> str:
    """
    Normalize to digits-only for WhatsApp `to` (no leading +).
    Heuristics tuned for Indian leases: 10-digit mobiles starting 6–9 get country code 91.
    """
    if not raw:
        return ""
    s = "".join(c for c in str(raw).strip() if c.isdigit())
    if not s:
        return ""
    if s.startswith("00"):
        s = s[2:]
    # 10-digit Indian mobile
    if len(s) == 10 and s[0] in "6789":
        return "91" + s
    # 0 + 10-digit mobile
    if len(s) == 11 and s[0] == "0" and s[1] in "6789":
        return "91" + s[1:]
    # Already 91 + 10 digits
    if len(s) == 12 and s.startswith("91"):
        return s
    # Other lengths: pass through (international / already correct)
    return s


def _truncate_param_text(text: str, max_len: int = 1024) -> str:
    """WhatsApp body parameter text max length (safety)."""
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"


def send_rent_reminder_template_graph(
    phone: str,
    *,
    tenant_name: str,
    amount: str,
    property_name: str,
    due_date: str,
    template_name: str = "kirayaeaseonboarding",
    language_code: str = "en_US",
    graph_version: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Send the approved **kirayaeaseonboarding** rent reminder template using the same JSON shape
    as Meta's Cloud API examples (positional body parameters only).

    Credentials: ``WHATSAPP_PAT_TOKEN`` (or ``WHATSAPP_TOKEN``) + ``PHONE_ID`` (or ``WHATSAPP_PHONE_NUMBER_ID``).
    """
    token = _whatsapp_token()
    phone_number_id = _phone_number_id()
    if not token or not phone_number_id:
        return {
            "error": "missing_config",
            "detail": "Set WHATSAPP_PAT_TOKEN and PHONE_ID (or legacy WHATSAPP_TOKEN / WHATSAPP_PHONE_NUMBER_ID).",
        }

    to_digits = normalize_whatsapp_e164(phone)
    if not to_digits:
        return {"error": "invalid_to", "detail": "Phone number is empty after normalization."}

    ver = graph_version or os.getenv("WHATSAPP_GRAPH_VERSION") or DEFAULT_GRAPH_VERSION
    url = f"https://graph.facebook.com/{ver}/{phone_number_id}/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    payload: Dict[str, Any] = {
        "messaging_product": "whatsapp",
        "to": to_digits,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {"code": language_code},
            "components": [
                {
                    "type": "body",
                    "parameters": [
                        {"type": "text", "text": _truncate_param_text(str(tenant_name))},
                        {"type": "text", "text": _truncate_param_text(str(amount))},
                        {"type": "text", "text": _truncate_param_text(str(property_name))},
                        {"type": "text", "text": _truncate_param_text(str(due_date))},
                    ],
                }
            ],
        },
    }

    try:
        logger.info(
            "WhatsApp rent reminder POST graph_version=%s phone_number_id=%s to=%s template=%s lang=%s",
            ver,
            phone_number_id,
            to_digits,
            template_name,
            language_code,
        )
        resp = requests.post(url, headers=headers, json=payload, timeout=30)
        try:
            data = resp.json()
        except Exception:
            data = {"raw": (resp.text or "")[:4000]}
        logger.info(
            "WhatsApp rent reminder response status=%s body=%s",
            resp.status_code,
            data,
        )
        if resp.status_code >= 400:
            return {"error": "graph_api", "status_code": resp.status_code, "body": data}
        if not isinstance(data, dict):
            return {"error": "invalid_json", "body": data}
        contacts = data.get("contacts")
        messages = data.get("messages")
        if not isinstance(contacts, list) or not contacts:
            return {"error": "unexpected_success_response", "body": data}
        if not isinstance(messages, list) or not messages:
            return {"error": "unexpected_success_response", "body": data}
        m0 = messages[0] if isinstance(messages[0], dict) else {}
        message_id = m0.get("id")
        message_status = (m0.get("message_status") or "").strip() or "accepted"
        if not message_id:
            return {"error": "unexpected_success_response", "body": data}
        return {
            "ok": True,
            "queued": True,
            "message_id": message_id,
            "message_status": message_status,
            "body": data,
        }
    except requests.RequestException as e:
        logger.exception("WhatsApp rent reminder request failed: %s", e)
        return {"error": "request_failed", "detail": str(e)}


def send_whatsapp_template(
    to_number: str,
    template_name: str,
    *,
    language_code: str = "en_US",
    graph_version: Optional[str] = None,
    body_parameters: Optional[list[dict[str, str]]] = None,
) -> Dict[str, Any]:
    """
    POST /{phone-number-id}/messages with a WhatsApp template payload.

    For templates with body variables, pass ``body_parameters`` as a list of dicts,
    each with required ``text`` and optional ``parameter_name`` (for Meta *named*
    body variables). Omit ``parameter_name`` for purely positional templates.
    """
    token = _whatsapp_token()
    phone_number_id = _phone_number_id()
    if not token or not phone_number_id:
        return {
            "error": "missing_config",
            "detail": "Set WHATSAPP_PAT_TOKEN and PHONE_ID (or legacy WHATSAPP_TOKEN / WHATSAPP_PHONE_NUMBER_ID).",
        }

    to_digits = normalize_whatsapp_e164(to_number)
    if not to_digits:
        return {"error": "invalid_to", "detail": "Phone number is empty after normalization."}

    ver = graph_version or os.getenv("WHATSAPP_GRAPH_VERSION") or DEFAULT_GRAPH_VERSION
    url = f"https://graph.facebook.com/{ver}/{phone_number_id}/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    payload = {
        "messaging_product": "whatsapp",
        "to": to_digits,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {"code": language_code},
        },
    }
    if body_parameters:
        plist: list[Dict[str, Any]] = []
        for p in body_parameters:
            raw_text = str(p.get("text", ""))
            entry: Dict[str, Any] = {
                "type": "text",
                "text": _truncate_param_text(raw_text),
            }
            pname = (p.get("parameter_name") or "").strip()
            if pname:
                entry["parameter_name"] = pname
            plist.append(entry)
        payload["template"]["components"] = [{"type": "body", "parameters": plist}]
    try:
        resp = requests.post(url, headers=headers, json=payload, timeout=30)
        data = resp.json()
        if resp.status_code >= 400:
            return {"error": "graph_api", "status_code": resp.status_code, "body": data}
        contacts = data.get("contacts") if isinstance(data, dict) else None
        messages = data.get("messages") if isinstance(data, dict) else None
        if not isinstance(contacts, list) or not contacts:
            return {"error": "unexpected_success_response", "body": data}
        if not isinstance(messages, list) or not messages:
            return {"error": "unexpected_success_response", "body": data}
        m0 = messages[0] if isinstance(messages[0], dict) else {}
        message_id = m0.get("id")
        message_status = (m0.get("message_status") or "").strip() or "accepted"
        if not message_id:
            return {"error": "unexpected_success_response", "body": data}
        return {
            "ok": True,
            "queued": True,
            "message_id": message_id,
            "message_status": message_status,
            "body": data,
        }
    except requests.RequestException as e:
        return {"error": "request_failed", "detail": str(e)}
