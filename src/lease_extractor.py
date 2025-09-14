# lease_extractor_llm_min.py
from io import BytesIO
import os, json, re
from typing import Dict, List, Optional

from dotenv import load_dotenv
load_dotenv()

# ---- your reusable manager ----
from modelConfig import ModelConfigManager

# ---- LangChain messages ----
from langchain_core.messages import SystemMessage, HumanMessage

# ---- PDF ----
try:
    from pypdf import PdfReader
except Exception:
    from PyPDF2 import PdfReader  # fallback

# ========= CONFIG =========
FIELDS = [
    "landlord_name","landlord_phone","landlord_email","landlord_address",
    "property_address","property_pincode","start_date","end_date",
    "tenant_name","tenant_address","tenant_city","tenant_state",
    "tenant_pincode","tenant_phone","aadhar","pan","rent_amount_inr"
]
MAX_CHARS = 12000
OVERLAP = 400

# Use your ModelConfigManager here
config = ModelConfigManager(
    model_name=os.getenv("LEASE_OPENAI_MODEL", "gpt-4o-mini"),
    temperature=0,
    max_retries=2,
)
LLM = config.model()  # ChatOpenAI instance

# ========= PDF & CHUNKING =========
def read_pdf_text(pdf_path: str) -> str:
    with open(pdf_path, "rb") as f:
        reader = PdfReader(BytesIO(f.read()))
    parts = []
    for p in reader.pages:
        parts.append(p.extract_text() or "")
    text = "\n".join(parts)
    # light normalize
    text = re.sub(r"[\x00-\x1F\u200B-\u200D\uFEFF]", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{2,}", "\n", text)
    return text.strip()

def chunk(text: str, max_chars: int = MAX_CHARS, overlap: int = OVERLAP) -> List[str]:
    if len(text) <= max_chars:
        return [text]
    out, i = [], 0
    while i < len(text):
        end = min(i + max_chars, len(text))
        out.append(text[i:end])
        if end == len(text): break
        i = end - overlap
    return out

# ========= PROMPT =========
PROMPT = """You are extracting fields from an Indian residential lease agreement.
Return ONLY a compact JSON object with these keys (null if not found):
{keys}

Normalization (best-effort; if unsure, use null):
- Dates: "YYYY-MM-DD" (parse common formats).
- Aadhaar: 12 digits only, no spaces.
- PAN: ABCDE1234F (uppercase).
- Phone: 10 digits (India).
- PIN: 6 digits.
- Rent: digits only (no commas/symbols).

Example:
Input snippet:
---
Owner Name: Rahul Sharma
Owner Mobile: 9876543210
Owner Email: rahul@example.com
Agreement Start Date: 01/04/2024
Monthly Rent: ₹ 18,500
Tenant's Name: Priya Singh
Tenant Mobile Number: 9123456789
Pin code: 560001
PAN: ABCDE1234F
---

Expected JSON:
{{
  "landlord_name": "Rahul Sharma",
  "landlord_phone": "9876543210",
  "landlord_email": "rahul@example.com",
  "landlord_address": null,
  "property_address": null,
  "property_pincode": null,
  "start_date": "2024-04-01",
  "end_date": null,
  "tenant_name": "Priya Singh",
  "tenant_address": null,
  "tenant_city": null,
  "tenant_state": null,
  "tenant_pincode": "560001",
  "tenant_phone": "9123456789",
  "aadhar": null,
  "pan": "ABCDE1234F",
  "rent_amount_inr": "18500"
}}

Now extract from this lease text between <LEASE> tags. Be conservative; use null when not explicit.

<LEASE>
{lease_text}
</LEASE>
"""

def build_prompt(lease_text: str) -> str:
    return PROMPT.format(
        keys=json.dumps(FIELDS),
        lease_text=lease_text
    )

# ========= LLM CALL (uses your manager's model) =========
def extract_chunk(text: str) -> Dict[str, Optional[str]]:
    prompt = build_prompt(text)
    msg = LLM.invoke([
        SystemMessage(content="Extract fields strictly and return only valid JSON."),
        HumanMessage(content=prompt),
    ])
    raw = (msg.content or "").strip()
    # grab JSON object
    m = re.search(r"\{.*\}\s*$", raw, flags=re.S)
    raw_json = m.group(0) if m else raw
    try:
        data = json.loads(raw_json)
        # keep only known fields; map "" or "null" to None
        return {k: (data.get(k) if data.get(k) not in ["", "null"] else None) for k in FIELDS}
    except Exception:
        return {k: None for k in FIELDS}

# ========= MERGE =========
def merge_results(partials: List[Dict[str, Optional[str]]]) -> Dict[str, Optional[str]]:
    merged = {k: None for k in FIELDS}
    for p in partials:
        for k, v in p.items():
            if merged[k] is None and v not in (None, ""):
                merged[k] = v
    return merged

# ========= PUBLIC API =========
def extract_from_pdf(pdf_path: str) -> Dict[str, Optional[str]]:
    text = read_pdf_text(pdf_path)
    pieces = chunk(text)
    partials = [extract_chunk(t) for t in pieces]
    merged = merge_results(partials)

    # quick normalizations (non-destructive)
    def digits_only(x): return re.sub(r"\D", "", x) if isinstance(x, str) else x
    if merged.get("tenant_phone"):
        d = digits_only(merged["tenant_phone"])
        merged["tenant_phone"] = d if d and len(d) == 10 else None
    if merged.get("landlord_phone"):
        d = digits_only(merged["landlord_phone"])
        merged["landlord_phone"] = d if d and len(d) == 10 else None
    if merged.get("tenant_pincode"):
        d = digits_only(merged["tenant_pincode"])
        merged["tenant_pincode"] = d if d and len(d) == 6 else None
    if merged.get("property_pincode"):
        d = digits_only(merged["property_pincode"])
        merged["property_pincode"] = d if d and len(d) == 6 else None
    if merged.get("aadhar"):
        d = digits_only(merged["aadhar"])
        merged["aadhar"] = d if d and len(d) == 12 else None
    if merged.get("pan"):
        p = (merged["pan"] or "").strip().upper()
        merged["pan"] = p if re.fullmatch(r"[A-Z]{5}\d{4}[A-Z]", p) else None
    if merged.get("rent_amount_inr"):
        merged["rent_amount_inr"] = re.sub(r"[^\d]", "", merged["rent_amount_inr"]) or None

    return merged

# if __name__ == "__main__":
#     # change path as needed
#     pdf_path = "/Users/anshagarwal/Desktop/KirayaEase/data/Lease_Agreement_Sample.pdf"
#     result = extract_from_pdf(pdf_path)
#     print(json.dumps(result, ensure_ascii=False, indent=2))
