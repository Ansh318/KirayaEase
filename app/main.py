from fastapi import FastAPI, HTTPException, Header, Request, Query
from app.api.v1 import auth, onboarding, agent_chat
from app.services.onboarding_services import UserService

app = FastAPI()
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev only; in prod, restrict this
    allow_credentials=True,
    allow_methods=["*"],
)
app.include_router(auth.router)
app.include_router(onboarding.router)
app.include_router(agent_chat.router)
# app.include_router(payments.router)
# app.include_router(digio.router)
# app.include_router(agent_chat.router)
# DATABASE_URL = os.getenv("DATABASE_URL")
# razorpay_service = RazorpayPaymentService()

@app.get("/")
def health_check():
    return {"status": "KirayaEase API running"}

