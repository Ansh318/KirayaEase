PRAGMA foreign_keys = ON;

-- =========================
-- AUTH / IDENTITY
-- =========================

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  onboarded INTEGER NOT NULL DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS otp_codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  otp TEXT NOT NULL,
  session_token TEXT UNIQUE NOT NULL,
  expiry INTEGER NOT NULL,      -- UNIX timestamp
  used INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  aadhaar TEXT UNIQUE,
  pan TEXT UNIQUE,
  date_of_birth TEXT NOT NULL,  -- ISO8601 'YYYY-MM-DD'
  role TEXT NOT NULL CHECK(role IN ('landlord','tenant','property manager')),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =========================
-- CORE DOMAIN
-- =========================

-- PROPERTIES (owned by a landlord)
CREATE TABLE IF NOT EXISTS properties (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT NOT NULL,                      -- e.g. "Sunrise 204"
  address      TEXT NOT NULL,
  city         TEXT,
  landlord_id  INTEGER NOT NULL,
  STATUS TEXT NOT NULL,
  created_at   TEXT DEFAULT (datetime('now')),
  FOREIGN KEY(landlord_id) REFERENCES users(id) ON DELETE CASCADE
);

-- LEASES (one row per tenant agreement for a property)
CREATE TABLE IF NOT EXISTS leases (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  property_id   INTEGER NOT NULL,
  tenant_id     INTEGER NOT NULL,                  -- store tenant as FK
  tenant_name   TEXT NOT NULL,                     -- optional display copy
  lease_start   TEXT NOT NULL,                     -- 'YYYY-MM-DD'
  lease_end     TEXT,
  monthly_rent  INTEGER NOT NULL,
  due_day       INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  status        TEXT NOT NULL DEFAULT 'open'
                 CHECK (status IN ('open','active','expired','terminated')),
  created_at    TEXT DEFAULT (datetime('now')),
  FOREIGN KEY(property_id) REFERENCES properties(id) ON DELETE CASCADE,
  FOREIGN KEY(tenant_id) REFERENCES users(id) ON DELETE CASCADE
);

-- UTILITIES (tracked per property)
CREATE TABLE IF NOT EXISTS utilities (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  property_id     INTEGER NOT NULL,
  type            TEXT NOT NULL,                   -- 'electricity'|'water'|'gas'|'internet'
  provider        TEXT,
  account_number  TEXT,
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_bill_amt   INTEGER,
  next_due_date   TEXT,                            -- 'YYYY-MM-DD'
  created_at      TEXT DEFAULT (datetime('now')),
  FOREIGN KEY(property_id) REFERENCES properties(id) ON DELETE CASCADE
);

-- RENT PAYMENTS (tie to lease so history is clean)
CREATE TABLE IF NOT EXISTS rent_payments (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  lease_id      INTEGER NOT NULL,                  -- reference lease, not (tenant, property)
  amount        INTEGER NOT NULL,
  payment_date  TEXT NOT NULL DEFAULT (datetime('now')),
  status        TEXT NOT NULL CHECK(status IN ('paid','pending','failed')),
  receipt_id    TEXT UNIQUE,
  FOREIGN KEY(lease_id) REFERENCES leases(id) ON DELETE CASCADE
);
