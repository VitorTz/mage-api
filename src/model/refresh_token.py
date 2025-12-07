from asyncpg import Connection
from uuid import UUID


async def create_refresh_token(id: UUID, user_id: UUID, conn: Connection) -> None:
    await conn.execute(
        """
            INSERT INTO refresh_tokens (
                id,
                user_id
            )
            VALUES
                ($1, $2)
        """,
        id,
        user_id
    )