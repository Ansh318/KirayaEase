-- =========================
-- AUTH / IDENTITY
-- =========================

CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  onboarded     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id        BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  role          TEXT NOT NULL CHECK (role IN ('tenant','landlord')),
  first_name     TEXT NOT NULL,
  last_name      TEXT NOT NULL,
  aadhaar        TEXT UNIQUE,
  pan            TEXT UNIQUE,
  date_of_birth  DATE NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id    TEXT PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL
);


-- -- Session context + message history for agentic conversations
-- CREATE TABLE IF NOT EXISTS chat_sessions (
--   session_id         TEXT PRIMARY KEY,
--   user_id            BIGINT REFERENCES users(id) ON DELETE SET NULL,
--   user_role          TEXT NOT NULL DEFAULT 'tenant' CHECK (user_role IN ('tenant','landlord')),
--   active_scope       TEXT NOT NULL DEFAULT 'self' CHECK (active_scope IN ('self','portfolio','tenant')),
--   active_tenant_id   TEXT,
--   created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
--   updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- CREATE TABLE IF NOT EXISTS chat_messages (
--   id             BIGSERIAL PRIMARY KEY,
--   session_id     TEXT NOT NULL REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
--   role           TEXT NOT NULL CHECK (role IN ('user','assistant','system')),
--   content        TEXT NOT NULL,
--   metadata       JSONB NOT NULL DEFAULT '{}'::jsonb,
--   created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- -- Generic audit table for create/update/delete operations
-- CREATE TABLE IF NOT EXISTS operation_logs (
--   id             BIGSERIAL PRIMARY KEY,
--   user_id        BIGINT REFERENCES users(id) ON DELETE SET NULL,
--   session_id     TEXT REFERENCES chat_sessions(session_id) ON DELETE SET NULL,
--   entity_type    TEXT NOT NULL,
--   entity_id      TEXT,
--   operation      TEXT NOT NULL CHECK (operation IN ('create','update','delete')),
--   old_data       JSONB,
--   new_data       JSONB,
--   created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
-- );


-- =========================
-- CORE DOMAIN (optimized)
-- =========================

-- properties: owned by a user; carries landlord display name; no address_line2
CREATE TABLE IF NOT EXISTS properties (
  id             BIGSERIAL PRIMARY KEY,
  owner_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  landlord_name  TEXT NOT NULL,           -- display only; can also be derived from users/profile
  name           TEXT NOT NULL,           -- e.g., "Maple Apartments #302"
  address_line1  TEXT,
  city           TEXT,
  state          TEXT,
  postal_code    TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- leases: relationship between property and tenant
CREATE TABLE IF NOT EXISTS leases (
  id             BIGSERIAL PRIMARY KEY,
  property_id    BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenant_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lease_text     TEXT NOT NULL,
  lease_start    DATE NOT NULL,
  lease_end      DATE NOT NULL,
  monthly_rent   INTEGER NOT NULL,
  security_deposit INTEGER NOT NULL,
  lock_in_period   INTEGER NOT NULL,
  due_day        INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  status         TEXT NOT NULL DEFAULT 'inactive' CHECK (status IN ('active','inactive','expired')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Basic integrity checks
  CONSTRAINT chk_lease_dates CHECK (lease_end > lease_start),
  CONSTRAINT chk_monthly_rent_pos CHECK (monthly_rent > 0)
);

-- rent payments: tied to a lease
CREATE TABLE IF NOT EXISTS rent_payments (
  id             BIGSERIAL PRIMARY KEY,
  lease_id       BIGINT NOT NULL REFERENCES leases(id) ON DELETE CASCADE,
  amount         INTEGER NOT NULL,
  payment_date   TIMESTAMPTZ NOT NULL DEFAULT now(),
  status         TEXT NOT NULL CHECK (status IN ('paid','pending','failed')),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('UPI','Card','NetBanking','Wallet')),
  sender_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receipt_id     TEXT UNIQUE,
  CONSTRAINT chk_payment_amount_pos CHECK (amount > 0)
);
