-- Remove SQLite-only pragmas
-- PRAGMA foreign_keys = ON;

-- =========================
-- AUTH / IDENTITY
-- =========================

-- users
CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  onboarded     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- sessions
CREATE TABLE IF NOT EXISTS sessions (
  session_id    TEXT PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- otp_codes
CREATE TABLE IF NOT EXISTS otp_codes (
  id            BIGSERIAL PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  otp           TEXT NOT NULL,
  session_token TEXT UNIQUE NOT NULL,
  expiry        BIGINT NOT NULL,  -- UNIX epoch seconds
  used          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- user_profiles
CREATE TABLE IF NOT EXISTS user_profiles (
  id             BIGSERIAL PRIMARY KEY,
  user_id        BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_name     TEXT NOT NULL,
  last_name      TEXT NOT NULL,
  aadhaar        TEXT UNIQUE,
  pan            TEXT UNIQUE,
  date_of_birth  DATE NOT NULL,
  role           TEXT NOT NULL CHECK (role IN ('landlord','tenant','property manager'))
);

-- =========================
-- CORE DOMAIN
-- =========================

-- properties (owned by a landlord)
CREATE TABLE IF NOT EXISTS properties (
  id           BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL,                        -- e.g. "Sunrise 204"
  address      TEXT NOT NULL,
  city         TEXT,
  landlord_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       TEXT NOT NULL,                        -- keep as free-text or add CHECK/ENUM later
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- leases (one row per tenant agreement for a property)
CREATE TABLE IF NOT EXISTS leases (
  id            BIGSERIAL PRIMARY KEY,
  property_id   BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenant_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- tenant is a user
  tenant_name   TEXT NOT NULL,                     -- optional display copy
  lease_start   DATE NOT NULL,
  lease_end     DATE,
  monthly_rent  INTEGER NOT NULL,
  due_day       INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','active','expired','terminated')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- utilities (tracked per property)
CREATE TABLE IF NOT EXISTS utilities (
  id              BIGSERIAL PRIMARY KEY,
  property_id     BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  type            TEXT NOT NULL,                   -- 'electricity'|'water'|'gas'|'internet'
  provider        TEXT,
  account_number  TEXT,
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_bill_amt   INTEGER,
  next_due_date   DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- rent payments (tie to lease so history is clean)
CREATE TABLE IF NOT EXISTS rent_payments (
  id            BIGSERIAL PRIMARY KEY,
  lease_id      BIGINT NOT NULL REFERENCES leases(id) ON DELETE CASCADE,
  amount        INTEGER NOT NULL,
  payment_date  TIMESTAMPTZ NOT NULL DEFAULT now(),
  status        TEXT NOT NULL CHECK (status IN ('paid','pending','failed')),
  receipt_id    TEXT UNIQUE
);