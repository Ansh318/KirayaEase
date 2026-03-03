from pydantic import BaseModel

class GoogleToken(BaseModel):
    id_token: str