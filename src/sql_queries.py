CREATE_USER = """ 
                  INSERT INTO users (email) VALUES (%s)
                  ON CONFLICT (email) DO NOTHING
                  RETURNING id;
              """

FETCH_USER = """
                SELECT id FROM users WHERE email = %s;
            """

AUTH_SESSION = """
INSERT INTO sessions (session_id, user_id, expires_at)
VALUES (%s, %s, %s)
"""

GET_USER_FROM_SESSION = """
    SELECT user_id FROM sessions
    WHERE session_id = %s
    ORDER BY created_at DESC
    LIMIT 1
"""

CHECK_ONBOARDED = """
    SELECT onboarded FROM users WHERE id = %s;
"""

CHECK_DUPLICATE_AADHAAR = """
    SELECT id FROM user_profiles 
    WHERE aadhaar = %s
"""

CHECK_DUPLICATE_PAN = """
    SELECT id FROM user_profiles 
    WHERE pan = %s
"""

INSERT_USER_PROFILE = """
INSERT INTO user_profiles
  (user_id, role, first_name, last_name, aadhaar, pan, date_of_birth)
VALUES
  (%s, %s, %s, %s, %s, %s, %s)
ON CONFLICT (user_id) DO UPDATE
SET role          = EXCLUDED.role,
    first_name    = EXCLUDED.first_name,
    last_name     = EXCLUDED.last_name,
    aadhaar       = EXCLUDED.aadhaar,
    pan           = EXCLUDED.pan,
    date_of_birth = EXCLUDED.date_of_birth
RETURNING id;
"""

MARK_USER_ONBOARDED = """
    UPDATE users 
    SET onboarded = TRUE
    WHERE id = %s
"""

GET_USER_PROFILE = """
        SELECT first_name, last_name, aadhaar, pan, date_of_birth
        FROM user_profiles
        WHERE user_id = %s;
    """

GET_PROPERTIES = "SELECT * FROM properties WHERE id = %s"