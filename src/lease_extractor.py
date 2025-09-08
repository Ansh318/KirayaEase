# lease_extractor.py

from io import BytesIO
from typing import Dict, Optional
import re
from pypdf import PdfReader


class LeaseExtractor:
    FIELD_PATTERNS = {
        "landlord_name": r"(?:Landlord Name|Lessor)\s*:\s*([A-Za-z .]+)",
        "tenant_name":   r"(?:Tenant Name|Lessee)\s*:\s*([A-Za-z .]+)",
        "tenant_address":r"(?:Tenant Address|Address)\s*:\s*([^\n]+)",
        "rent_amount":   r"(?:Monthly Rent|Rent)\s*:\s*₹?\s*([\d,]+)",
        "start_date":    r"(?:Start Date|Commencement)\s*:\s*([0-9]{1,2}[-/][0-9A-Za-z]{2,9}[-/][0-9]{2,4})",
        "end_date":      r"(?:End Date|Expiry)\s*:\s*([0-9]{1,2}[-/][0-9A-Za-z]{2,9}[-/][0-9]{2,4})",
        "aadhar":        r"(?:Aadhaar|Aadhar)\D*([\d ]{12,14})",
        "pan":           r"(?:PAN)\D*([A-Z]{5}\d{4}[A-Z])",
    }

    def __init__(self, pdf_bytes: bytes):
        self.pdf_bytes = pdf_bytes
        self.text = self._extract_text_from_pdf()

    def _extract_text_from_pdf(self) -> str:
        """Extract text from the PDF text layer (fast, no OCR)."""
        reader = PdfReader(BytesIO(self.pdf_bytes))
        parts = []
        for p in reader.pages:
            t = p.extract_text() or ""
            parts.append(t)
        return "\n".join(parts)

    def _find(self, pattern: str) -> Optional[str]:
        m = re.search(pattern, self.text, flags=re.IGNORECASE)
        return m.group(1).strip() if m else None

    def extract_details(self) -> Dict[str, Optional[str]]:
        """Return extracted fields from the lease PDF."""
        data = {k: self._find(pat) for k, pat in self.FIELD_PATTERNS.items()}

        # Normalize
        if data.get("rent_amount"):
            data["rent_amount"] = data["rent_amount"].replace(",", "")
        if data.get("aadhar"):
            data["aadhar"] = data["aadhar"].replace(" ", "")

        return {
            "landlord_name": data.get("landlord_name"),
            "tenant_name": data.get("tenant_name"),
            "tenant_address": data.get("tenant_address"),
            "rent_amount_inr": data.get("rent_amount"),
            "start_date": data.get("start_date"),
            "end_date": data.get("end_date"),
            "aadhar": data.get("aadhar"),
            "pan": data.get("pan"),
            "raw_preview": self.text[:1000],
        }


# --- Example usage ---
if __name__ == "__main__":
    with open("/Users/anshagarwal/Desktop/KirayaEase/data/demo_lease.pdf", "rb") as f:
        pdf_bytes = f.read()
    extractor = LeaseExtractor(pdf_bytes)
    details = extractor.extract_details()
    print(details)