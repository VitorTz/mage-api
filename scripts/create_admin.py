from passlib.context import CryptContext
from src.security import hash_password
from dotenv import load_dotenv
import asyncio
import asyncpg
import os

load_dotenv()


async def create_superuser():
    conn = await asyncpg.connect(os.getenv("DATABASE_URL"))
    try:
        print("[ADMIN]")
        name = input("nome: ").strip()
        email = input("email: ").strip()
        raw_password = input("senha: ").strip()
        hashed = hash_password(raw_password)
        role = "ADMIN"        
        await conn.execute("""
            INSERT INTO users (
                name, 
                email, 
                password_hash, 
                role                
            )
            VALUES (
                $1,
                $2,
                $3, 
                $4
            )
            ON CONFLICT 
                (email) 
            DO NOTHING
        """, name, email, hashed, role)
        print(f"Admin criado com sucesso! Login: {email}")
    except Exception as e:
        print(f"Erro: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(create_superuser())