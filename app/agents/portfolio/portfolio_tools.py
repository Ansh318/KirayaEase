"""Portfolio and property listing tools for the agent."""
from datetime import date, datetime
import os

import psycopg2
from psycopg2.extras import RealDictCursor
from langchain_core.tools import tool

from app.schemas.property_manager import PropertyManager
from app.db.sql_queries import GET_LEASES_BY_OWNER


@tool
def get_my_properties(user_id: int) -> dict:
    """List all properties owned by the landlord. Use the landlord's user_id (current user). Call when the user asks for 'my properties', 'portfolio', 'list properties'."""
    items = PropertyManager().get_properties_by_owner(user_id)
    return {"properties": items, "count": len(items)}


@tool
def get_my_leases(user_id: int) -> dict:
    """List all leases for the landlord (across all their properties). Use the landlord's user_id. Call when the user asks for 'my leases', 'all leases', 'rent roll'."""
    conn = psycopg2.connect(os.getenv("DATABASE_URL"))
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(GET_LEASES_BY_OWNER, (user_id,))
        rows = cur.fetchall()
    conn.close()
    out = []
    for r in rows:
        d = dict(r)
        for k, v in d.items():
            if isinstance(v, (date, datetime)):
                d[k] = v.isoformat()
        out.append(d)
    return {"leases": out, "count": len(out)}
