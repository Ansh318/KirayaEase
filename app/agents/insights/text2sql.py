import os
import psycopg2
from typing import List, Dict, Any
from openai import OpenAI


class Text2SQLService:

    # ==========================================================
    # INIT
    # ==========================================================

    def __init__(self, database_url: str | None = None, openai_api_key: str | None = None):

        self.database_url = "postgres://u5udoe0pj32ic3:p38edfcbf488f7b83bfacc2bff33cabf1715e469e7ce649fdb9007920a92141fa@casrkuuedp6an1.cluster-czrs8kj4isg7.us-east-1.rds.amazonaws.com:5432/d1jragc2i7777k"
        self.openai_api_key = openai_api_key or os.getenv("OPENAI_API_KEY")

        if not self.database_url:
            raise RuntimeError("DATABASE_URL not set")

        if not self.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY not set")

        self.client = OpenAI(api_key=self.openai_api_key)

        self.forbidden = [
            "INSERT",
            "UPDATE",
            "DELETE",
            "DROP",
            "ALTER",
            "TRUNCATE"
        ]

        # ==========================================================
        # DATABASE SCHEMA CONTEXT FOR LLM
        # ==========================================================

        self.schema = """
DATABASE SCHEMA

users
- id (BIGSERIAL PRIMARY KEY)
- email (TEXT UNIQUE)
- onboarded (BOOLEAN)
- created_at (TIMESTAMPTZ)

user_profiles
- user_id (BIGINT PRIMARY KEY → users.id)
- role ('tenant','landlord')
- first_name
- last_name
- aadhaar
- pan
- date_of_birth

properties
- id (BIGSERIAL PRIMARY KEY)
- owner_id → users.id
- landlord_name
- name
- address_line1
- city
- state
- postal_code
- created_at

leases
- id (BIGSERIAL PRIMARY KEY)
- property_id → properties.id
- tenant_id → users.id
- lease_text
- lease_start
- lease_end
- monthly_rent
- security_deposit
- lock_in_period
- due_day
- status ('active','inactive','expired')

rent_payments
- id (BIGSERIAL PRIMARY KEY)
- lease_id → leases.id
- amount
- payment_date
- status ('paid','pending','failed')
- payment_method ('UPI','Card','NetBanking','Wallet')
- sender_id → users.id
- receiver_id → users.id
- receipt_id

RELATIONSHIPS

properties.owner_id → users.id

leases.property_id → properties.id
leases.tenant_id → users.id

rent_payments.lease_id → leases.id
rent_payments.sender_id → users.id
rent_payments.receiver_id → users.id
"""

    # ==========================================================
    # SQL GENERATION
    # ==========================================================

    def generate_sql(self, question: str) -> str:

        prompt = f"""
You are a PostgreSQL expert.

Generate a SQL SELECT query only.

Rules:
- ONLY SELECT queries
- No INSERT, UPDATE, DELETE, DROP, ALTER
- Use valid column names
- Do NOT include owner_id filter
- Limit results to 100 rows
- Return ONLY SQL

Schema:
{self.schema}

User Question:
{question}
"""

        response = self.client.chat.completions.create(
            model="gpt-4o-mini",
            temperature=0,
            messages=[{"role": "user", "content": prompt}]
        )

        sql = response.choices[0].message.content.strip()
        # remove markdown and semicolons
        sql = sql.replace("```sql", "").replace("```", "").strip()
        sql = sql.rstrip(";")
        return sql

    # ==========================================================
    # SQL VALIDATION
    # ==========================================================

    def validate_sql(self, sql: str) -> str:

        upper_sql = sql.upper()

        if not upper_sql.startswith("SELECT"):
            raise ValueError("Only SELECT queries allowed")

        for word in self.forbidden:
            if word in upper_sql:
                raise ValueError("Dangerous SQL detected")

        return sql

    # ==========================================================
    # LANDLORD FILTER INJECTION
    # ==========================================================

    def inject_landlord_filter(self, sql: str, landlord_id: int) -> str:

        sql = sql.strip().rstrip(";")

        sql_lower = sql.lower()

        if "properties" in sql_lower:

            if "where" in sql_lower:
                sql += f" AND properties.owner_id = {landlord_id}"
            else:
                sql += f" WHERE properties.owner_id = {landlord_id}"

        else:

            sql = f"""
            SELECT * FROM (
                {sql}
            ) AS subquery
            """

        if "limit" not in sql_lower:
            sql += " LIMIT 100"

        return sql

    # ==========================================================
    # DATABASE EXECUTION
    # ==========================================================

    def execute_query(self, sql: str) -> List[Dict[str, Any]]:

        with psycopg2.connect(self.database_url) as conn:

            with conn.cursor() as cur:

                cur.execute(sql)

                columns = [desc[0] for desc in cur.description]

                rows = cur.fetchall()

        return [dict(zip(columns, row)) for row in rows]

    # ==========================================================
    # PUBLIC METHOD
    # ==========================================================

    def query(self, question: str, landlord_id: int) -> Dict[str, Any]:

        try:

            raw_sql = self.generate_sql(question)

            validated_sql = self.validate_sql(raw_sql)

            safe_sql = self.inject_landlord_filter(validated_sql, landlord_id)

            results = self.execute_query(safe_sql)

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

# def main():

#     service = Text2SQLService()

#     question = "Show all my properties"

#     landlord_id = 1

#     result = service.query(
#         question=question,
#         landlord_id=landlord_id
#     )

#     print("\n--- RESULT ---\n")

#     if result["success"]:

#         print("SQL Generated:\n")
#         print(result["sql"])

#         print("\nData:\n")
#         for row in result["data"]:
#             print(row)

#     else:
#         print("Error:", result["error"])


# if __name__ == "__main__":
#     main()