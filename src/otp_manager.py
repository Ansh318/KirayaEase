import os 
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import random
import sqlite3
import time
from dotenv import load_dotenv
from templates import render_otp_email_html
load_dotenv()
from fastapi import HTTPException

class OTPManager:
    def __init__(self):
        self.smtp_config = {
            "server": os.getenv("SMTP_SERVER"),
            "port": int(os.getenv("SMTP_PORT")),
            "username": os.getenv("SMTP_USERNAME"),
            "password": os.getenv("SMTP_PASSWORD"),
            "sender": os.getenv("SMTP_SENDER"),
        }
        self.db_path = os.getenv("DATABASE_PATH")

    def generate_otp(self):
        range_start = 100000
        range_end = 999999
        return str(random.randint(range_start, range_end))
    
    def store_otp(self, email, otp, validity_seconds=300):
        expiry = int(time.time()) + validity_seconds
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO otp_codes (email, otp, expiry, used) VALUES (?, ?, ?, 0)",
                (email, otp, expiry)
            )
            conn.commit()

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
            msg["Subject"] = "Your KirayaEase OTP Code"
            html_content = render_otp_email_html(otp,receiver_email)
            msg.attach(MIMEText(html_content, "html"))

            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(username, password)
                server.sendmail(sender_email, receiver_email, msg.as_string())
            return True
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error sending email: {e}")

    def verify_otp(self, email, user_otp):
        current_time = int(time.time())
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT id, otp, expiry, used 
                FROM otp_codes 
                WHERE email = ? AND used = 0 
                ORDER BY expiry DESC 
                LIMIT 1
                """,
                (email,)
        )
            result = cursor.fetchone()
            if not result:
                raise ValueError("No valid OTP found for this email")
            
            otp_id, otp, expiry, used = result
            if current_time > expiry:
                raise ValueError("OTP has expired")
            if otp != user_otp:
                raise ValueError("Invalid OTP")
            cursor.execute("UPDATE otp_codes SET used = 1 WHERE id = ?", (otp_id,))
            conn.commit()
            return True



# otp_manager = OTPManager()
# otp = otp_manager.generate_otp()
# otp_manager.store_otp("aragarwal@wisc.edu",otp)
# otp_manager.send_email("aragarwal@wisc.edu", otp)