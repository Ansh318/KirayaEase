import razorpay
import os 
from dotenv import load_dotenv
load_dotenv()
import warnings
warnings.filterwarnings("ignore", category=UserWarning)

razorpay_client = razorpay.Client(auth=(os.getenv("RAZORPAY_TEST_KEY_ID"), os.getenv("RAZORPAY_KEY_SECRET")))

def create_razorpay_order(razorpay_client, amount_in_rupees, currency="INR", receipt_id="receipt#1", payment_capture=True):
    """
    Create a Razorpay order.

    Args:
        razorpay_client: The initialized Razorpay client object.
        amount_in_rupees (float or int): Amount in rupees. Will be converted to paise.
        currency (str): Currency code (default: INR).
        receipt_id (str): Custom receipt ID for tracking.
        payment_capture (bool): Whether to auto-capture the payment (default: True).

    Returns:
        dict: The created order object or error message.
    """
    order_data = {
        "amount": int(amount_in_rupees * 100),  # Convert to paise
        "currency": currency,
        "receipt": receipt_id,
        "payment_capture": int(payment_capture)
    }

    try:
        order = razorpay_client.order.create(data=order_data)
        print("✅ Order created successfully:")
        print(order)
        return order
    except Exception as e:
        print("❌ Error creating order:")
        print(str(e))
        return {"error": str(e)}


# Create order
order = create_razorpay_order(
    razorpay_client=razorpay_client,
    amount_in_rupees=500,
    receipt_id="txn_001"
)