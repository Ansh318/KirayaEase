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
  date_of_birth  DATE NOT NULL,
);

-- =========================
-- CORE DOMAIN
-- =========================

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

-- rent payments (tie to lease so history is clean)
CREATE TABLE IF NOT EXISTS rent_payments (
  id            BIGSERIAL PRIMARY KEY,
  lease_id      BIGINT NOT NULL REFERENCES leases(id) ON DELETE CASCADE,
  amount        INTEGER NOT NULL,
  payment_date  TIMESTAMPTZ NOT NULL DEFAULT now(),
  status        TEXT NOT NULL CHECK (status IN ('paid','pending','failed')),
  receipt_id    TEXT UNIQUE
);