import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt import decode_token
from app.db.models import User
from app.db.session import get_session

# tokenUrl is informational only (used by OpenAPI docs); the real login
# endpoint is POST /auth/google, not a form-based password flow.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/google")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    session: AsyncSession = Depends(get_session),
) -> User:
    """FastAPI dependency — resolves the Bearer JWT to a User row.

    Raises HTTP 401 if the token is missing, invalid, expired, or the
    user no longer exists in the database.
    """
    unauth = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token)
        sub: str | None = payload.get("sub")
        if sub is None:
            raise unauth
        user_id = uuid.UUID(sub)
    except (JWTError, ValueError):
        raise unauth

    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise unauth
    return user
