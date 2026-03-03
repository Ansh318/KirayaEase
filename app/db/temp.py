
@app.on_event("startup")
def startup_db_checks():
    _ensure_runtime_schema()

CREATE_CHAT_SESSION_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS chat_sessions (
  session_id         TEXT PRIMARY KEY,
  user_id            BIGINT REFERENCES users(id) ON DELETE SET NULL,
  user_role          TEXT NOT NULL DEFAULT 'tenant' CHECK (user_role IN ('tenant','landlord')),
  active_scope       TEXT NOT NULL DEFAULT 'self' CHECK (active_scope IN ('self','portfolio','tenant')),
  active_tenant_id   TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""

CREATE_CHAT_MESSAGE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS chat_messages (
  id             BIGSERIAL PRIMARY KEY,
  session_id     TEXT NOT NULL REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
  role           TEXT NOT NULL CHECK (role IN ('user','assistant','system')),
  content        TEXT NOT NULL,
  metadata       JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""

CREATE_OPERATION_LOG_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS operation_logs (
  id             BIGSERIAL PRIMARY KEY,
  user_id        BIGINT REFERENCES users(id) ON DELETE SET NULL,
  session_id     TEXT REFERENCES chat_sessions(session_id) ON DELETE SET NULL,
  entity_type    TEXT NOT NULL,
  entity_id      TEXT,
  operation      TEXT NOT NULL CHECK (operation IN ('create','update','delete')),
  old_data       JSONB,
  new_data       JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""

def _get_db_connection():
    if not DATABASE_URL:
        return None
    return psycopg2.connect(DATABASE_URL)

def _ensure_runtime_schema():
    """
    Ensures runtime tables and backward-compatible columns exist on Postgres (Heroku).
    """
    conn = _get_db_connection()
    if conn is None:
        print("⚠️ DATABASE_URL not set. DB persistence/audit is disabled.")
        return
    try:
        with conn:
            with conn.cursor() as cursor:
                cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'tenant';")
                cursor.execute("ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS pan TEXT;")
                cursor.execute(CREATE_CHAT_SESSION_TABLE_SQL)
                cursor.execute(CREATE_CHAT_MESSAGE_TABLE_SQL)
                cursor.execute(CREATE_OPERATION_LOG_TABLE_SQL)
    except Exception as e:
        print(f"⚠️ Failed to ensure runtime schema: {e}")
    finally:
        conn.close()

def _get_user_id_from_session(cursor, session_id: str) -> Optional[int]:
    cursor.execute("SELECT user_id FROM sessions WHERE session_id = %s LIMIT 1;", (session_id,))
    row = cursor.fetchone()
    return row[0] if row else None

def _insert_operation_log(
    cursor,
    *,
    operation: str,
    entity_type: str,
    entity_id: Optional[str],
    user_id: Optional[int] = None,
    session_id: Optional[str] = None,
    old_data: Optional[dict] = None,
    new_data: Optional[dict] = None,
):
    cursor.execute(
        """
        INSERT INTO operation_logs (user_id, session_id, entity_type, entity_id, operation, old_data, new_data)
        VALUES (%s, %s, %s, %s, %s, %s, %s);
        """,
        (
            user_id,
            session_id,
            entity_type,
            entity_id,
            operation,
            Json(old_data) if old_data is not None else None,
            Json(new_data) if new_data is not None else None,
        ),
    )

def _persist_chat_exchange(request, response_text: str, payment_order_id: Optional[str], payment_amount: Optional[int]):
    conn = _get_db_connection()
    if conn is None:
        return
    try:
        with conn:
            with conn.cursor() as cursor:
                user_id = _get_user_id_from_session(cursor, request.session_id)
                cursor.execute(
                    """
                    INSERT INTO chat_sessions (session_id, user_id, user_role, active_scope, active_tenant_id)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (session_id)
                    DO UPDATE SET
                      user_id = COALESCE(EXCLUDED.user_id, chat_sessions.user_id),
                      user_role = EXCLUDED.user_role,
                      active_scope = EXCLUDED.active_scope,
                      active_tenant_id = EXCLUDED.active_tenant_id,
                      updated_at = now();
                    """,
                    (
                        request.session_id,
                        user_id,
                        request.user_role,
                        request.active_scope,
                        request.active_tenant_id,
                    ),
                )
                cursor.execute(
                    """
                    INSERT INTO chat_messages (session_id, role, content, metadata)
                    VALUES (%s, %s, %s, %s);
                    """,
                    (
                        request.session_id,
                        "user",
                        request.message,
                        Json({
                            "active_scope": request.active_scope,
                            "active_tenant_id": request.active_tenant_id,
                            "user_role": request.user_role,
                        }),
                    ),
                )
                cursor.execute(
                    """
                    INSERT INTO chat_messages (session_id, role, content, metadata)
                    VALUES (%s, %s, %s, %s);
                    """,
                    (
                        request.session_id,
                        "assistant",
                        response_text,
                        Json({
                            "payment_order_id": payment_order_id,
                            "payment_amount": payment_amount,
                        }),
                    ),
                )
                _insert_operation_log(
                    cursor,
                    operation="create",
                    entity_type="chat_exchange",
                    entity_id=request.session_id,
                    user_id=user_id,
                    session_id=request.session_id,
                    new_data={
                        "query": request.message,
                        "response": response_text,
                        "user_role": request.user_role,
                        "active_scope": request.active_scope,
                        "active_tenant_id": request.active_tenant_id,
                    },
                )
    except Exception as e:
        print(f"⚠️ Failed to persist chat exchange: {e}")
    finally:
        conn.close()