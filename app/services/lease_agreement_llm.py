"""LLM-backed full lease agreement text generation."""
from __future__ import annotations

import json
import logging
from typing import Optional

from langchain_core.messages import HumanMessage, SystemMessage

from app.core.modelConfig import ModelConfigManager
from app.schemas.lease_write import LeaseWriteBody
from app.services.lease_agreement_template import DEFAULT_LEASE_AGREEMENT_TEMPLATE

logger = logging.getLogger(__name__)

_MAX_OUTPUT_CHARS = 48_000


def _strip_code_fences(text: str) -> str:
    t = (text or "").strip()
    if not t.startswith("```"):
        return t
    lines = t.split("\n")
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    return "\n".join(lines).strip()


def generate_lease_agreement_text(
    lease_body: LeaseWriteBody,
    reference_prompt: Optional[str] = None,
) -> str:
    """
    Produce plain-text lease agreement from structured facts + default template + optional customization.
    """
    llm = ModelConfigManager("gpt-4o-mini", 0.2, 3).model()
    facts = lease_body.model_dump(mode="json")
    system = """You draft residential lease agreements as plain text only (no markdown code fences).
Use clear section headings (ALL CAPS or numbered sections).
You must incorporate the FACTS accurately (names, dates, rent, deposit, due day, address).
Include a short disclaimer that this is not legal advice.
Use INR for currency. Be thorough but avoid repeating the same clause twice."""

    user_content = [
        "STRUCTURE TO FOLLOW (adapt as needed unless the landlord customization clearly overrides sections):\n",
        DEFAULT_LEASE_AGREEMENT_TEMPLATE,
        "\n\nFACTS (must appear accurately in the agreement):\n",
        json.dumps(facts, indent=2, default=str),
    ]
    ref = (reference_prompt or "").strip()
    if ref:
        user_content.append(
            "\n\nLANDLORD REFERENCE / CUSTOMIZATION (incorporate where reasonable; do not contradict FACTS):\n"
            + ref
        )
    else:
        user_content.append(
            "\n\nNo extra customization — use the default structure and standard residential terms."
        )

    try:
        resp = llm.invoke(
            [
                SystemMessage(content=system),
                HumanMessage(content="".join(user_content)),
            ]
        )
    except Exception as e:
        logger.exception("LLM lease agreement generation failed: %s", e)
        raise RuntimeError(f"Lease agreement generation failed: {e}") from e

    text = _strip_code_fences(
        resp.content if isinstance(resp.content, str) else str(resp.content or "")
    )
    if len(text) > _MAX_OUTPUT_CHARS:
        text = text[:_MAX_OUTPUT_CHARS] + "\n\n[Document truncated for maximum length.]"
    if len(text.strip()) < 200:
        raise RuntimeError("Generated agreement was too short; please retry.")
    return text


def generate_from_lease_dict(
    lease_fields: dict,
    reference_prompt: Optional[str] = None,
) -> str:
    body = LeaseWriteBody.model_validate(lease_fields)
    return generate_lease_agreement_text(body, reference_prompt=reference_prompt)
