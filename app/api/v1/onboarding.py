from fastapi import APIRouter, Header, HTTPException
from app.services.onboarding_services import UserService
from app.schemas.onboarding_schema import OnboardingRequest


router = APIRouter()

@router.post("/onboarding")
def onboarding(data: OnboardingRequest, authorization: str = Header(...)):
    session_token = authorization.replace("Bearer ", "").strip()
    b = UserService().handle_user_onboarding(session_token, data.first_name, data.last_name, data.dob, data.aadhaar, data.pan, data.role)
    print(b)
    return (b)

@router.get('/user-profile')
def get_user_profile(authorization: str = Header(...)):
    session_token = authorization.replace("Bearer ", "").strip()
    user_profile = UserService().get_user_by_token(session_token)
    if not user_profile:
        raise HTTPException(status_code=401, detail = 'Invalid user')
    return user_profile