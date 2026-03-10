from pydantic import BaseModel


class OnboardingRequest(BaseModel):
    first_name: str
    last_name: str
    role: str
