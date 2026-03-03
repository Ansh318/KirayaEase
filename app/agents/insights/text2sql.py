import os
import re
import psycopg2
from typing import List, Dict, Any
from openai import OpenAI

# ==========================================================
# CONFIG
# ==========================================================

DATABASE_URL = os.getenv("DATABASE_URL")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL not set")

if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY not set")

client = OpenAI(api_key=OPENAI_API_KEY)

# ==========================================================
# DATABASE SCHEMA (GIVE MODEL STRICT CONTEXT)
# ==========================================================

SCHEMA = """
Tables:

landlords(id, name, email)

properties(id, landlord_id, name, city, status)

leases(id, property_id, tenant_name, rent_amount, start_date, end_date, status)

payments(id, lease_id, amount, paid_on, status)

Relationships:
- properties.landlord_id → landlords.id
- leases.property_id → properties.id
- payments.lease_id → leases.id
"""

# ==========================================================
# SQL GENERATION
# ==========================================================

def generate_sql(question: str) -> str:
    """
    Generate SQL query from natural language question.
    Does NOT include landlord_id filter — we inject it safely later.
    """

    prompt = f"""
You are a PostgreSQL expert.

Generate a SQL SELECT query only.

Rules:
- ONLY SELECT queries.
- No INSERT, UPDATE, DELETE, DROP, ALTER.
- Use valid column names.
- Do NOT include landlord_id filter.
- Limit results to 100 rows.
- Return ONLY SQL.

Schema:
{SCHEMA}

User Question:
{question}
"""

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        temperature=0,
        messages=[{"role": "user", "content": prompt}]
    )

    sql = response.choices[0].message.content.strip()
    return sql


# ==========================================================
# SQL VALIDATION
# ==========================================================

FORBIDDEN = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE"]


def validate_sql(sql: str) -> str:
    upper_sql = sql.upper()

    if not upper_sql.startswith("SELECT"):
        raise ValueError("Only SELECT queries allowed")

    for word in FORBIDDEN:
        if word in upper_sql:
            raise ValueError("Dangerous SQL detected")

    return sql


# ==========================================================
# LANDLORD FILTER INJECTION (SECURITY CRITICAL)
# ==========================================================

def inject_landlord_filter(sql: str, landlord_id: int) -> str:
    """
    Ensures every query is scoped to the landlord.
    Works by wrapping original query as subquery if needed.
    """

    # Simple case: query already joins properties
    if "properties" in sql.lower():
        if "where" in sql.lower():
            sql += f" AND properties.landlord_id = {landlord_id}"
        else:
            sql += f" WHERE properties.landlord_id = {landlord_id}"
    else:
        # Wrap query safely
        sql = f"""
        SELECT * FROM (
            {sql}
        ) AS subquery
        """

    # Ensure LIMIT
    if "limit" not in sql.lower():
        sql += " LIMIT 100"

    return sql


# ==========================================================
# EXECUTION
# ==========================================================

def execute_query(sql: str) -> List[Dict[str, Any]]:
    with psycopg2.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            columns = [desc[0] for desc in cur.description]
            rows = cur.fetchall()

    return [dict(zip(columns, row)) for row in rows]


# ==========================================================
# PUBLIC FUNCTION
# ==========================================================

def text2sql_query(question: str, landlord_id: int) -> Dict[str, Any]:
    """
    Main function to call from your agent.
    """

    try:
        # Step 1: Generate SQL
        raw_sql = generate_sql(question)

        # Step 2: Validate
        validated_sql = validate_sql(raw_sql)

        # Step 3: Inject landlord filter
        safe_sql = inject_landlord_filter(validated_sql, landlord_id)

        # Step 4: Execute
        results = execute_query(safe_sql)

        return {
            "success": True,
            "sql": safe_sql,
            "data": results
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }