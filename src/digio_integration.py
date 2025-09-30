import os
import base64
import requests
from dotenv import load_dotenv

#post {BASE_URL}/v3/client/kyc/ckyc/search

# {BASE_URL}/v3/client/kyc/ckyc/get_otp

load_dotenv()

class DigioClient:
    def __init__(self):
        self.client_id = os.getenv("DIGIO_CLIENT_ID")
        self.client_secret = os.getenv("DIGIO_CLIENT_SECRET")
        # Sandbox: https://ext.digio.in:444 ; Prod: https://api.digio.in
        self.base_url = os.getenv("DIGIO_BASE_URL", "https://ext.digio.in:444")
        self.upload_url = f"{self.base_url}/client/kyc/v2/request/with_template"

        if not self.client_id or not self.client_secret:
            raise ValueError("DIGIO_CLIENT_ID and DIGIO_CLIENT_SECRET must be set")

    def _auth_header(self) -> str:
        token = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()
        return f"Basic {token}"

    # --- core ---
    def initiate_kyc(self, body: dict) -> dict:
        headers = {
            "Authorization": self._auth_header(),
            "Content-Type": "application/json",
        }
        try:
            resp = requests.post(self.upload_url, headers=headers, json=body, timeout=30)
            if resp.status_code >= 400:
                raise RuntimeError(
        f"Digio {resp.status_code} Error: {resp.text}"
    )
            resp.raise_for_status()

        except requests.RequestException as e:
            raise RuntimeError(f"Network error calling Digio: {e}")

        try:
            return resp.json()
        except ValueError:
            return {"raw": resp.text}

    def fetch_user_data(self, kid: str) -> dict:
        """
        Fetches KYC response for a given KID (kyc_request_id) from Digio
        """
        headers = {
            "Authorization": self._auth_header(),
            "Content-Type": "application/json",
        }
        fetch_url = f"{self.base_url}/client/kyc/v2/{kid}/response"
        try:
            resp = requests.get(fetch_url, headers=headers, timeout=30)
            resp.raise_for_status()
        except requests.RequestException as e:
            raise RuntimeError(f"Network error calling Digio: {e}")

        try:
            return resp.json()
        except ValueError:
            return {"raw": resp.text}

    def extract_aadhaar_pan(body: dict):
        """
        Extract Aadhaar and PAN details from Digio webhook response.
        Automatically removes large image data for storage efficiency.
        """
        try:
            # Navigate to action details
            actions = body.get("actions", [])
            if not actions:
                raise ValueError("No actions found in payload")

            details = actions[0].get("details", {})

            aadhaar_data = details.get("aadhaar", {})
            pan_data = details.get("pan", {})

            # Remove base64 image field if exists
            if "image" in aadhaar_data:
                aadhaar_data.pop("image")

            return {
                "aadhaar": aadhaar_data,
                "pan": pan_data
            }

        except Exception as e:
            print(f"Error parsing payload: {e}")
            return None

# # --- Example usage ---
# if __name__ == "__main__":
#     digio = DigioClient()

#     body = {
#         "customer_identifier": "9820023475",
#         "customer_name": "Ravi Agarwal",
#         "template_name": "KE_DIGILOCKER_INTEGRATION",
#         "notify_customer": "false",
#         "generate_access_token": "true",
#         "request_details": {}
#     }
    
#     response = digio.initiate_kyc(body)
#     print(response)

