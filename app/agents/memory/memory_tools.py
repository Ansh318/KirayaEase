"""Tools for explicit long-term user memory."""
from __future__ import annotations

from langchain_core.tools import tool

from app.services.user_agent_memory_store import append_memory_fact


@tool
def remember_user_fact(user_id: int, fact: str) -> dict:
    """Persist a short, stable fact about this user (preferences, timezone, how they name properties, reminders they asked you to remember). Use when they explicitly ask to remember something or share long-lived context. Do not store secrets or full lease terms — summarize."""
    ok = append_memory_fact(int(user_id), fact)
    if not ok:
        return {
            "status": "error",
            "message": "Could not save memory (missing user or database).",
        }
    return {
        "status": "saved",
        "message": "Fact saved to long-term memory for future chats.",
    }
