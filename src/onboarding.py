import sqlite3
from fastapi import HTTPException
import os
from dotenv import load_dotenv
load_dotenv()

def handle_user_onboarding(session_token, first_name, last_name, dob, aadhaar, pan, role):
    # Step 1: Validate required fields
    if not (aadhaar or pan):
        raise HTTPException(status_code=400, detail="Aadhaar or PAN required")

    if role.lower() not in ("tenant", "landlord", "manager"):
        raise HTTPException(status_code=400, detail="Invalid role")

    # Step 2: Get user_id from session_token
    with sqlite3.connect(os.getenv("DATABASE_PATH")) as conn:
        cursor = conn.cursor()

        cursor.execute("SELECT user_id FROM sessions WHERE session_id = ?", (session_token,))
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=401, detail="Invalid or expired session")
        
        user_id = result[0]

        # Step 3: Check if user already onboarded
        cursor.execute("SELECT id FROM user_profiles WHERE user_id = ?", (user_id,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="User already onboarded")

        # Step 4: Aadhaar/PAN duplication checks
        if aadhaar:
            cursor.execute("SELECT id FROM user_profiles WHERE aadhaar = ?", (aadhaar,))
            if cursor.fetchone():
                raise HTTPException(status_code=409, detail="Aadhaar already in use")

        if pan:
            cursor.execute("SELECT id FROM user_profiles WHERE pan = ?", (pan,))
            if cursor.fetchone():
                raise HTTPException(status_code=409, detail="PAN already in use")

        # Step 5: Insert new user_profile
        cursor.execute("""
            INSERT INTO user_profiles (user_id, first_name, last_name, aadhaar, pan, date_of_birth, role)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, first_name, last_name, aadhaar, pan, dob, role.lower()))
        
        cursor.execute("""
            UPDATE users SET onboarded = 1 WHERE id = ?
        """, (user_id,))
        
        conn.commit()

    return {"success": True, "message": "User onboarded successfully"}
