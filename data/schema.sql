
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
  role TEXT NOT NULL CHECK(role IN ('tenant','landlord','manager')),
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