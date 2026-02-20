import os
import warnings

import razorpay
from dotenv import load_dotenv

load_dotenv()
warnings.filterwarnings("ignore", category=UserWarning)


class RazorpayPaymentService:
    def __init__(self, key_id: str | None = None, key_secret: str | None = None):
        self.key_id = key_id or os.getenv("RAZORPAY_TEST_KEY_ID")
        self.key_secret = key_secret or os.getenv("RAZORPAY_KEY_SECRET")

        if not self.key_id or not self.key_secret:
            raise RuntimeError(
                "Missing Razorpay credentials. Set RAZORPAY_TEST_KEY_ID and RAZORPAY_KEY_SECRET."
            )

        self.client = razorpay.Client(auth=(self.key_id, self.key_secret))

    def create_order(
        self,
        amount_in_rupees: float | int,
        currency: str = "INR",
        receipt_id: str = "receipt#1",
        payment_capture: bool = True,
        notes: dict | None = None,
    ) -> dict:
        """
        Create a Razorpay order.

        Args:
            amount_in_rupees (float or int): Amount in rupees. Converted to paise.
            currency (str): Currency code (default: INR).
            receipt_id (str): Custom receipt ID for tracking.
            payment_capture (bool): Whether to auto-capture the payment (default: True).

        Returns:
            dict: The created order object or error message.
        """
        order_data = {
            "amount": int(amount_in_rupees * 100),
            "currency": currency,
            "receipt": receipt_id,
            "payment_capture": int(payment_capture),
            "notes": notes or {},
        }

        try:
            order = self.client.order.create(data=order_data)
            print("Order created successfully.")
            ## DB INSERTION HAPPENS HERE WHERE PAYMENT ORDER IS CREATED AND AUDITED
            return order
        except Exception as e:
            print(f"Error creating order: {e}")
            return {"error": str(e)}

    def verify_payment_signature(
        self, order_id: str, payment_id: str, signature: str
    ) -> bool:
        try:
            self.client.utility.verify_payment_signature(
                {
                    "razorpay_order_id": order_id,
                    "razorpay_payment_id": payment_id,
                    "razorpay_signature": signature,
                }
            )
            return True
        except Exception as e:
            print(f"Payment signature verification failed: {e}")
            return False

# if __name__ == "__main__":
#     service = RazorpayPaymentService()
#     order = service.create_order(
#         amount_in_rupees=500,
#         receipt_id="txn_001",
#     )
#     print(order)