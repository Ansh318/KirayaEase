import razorpay
import os 
from dotenv import load_dotenv
load_dotenv()

razorpay_client = razorpay.Client(auth=(os.getenv("RAZORPAY_TEST_KEY_ID"), os.getenv("RAZORPAY_KEY_SECRET")))

print(razorpay_client)

order_data = {
    "amount": 50000,  # Amount in paise = ₹500.00
    "currency": "INR",
    "receipt": "receipt#1",
    "payment_capture": 1  # Auto-capture
}

try:
    order = razorpay_client.order.create(data=order_data)
    print("✅ Order created successfully:")
    print(order)
except Exception as e:
    print("❌ Error creating order:")
    print(str(e))
