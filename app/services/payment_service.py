# app/services/payment_service.py

import razorpay
from core.config import settings


class RazorpayPaymentService:
    def __init__(self):
        if not settings.RAZORPAY_TEST_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
            raise RuntimeError("Missing Razorpay credentials.")

        self.client = razorpay.Client(
            auth=(settings.RAZORPAY_TEST_KEY_ID, settings.RAZORPAY_KEY_SECRET)
        )

    def create_order(self, amount_in_rupees: float, receipt_id: str):
        order_data = {
            "amount": int(amount_in_rupees * 100),
            "currency": "INR",
            "receipt": receipt_id,
            "payment_capture": 1,
        }

        return self.client.order.create(data=order_data)

    def verify_payment_signature(self, order_id: str, payment_id: str, signature: str):
        self.client.utility.verify_payment_signature(
            {
                "razorpay_order_id": order_id,
                "razorpay_payment_id": payment_id,
                "razorpay_signature": signature,
            }
        )
        return True