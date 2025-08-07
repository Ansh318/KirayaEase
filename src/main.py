from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from otp_manager import OTPManager
import os, sqlite3, uuid
from dotenv import load_dotenv
from datetime import date
from onboarding import handle_user_onboarding, get_user_by_token
import razorpay
import warnings
warnings.filterwarnings("ignore", category=UserWarning)

razorpay_client = razorpay.Client(
    auth=(os.getenv("RAZORPAY_TEST_KEY_ID"), os.getenv("RAZORPAY_KEY_SECRET"))
)

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

class CreateOrderRequest(BaseModel):
    amount: float
    receipt_id: str = "receipt_auto"

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
        onboarded_bool, role = otp_manager.check_onboarding(user_id)
        print(user_id, session_id, role)
        print(role, onboarded_bool)
        return {
            "success": True, 
            "session_token": session_id,
            "message": "OTP verified",
            "onboarded": onboarded_bool,
            "user_role": role
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


@app.get('/user-profile')
def get_user_profile(authorization: str = Header(...)):
    session_token = authorization.replace("Bearer ", "").strip()
    user_profile = get_user_by_token(session_token)
    if not user_profile:
        raise HTTPException(status_code=401, detail = 'Invalid user')
    return user_profile


@app.post('/create-payment-order')
def create_payment(request: CreateOrderRequest, currency = "INR", payment_capture = True):
    order_data = {
        "amount": request.amount, 
        "currency": currency,
        "receipt": request.receipt_id,
        "payment_capture": (payment_capture)
    }
    order = razorpay_client.order.create(data=order_data)
    return order

