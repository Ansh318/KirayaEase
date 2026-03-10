# =========================
# AUTH / USERS
# =========================

CREATE_USER = """
INSERT INTO users (email)
VALUES (%s)
ON CONFLICT (email) DO NOTHING
RETURNING id;
"""


FETCH_USER = """
SELECT id
FROM users
WHERE email = %s;
"""


AUTH_SESSION = """
INSERT INTO sessions (session_id, user_id, expires_at)
VALUES (%s, %s, %s);
"""


GET_USER_FROM_SESSION = """
SELECT user_id
FROM sessions
WHERE session_id = %s
ORDER BY created_at DESC
LIMIT 1;
"""


CHECK_ONBOARDED = """
SELECT onboarded
FROM users
WHERE id = %s;
"""


MARK_USER_ONBOARDED = """
UPDATE users
SET onboarded = TRUE
WHERE id = %s;
"""


DELETE_SESSION = """
DELETE FROM sessions
WHERE user_id = %s;
"""


DELETE_USER = """
DELETE FROM users
WHERE id = %s;
"""


# =========================
# PROPERTIES
# =========================

ADD_PROPERTY = """
INSERT INTO properties (
    owner_id,
    name,
    tenant_name,
    address_line1,
    city,
    state,
    postal_code
)
VALUES (%s, %s, %s, %s, %s, %s, %s)
RETURNING id;
"""


GET_PROPERTY = """
SELECT *
FROM properties
WHERE id = %s;
"""


GET_PROPERTIES_BY_OWNER = """
SELECT *
FROM properties
WHERE owner_id = %s
ORDER BY created_at DESC;
"""


DELETE_PROPERTY = """
DELETE FROM properties
WHERE id = %s;
"""


# =========================
# LEASES
# =========================

ADD_LEASE = """
INSERT INTO leases (
    property_id,
    lease_text,
    lease_start,
    lease_end,
    monthly_rent,
    security_deposit,
    lock_in_period,
    due_day
)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
RETURNING id;
"""


GET_LEASE_BY_PROPERTY = """
SELECT *
FROM leases
WHERE property_id = %s
ORDER BY created_at DESC
LIMIT 1;
"""


GET_LEASE = """
SELECT *
FROM leases
WHERE id = %s;
"""


DELETE_LEASE = """
DELETE FROM leases
WHERE id = %s;
"""


GET_LEASES_BY_OWNER = """
SELECT
  l.id AS lease_id,
  l.property_id,
  l.lease_text,
  l.lease_start,
  l.lease_end,
  l.monthly_rent,
  l.security_deposit,
  l.lock_in_period,
  l.due_day,
  l.status AS lease_status,
  l.created_at AS lease_created_at,
  p.name AS property_name,
  p.tenant_name AS property_tenant_name,
  p.address_line1,
  p.city,
  p.state,
  p.postal_code
FROM leases l
JOIN properties p ON p.id = l.property_id
WHERE p.owner_id = %s
ORDER BY l.created_at DESC;
"""


# =========================
# RENT CONFIRMATIONS
# =========================

CREATE_RENT_CONFIRMATION = """
INSERT INTO rent_confirmations (
    lease_id,
    confirmed_by,
    month,
    amount,
    status
)
VALUES (%s, %s, %s, %s, %s)
RETURNING id;
"""


CONFIRM_RENT_PAYMENT = """
UPDATE rent_confirmations
SET status = 'confirmed',
    confirmed_at = NOW()
WHERE lease_id = %s
AND month = %s;
"""


GET_RENT_HISTORY = """
SELECT *
FROM rent_confirmations
WHERE lease_id = %s
ORDER BY month DESC;
"""


GET_PENDING_RENTS = """
SELECT *
FROM rent_confirmations
WHERE status = 'pending'
ORDER BY month ASC;
"""