from fastapi import FastAPI, HTTPException, Header, Request, Query
from app.api.v1 import auth, onboarding, agent_chat, leases
from app.services.onboarding_services import UserService

app = FastAPI()
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev only; in prod, restrict this
    allow_credentials=True,
    allow_methods=["*"],
)
app.include_router(auth.router)
app.include_router(onboarding.router)
app.include_router(agent_chat.router)
app.include_router(leases.router)

# Serve uploaded PDFs (dev/simple prod). For durable storage, switch to S3/GCS.
_uploads_dir = os.path.abspath(os.path.join(os.getcwd(), "uploads"))
os.makedirs(_uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads_dir), name="uploads")
# app.include_router(payments.router)
# app.include_router(digio.router)
# app.include_router(agent_chat.router)
# DATABASE_URL = os.getenv("DATABASE_URL")
# razorpay_service = RazorpayPaymentService()

@app.get("/")
def health_check():
    return {"status": "KirayaEase API running"}

