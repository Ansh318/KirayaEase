
-- OTP Codes
CREATE TABLE otp_codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  otp TEXT NOT NULL,
  session_token TEXT UNIQUE NOT NULL,
  expiry INTEGER NOT NULL,  -- store as UNIX timestamp
  used INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Users
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  onboarded INTEGER NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Sessions
CREATE TABLE sessions (
  session_id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(user_id) REFERENCES users(id)
);

-- User Profiles
CREATE TABLE user_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  aadhaar TEXT UNIQUE,
  pan TEXT UNIQUE,
  date_of_birth DATE NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('landlord','tenant','property manager')),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Properties
CREATE TABLE properties (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT NOT NULL,
  city TEXT,
  landlord_id INTEGER NOT NULL,
  rent_amount INTEGER NOT NULL,
  FOREIGN KEY(landlord_id) REFERENCES users(id)
);


-- Property Tenants (leases)
CREATE TABLE property_tenants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  property_id INTEGER NOT NULL,
  lease_start DATE NOT NULL,
  lease_end DATE,
  monthly_rent INTEGER NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  due_date DATE NOT NULL
  FOREIGN KEY(tenant_id) REFERENCES users(id),
  FOREIGN KEY(property_id) REFERENCES properties(id),
  UNIQUE(tenant_id, property_id, is_active) -- ensures one active lease per (tenant, property)
);

-- Rent Payments
CREATE TABLE rent_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  property_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status TEXT NOT NULL CHECK(status IN ('paid', 'pending', 'failed')),
  receipt_id TEXT UNIQUE,  -- new column for payment receipt/reference
  FOREIGN KEY(tenant_id) REFERENCES users(id),
  FOREIGN KEY(property_id) REFERENCES properties(id)
);
- =========================
-- CORE DOMAIN
-- =========================

-- PROPERTIES (owned by a landlord)
CREATE TABLE IF NOT EXISTS properties (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT NOT NULL,                      -- e.g. "Sunrise 204"
  address      TEXT NOT NULL,
  city         TEXT,
  landlord_id  INTEGER NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(landlord_id) REFERENCES users(id) ON DELETE CASCADE
);

-- LEASES (one row per tenant agreement for a property)
CREATE TABLE IF NOT EXISTS leases (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  property_id   INTEGER NOT NULL,
  tenant_id     INTEGER NOT NULL,                  -- FIXED: store tenant as FK, not just name
  tenant_name   TEXT NOT NULL,                     -- keep display name too (optional)
  lease_start   DATE NOT NULL,
  lease_end     DATE,
  monthly_rent  INTEGER NOT NULL,
  due_day       INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),  -- FIXED: was DATE
  status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'active','expired','terminated')),
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(property_id) REFERENCES properties(id) ON DELETE CASCADE,
  FOREIGN KEY(tenant_id) REFERENCES users(id) ON DELETE CASCADE
);

-- UTILITIES (tracked per property)
CREATE TABLE IF NOT EXISTS utilities (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  property_id     INTEGER NOT NULL,
  type            TEXT NOT NULL,                   -- 'electricity' | 'water' | 'gas' | 'internet'
  provider        TEXT,
  account_number  TEXT,
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  last_bill_amt   INTEGER,
  next_due_date   DATE,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(property_id) REFERENCES properties(id) ON DELETE CASCADE
);

-- RENT PAYMENTS (tie to lease so history is clean)
CREATE TABLE IF NOT EXISTS rent_payments (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  lease_id      INTEGER NOT NULL,                  -- FIXED: reference lease, not (tenant, property)
  amount        INTEGER NOT NULL,
  payment_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status        TEXT NOT NULL CHECK(status IN ('paid','pending','failed')),
  receipt_id    TEXT UNIQUE,
  FOREIGN KEY(lease_id) REFERENCES leases(id) ON DELETE CASCADE
);