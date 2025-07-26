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