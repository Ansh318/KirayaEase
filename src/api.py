from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from otp_manager import OTPManager
import os 
from dotenv import load_dotenv
load_dotenv()


app = FastAPI()
db_path = os.getenv("DB_PATH")

class OTPRequest(BaseModel):
    email: str
    otp: str

@app.post("/send-otp")
async def send_otp(request: OTPRequest):
    otp_manager = OTPManager()
    try:
        success = otp_manager.verify_otp(request.email, request.otp)
        return { "success": success }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))