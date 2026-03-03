from fastapi import APIRouter, HTTPException
from schemas.payment_schema import CreateOrderRequest, VerifyPaymentRequest
from services.payment_service import RazorpayPaymentService
import uuid

router = APIRouter()
payment_service = RazorpayPaymentService()


@router.post("/create-payment-order")
def create_payment(request: CreateOrderRequest):
    try:
        amount = request.amount

        # convert to rupees if sent in paise
        if amount >= 100:
            amount = amount / 100

        receipt_id = request.receipt_id
        if not receipt_id or receipt_id == "receipt_auto":
            receipt_id = f"rcpt_{uuid.uuid4().hex[:8]}"

        return payment_service.create_order(amount, receipt_id)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/verify-payment")
def verify_payment(request: VerifyPaymentRequest):
    try:
        payment_service.verify_payment_signature(
            request.order_id,
            request.payment_id,
            request.signature,
        )
        return {"success": True}
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid payment signature")