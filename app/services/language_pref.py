"""Language preference helpers for multilingual chat replies."""
from __future__ import annotations

import re
from typing import Optional


_DEVANAGARI_RE = re.compile(r"[\u0900-\u097F]")


def _infer_from_text(message: str) -> Optional[str]:
    msg = (message or "").strip()
    if not msg:
        return None
    if _DEVANAGARI_RE.search(msg):
        return "Hindi"
    low = msg.lower()
    if any(k in low for k in (" hindi ", "hinglish", "हिंदी", "हिन्दी")):
        return "Hindi"
    return "English"


def response_language_instruction(
    message: str,
    preferred_language: Optional[str] = None,
) -> str:
    """
    Returns a short instruction to control response language.
    Priority: explicit client preference, otherwise inferred from message script/text.
    """
    preferred = (preferred_language or "").strip()
    lang = preferred or _infer_from_text(message) or "English"
    return (
        f"Respond in {lang}. If the user explicitly asks to switch language, follow that request."
    )
