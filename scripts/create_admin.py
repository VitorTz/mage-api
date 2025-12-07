from dotenv import load_dotenv
from src import security
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
        phone = input("telefone: ").strip()
        raw_password = input("senha: ").strip()
        hashed = security.hash_password(raw_password)
        role = "ADMIN"  
        await conn.execute("""
            INSERT INTO users (
                name,
                email,
                password_hash,
                phone,
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
        """,
        name,
        email,
        hashed,
        phone,
        role
    )
        print(f"Admin criado com sucesso! Login: {email}")
    except Exception as e:
        print(f"Erro: {e}")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(create_superuser())