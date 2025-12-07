from fastapi import status, Response
from fastapi.exceptions import HTTPException
from src.schemas.auth import LoginRequest
from src.schemas.user import UserLoginData, UserResponse
from src.model import user as user_model
from src.model import refresh_token as refresh_token_model
from typing import Optional
from asyncpg import Connection
from src import security


INVALID_CREDENTIALS = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED, 
    detail="Email, CPF ou senha inválidos."
)

async def login(
    login_req: LoginRequest, 
    response: Response, 
    conn: Connection
) -> UserResponse:
    
    data: Optional[UserLoginData] = await user_model.get_user_login_data(
        login_req.identifier,
        conn
    )    

    if not data:
        raise INVALID_CREDENTIALS
    
    if not security.verify_password(login_req.password, data.password_hash):
        raise INVALID_CREDENTIALS
        
    if data.role == "CLIENTE":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso não permitido para perfil Cliente."
        )
        
    session_token = security.create_session_token(data.id, data.role)
        
    await refresh_token_model.create_refresh_token(
        session_token.refresh_token.id,
        data.id,
        conn
    )
        
    security.set_session_token_cookie(response, session_token)
        
    return UserResponse(
        id=data.id,
        name=data.name,
        nickname=data.nickname,
        email=data.email,
        role=data.role,
        notes=data.notes,
        state_tax_indicator=data.state_tax_indicator,
        credit_limit=data.credit_limit,
        invoice_amount=data.invoice_amount,
        created_at=data.created_at,
        updated_at=data.updated_at
    )