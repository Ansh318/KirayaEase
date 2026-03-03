from fastapi import APIRouter
from schemas.google_auth import GoogleToken
from services.auth_services import AuthManager

router = APIRouter()

@router.post("/auth-google")
def google_auth(data: GoogleToken):
    return AuthManager().google_login(data.id_token)