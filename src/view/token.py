from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class Token(BaseModel):
    
    id: str
    token: str
    expires_at: datetime


class SessionToken(BaseModel):
    
    access_token: Token
    refresh_token: Token