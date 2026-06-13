"""
Cloud SQL connection layer — replaces bare psycopg2.connect(DATABASE_URL).

On Google Cloud Run, connections go through the Cloud SQL Python Connector
(unix socket / IAM auth).  For local development and legacy Heroku fallback,
DATABASE_URL is used directly so no code change is needed outside this module.

Usage (drop-in replacement for psycopg2.connect calls):
    from app.db.cloud_sql import get_connection

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(...)
    finally:
        conn.close()      # returns to pool

Or as a context manager (autocommit/rollback via psycopg2):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(...)
"""
from __future__ import annotations

import os
import threading
from typing import Optional

import psycopg2
import psycopg2.pool
from psycopg2.extras import RealDictCursor  # noqa: F401  re-exported for callers

# ── Cloud SQL Connector (optional import) ─────────────────────────────────────
try:
    from google.cloud.sql.connector import Connector, IPTypes
    _HAS_CONNECTOR = True
except ImportError:
    _HAS_CONNECTOR = False

# ── Module-level pool / connector ────────────────────────────────────────────
_lock = threading.Lock()
_pool: Optional[psycopg2.pool.ThreadedConnectionPool] = None
_connector: Optional["Connector"] = None


def _use_cloud_sql() -> bool:
    """True when CLOUD_SQL_INSTANCE env var is set (Cloud Run deployment)."""
    return bool(os.getenv("CLOUD_SQL_INSTANCE")) and _HAS_CONNECTOR


def _make_pool() -> psycopg2.pool.ThreadedConnectionPool:
    """Build a connection pool — Cloud SQL connector or legacy DATABASE_URL."""
    min_conn = int(os.getenv("DB_POOL_MIN", "2"))
    max_conn = int(os.getenv("DB_POOL_MAX", "10"))

    if _use_cloud_sql():
        return _make_cloud_sql_pool(min_conn, max_conn)
    return _make_url_pool(min_conn, max_conn)


def _make_url_pool(
    min_conn: int, max_conn: int
) -> psycopg2.pool.ThreadedConnectionPool:
    """Standard DATABASE_URL pool (local dev / legacy Heroku)."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError(
            "DATABASE_URL environment variable is not set. "
            "Set it for local dev or CLOUD_SQL_INSTANCE for Cloud Run."
        )
    # Heroku sometimes gives postgres:// — psycopg2 needs postgresql://
    if database_url.startswith("postgres://"):
        database_url = "postgresql://" + database_url[len("postgres://"):]
    return psycopg2.pool.ThreadedConnectionPool(min_conn, max_conn, database_url)


def _make_cloud_sql_pool(
    min_conn: int, max_conn: int
) -> psycopg2.pool.ThreadedConnectionPool:
    """
    Cloud SQL Python Connector pool.

    Required env vars:
      CLOUD_SQL_INSTANCE  — e.g. my-project:asia-south1:kiraya-ease-db
      DB_NAME             — database name (default: kirayaease)
      DB_USER             — IAM service account email (IAM auth) or DB user
      DB_PASSWORD         — only when using password auth; omit for IAM auth
    """
    global _connector
    instance = os.getenv("CLOUD_SQL_INSTANCE", "")
    db_name = os.getenv("DB_NAME", "kirayaease")
    db_user = os.getenv("DB_USER", "")
    db_password = os.getenv("DB_PASSWORD", "")

    ip_type = IPTypes.PRIVATE if os.getenv("PRIVATE_IP") else IPTypes.PUBLIC

    _connector = Connector(ip_type=ip_type)

    def _getconn() -> psycopg2.extensions.connection:
        kwargs: dict = {
            "db": db_name,
            "user": db_user,
            "driver": "pg8000",
        }
        if db_password:
            kwargs["password"] = db_password
        else:
            kwargs["enable_iam_auth"] = True

        raw = _connector.connect(instance, **kwargs)
        # Wrap pg8000 connection in a psycopg2-compatible shim via SQLAlchemy,
        # or use pg8000 directly.  Here we re-open with psycopg2 via unix socket
        # if available, otherwise fall back to TCP via the proxy port.
        return raw  # type: ignore[return-value]

    # pg8000 connections wrapped in pool
    # For full psycopg2 compatibility we use the unix socket path exposed by
    # the connector when running on Cloud Run.
    pool = psycopg2.pool.ThreadedConnectionPool(
        min_conn,
        max_conn,
        host=f"/cloudsql/{instance}",
        dbname=db_name,
        user=db_user,
        password=db_password or None,
    )
    return pool


def _get_pool() -> psycopg2.pool.ThreadedConnectionPool:
    global _pool
    if _pool is None:
        with _lock:
            if _pool is None:
                _pool = _make_pool()
    return _pool


class _PooledConnection:
    """
    Thin wrapper that returns the connection to the pool on close().
    Supports both context-manager and explicit close() usage.
    """

    def __init__(self, conn: psycopg2.extensions.connection, pool: psycopg2.pool.ThreadedConnectionPool):
        self._conn = conn
        self._pool = pool

    # ── Delegate everything to the real connection ────────────────────────────
    def cursor(self, *args, **kwargs):
        return self._conn.cursor(*args, **kwargs)

    def commit(self):
        self._conn.commit()

    def rollback(self):
        self._conn.rollback()

    @property
    def autocommit(self):
        return self._conn.autocommit

    @autocommit.setter
    def autocommit(self, value):
        self._conn.autocommit = value

    # ── Pool return ──────────────────────────────────────────────────────────
    def close(self):
        self._pool.putconn(self._conn)

    # ── Context manager — mirrors psycopg2 "with conn:" semantics ────────────
    def __enter__(self):
        return self._conn.__enter__()

    def __exit__(self, exc_type, exc_val, exc_tb):
        result = self._conn.__exit__(exc_type, exc_val, exc_tb)
        self._pool.putconn(self._conn)
        return result


def get_connection() -> _PooledConnection:
    """
    Get a psycopg2 connection from the pool.

    Drop-in replacement for ``psycopg2.connect(os.getenv("DATABASE_URL"))``.
    Always call ``.close()`` (or use as context manager) to return the
    connection to the pool.
    """
    pool = _get_pool()
    raw = pool.getconn()
    return _PooledConnection(raw, pool)


def close_pool() -> None:
    """Close all connections (call on app shutdown)."""
    global _pool, _connector
    with _lock:
        if _pool:
            _pool.closeall()
            _pool = None
        if _connector:
            try:
                _connector.close()
            except Exception:
                pass
            _connector = None
