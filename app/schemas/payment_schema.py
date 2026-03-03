from pydantic import BaseModel

class CreateOrderRequest(BaseModel):
     amount: float
     receipt_id: str = "receipt_auto"


class VerifyPaymentRequest(BaseModel):
    order_id: str
    payment_id: str
    signature: str