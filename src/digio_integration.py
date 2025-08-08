from model import OpenAIModel
import pdfkit
import tempfile
import requests
import json



def send_to_digio_from_string(signer_info: dict, session_token: str):
    headers = {
        "x-session": session_token
    }

    payload = {
        "signers": [
            {
                "identifier": signer_info["email"],
                "name": signer_info["name"],
                "signer_type": 1,
                "email": signer_info["email"],
                "phone": signer_info["phone"],
                "reason": "Residential Lease Agreement Signature"
            }
        ],
        "e_stamp": True,
        "display_on_page": True,
        "expire_in_days": 7,
        "file_name": "lease_agreement.pdf",
        "send_sign_link": False
    }

    # Create PDF in-memory using tempfile
    

    files = {
        "file": ("/Users/anshagarwal/Desktop/KirayaEase/data/residential-rental-agreement-format.pdf", "application/pdf")
    }

    res = requests.post(
        url="https://ext.digio.in:444/v2/client/document/upload",
        headers=headers,
        files=files,
        data={"data": json.dumps(payload)}
    )

    res.raise_for_status()
    return {
        "document_id": res.json()["id"],
        "sign_url": res.json()["signers"][0]["sign_url"]
    }



# model = OpenAIModel("gpt-4", "0", "1")
# response = model.run_chain(
#     "Lease Prompt",
#     "Ravi Kumar is renting a 2BHK apartment in Andheri West, Mumbai from Sept 1, 2025. Landlord is Ansh Agarwal. Rent is ₹25,000/month. Deposit is ₹50,000. Property is 950 sq ft with 2 bathrooms and 1 car park. Starting meter reading is 5421."
# )
# Step 2: Define signer info
signer_info = {
    "name": "Ravi Kumar",
    "email": "ravi@example.com",
    "phone": "9876543210"
}

# Step 3: Your Digio session token (after login / auth)
session_token = "SIDXRTMJXLNBMYSQDZBBZGGVBRFQIFSB"

# Step 4: Upload to Digio
result = send_to_digio_from_string(signer_info, session_token)

print("Document ID:", result["document_id"])
print("Sign URL:", result["sign_url"])