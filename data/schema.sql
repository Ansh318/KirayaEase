-- =========================
-- AUTH / IDENTITY
-- =========================

CREATE TABLE IF NOT EXISTS users (
  id            BIGSERIAL PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  onboarded     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id    TEXT PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS otp_codes (
  id            BIGSERIAL PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  otp           TEXT NOT NULL,
  session_token TEXT UNIQUE NOT NULL,
  expiry        BIGINT NOT NULL,  -- UNIX epoch seconds
  used          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_profiles (
  id             BIGSERIAL PRIMARY KEY,
  user_id        BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_name     TEXT NOT NULL,
  last_name      TEXT NOT NULL,
  aadhaar        TEXT UNIQUE,
  date_of_birth  DATE NOT NULL
);


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
  lease_start    DATE NOT NULL,
  lease_end      DATE NOT NULL,
  monthly_rent   INTEGER NOT NULL,
  due_day        INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  status         TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired')),
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
  receipt_id     TEXT UNIQUE,
  CONSTRAINT chk_payment_amount_pos CHECK (amount > 0)
);
