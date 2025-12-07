from fastapi import status, Response
from fastapi.responses import JSONResponse
from fastapi.exceptions import HTTPException
from src.view.auth import LoginRequest
from src.view.token import SessionToken
from src.view.user import UserLoginData, UserResponse
from src.model import user as user_model
from src.model import refresh_token as refresh_token_model
from src.exceptions import DatabaseError
from src.security import verify_password, create_session_token, set_session_token_cookie
from typing import Optional
from asyncpg import Connection


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
    
    if not verify_password(login_req.password, data.password_hash):
        raise INVALID_CREDENTIALS
        
    if data.role == "CLIENTE":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso não permitido para perfil Cliente."
        )
        
    session_token = create_session_token(data.id, data.role)
        
    await refresh_token_model.create_refresh_token(
        session_token.refresh_token.id,
        data.id,
        conn
    )
        
    set_session_token_cookie(response, session_token)
        
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