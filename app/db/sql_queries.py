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


UPDATE_USER_ONBOARDING = """
UPDATE users
SET first_name = %s, last_name = %s
WHERE id = %s;
"""


GET_USER_BY_ID = """
SELECT id, email, first_name, last_name, onboarded
FROM users
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
    tenant_phone,
    address_line1,
    city,
    state,
    postal_code
)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
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
    pdf_url,
    lease_start,
    lease_end,
    monthly_rent,
    security_deposit,
    lock_in_period,
    due_day
)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
RETURNING id;
"""


GET_LEASE_BY_PROPERTY = """
SELECT *
FROM leases
WHERE property_id = %s
ORDER BY created_at DESC
LIMIT 1;
"""


# Used to detect duplicate uploads: same owner + same property (by name or address+postal).
FIND_LEASE_BY_OWNER_AND_PROPERTY = """
SELECT l.id AS lease_id, p.name AS property_name
FROM leases l
JOIN properties p ON p.id = l.property_id
WHERE p.owner_id = %s
  AND (
    (TRIM(COALESCE(%s, '')) != '' AND LOWER(TRIM(p.name)) = LOWER(TRIM(%s)))
    OR
    (TRIM(COALESCE(%s, '')) != '' AND TRIM(COALESCE(%s, '')) != ''
     AND LOWER(TRIM(COALESCE(p.address_line1, ''))) = LOWER(TRIM(COALESCE(%s, '')))
     AND LOWER(TRIM(COALESCE(p.postal_code, ''))) = LOWER(TRIM(COALESCE(%s, ''))))
  )
ORDER BY l.created_at DESC
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
  l.pdf_url,
  l.lease_start,
  l.lease_end,
  l.monthly_rent,
  l.security_deposit,
  l.lock_in_period,
  l.due_day,
  l.status AS lease_status,
  l.created_at AS lease_created_at,
  l.docuseal_submission_id,
  l.docuseal_status,
  l.docuseal_signed_at,
  l.docuseal_combined_document_url,
  l.docuseal_submission_slug,
  l.docuseal_shared_link,
  l.docuseal_signing_url,
  p.name AS property_name,
  p.tenant_name AS property_tenant_name,
  p.tenant_phone,
  p.address_line1,
  p.city,
  p.state,
  p.postal_code
FROM leases l
JOIN properties p ON p.id = l.property_id
WHERE p.owner_id = %s
ORDER BY l.created_at DESC;
"""


GET_LEASE_DETAIL_FOR_OWNER = """
SELECT
  l.id AS lease_id,
  l.property_id,
  l.lease_text,
  l.pdf_url,
  l.lease_start,
  l.lease_end,
  l.monthly_rent,
  l.security_deposit,
  l.lock_in_period,
  l.due_day,
  l.status AS lease_status,
  l.created_at AS lease_created_at,
  l.docuseal_submission_id,
  l.docuseal_status,
  l.docuseal_signed_at,
  l.docuseal_combined_document_url,
  l.docuseal_submission_slug,
  l.docuseal_shared_link,
  l.docuseal_signing_url,
  p.name AS property_name,
  p.tenant_name AS property_tenant_name,
  p.tenant_phone,
  p.address_line1,
  p.city,
  p.state,
  p.postal_code
FROM leases l
JOIN properties p ON p.id = l.property_id
WHERE l.id = %s AND p.owner_id = %s
LIMIT 1;
"""


UPDATE_PROPERTY_FOR_OWNER = """
UPDATE properties p
SET
  name = %s,
  tenant_name = %s,
  tenant_phone = %s,
  address_line1 = %s,
  city = %s,
  state = %s,
  postal_code = %s
WHERE p.id = %s AND p.owner_id = %s
RETURNING p.id;
"""


UPDATE_LEASE_FOR_OWNER = """
UPDATE leases l
SET
  lease_start = %s,
  lease_end = %s,
  monthly_rent = %s,
  security_deposit = %s,
  lock_in_period = %s,
  due_day = %s
FROM properties p
WHERE l.id = %s
  AND l.property_id = p.id
  AND p.owner_id = %s
RETURNING l.id;
"""


UPSERT_USER_LEASE_DRAFT = """
INSERT INTO user_lease_drafts (user_id, draft_json, updated_at)
VALUES (%s, %s, now())
ON CONFLICT (user_id) DO UPDATE SET
  draft_json = EXCLUDED.draft_json,
  updated_at = now();
"""


GET_USER_LEASE_DRAFT = """
SELECT draft_json
FROM user_lease_drafts
WHERE user_id = %s
LIMIT 1;
"""


DELETE_USER_LEASE_DRAFT = """
DELETE FROM user_lease_drafts
WHERE user_id = %s;
"""


UPSERT_USER_LEASE_AGREEMENT_PREVIEW = """
INSERT INTO user_lease_agreement_previews (user_id, agreement_text, lease_fields_json, reference_prompt, updated_at)
VALUES (%s, %s, %s, %s, now())
ON CONFLICT (user_id) DO UPDATE SET
  agreement_text = EXCLUDED.agreement_text,
  lease_fields_json = EXCLUDED.lease_fields_json,
  reference_prompt = EXCLUDED.reference_prompt,
  updated_at = now();
"""


GET_USER_LEASE_AGREEMENT_PREVIEW = """
SELECT agreement_text, lease_fields_json, reference_prompt, updated_at
FROM user_lease_agreement_previews
WHERE user_id = %s
LIMIT 1;
"""


DELETE_USER_LEASE_AGREEMENT_PREVIEW = """
DELETE FROM user_lease_agreement_previews
WHERE user_id = %s;
"""


UPDATE_LEASE_TEXT_FOR_OWNER = """
UPDATE leases l
SET lease_text = %s
FROM properties p
WHERE l.id = %s
  AND l.property_id = p.id
  AND p.owner_id = %s
RETURNING l.id;
"""


UPDATE_LEASE_PDF_URL = """
UPDATE leases
SET pdf_url = %s
WHERE id = %s;
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


UPSERT_CONFIRM_RENT_PAYMENT = """
INSERT INTO rent_confirmations (lease_id, confirmed_by, month, amount, status, confirmed_at)
SELECT %s, %s, %s, l.monthly_rent, 'confirmed', NOW()
FROM leases l
WHERE l.id = %s
ON CONFLICT (lease_id, month)
DO UPDATE SET
  confirmed_by = EXCLUDED.confirmed_by,
  amount = EXCLUDED.amount,
  status = 'confirmed',
  confirmed_at = NOW();
"""


# =========================
# LEASE FILES (PDF storage)
# =========================

UPSERT_LEASE_FILE = """
INSERT INTO lease_files (lease_id, content, content_type)
VALUES (%s, %s, %s)
ON CONFLICT (lease_id)
DO UPDATE SET
  content = EXCLUDED.content,
  content_type = EXCLUDED.content_type,
  updated_at = NOW();
"""

GET_LEASE_FILE_FOR_OWNER = """
SELECT lf.content, COALESCE(lf.content_type, 'application/pdf') AS content_type
FROM lease_files lf
JOIN leases l ON l.id = lf.lease_id
JOIN properties p ON p.id = l.property_id
WHERE lf.lease_id = %s
  AND p.owner_id = %s
LIMIT 1;
"""

CHECK_LEASE_OWNERSHIP = """
SELECT 1
FROM leases l
JOIN properties p ON p.id = l.property_id
WHERE l.id = %s AND p.owner_id = %s
LIMIT 1;
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


GET_PENDING_RENTS_BY_OWNER = """
SELECT rc.*, p.name AS property_name, l.monthly_rent
FROM rent_confirmations rc
JOIN leases l ON l.id = rc.lease_id
JOIN properties p ON p.id = l.property_id
WHERE p.owner_id = %s AND rc.status = 'pending'
ORDER BY rc.month ASC;
"""


GET_RENT_CONFIRMATIONS_BY_OWNER = """
SELECT
  rc.id AS confirmation_id,
  rc.lease_id,
  rc.month,
  rc.amount,
  rc.status AS payment_status,
  rc.confirmed_at,
  rc.created_at,
  p.id AS property_id,
  p.name AS property_name,
  l.monthly_rent
FROM rent_confirmations rc
JOIN leases l ON l.id = rc.lease_id
JOIN properties p ON p.id = l.property_id
WHERE p.owner_id = %s
ORDER BY rc.month DESC, rc.created_at DESC;
"""


GET_CONFIRMED_LEASE_MONTHS_BY_OWNER = """
SELECT rc.lease_id, rc.month
FROM rent_confirmations rc
JOIN leases l ON l.id = rc.lease_id
JOIN properties p ON p.id = l.property_id
WHERE p.owner_id = %s AND rc.status = 'confirmed';
"""


UPDATE_PROPERTY_TENANT_PHONE = """
UPDATE properties
SET tenant_phone = %s
WHERE id = %s AND owner_id = %s
RETURNING id, tenant_phone;
"""


GET_LEASE_WITH_PROPERTY_FOR_OWNER = """
SELECT
  l.id AS lease_id,
  l.due_day,
  l.lease_end,
  l.status AS lease_status,
  l.monthly_rent,
  p.id AS property_id,
  p.owner_id,
  p.name AS property_name,
  p.tenant_phone
FROM leases l
JOIN properties p ON p.id = l.property_id
WHERE l.id = %s AND p.owner_id = %s
LIMIT 1;
"""


# =========================
# DocuSeal (e-sign) — lease signing
# =========================

UPDATE_LEASE_DOCUSEAL_SUBMISSION_FOR_OWNER = """
UPDATE leases l
SET
  docuseal_submission_id = %s,
  docuseal_status = %s,
  docuseal_signed_at = NULL,
  docuseal_combined_document_url = NULL,
  docuseal_submission_slug = %s,
  docuseal_shared_link = %s,
  docuseal_signing_url = %s
FROM properties p
WHERE l.id = %s
  AND l.property_id = p.id
  AND p.owner_id = %s
RETURNING l.id;
"""


UPDATE_LEASE_DOCUSEAL_FROM_WEBHOOK = """
UPDATE leases
SET
  docuseal_status = %s,
  docuseal_signed_at = COALESCE(%s::timestamptz, docuseal_signed_at),
  docuseal_combined_document_url = COALESCE(%s, docuseal_combined_document_url)
WHERE docuseal_submission_id = %s
RETURNING id;
"""


# =========================
# Agent chat memory (thread + long-term notes)
# =========================

INSERT_AGENT_CHAT_MESSAGE = """
INSERT INTO agent_chat_messages (thread_key, user_id, role, content)
VALUES (%s, %s, %s, %s);
"""


LIST_AGENT_CHAT_MESSAGES_RECENT = """
SELECT role, content
FROM agent_chat_messages
WHERE thread_key = %s
ORDER BY id DESC
LIMIT %s;
"""


GET_USER_AGENT_MEMORY_SUMMARY = """
SELECT summary
FROM user_agent_memory
WHERE user_id = %s
LIMIT 1;
"""


UPSERT_USER_AGENT_MEMORY_SUMMARY = """
INSERT INTO user_agent_memory (user_id, summary, updated_at)
VALUES (%s, %s, now())
ON CONFLICT (user_id) DO UPDATE SET
  summary = EXCLUDED.summary,
  updated_at = now();
"""