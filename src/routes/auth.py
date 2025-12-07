from fastapi import APIRouter, Depends, status, Response
from src.view.auth import LoginRequest
from src.view.user import UserResponse
from src.db.db import get_db_pool
from src.controller import auth
from asyncpg import Pool


router = APIRouter()


@router.post("/login", status_code=status.HTTP_200_OK, response_model=UserResponse)
async def login(
    login_req: LoginRequest,
    response: Response,
    pool: Pool = Depends(get_db_pool)
):
    async with pool.acquire() as conn:
        return await auth.login(login_req, response, conn)