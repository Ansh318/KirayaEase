import os
import time
import uuid
import random
import sqlite3
import smtplib

from dotenv import load_dotenv
from fastapi import HTTPException
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import requests
import psycopg2
# Load environment variables
load_dotenv()

# Internal modules
from templates import render_otp_email_html
from sql_queries import (
    VERIFY_OTP,
    STORE_OTP,
    CREATE_USER,
    FETCH_USER,
    UPDATE_OTP,
    AUTH_SESSION,
    CHECK_ONBOARDED
)

class OTPManager:
    def __init__(self):
        self.smtp_config = {
            "server": os.getenv("SMTP_SERVER"),
            "port": int(os.getenv("SMTP_PORT")),
            "username": os.getenv("SMTP_USERNAME"),
            "password": os.getenv("SMTP_PASSWORD"),
            "sender": os.getenv("SMTP_SENDER"),
        }
        self.db_path = os.getenv("DATABASE_URL")

    def generate_otp(self):
        return str(random.randint(100000, 999999))
    
    def store_otp(self, user_id, otp, validity_seconds=100000000000):
        expiry = int(time.time()) + validity_seconds
        session_token = str(uuid.uuid4())
        conn = psycopg2.connect(self.db_path)
        cursor = conn.cursor()
        cursor = conn.cursor()
        cursor.execute(STORE_OTP,(user_id, otp, session_token, expiry))
        conn.commit()
        return session_token

    def create_fetch_user(self, email):
        conn = psycopg2.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(CREATE_USER, (email,))
        conn.commit()

        cursor.execute(FETCH_USER, (email,))
        result = cursor.fetchone()

        if result:
            return result[0]
        else:
            raise ValueError("Failed to fetch or create user")

    def send_email(self, receiver_email, otp):
        try:
            smtp_server = self.smtp_config.get("server")
            smtp_port = self.smtp_config.get("port")
            username = self.smtp_config.get("username")
            password = self.smtp_config.get("password")
            sender_email = self.smtp_config.get("sender")

            msg = MIMEMultipart()
            msg["From"] = sender_email
            msg["To"] = receiver_email
            msg["Subject"] = "Your KirayaEase One-Time-Password"
            html_content = render_otp_email_html(otp,receiver_email)
            msg.attach(MIMEText(html_content, "html"))

            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(username, password)
                server.sendmail(sender_email, receiver_email, msg.as_string())
            return True
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error sending email: {e}")

    def verify_otp(self, session_token, user_otp):
        current_time = int(time.time())
        conn = psycopg2.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(VERIFY_OTP, (session_token,))
        result = cursor.fetchone()
        if not result:
            raise ValueError("No valid OTP found for this session")
        
        user_id, otp, expiry, = result[0], result[1], result[2]
        if current_time > expiry or otp != user_otp:
            raise ValueError("OTP has expired or is invalid")
        
        cursor.execute(UPDATE_OTP, (session_token, user_id)) 
        conn.commit()
        return user_id

    def create_login_session(self, user_id):
        session_id = str(uuid.uuid4())
        conn = psycopg2.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(AUTH_SESSION, (session_id, user_id))
        conn.commit()
        return session_id

    def check_onboarding(self, user_id):
        conn = psycopg2.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(CHECK_ONBOARDED, (user_id,))
        result = cursor.fetchone()
        if result:
            id, role = result[0], result[1]
            return True, role
        else:
            return False, 'None'
         
# otp_manager = OTPManager()
# otp = otp_manager.generate_otp()
# # # otp_manager.store_otp("ansh.agarwal2712@gmail.com",otp)
# otp_manager.send_email("ansh.agarwal2712@gmail.com", otp)
# # otp_manager.verify_otp('ansh.agarwal2712@gmail.com', '935136')