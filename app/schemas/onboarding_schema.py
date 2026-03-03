from pydantic import BaseModel
from typing import Optional
from datetime import date

class OnboardingRequest(BaseModel):
    first_name: str
    last_name: str
    dob: Optional[date] = None
    aadhaar: Optional[str] = None
    pan: Optional[str] = None
    role: str
