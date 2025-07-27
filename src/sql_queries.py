VERIFY_OTP = """
    SELECT user_id, otp, expiry, used 
    FROM otp_codes 
    WHERE session_token = ? AND used = 0 
    ORDER BY expiry DESC 
    LIMIT 1
"""

UPDATE_OTP ="""
               UPDATE otp_codes SET used = 1 WHERE session_token = ? AND user_id = ?
            """

STORE_OTP = """
              INSERT INTO otp_codes (user_id, otp, session_token, expiry) VALUES (?, ?, ?, ?)
            """


CREATE_USER = """ 
                  INSERT OR IGNORE INTO users (email) VALUES (?);
              """

FETCH_USER = """
                SELECT id FROM users WHERE email = ?
            """

AUTH_SESSION = """
            INSERT INTO sessions (session_id, user_id) VALUES (?, ?)
        """

GET_USER_FROM_SESSION = """
    SELECT user_id FROM otp_codes 
    WHERE session_token = ? AND used = 1 
    ORDER BY created_at DESC 
    LIMIT 1
"""

CHECK_ONBOARDED = """
    SELECT id FROM user_profiles 
    WHERE user_id = ?
"""

CHECK_DUPLICATE_AADHAAR = """
    SELECT id FROM user_profiles 
    WHERE aadhaar = ?
"""

CHECK_DUPLICATE_PAN = """
    SELECT id FROM user_profiles 
    WHERE pan = ?
"""

INSERT_USER_PROFILE = """
    INSERT INTO user_profiles 
    (user_id, first_name, last_name, aadhaar, pan, date_of_birth, role)
    VALUES (?, ?, ?, ?, ?, ?, ?)
"""

MARK_USER_ONBOARDED = """
    UPDATE users 
    SET onboarded = 1 
    WHERE id = ?
"""