"""Load and persist multi-turn agent chat for a thread (long-term conversation memory)."""
from __future__ import annotations

import os
from typing import List, Optional

import psycopg2
from langchain_core.messages import AIMessage, BaseMessage, HumanMessage

from app.db.sql_queries import INSERT_AGENT_CHAT_MESSAGE, LIST_AGENT_CHAT_MESSAGES_RECENT

# ~60 user/assistant pairs max before trim-by-chars kicks in
_MAX_ROWS = 120
_MAX_HISTORY_CHARS = 90_000


def build_thread_key(
    user_id: int,
    *,
    conversation_id: Optional[str] = None,
    anon_session_token: str = "",
) -> str:
    """
    Stable key for one conversation. Logged-in users default to one thread per user unless
    `conversation_id` is used to split (e.g. multiple chat tabs).
    Anonymous users are keyed by session token prefix.
    """
    conv = (conversation_id or "default").strip() or "default"
    if user_id and user_id > 0:
        return f"user:{user_id}:conv:{conv}"
    anon = (anon_session_token or "anon").strip() or "anon"
    # Bound length so thread_key stays reasonable
    safe = anon[:120] if len(anon) > 120 else anon
    return f"anon:{safe}:conv:{conv}"


def _trim_by_chars(messages: List[BaseMessage], max_chars: int) -> List[BaseMessage]:
    total = 0
    kept: List[BaseMessage] = []
    for m in reversed(messages):
        c = m.content if isinstance(m.content, str) else str(m.content or "")
        if total + len(c) > max_chars and kept:
            break
        kept.append(m)
        total += len(c)
    return list(reversed(kept))


def load_thread_messages(thread_key: str) -> List[BaseMessage]:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return []
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    LIST_AGENT_CHAT_MESSAGES_RECENT,
                    (thread_key, _MAX_ROWS),
                )
                rows = cur.fetchall()
    finally:
        conn.close()
    # Query returns newest first; flip to chronological
    rows.reverse()
    out: List[BaseMessage] = []
    for role, content in rows:
        text = content if isinstance(content, str) else str(content)
        if role == "human":
            out.append(HumanMessage(content=text))
        else:
            out.append(AIMessage(content=text))
    return _trim_by_chars(out, _MAX_HISTORY_CHARS)


def append_exchange(
    thread_key: str,
    user_id: Optional[int],
    user_text: str,
    assistant_text: str,
) -> None:
    """Persist one user message + one assistant reply (plain text)."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return
    uid = int(user_id) if user_id and user_id > 0 else None
    conn = psycopg2.connect(database_url)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    INSERT_AGENT_CHAT_MESSAGE,
                    (thread_key, uid, "human", user_text),
                )
                cur.execute(
                    INSERT_AGENT_CHAT_MESSAGE,
                    (thread_key, uid, "assistant", assistant_text),
                )
    finally:
        conn.close()
