# Digio Model
from pydantic import BaseModel
class DigioKYC(BaseModel):
    session_token: str
    phone_number: str
    first_name: str
    last_name: str