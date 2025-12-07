from fastapi import Depends, HTTPException, status, Cookie, Response
from datetime import datetime, timedelta, timezone
from src.view.user import UserPayload
from src.view.token import SessionToken, Token
from src.constants import Constants
from passlib.context import CryptContext
from src.exceptions import DatabaseError
from typing import Optional
from asyncpg import Pool
from asyncpg.connection import Connection
from src.db.db import get_db_pool
from src import util
import uuid
import jwt



pwd_context = CryptContext(
    schemes=["argon2"],     
    deprecated="auto"
)

VALID_ROLES = {
    'ADMIN', 
    'CAIXA', 
    'GERENTE', 
    'CLIENTE', 
    'ESTOQUISTA', 
    'CONTADOR'
}

CREDENTIALS_EXCEPTION = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)

USER_IS_NOT_ACTIVE_EXCEPTION = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="User exists but is not active",
    headers={"WWW-Authenticate": "Bearer"},
)

INVALID_PASSWORD_EXCEPTION = HTTPException(
    status_code=status.HTTP_400_BAD_REQUEST,
    detail="Password must be at least 8 characters long"
)


def hash_password(password: str) -> str:
    if not password or len(password) < 8:
        raise INVALID_PASSWORD_EXCEPTION
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:    
    try:      
        return pwd_context.verify(plain_password, hashed_password)
    except Exception:
        return False


def create_access_token(user_id: uuid.UUID | str, role: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(
        hours=Constants.ACCESS_TOKEN_EXPIRE_HOURS
    )

    token_id = str(uuid.uuid4())
    
    payload = {
        "sub": str(user_id),
        "exp": expires_at,
        "jti": token_id,
        "role": role,
        "type": "access",
    }
    
    token = jwt.encode(
        payload,
        Constants.SECRET_KEY,
        algorithm=Constants.ALGORITHM
    )    
    
    return Token(id=token_id, token=token, expires_at=expires_at)

def create_refresh_token(user_id: uuid.UUID | str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(
        days=Constants.REFRESH_TOKEN_EXPIRE_DAYS
    )    
    
    token_id = str(uuid.uuid4())
    payload = {
        "sub": str(user_id),
        "exp": expires_at,
        "jti": token_id,
        "type": "refresh"
    }
    
    token = jwt.encode(
        payload,
        Constants.SECRET_KEY,
        algorithm=Constants.ALGORITHM
    )
    
    return Token(id=token_id, token=token, expires_at=expires_at)
    


def create_session_token(user_id: uuid.UUID | str, role: str) -> SessionToken:
    return SessionToken(
        access_token=create_access_token(user_id, role),
        refresh_token=create_refresh_token(user_id)
    )


async def extract_payload_optional(access_token: Optional[str] = Cookie(default=None)) -> Optional[UserPayload]:
    if access_token is None: return None
    try:
        payload = jwt.decode(
            access_token,
            Constants.SECRET_KEY,
            algorithms=[Constants.ALGORITHM]
        )
        
        user_id: Optional[str] = payload.get("sub")
        token_type: Optional[str] = payload.get("type")
        role: str = payload.get("role", "CLIENTE")
        if role not in VALID_ROLES: role = "CLIENTE"
            
        if user_id is None or token_type != "access":
            return None
            
        return UserPayload(user_id=user_id, role=role)
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None
        

async def get_rls_connection(
    pool: Pool = Depends(get_db_pool),
    user_payload: Optional[UserPayload] = Depends(extract_payload_optional)
) -> Connection:
    async with pool.acquire() as connection:
        async with connection.transaction():
            try:
                if user_payload:                    
                    await connection.execute(
                        "SELECT set_config('app.current_user_id', $1, true), "
                        "       set_config('app.current_user_role', $2, true)",
                        str(user_payload.user_id),
                        user_payload.role
                    )
                else:
                    await connection.execute(
                        "SELECT set_config('app.current_user_id', '', true), "
                        "       set_config('app.current_user_role', '', true)"
                    )
                
                yield connection            
            except Exception as e:
                print(f"[CRITICAL] Erro ao configurar sessão RLS: {e}")
                raise DatabaseError(status_code=500, detail="Security context failure.")


def require_user(payload: Optional[UserPayload] = Depends(extract_payload_optional)) -> UserPayload:
    if payload is None:
        raise CREDENTIALS_EXCEPTION
    return payload


def set_session_token_cookie(response: Response, session_token: SessionToken):
    if Constants.IS_PRODUCTION:
        samesite_policy = "none"
        secure_policy = True
    else:
        samesite_policy = "lax"
        secure_policy = False
    
    # Cookie do Access Token (curta duração)
    response.set_cookie(
        key="access_token",
        value=session_token.access_token.token,
        httponly=True,
        secure=secure_policy,
        samesite=samesite_policy,
        path="/",
        max_age=util.seconds_until(session_token.access_token.expires_at)
    )
    
    # Cookie do Refresh Token (longa duração)
    response.set_cookie(
        key="refresh_token",
        value=session_token.refresh_token.token,
        httponly=True,
        secure=secure_policy,
        samesite=samesite_policy,
        path="/",
        max_age=util.seconds_until(session_token.refresh_token.expires_at)
    )


def unset_session_token_cookie(response: Response):
    if Constants.IS_PRODUCTION:
        samesite_policy = "none"
        secure_policy = True
    else:
        samesite_policy = "lax"
        secure_policy = False

    response.delete_cookie(
        key="access_token",
        httponly=True,
        path="/",
        samesite=samesite_policy,
        secure=secure_policy
    )

    response.delete_cookie(
        key="refresh_token",
        httponly=True,
        path="/",
        samesite=samesite_policy,
        secure=secure_policy
    )
