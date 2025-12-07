from src.view.user import UserLoginData
from asyncpg import Connection
from typing import Optional
import re


async def get_user_login_data(identifier: str, conn: Connection) -> Optional[UserLoginData]:
    clean = identifier.strip().lower()
    numeric = re.sub(r'\D', '', identifier)
        
    base_query = """
        SELECT 
            id, name, nickname, email, password_hash, notes,
            role, state_tax_indicator, credit_limit, 
            invoice_amount, created_at, updated_at
        FROM users 
        WHERE is_active = TRUE AND 
    """
    
    row = None
    
    if '@' in clean: # EMAIL
        query = base_query + "LOWER(email) = $1"
        row = await conn.fetchrow(query, clean)
    elif len(numeric) == 11: # CPF
        query = base_query + "cpf = $1"        
        row = await conn.fetchrow(query, numeric) 

    return UserLoginData(**dict(row)) if row else None