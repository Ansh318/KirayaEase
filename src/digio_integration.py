# # from model import OpenAIModel
# # import pdfkit
# # import tempfile
# # import requests
# # import json



# # def send_to_digio_from_string(signer_info: dict, session_token: str):
# #     headers = {
# #         "x-session": session_token
# #     }

# #     payload = {
# #         "signers": [
# #             {
# #                 "identifier": signer_info["email"],
# #                 "name": signer_info["name"],
# #                 "signer_type": 1,
# #                 "email": signer_info["email"],
# #                 "phone": signer_info["phone"],
# #                 "reason": "Residential Lease Agreement Signature"
# #             }
# #         ],
# #         "e_stamp": True,
# #         "display_on_page": True,
# #         "expire_in_days": 7,
# #         "file_name": "lease_agreement.pdf",
# #         "send_sign_link": False
# #     }

# #     # Create PDF in-memory using tempfile
    

# #     files = {
# #         "file": ("/Users/anshagarwal/Desktop/KirayaEase/data/residential-rental-agreement-format.pdf", "application/pdf")
# #     }

# #     res = requests.post(
# #         url="https://ext.digio.in:444/v2/client/document/upload",
# #         headers=headers,
# #         files=files,
# #         data={"data": json.dumps(payload)}
# #     )

# #     res.raise_for_status()
# #     return {
# #         "document_id": res.json()["id"],
# #         "sign_url": res.json()["signers"][0]["sign_url"]
# #     }



# # # model = OpenAIModel("gpt-4", "0", "1")
# # # response = model.run_chain(
# # #     "Lease Prompt",
# # #     "Ravi Kumar is renting a 2BHK apartment in Andheri West, Mumbai from Sept 1, 2025. Landlord is Ansh Agarwal. Rent is ₹25,000/month. Deposit is ₹50,000. Property is 950 sq ft with 2 bathrooms and 1 car park. Starting meter reading is 5421."
# # # )
# # # Step 2: Define signer info
# # signer_info = {
# #     "name": "Ravi Kumar",
# #     "email": "ravi@example.com",
# #     "phone": "9876543210"
# # }

# # # Step 3: Your Digio session token (after login / auth)
# # session_token = "SIDXRTMJXLNBMYSQDZBBZGGVBRFQIFSB"

# # # Step 4: Upload to Digio
# # result = send_to_digio_from_string(signer_info, session_token)

# # print("Document ID:", result["document_id"])
# # print("Sign URL:", result["sign_url"])


# import base64
# import json
# import requests
# from pathlib import Path

# SANDBOX_BASE = "https://ext-enterprise.digio.in"  # Sandbox backend base URL
# CREATE_SIGN_REQUEST_ENDPOINT = f"{SANDBOX_BASE}/v2/client/document/upload"

# # ---- Replace with your sandbox API credentials (auto-generated for support@kirayaease.in) ----
# CLIENT_ID = "ACK250813121856675OULMZUIY1EVG87"
# CLIENT_SECRET = "FMPO4U5VSRWM9CA9UUK3KLC9VHEJ8ZJZ"

# def _basic_auth_header(client_id: str, client_secret: str) -> str:
#     token = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
#     return f"Basic {token}"

# def send_to_digio_with_pdf(pdf_path: str, signer_info: dict):
#     """
#     Creates a sign request (multipart) and uploads a PDF for signing.
#     signer_info = {"name": "...", "email": "...", "phone": "..."}
#     """
#     # Build metadata payload
#     payload = {
#         "signers": [
#             {
#                 "identifier": signer_info["email"],     # usually the email
#                 "name": signer_info["name"],
#                 "signer_type": 1,                       # individual
#                 "email": signer_info["email"],
#                 "phone": signer_info["phone"],
#                 "reason": "Residential Lease Agreement Signature",
#             }
#         ],
#         "e_stamp": True,
#         "display_on_page": True,
#         "expire_in_days": 7,
#         "file_name": Path(pdf_path).name,
#         "send_sign_link": False  # you can set True to let Digio send the link
#     }

#     headers = {
#         "Authorization": _basic_auth_header(CLIENT_ID, CLIENT_SECRET)
#         # Do NOT use x-session here; that's for dashboard UI login.
#     }

#     with open(pdf_path, "rb") as f:
#         files = {
#             # IMPORTANT: ('file', (filename, bytes, mimetype))
#             "file": (Path(pdf_path).name, f.read(), "application/pdf"),
#             # The metadata goes in "data" as JSON string
#             "data": (None, json.dumps(payload), "application/json"),
#         }

#     res = requests.post(
#         url=CREATE_SIGN_REQUEST_ENDPOINT,
#         headers=headers,
#         files=files,
#         timeout=60
#     )
#     res.raise_for_status()
#     data = res.json()

#     # Typical response contains document id and signer objects with sign_url
#     document_id = data.get("id") or data.get("document_id")
#     signers = data.get("signers", [])
#     sign_url = signers[0].get("sign_url") if signers else None

#     return {"document_id": document_id, "sign_url": sign_url}

# # ---- Example usage ----
# signer_info = {"name": "Ravi Kumar", "email": "ravi@example.com", "phone": "9876543210"}
# result = send_to_digio_with_pdf(
#     pdf_path="/Users/anshagarwal/Desktop/KirayaEase/data/residential-rental-agreement-format.pdf",
#     signer_info=signer_info
# )
# print("Document ID:", result["document_id"])
# print("Sign URL:", result["sign_url"])

"""
digio_sandbox_sign.py
Minimal end-to-end: upload a PDF for signing on Digio (Sandbox Enterprise)
- Uses API backend host: https://ext.digio.in:444
- Auth: Basic base64(client_id:client_secret)
- Multipart: file (binary) + data (JSON string)
"""

import os
import json
import base64
import requests
from pathlib import Path
from typing import Dict, Optional
from dotenv import load_dotenv


DIGIO_SANDBOX_API = "https://ext.digio.in:444"
UPLOAD_URL = f"{DIGIO_SANDBOX_API}/v2/client/document/upload"
GET_DOC_URL = f"{DIGIO_SANDBOX_API}/v2/client/document"  # append /{document_id}

# Read from environment (recommended). Export before running:
# export DIGIO_CLIENT_ID="..."
# export DIGIO_CLIENT_SECRET="..."
CLIENT_ID = os.getenv("DIGIO_CLIENT_ID")
CLIENT_SECRET = os.getenv("DIGIO_CLIENT_SECRET")


def _require_env(var_name: str) -> str:
    val = os.getenv(var_name)
    if not val:
        raise RuntimeError(f"Missing environment variable: {var_name}")
    return val


def _basic_auth_header(client_id: str, client_secret: str) -> str:
    token = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    return f"Basic {token}"


def create_sign_request(
    pdf_path: str,
    signer: Dict[str, str],
    *,
    e_stamp: bool = True,
    display_on_page: bool = True,
    expire_in_days: int = 7,
    send_sign_link: bool = False,
    client_id: Optional[str] = None,
    client_secret: Optional[str] = None,
) -> Dict[str, Optional[str]]:
    """
    Uploads a PDF and creates a sign request.

    signer = {
        "name": "Ravi Kumar",
        "email": "ravi@example.com",
        "phone": "919876543210"  # E.164, include country code
    }

    Returns: {"document_id": "...", "sign_url": "..."}  # sign_url None if send_sign_link=True
    """
    cid = client_id or _require_env("DIGIO_CLIENT_ID")
    csec = client_secret or _require_env("DIGIO_CLIENT_SECRET")

    headers = {
        "Authorization": _basic_auth_header(cid, csec)
    }

    payload = {
        "signers": [
            {
                "identifier": signer["email"],   # could use phone if preferred
                "name": signer["name"],
                "signer_type": 1,                # 1 = individual
                "email": signer["email"],
                "phone": signer["phone"],
                "reason": "Residential Lease Agreement Signature",
            }
        ],
        "e_stamp": e_stamp,
        "display_on_page": display_on_page,
        "expire_in_days": expire_in_days,
        "file_name": Path(pdf_path).name,
        "send_sign_link": send_sign_link
    }

    # IMPORTANT: multipart with:
    #   - files={"file": (filename, binary, "application/pdf")}
    #   - data={"data": json.dumps(payload)}
    with open(pdf_path, "rb") as f:
        files = {
            "file": (Path(pdf_path).name, f, "application/pdf"),
        }
        data = {
            "data": json.dumps(payload)
        }

        res = requests.post(
            UPLOAD_URL,
            headers=headers,
            files=files,
            data=data,
            timeout=60
        )

    if not res.ok:
        raise RuntimeError(f"Digio upload failed {res.status_code}: {res.text}")

    resp = res.json()
    document_id = resp.get("id") or resp.get("document_id")
    sign_url = None
    # If send_sign_link=False, API generally returns sign_url under signers[0]
    signers = resp.get("signers") or []
    if signers and isinstance(signers, list):
        sign_url = signers[0].get("sign_url")

    return {"document_id": document_id, "sign_url": sign_url}


def get_document_status(document_id: str, *, client_id: Optional[str] = None, client_secret: Optional[str] = None) -> Dict:
    """Fetch the document details/status after creation."""
    cid = client_id or _require_env("DIGIO_CLIENT_ID")
    csec = client_secret or _require_env("DIGIO_CLIENT_SECRET")

    headers = {
        "Authorization": _basic_auth_header(cid, csec)
    }
    url = f"{GET_DOC_URL}/{document_id}"
    r = requests.get(url, headers=headers, timeout=30)
    if not r.ok:
        raise RuntimeError(f"Digio get-document failed {r.status_code}: {r.text}")
    return r.json()


if __name__ == "__main__":
    # ---- Edit these for your test ----
    pdf_path = "/Users/anshagarwal/Desktop/KirayaEase/data/residential-rental-agreement-format.pdf"
    signer_info = {
        "name": "Ravi Kumar",
        "email": "ravi@example.com",
        "phone": "919876543210"  # include country code, digits only
    }

    # Set env vars before running:
    # export DIGIO_CLIENT_ID="your_client_id"
    # export DIGIO_CLIENT_SECRET="your_client_secret"

    try:
        result = create_sign_request(pdf_path, signer_info, send_sign_link=False)
        print("Document ID:", result["document_id"])
        print("Sign URL:", result["sign_url"])  # open this to test signer flow (when send_sign_link=False)

        # Optional: poll status
        if result["document_id"]:
            details = get_document_status(result["document_id"])
            print("Document Status:", details.get("status"))
    except Exception as e:
        # Print full server error to debug quickly
        raise