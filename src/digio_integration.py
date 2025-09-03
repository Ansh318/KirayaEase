import os
import base64
import requests
from dotenv import load_dotenv

load_dotenv()

class DigioClient:
    def __init__(self):
        self.client_id = os.getenv("DIGIO_CLIENT_ID")
        self.client_secret = os.getenv("DIGIO_CLIENT_SECRET")
        # Sandbox: https://ext.digio.in:444 ; Prod: https://api.digio.in
        self.base_url = os.getenv("DIGIO_BASE_URL", "https://ext.digio.in:444")
        self.upload_url = f"{self.base_url}/v2/client/document/uploadpdf"

        if not self.client_id or not self.client_secret:
            raise ValueError("DIGIO_CLIENT_ID and DIGIO_CLIENT_SECRET must be set")

    # --- helpers ---
    @staticmethod
    def pdf_to_base64(pdf_path: str) -> str:
        """Read a PDF file and convert to Base64 string."""
        with open(pdf_path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")

    def _auth_header(self) -> str:
        token = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()
        return f"Basic {token}"

    # --- core ---
    def create_sign_request(self, body: dict) -> dict:
        headers = {
            "Authorization": self._auth_header(),
            "Content-Type": "application/json",
        }
        try:
            resp = requests.post(self.upload_url, headers=headers, json=body, timeout=30)
            resp.raise_for_status()
        except requests.RequestException as e:
            raise RuntimeError(f"Network error calling Digio: {e}")

        try:
            return resp.json()
        except ValueError:
            return {"raw": resp.text}


# --- Example usage ---
if __name__ == "__main__":
    digio = DigioClient()

    base64_pdf = digio.pdf_to_base64(
        "/Users/anshagarwal/Desktop/KirayaEase/data/residential-rental-agreement-format.pdf"
    )

    body = {
        "signers": [
            {
                "identifier": "ansh.agarwal@kirayaease.in",
                "name": "Ansh Agarwal",
                "sign_type": "electronic",
                "reason": "Lease Agreement",
            }
        ],
        "expire_in_days": 10,
        "display_on_page": "All",
        "notify_signers": "true",
        "send_sign_link": "false",
        "file_name": "Residential_Rent_Agreement.pdf",
        "file_data": base64_pdf,
    }

    response = digio.create_sign_request(body)
    print(response)