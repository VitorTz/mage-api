from fastapi.exceptions import HTTPException
from fastapi import status
from dotenv import load_dotenv
from pathlib import Path
from typing import TypeVar, Awaitable, Optional
from src.exceptions import DatabaseError
import asyncpg
import os


load_dotenv()


class Database:
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None    

    async def execute_sql_file(self, path: Path, conn: asyncpg.Connection) -> None:
        try:
            if not path.exists():
                print(f"[WARN] Schema file not found: {path}")
                return
            
            with open(path, "r", encoding="utf-8") as f:
                sql_commands = f.read()
            await conn.execute(sql_commands)
            print(f"[INFO] Schema executado com sucesso: {path}")
        except Exception as e:
            print(f"[ERROR] Falha ao executar schema [{path}] | {e}")

    async def connect(self):
        print("Iniciando conexão com o Banco de Dados...")
        try:
            self.pool = await asyncpg.create_pool(
                dsn=os.getenv("DATABASE_URL"),
                min_size=1,
                max_size=10,
                command_timeout=60,
                statement_cache_size=0 
            )
                    
            async with self.pool.acquire() as conn:
                version = await conn.fetchval("SELECT version()")
                print(f"Conectado ao Postgres: {version}")
                
                # Migração [Alembic ou dbmate em produção]
                await self.execute_sql_file(Path("db/schema.sql"), conn)
                await self.execute_sql_file(Path("db/views.sql"), conn)
                await self.execute_sql_file(Path("db/insertions.sql"), conn)
                await self.execute_sql_file(Path("db/index.sql"), conn)
                await self.execute_sql_file(Path("db/rls.sql"), conn)

            print("DB Pool conectado com sucesso (Supabase Mode)")
            
        except Exception as e:
            print(f"Erro CRÍTICO ao conectar no banco: {e}")
            raise e

    async def disconnect(self):
        if self.pool:
            await self.pool.close()
            print("DB Pool encerrado corretamente")


db = Database()


async def get_db_pool():
    if db.pool is None:
        raise RuntimeError("Database pool não foi inicializado. Verifique o startup.")
    return db.pool
        

T = TypeVar("T")

ERROR_MAP = {
    "users_unique_email": "Email já cadastrado.",
    "users_unique_cpf": "CPF já cadastrado.",
    "products_sku_key": "SKU já existe.",
    "product_barcodes_pkey": "Código de barras já existe.",

    "users_name_length": "Nome deve ter entre 3 e 256 caracteres.",
    "users_nickname_length": "Apelido deve ter entre 3 e 256 caracteres.",
    "users_note_length": "Anotação deve ter no máximo 512 caracteres.",
    "users_cpf_format": "CPF inválido.",
    "users_phone_format": "Número de telefone inválido",

    "sale_items_greater_than_zero": "Um item pertencente a compra não pode ter quantidade zero."
}

async def db_safe_exec(operation: Awaitable[T]) -> T:
    try:
        return await operation
    except asyncpg.exceptions.UniqueViolationError as e:
        detail = ERROR_MAP.get(e.constraint_name, "Conflito de dados únicos.")
        raise DatabaseError(
            code=status.HTTP_409_CONFLICT,
            detail=detail
        )
    except asyncpg.exceptions.CheckViolationError as e:
        detail = ERROR_MAP.get(e.constraint_name, "Dados inválidos")        
        raise DatabaseError(
            code=status.HTTP_400_BAD_REQUEST,
            detail=detail
        )
    except Exception as e:
        if isinstance(e, HTTPException): raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail="Erro interno ao processar operação."
        )