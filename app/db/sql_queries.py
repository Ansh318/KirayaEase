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
    aadhaar       = COALESCE(EXCLUDED.aadhaar, user_profiles.aadhaar),
    pan           = COALESCE(EXCLUDED.pan, user_profiles.pan),
    date_of_birth = COALESCE(EXCLUDED.date_of_birth, user_profiles.date_of_birth);
"""

MARK_USER_ONBOARDED = """
    UPDATE users 
    SET onboarded = TRUE
    WHERE id = %s
"""

GET_USER_PROFILE = """
        SELECT first_name, last_name, aadhaar, pan, date_of_birth, role
        FROM user_profiles
        WHERE user_id = %s;
    """

GET_PROPERTIES = "SELECT * FROM properties WHERE id = %s"

ADD_PROPERTY = """INSERT INTO properties (
                    owner_id,
                    landlord_name,
                    name,
                    address_line1,
                    city,
                    state,
                    postal_code
                )
                VALUES (%s,%s,%s,%s,%s,%s,%s)
                RETURNING id
            """


DELETE_USER_PROFILE = """
    DELETE FROM user_profiles WHERE user_id = %s
"""

DELETE_SESSION = """
    DELETE FROM sessions WHERE user_id = %s
"""

DELETE_USER = """
    DELETE FROM users WHERE id = %s
"""