# lease_extractor_llm_min.py
from io import BytesIO
import os, json, re
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv
load_dotenv()
# ---- your reusable manager ----
from app.core.modelConfig import ModelConfigManager
from app.services.whatsapp_service import normalize_whatsapp_e164
# ---- LangChain messages ----
from langchain_core.messages import SystemMessage, HumanMessage
# ---- PDF ----
try:
    from pypdf import PdfReader
except Exception:
    from PyPDF2 import PdfReader  # fallback

# ========= CONFIG =========
# Keys match DB columns: properties (name, tenant_name, tenant_phone, address_line1, city, state, postal_code)
# and leases (lease_start, lease_end, monthly_rent, security_deposit, lock_in_period, due_day).
# owner_id, property_id, lease_text are set by the app when inserting.
DB_INSERT_FIELDS = [
    "name",              # property name (e.g. "Property at <address>")
    "tenant_name",
    "tenant_phone",     # tenant mobile for WhatsApp; null if not stated
    "address_line1",
    "city",
    "state",
    "postal_code",
    "lease_start",
    "lease_end",
    "monthly_rent",
    "security_deposit",
    "lock_in_period",
    "due_day",
]
MAX_CHARS = 12000
OVERLAP = 400

# Use your ModelConfigManager here
config = ModelConfigManager(
    model_name="gpt-4o-mini",
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
PROMPT = """You extract data from an Indian residential lease for database insertion.

Return ONLY a single JSON object with exactly these keys. No explanation, no markdown, no other text—only the JSON. Use null for any value not found.

Keys:
{keys}

Rules:
- name: property name (use full property address or "Property at <address>" if no title)
- tenant_name, address_line1, city, state, postal_code: from tenant/leased premises; postal_code = 6 digits
- tenant_phone: tenant's mobile number as written in the lease (e.g. "+91 98765 43210", "09876543210", "9876543210"). Use null if no phone appears anywhere for the tenant/lessee.
- lease_start, lease_end: dates as "YYYY-MM-DD"
- monthly_rent, security_deposit: integers (INR)
- lock_in_period: integer (months), or null
- due_day: integer 1–31 (day of month rent is due)

Example input:
---
Agreement Start: 01/04/2024, End: 28/02/2025
Monthly Rent: ₹ 18,500. Security: ₹ 50,000. Lock-in: 6 months. Rent due: 5th.
Tenant: Priya Singh. Premises: 42 MG Road, Bengaluru, Karnataka 560001.
---

Expected output (only this JSON, nothing else):
{{
  "name": "Property at 42 MG Road",
  "tenant_name": "Priya Singh",
  "tenant_phone": "+91 9876543210",
  "address_line1": "42 MG Road",
  "city": "Bengaluru",
  "state": "Karnataka",
  "postal_code": "560001",
  "lease_start": "2024-04-01",
  "lease_end": "2025-02-28",
  "monthly_rent": 18500,
  "security_deposit": 50000,
  "lock_in_period": 6,
  "due_day": 5
}}

Extract from the lease text between <LEASE> tags. Return only the JSON object.

<LEASE>
{lease_text}
</LEASE>
"""

def build_prompt(lease_text: str) -> str:
    return PROMPT.format(
        keys=json.dumps(DB_INSERT_FIELDS),
        lease_text=lease_text
    )

# ========= LLM CALL (uses your manager's model) =========
def extract_chunk(text: str) -> Dict[str, Optional[str]]:
    prompt = build_prompt(text)
    msg = LLM.invoke([
        SystemMessage(content="Return only a single JSON object with the exact keys required for database insertion. No markdown, no explanation, no other text."),
        HumanMessage(content=prompt),
    ])
    raw = (msg.content or "").strip()
    # grab JSON object
    m = re.search(r"\{.*\}\s*$", raw, flags=re.S)
    raw_json = m.group(0) if m else raw
    try:
        data = json.loads(raw_json)
        # keep only known fields; map "" or "null" to None
        return {k: (data.get(k) if data.get(k) not in ["", "null"] else None) for k in DB_INSERT_FIELDS}
    except Exception:
        return {k: None for k in DB_INSERT_FIELDS}

# ========= MERGE =========
def merge_results(partials: List[Dict[str, Optional[str]]]) -> Dict[str, Optional[str]]:
    merged = {k: None for k in DB_INSERT_FIELDS}
    for p in partials:
        for k, v in p.items():
            if merged[k] is None and v not in (None, ""):
                merged[k] = v
    return merged

#@tool 
# ========= PUBLIC API =========
def extract_from_pdf(pdf_path: str) -> Dict[str, Any]:
    text = read_pdf_text(pdf_path)
    pieces = chunk(text)
    partials = [extract_chunk(t) for t in pieces]
    merged = merge_results(partials)

    # Normalize for DB: postal_code 6 digits; numeric fields as int or None
    def digits_only(x): return re.sub(r"\D", "", x) if isinstance(x, str) else x
    if merged.get("postal_code"):
        d = digits_only(merged["postal_code"])
        merged["postal_code"] = d if d and len(d) == 6 else None
    for num_key in ("monthly_rent", "security_deposit", "lock_in_period", "due_day"):
        v = merged.get(num_key)
        if v is not None:
            if isinstance(v, int):
                merged[num_key] = v
            else:
                d = digits_only(str(v)) if v else None
                merged[num_key] = int(d) if d else None
    # WhatsApp: normalize tenant phone; drop if invalid/too short
    raw_phone = merged.get("tenant_phone")
    if raw_phone not in (None, ""):
        tp = normalize_whatsapp_e164(str(raw_phone))
        merged["tenant_phone"] = tp if len(tp) >= 10 else None
    else:
        merged["tenant_phone"] = None
    return merged

# if __name__ == "__main__":
#     # change path as needed
#     pdf_path = "/Users/anshagarwal/Desktop/KirayaEase/data/Lease_Agreement_Sample.pdf"
#     result = extract_from_pdf(pdf_path)
#     print(json.dumps(result, ensure_ascii=False, indent=2))
