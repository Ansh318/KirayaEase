
# lease_extractor.py
import re
import unicodedata
from io import BytesIO
from typing import Dict, List, Optional

try:
    from pypdf import PdfReader
except Exception:
    from PyPDF2 import PdfReader  # fallback


def _normalize_text(s: str) -> str:
    """Normalize Unicode, strip control chars, unify separators, collapse whitespace."""
    s = unicodedata.normalize("NFKC", s)
    s = (
        s.replace("’", "'")
        .replace("‘", "'")
        .replace("“", '"')
        .replace("”", '"')
        .replace("–", "-")
        .replace("—", "-")
    )
    s = re.sub(r"[\x00-\x1F\u200B-\u200D\uFEFF]", "", s)
    s = re.sub(r"\s*[:：]\s*", ": ", s)
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\n{2,}", "\n", s)
    return s.strip()


class LeaseExtractor:
    FIELD_PATTERNS: Dict[str, List[str]] = {
    "landlord_name": [
        r"Owner Name[^\n:]*:\s*([^\n]+?)(?=\s*(?:Owner Mobile|Owner Email|Owner Address|$))"
    ],
    "landlord_phone": [
        r"Owner Mobile[^\n:]*:\s*([0-9]{10})"
    ],
    "landlord_email": [
        r"Owner Email[^\n:]*:\s*([^\s]+@[^\s]+)(?=\s*(?:Owner Address|Owner City|$))"
    ],
    "landlord_address": [
        r"Owner Address[^\n:]*:\s*([^\n]+?)(?=\s*(?:Owner City|Owner State|Rented Property|$))"
    ],
    "property_address": [
        r"Address of Rented Property[^\n:]*:\s*([^\n]+?)(?=\s*(?:Rented Property Pin|Agreement Start|Agreement End|Tenant|$))"
    ],
    "property_pincode": [
        r"Rented Property Pin code[^\n:]*:\s*([0-9]{6})"
    ],
    "start_date": [
        r"Agreement Start Date[^\n:]*:\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
    ],
    "end_date": [
        r"Agreement End Date[^\n:]*:\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
    ],
    "tenant_name": [
        r"Tenant['`′’]s? Name[^\n:]*:\s*([^\n]+?)(?=\s*(?:Tenant Permanent Address|Tenant City|Tenant State|Pin code|$))"
    ],
    "tenant_address": [
        r"Tenant Permanent Address[^\n:]*:\s*([^\n]+?)(?=\s*(?:Tenant City|Tenant State|Pin code|$))"
    ],
    "tenant_city": [
        r"Tenant City/District[^\n:]*:\s*([^\n]+?)(?=\s*(?:Tenant State|Pin code|$))"
    ],
    "tenant_state": [
        r"Tenant State[^\n:]*:\s*([^\n]+?)(?=\s*(?:Pin code|Tenant|$))"
    ],
    "tenant_pincode": [
        r"Pin code[^\n:]*:\s*([0-9]{6})"
    ],
    "tenant_phone": [
        r"Tenant.*?Mobile Number[^\n:]*:\s*([0-9]{10})"
    ],
    "aadhar": [
        r"(?:Aadhaar|Aadhar)[^\n:]*:\s*([\d ]{12,14})"
    ],
    "pan": [
        r"\bPAN[^\n:]*:\s*([A-Z]{5}\d{4}[A-Z])"
    ],
    "rent_amount": [
        r"(?:Monthly Rent|Rent)[^\n:]*:\s*₹?\s*([\d,]+)"
    ],
}

    def __init__(self, pdf_bytes: bytes):
        self.text = self._extract_text_from_pdf(pdf_bytes)

    def _extract_text_from_pdf(self, pdf_bytes: bytes) -> str:
        reader = PdfReader(BytesIO(pdf_bytes))
        parts = []
        for p in reader.pages:
            t = p.extract_text() or ""
            parts.append(t)
        return ( _normalize_text("\n".join(parts)))

    def _find_first(self, patterns: List[str]) -> Optional[str]:
        for pat in patterns:
            m = re.search(pat, self.text, flags=re.IGNORECASE)
            if m:
                return re.sub(r"\s{2,}", " ", m.group(1).strip())
        return None

    def extract_details(self) -> Dict[str, Optional[str]]:
        found: Dict[str, Optional[str]] = {}
        for key, pats in self.FIELD_PATTERNS.items():
            found[key] = self._find_first(pats)

        if found.get("aadhar"):
            found["aadhar"] = found["aadhar"].replace(" ", "")
        if found.get("rent_amount"):
            found["rent_amount"] = found["rent_amount"].replace(",", "")

        return {
            "landlord_name": found.get("landlord_name"),
            "landlord_phone": found.get("landlord_phone"),
            "landlord_email": found.get("landlord_email"),
            "landlord_address": found.get("landlord_address"),
            "property_address": found.get("property_address"),
            "property_pincode": found.get("property_pincode"),
            "start_date": found.get("start_date"),
            "end_date": found.get("end_date"),
            "tenant_name": found.get("tenant_name"),
            "tenant_address": found.get("tenant_address"),
            "tenant_city": found.get("tenant_city"),
            "tenant_state": found.get("tenant_state"),
            "tenant_pincode": found.get("tenant_pincode"),
            "tenant_phone": found.get("tenant_phone"),
            "aadhar": found.get("aadhar"),
            "pan": found.get("pan"),
            "rent_amount_inr": found.get("rent_amount")
        }


# ---------------- MAIN -----------------
def main():
    pdf_path = "/Users/anshagarwal/Desktop/KirayaEase/data/Lease_Agreement_Sample.pdf"
    with open(pdf_path, "rb") as f:
        pdf_bytes = f.read()

    extractor = LeaseExtractor(pdf_bytes)
    details = extractor.extract_details()
    print(details)


if __name__ == "__main__":
    main()