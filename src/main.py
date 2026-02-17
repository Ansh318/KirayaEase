from fastapi import FastAPI, HTTPException, Header, Request, Query
from pydantic import BaseModel
from auth import AuthManager
import os, sqlite3, uuid
from dotenv import load_dotenv
from datetime import date
from onboarding import handle_user_onboarding, get_user_by_token
import razorpay
import warnings
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
warnings.filterwarnings("ignore", category=UserWarning)
from chatbot import RentWiseAssistant
import os
from dotenv import load_dotenv
load_dotenv()
import requests
import base64,  binascii
import psycopg2
from psycopg2.extras import Json
from digio_integration import DigioClient
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse, PlainTextResponse
from lease_extractor import extract_from_pdf
import json
import tempfile, os

# MAX_FILE_MB = 20


# DIGIO_CLIENT_ID = os.getenv("DIGIO_CLIENT_ID")
# DIGIO_CLIENT_SECRET = os.getenv("DIGIO_CLIENT_SECRET")

# # Initialize Razorpay client with fallback to hardcoded test credentials if env vars not set
# razorpay_key_id = os.getenv("RAZORPAY_TEST_KEY_ID") or "rzp_test_v4oAPsjPGsrOQR"
# razorpay_key_secret = os.getenv("RAZORPAY_KEY_SECRET") or "wnbpXVnrlLqyhDruEbsgBCja"



# def normalize_text(text: str) -> str:
#     """
#     Normalize Unicode characters to ASCII equivalents to prevent encoding issues.
#     Replaces smart quotes, curly apostrophes, and other Unicode characters with ASCII.
#     """
#     replacements = {
#         '\u2018': "'",  # Left single quotation mark
#         '\u2019': "'",  # Right single quotation mark (apostrophe)
#         '\u201C': '"',  # Left double quotation mark
#         '\u201D': '"',  # Right double quotation mark
#         '\u2013': '-',  # En dash
#         '\u2014': '--', # Em dash
#         '\u2026': '...',# Ellipsis
#         '\u00A0': ' ',  # Non-breaking space
#     }
#     result = text
#     for unicode_char, ascii_char in replacements.items():
#         result = result.replace(unicode_char, ascii_char)
#     return result


# razorpay_client = razorpay.Client(
#     auth=(razorpay_key_id, razorpay_key_secret)
# )

app = FastAPI()
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev only; in prod, restrict this
    allow_credentials=True,
    allow_methods=["*"],
)
DATABASE_URL = os.getenv("DATABASE_URL")

# @app.on_event("startup")
# def startup_db_checks():
#     _ensure_runtime_schema()

# CREATE_CHAT_SESSION_TABLE_SQL = """
# CREATE TABLE IF NOT EXISTS chat_sessions (
#   session_id         TEXT PRIMARY KEY,
#   user_id            BIGINT REFERENCES users(id) ON DELETE SET NULL,
#   user_role          TEXT NOT NULL DEFAULT 'tenant' CHECK (user_role IN ('tenant','landlord')),
#   active_scope       TEXT NOT NULL DEFAULT 'self' CHECK (active_scope IN ('self','portfolio','tenant')),
#   active_tenant_id   TEXT,
#   created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
#   updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
# );
# """

# CREATE_CHAT_MESSAGE_TABLE_SQL = """
# CREATE TABLE IF NOT EXISTS chat_messages (
#   id             BIGSERIAL PRIMARY KEY,
#   session_id     TEXT NOT NULL REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
#   role           TEXT NOT NULL CHECK (role IN ('user','assistant','system')),
#   content        TEXT NOT NULL,
#   metadata       JSONB NOT NULL DEFAULT '{}'::jsonb,
#   created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
# );
# """

# CREATE_OPERATION_LOG_TABLE_SQL = """
# CREATE TABLE IF NOT EXISTS operation_logs (
#   id             BIGSERIAL PRIMARY KEY,
#   user_id        BIGINT REFERENCES users(id) ON DELETE SET NULL,
#   session_id     TEXT REFERENCES chat_sessions(session_id) ON DELETE SET NULL,
#   entity_type    TEXT NOT NULL,
#   entity_id      TEXT,
#   operation      TEXT NOT NULL CHECK (operation IN ('create','update','delete')),
#   old_data       JSONB,
#   new_data       JSONB,
#   created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
# );
# """

# def _get_db_connection():
#     if not DATABASE_URL:
#         return None
#     return psycopg2.connect(DATABASE_URL)

# def _ensure_runtime_schema():
#     """
#     Ensures runtime tables and backward-compatible columns exist on Postgres (Heroku).
#     """
#     conn = _get_db_connection()
#     if conn is None:
#         print("⚠️ DATABASE_URL not set. DB persistence/audit is disabled.")
#         return
#     try:
#         with conn:
#             with conn.cursor() as cursor:
#                 cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'tenant';")
#                 cursor.execute("ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS pan TEXT;")
#                 cursor.execute(CREATE_CHAT_SESSION_TABLE_SQL)
#                 cursor.execute(CREATE_CHAT_MESSAGE_TABLE_SQL)
#                 cursor.execute(CREATE_OPERATION_LOG_TABLE_SQL)
#     except Exception as e:
#         print(f"⚠️ Failed to ensure runtime schema: {e}")
#     finally:
#         conn.close()

# def _get_user_id_from_session(cursor, session_id: str) -> Optional[int]:
#     cursor.execute("SELECT user_id FROM sessions WHERE session_id = %s LIMIT 1;", (session_id,))
#     row = cursor.fetchone()
#     return row[0] if row else None

# def _insert_operation_log(
#     cursor,
#     *,
#     operation: str,
#     entity_type: str,
#     entity_id: Optional[str],
#     user_id: Optional[int] = None,
#     session_id: Optional[str] = None,
#     old_data: Optional[dict] = None,
#     new_data: Optional[dict] = None,
# ):
#     cursor.execute(
#         """
#         INSERT INTO operation_logs (user_id, session_id, entity_type, entity_id, operation, old_data, new_data)
#         VALUES (%s, %s, %s, %s, %s, %s, %s);
#         """,
#         (
#             user_id,
#             session_id,
#             entity_type,
#             entity_id,
#             operation,
#             Json(old_data) if old_data is not None else None,
#             Json(new_data) if new_data is not None else None,
#         ),
#     )

# def _persist_chat_exchange(request, response_text: str, payment_order_id: Optional[str], payment_amount: Optional[int]):
#     conn = _get_db_connection()
#     if conn is None:
#         return
#     try:
#         with conn:
#             with conn.cursor() as cursor:
#                 user_id = _get_user_id_from_session(cursor, request.session_id)
#                 cursor.execute(
#                     """
#                     INSERT INTO chat_sessions (session_id, user_id, user_role, active_scope, active_tenant_id)
#                     VALUES (%s, %s, %s, %s, %s)
#                     ON CONFLICT (session_id)
#                     DO UPDATE SET
#                       user_id = COALESCE(EXCLUDED.user_id, chat_sessions.user_id),
#                       user_role = EXCLUDED.user_role,
#                       active_scope = EXCLUDED.active_scope,
#                       active_tenant_id = EXCLUDED.active_tenant_id,
#                       updated_at = now();
#                     """,
#                     (
#                         request.session_id,
#                         user_id,
#                         request.user_role,
#                         request.active_scope,
#                         request.active_tenant_id,
#                     ),
#                 )
#                 cursor.execute(
#                     """
#                     INSERT INTO chat_messages (session_id, role, content, metadata)
#                     VALUES (%s, %s, %s, %s);
#                     """,
#                     (
#                         request.session_id,
#                         "user",
#                         request.message,
#                         Json({
#                             "active_scope": request.active_scope,
#                             "active_tenant_id": request.active_tenant_id,
#                             "user_role": request.user_role,
#                         }),
#                     ),
#                 )
#                 cursor.execute(
#                     """
#                     INSERT INTO chat_messages (session_id, role, content, metadata)
#                     VALUES (%s, %s, %s, %s);
#                     """,
#                     (
#                         request.session_id,
#                         "assistant",
#                         response_text,
#                         Json({
#                             "payment_order_id": payment_order_id,
#                             "payment_amount": payment_amount,
#                         }),
#                     ),
#                 )
#                 _insert_operation_log(
#                     cursor,
#                     operation="create",
#                     entity_type="chat_exchange",
#                     entity_id=request.session_id,
#                     user_id=user_id,
#                     session_id=request.session_id,
#                     new_data={
#                         "query": request.message,
#                         "response": response_text,
#                         "user_role": request.user_role,
#                         "active_scope": request.active_scope,
#                         "active_tenant_id": request.active_tenant_id,
#                     },
#                 )
#     except Exception as e:
#         print(f"⚠️ Failed to persist chat exchange: {e}")
#     finally:
#         conn.close()

# def _normalize_indian_phone(raw_phone: str) -> str:
#     digits = "".join(ch for ch in (raw_phone or "") if ch.isdigit())
#     if digits.startswith("91") and len(digits) == 12:
#         return f"+{digits}"
#     if len(digits) == 10:
#         return f"+91{digits}"
#     if raw_phone.startswith("+") and len(digits) >= 8:
#         return raw_phone
#     raise HTTPException(status_code=400, detail="Invalid phone number format")



# class UserStatusRequest(BaseModel):
#     email: str

class GoogleToken(BaseModel):
    id_token: str

# class CreateOrderRequest(BaseModel):
#     amount: float
#     receipt_id: str = "receipt_auto"


@app.post("/auth/google")
def google_auth(data: GoogleToken):
    return AuthManager().google_login(data.id_token)

# @app.get('/user-profile')
# def get_user_profile(authorization: str = Header(...)):
#     session_token = authorization.replace("Bearer ", "").strip()
#     user_profile = get_user_by_token(session_token)
#     if not user_profile:
#         raise HTTPException(status_code=401, detail = 'Invalid user')
#     return user_profile

# @app.post('/user-status')
# def user_status(request: UserStatusRequest):
#     """
#     Returns whether a user exists and is onboarded, used by login routing.
#     """
#     conn = _get_db_connection()
#     if conn is None:
#         raise HTTPException(status_code=500, detail="DATABASE_URL not configured")

#     try:
#         with conn:
#             with conn.cursor() as cursor:
#                 cursor.execute(
#                     """
#                     SELECT id, onboarded, role
#                     FROM users
#                     WHERE lower(email) = lower(%s)
#                     LIMIT 1
#                     """,
#                     (request.email.strip(),),
#                 )
#                 row = cursor.fetchone()
#                 if not row:
#                     return {
#                         "exists": False,
#                         "onboarded": False,
#                         "role": None,
#                     }
#                 return {
#                     "exists": True,
#                     "onboarded": bool(row[1]),
#                     "role": row[2],
#                     "user_id": row[0],
#                 }
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=f"Failed to fetch user status: {str(e)}")
#     finally:
#         conn.close()


# @app.post('/create-payment-order')
# def create_payment(request: CreateOrderRequest, currency: str = "INR", payment_capture: bool = True):
#     """
#     Create a Razorpay payment order.
#     Amount should be in paise (smallest currency unit).
#     """
#     try:
#         # Ensure amount is in paise (if sent in rupees, convert)
#         # Frontend sends amount in paise already, but handle both cases
#         amount = request.amount
#         if amount < 100:  # If amount is less than 100, assume it's in rupees
#             amount = int(amount * 100)  # Convert to paise
#         else:
#             amount = int(amount)  # Already in paise
        
#         # Generate receipt_id if not provided
#         receipt_id = request.receipt_id
#         if not receipt_id or receipt_id == "receipt_auto":
#             import uuid
#             receipt_id = f"rcpt_{uuid.uuid4().hex[:8]}"
        
#         order_data = {
#             "amount": amount,  # Amount in paise
#             "currency": currency,
#             "receipt": receipt_id,
#             "payment_capture": 1 if payment_capture else 0
#         }
        
#         order = razorpay_client.order.create(data=order_data)
#         print(f"✅ Payment order created: {order.get('id')}")
#         conn = _get_db_connection()
#         if conn is not None:
#             try:
#                 with conn:
#                     with conn.cursor() as cursor:
#                         _insert_operation_log(
#                             cursor,
#                             operation="create",
#                             entity_type="payment_order",
#                             entity_id=order.get("id"),
#                             new_data=order,
#                         )
#             except Exception as log_error:
#                 print(f"⚠️ Failed to audit payment order create: {log_error}")
#             finally:
#                 conn.close()
#         return order
#     except Exception as e:
#         print(f"❌ Error creating payment order: {str(e)}")
#         raise HTTPException(
#             status_code=500,
#             detail=f"Failed to create payment order: {str(e)}"
#         )


# # Digio Model
# class DigioKYC(BaseModel):
#     session_token: str
#     phone_number: str
#     first_name: str
#     last_name: str

# @app.post('/digio-kyc')
# async def initiate_digio(request: DigioKYC):
#     full_name = request.first_name + " " + request.last_name
#     body = {
#         "customer_identifier": request.phone_number,
#         "customer_name": full_name,
#         "template_name": "KE_DIGILOCKER_INTEGRATION",
#         "notify_customer": "false",
#         "generate_access_token": "true",
#         "request_details": {}
#     }
#     digio = DigioClient()
#     response = digio.initiate_kyc(body)
#     return response

# @app.post("/webhooks/digio")
# async def digio_webhook(request: Request):
#     try:
#         raw = await request.body()
#         payload = json.loads(raw.decode("utf-8"))
#     except Exception:
#         # ack quickly; log parse error
#         print("⚠️ Digio webhook: JSON parse error")
#         return {"ok": True}

#     print(payload)

#     digilocker_data = payload["payload"]["digilocker_request"]
#     kyc_request_id = digilocker_data["kyc_request_id"]
#     state = digilocker_data['state']

#     documents = DigioClient().fetch_user_data(kyc_request_id)
#     aadhaar_pan_data = DigioClient().extract_aadhaar_pan(documents)
#     pan_number = aadhaar_pan_data["aadhaar"]['id_number']
#     aadhar_number = aadhaar_pan_data["pan"]['id_number']
#     full_name = aadhaar_pan_data["aadhaar"]['name']
#     first_name, last_name = full_name.split(" ", 1)
#     dob = aadhaar_pan_data["pan"]['dob']

#     onboard_user = handle_user_onboarding(
#             session_token = request.session_token,
#             first_name = first_name,
#             last_name = last_name, 
#             dob = dob,
#             aadhaar =  aadhar_number,
#             pan = pan_number
#         )
#     return onboard_user

#     # if state == 'COMPLETED':
#     #     pass
#     # return {"success": "True"}

# @app.post("/extract-lease-content")
# async def extract_lease_content(
#     file: UploadFile = File(...),
#     query: str = Form("")
# ):
#     """
#     Extract lease content from PDF and process through the agentic chatbot.
#     The agent will identify this as a lease extraction task and route to the lease agent.
#     """
#     # 1) basic validation
#     if not (file.filename or "").lower().endswith(".pdf"):
#         raise HTTPException(status_code=400, detail="Only .pdf files are supported.")

#     # 2) stream upload to a temp file (works well with pypdf)
#     total = 0
#     try:
#         with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
#             while True:
#                 chunk = await file.read(1024 * 1024)  # 1MB
#                 if not chunk:
#                     break
#                 total += len(chunk)
#                 if total > MAX_FILE_MB * 1024 * 1024:
#                     raise HTTPException(status_code=413, detail=f"File too large (>{MAX_FILE_MB}MB).")
#                 tmp.write(chunk)
#             tmp_path = tmp.name
#     except HTTPException:
#         raise
#     except Exception:
#         raise HTTPException(status_code=500, detail="Failed to buffer uploaded file.")

#     # 3) Extract lease details using the extractor
#     try:
#         fields = extract_from_pdf(tmp_path)
#     except Exception as e:
#         # Clean up file on error
#         try: os.remove(tmp_path)
#         except Exception: pass
#         raise HTTPException(status_code=500, detail=f"Extraction failed: {e}")
    
#     # 4) Send a simple confirmation request to the chatbot agent
#     # The router agent will identify this as a lease-related task and route to lease_agent
#     try:
#         # Create a simple confirmation message - don't include extracted details
#         # The agent should just confirm that the lease was added
#         if query and query.strip():
#             # User provided a specific query - use it
#             agent_query = f"I've uploaded and extracted a lease document. The lease has been processed and saved. {query}"
#         else:
#             # Default confirmation message
#             agent_query = "I've uploaded and extracted a lease document. The lease has been processed and saved to my leases. Please confirm this briefly."
        
#         # Use the agentic chatbot to process this
#         # Router identifies this as a lease task → routes to lease_agent → returns confirmation with onboarding link
#         chat_result = assistant.chat(
#             query=agent_query,
#             session_id=f"lease_upload_{uuid.uuid4().hex[:12]}",
#             user_role="landlord",
#             active_scope="tenant",
#         )
        
#         # Normalize Unicode characters to prevent encoding issues
#         agent_response = normalize_text(chat_result.get("answer", "Alright, I've added the lease to your leases."))
        
#         # Generate tenant onboarding link from extracted lease data
#         # Use lease_id or create one from extracted fields
#         lease_id = f"lease_{hash(str(fields)) % 100000}"
#         tenant_name = fields.get('tenant_name', 'Tenant')
#         onboarding_link = f"https://kirayaease.com/onboard/{lease_id}"
        
#         # If agent response doesn't already include the link, append it
#         if onboarding_link not in agent_response:
#             agent_response += f"\n\n📎 Tenant Onboarding Link:\n{onboarding_link}\n\nShare this link with {tenant_name} to complete their onboarding and KYC verification."

#         conn = _get_db_connection()
#         if conn is not None:
#             try:
#                 with conn:
#                     with conn.cursor() as cursor:
#                         _insert_operation_log(
#                             cursor,
#                             operation="create",
#                             entity_type="lease_upload",
#                             entity_id=lease_id,
#                             new_data={
#                                 "fields": fields,
#                                 "onboarding_link": onboarding_link,
#                                 "tenant_name": tenant_name,
#                             },
#                         )
#             except Exception as log_error:
#                 print(f"⚠️ Failed to audit lease upload create: {log_error}")
#             finally:
#                 conn.close()
        
#         # Clean up the temp file after processing
#         try: os.remove(tmp_path)
#         except Exception: pass
        
#         return JSONResponse({
#             "fields": fields,
#             "agent_response": agent_response,
#             "onboarding_link": onboarding_link,  # Include link in response
#             "lease_id": lease_id,
#             "message": "Lease document processed successfully by the agent."
#         })
#     except Exception as e:
#         # If agent processing fails, still return the extracted fields
#         print(f"Agent processing error: {e}")
#         # Clean up the temp file
#         try: os.remove(tmp_path)
#         except Exception: pass
#         return JSONResponse({
#             "fields": fields,
#             "agent_response": "Alright, I've added the lease to your leases.",
#             "message": "Lease extracted successfully."
#         })


# class ChatResponse(BaseModel):
#     response: str
#     payment_order_id: Optional[str] = None
#     payment_amount: Optional[int] = None

# # Request model
# class ChatRequest(BaseModel):
#     message: str
#     session_id: str = "default"  # Session ID for conversation memory
#     conversation_history: Optional[List[dict]] = None  # Optional conversation history
#     user_role: str = "tenant"
#     active_scope: str = "self"
#     active_tenant_id: Optional[str] = None
#     property_context: Optional[Dict[str, Any]] = None

# # Initialize the agentic chatbot assistant
# # Using gpt-4o-mini for cost efficiency, can be changed to gpt-4 for better performance
# assistant = RentWiseAssistant(model_name="gpt-4o-mini", temperature=0, max_retries=3)


# @app.post("/chatbot", response_model=ChatResponse)
# async def chat_with_ai(request: ChatRequest):
#     """
#     Chat endpoint using the agentic framework with conversation memory.
#     Routes queries to specialized agents: lease, reminder, insights, and payments.
#     Maintains conversation context across messages using session_id.
#     """
#     try:
#         # Use the new chat method which uses the agentic framework with memory
#         chat_result = assistant.chat(
#             query=request.message,
#             session_id=request.session_id,
#             conversation_history=request.conversation_history,
#             user_role=request.user_role,
#             active_scope=request.active_scope,
#             active_tenant_id=request.active_tenant_id,
#             property_context=request.property_context,
#         )
        
#         # Normalize Unicode characters to prevent encoding issues
#         response_text = normalize_text(chat_result.get("answer", ""))
        
#         # Extract payment info if payment was initiated
#         payment_order_id = chat_result.get("payment_order_id")
#         payment_amount = chat_result.get("payment_amount")
        
#         # Debug logging
#         if payment_order_id:
#             print(f"✅ Payment order created: {payment_order_id}, amount: {payment_amount}")

#         _persist_chat_exchange(
#             request=request,
#             response_text=response_text,
#             payment_order_id=payment_order_id,
#             payment_amount=payment_amount,
#         )
        
#         return {
#             "response": response_text,
#             "payment_order_id": payment_order_id,
#             "payment_amount": payment_amount
#         }
#     except Exception as e:
#         print(f"❌ Chatbot error: {str(e)}")
#         raise HTTPException(status_code=500, detail=f"Chatbot error: {str(e)}")

# @app.get("/")
# def health_check():
#     return {"status": "KirayaEase API running"}