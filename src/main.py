from fastapi import FastAPI, HTTPException, Header, Request
from pydantic import BaseModel
from otp_manager import OTPManager
import os, sqlite3, uuid
from dotenv import load_dotenv
from datetime import date
from onboarding import handle_user_onboarding, get_user_by_token
import razorpay
import warnings
from typing import Optional, List
from pydantic import BaseModel, Field
warnings.filterwarnings("ignore", category=UserWarning)
# from chatbot import RentWiseAssistant
import os
from dotenv import load_dotenv
load_dotenv()
DIGIO_CLIENT_ID = os.getenv("DIGIO_CLIENT_ID")
DIGIO_CLIENT_SECRET = os.getenv("DIGIO_CLIENT_SECRET")
import requests
import base64,  binascii
from digio_integration import DigioClient
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from lease_extractor import extract_from_pdf
import json
import tempfile, os

MAX_FILE_MB = 20

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
        onboarded_bool = otp_manager.check_onboarding(user_id)
        print(user_id, session_id,)
        print(onboarded_bool)
        return {
            "success": True, 
            "session_token": session_id,
            "message": "OTP verified",
            "onboarded": onboarded_bool,
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
            aadhaar =  request.aadhar_card,
            pan = request.pan_number
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
    print(order)
    return order

class ChatResponse(BaseModel):
    response: str

# Request model
class ChatRequest(BaseModel):
    message: str

# assistant = RentWiseAssistant("gpt-4", temperature=0.7, max_retries=2)

# @app.post("/chatbot", response_model=ChatResponse)
# async def chat_with_ai(request: ChatRequest):
#     try:
#         output = assistant.run_chain(
#             prompt_id="System Prompt",
#             query=request.message
#         )
#         return {"response": output.get("text", str(output))}
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))


# Digio Model
class DigioKYC(BaseModel):
    session_token: str
    phone_number: str
    first_name: str
    last_name: str

@app.post('/digio-kyc')
async def initiate_digio(request: DigioKYC):
    full_name = request.first_name + " " + request.last_name
    body = {
        "customer_identifier": request.phone_number,
        "customer_name": full_name,
        "template_name": "KE_DIGILOCKER_INTEGRATION",
        "notify_customer": "false",
        "generate_acces_token": "true",
        "request_details": {}
    }
    digio = DigioClient()
    response = digio.initiate_kyc(body)
    return response

@app.post("/webhooks/digio")
async def digio_webhook(request: Request):
    raw = await request.body()
    payload = json.loads(raw.decode("utf-8"))
    print(payload)
    return payload

@app.post("/extract-lease-content")
async def extract_lease_content(file: UploadFile = File(...)):
    # 1) basic validation
    if not (file.filename or "").lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only .pdf files are supported.")

    # 2) stream upload to a temp file (works well with pypdf)
    total = 0
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            while True:
                chunk = await file.read(1024 * 1024)  # 1MB
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_FILE_MB * 1024 * 1024:
                    raise HTTPException(status_code=413, detail=f"File too large (>{MAX_FILE_MB}MB).")
                tmp.write(chunk)
            tmp_path = tmp.name
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to buffer uploaded file.")

    # 3) run LLM extractor on the saved path
    try:
        fields = extract_from_pdf(tmp_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Extraction failed: {e}")
    finally:
        try: os.remove(tmp_path)
        except Exception: pass
    print(fields)
    # 4) return fields to the frontend
    return JSONResponse({"fields": fields})
