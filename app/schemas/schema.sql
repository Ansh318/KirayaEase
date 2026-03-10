-- =========================
-- AUTH / IDENTITY
-- =========================

CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  first_name    TEXT,
  last_name     TEXT,
  onboarded     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS sessions (
  session_id    TEXT PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL
);


-- =========================
-- PROPERTIES
-- =========================

CREATE TABLE IF NOT EXISTS properties (
  id             BIGSERIAL PRIMARY KEY,
  owner_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  name           TEXT NOT NULL,           -- "Maple Apartments #302"
  tenant_name    TEXT,                    -- simple MVP tenant tracking

  address_line1  TEXT,
  city           TEXT,
  state          TEXT,
  postal_code    TEXT,

  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_properties_owner
ON properties(owner_id);


-- =========================
-- LEASES
-- =========================

CREATE TABLE IF NOT EXISTS leases (
  id               BIGSERIAL PRIMARY KEY,
  property_id      BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,

  lease_text       TEXT,
  pdf_url          TEXT,
  lease_start      DATE NOT NULL,
  lease_end        DATE NOT NULL,

  monthly_rent     INTEGER NOT NULL,
  security_deposit INTEGER,
  lock_in_period   INTEGER,

  due_day          INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),

  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','expired','terminated')),

  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_lease_dates CHECK (lease_end > lease_start),
  CONSTRAINT chk_rent_positive CHECK (monthly_rent > 0)
);

CREATE INDEX idx_leases_property
ON leases(property_id);


-- =========================
-- RENT CONFIRMATIONS
-- =========================

CREATE TABLE IF NOT EXISTS rent_confirmations (
  id            BIGSERIAL PRIMARY KEY,

  lease_id      BIGINT NOT NULL REFERENCES leases(id) ON DELETE CASCADE,
  confirmed_by  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  month         DATE NOT NULL,           -- example: 2026-03-01
  amount        INTEGER NOT NULL,

  status        TEXT NOT NULL
                CHECK (status IN ('pending','confirmed')),

  confirmed_at  TIMESTAMPTZ,

  notes         TEXT,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_amount_pos CHECK (amount > 0),

  UNIQUE (lease_id, month)  -- prevents duplicate confirmations
);


CREATE INDEX idx_rent_confirmations_lease
ON rent_confirmations(lease_id);

CREATE INDEX idx_rent_confirmations_month
ON rent_confirmations(month);