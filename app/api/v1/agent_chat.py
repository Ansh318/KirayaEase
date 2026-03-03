from fastapi import APIRouter, HTTPException, Header
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse, PlainTextResponse
from core.workflow import build_graph
from services.onboarding_services import UserService

router = APIRouter()

def build_initial_state(message: str,session_id: str, authorization: str = Header(...)):
    # session_id here is the auth session token string
    profile = UserService().get_user_by_token(session_id)
    session_token = authorization.replace("Bearer ", "").strip()

    return {
        "messages": [{"role": "user", "content": message}],
        "user_id": profile["user_id"],
        "role": profile["role"],
        "session_id": session_token,
        "intent": None,
        "query_result": None,
    }

@router.post("/agent-chat")
def agent_chat(message: str,session_id: str, authorization: str = Header(...)):
    state = build_initial_state(message,session_id, authorization)
    result = build_graph().invoke(state)
    return result