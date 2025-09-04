VERIFY_OTP = """
    SELECT user_id, otp, expiry, used 
    FROM otp_codes 
    WHERE session_token = %s AND used = 0 
    ORDER BY expiry DESC 
    LIMIT 1
"""

UPDATE_OTP ="""
               UPDATE otp_codes SET used = 1 WHERE session_token = %s AND user_id = %s
            """

STORE_OTP = """
              INSERT INTO otp_codes (user_id, otp, session_token, expiry) VALUES (%s, %s, %s, %s)
            """


CREATE_USER = """ 
                  INSERT INTO users (email) VALUES (%s)
                  ON CONFLICT (email) DO NOTHING
                  RETURNING id;
              """

FETCH_USER = """
                SELECT id FROM users WHERE email = %s;
            """

AUTH_SESSION = """
            INSERT INTO sessions (session_id, user_id) VALUES (%s, %s)
        """

GET_USER_FROM_SESSION = """
    SELECT user_id FROM otp_codes 
    WHERE session_token = %s AND used = 1 
    ORDER BY created_at DESC 
    LIMIT 1
"""

CHECK_ONBOARDED = """
    SELECT id, role FROM user_profiles 
    WHERE user_id = %s
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
    (user_id, first_name, last_name, aadhaar, pan, date_of_birth, role)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
"""

MARK_USER_ONBOARDED = """
    UPDATE users 
    SET onboarded = 1 
    WHERE id = %s
"""

GET_USER_PROFILE = """
        SELECT first_name, last_name, aadhaar, pan, date_of_birth,role
        FROM user_profiles
        WHERE user_id = %s;
    """

ADD_PROPERTY = """INSERT INTO properties (name, address, city, landlord_id, status)
                VALUES (%s, %s, %s, %s, %s)
                """

DELETE_PROPERTY = "DELETE FROM properties WHERE id = %s"

ADD_UTILITY = """
INSERT INTO utilities (property_id, type, provider, account_number, status, last_bill_amt, next_due_date)
VALUES (%s, %s, %s, %s, %s, %s, %s);
"""

DELETE_UTILITY = """
DELETE FROM utilities WHERE id = %s;
"""

GET_PROPERTIES = "SELECT * FROM properties WHERE id = %s"