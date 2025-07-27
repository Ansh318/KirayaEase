from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from otp_manager import OTPManager
import os, sqlite3, uuid
from dotenv import load_dotenv
from datetime import date
from onboarding import handle_user_onboarding

app = FastAPI()
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev only; in prod, restrict this
    allow_credentials=True,
    allow_methods=["*"],
)
db_path = os.getenv("DB_PATH")

class EmailRequest(BaseModel):
    email: str

class OTPVerification(BaseModel):
    session_token: str
    otp: str

class OnboardingRequest(BaseModel):
    session_token: str
    first_name: str
    last_name: str
    date_of_birth: date
    aadhar_card: str
    pan_number: str
    user_role: str

@app.post("/request-otp")
async def request_otp(request: EmailRequest):
    otp_manager = OTPManager()
    otp = otp_manager.generate_otp()
    user_id = otp_manager.create_fetch_user(request.email)
    session_token = otp_manager.store_otp(user_id, otp)
    otp_manager.send_email(request.email, otp)
    return {
        "success": True, 
        "session_token" : session_token,
         "message": "OTP sent to email"
    }

@app.post("/verify-otp")
async def verify_otp(request: OTPVerification):
    otp_manager = OTPManager()
    try:
        user_id = otp_manager.verify_otp(request.session_token, request.otp)
        session_id = otp_manager.create_login_session(user_id)
        return {
            "success": True, 
            "auth_token": session_id,
            "message": "OTP verified"
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    
@app.post('/user-onboarding')
async def onboard_user(request: OnboardingRequest):
    try:
        onboard_user = handle_user_onboarding(
            session_token = request.session_token,
            first_name = request.first_name,
            last_name = request.last_name, 
            dob = request.date_of_birth,
            aadhaar=  request.aadhar_card,
            pan = request.pan_number,
            role = request.user_role
        )
        return onboard_user
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


