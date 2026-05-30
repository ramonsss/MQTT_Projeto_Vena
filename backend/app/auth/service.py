import hashlib
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.google import verify_google_token
from app.auth.jwt import create_access_token, create_refresh_token
from app.auth.schemas import TokenResponse, UserInfo
from app.config import settings
from app.db.models import RefreshToken, User


def _hash_token(raw: str) -> str:
    """SHA-256 of the raw token string — stored in DB for O(1) lookup.

    A UUID refresh token has 128 bits of entropy, so SHA-256 (without salt)
    is sufficient: dictionary attacks are impossible at this entropy level.
    bcrypt would add unnecessary latency on every refresh call.
    """
    return hashlib.sha256(raw.encode()).hexdigest()


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


def _token_response(user: User, access_token: str, raw_refresh: str) -> TokenResponse:
    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        expires_in=settings.jwt_expire_minutes * 60,
        user=UserInfo(id=user.id, email=user.email),
    )


async def login_with_google(id_token: str, session: AsyncSession) -> TokenResponse:
    """Validate Google id_token, upsert User, issue access + refresh tokens."""
    # 1. Verify with Google
    try:
        google_info = verify_google_token(id_token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))

    # 2. Upsert user by google_sub
    result = await session.execute(
        select(User).where(User.google_sub == google_info.sub)
    )
    user = result.scalar_one_or_none()
    if user is None:
        user = User(google_sub=google_info.sub, email=google_info.email)
        session.add(user)
        await session.flush()  # populate user.id before using it below
    else:
        user.email = google_info.email  # keep email in sync with Google

    # 3. Issue tokens
    access_token = create_access_token(user)
    raw_refresh, expires_at = create_refresh_token()

    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=_hash_token(raw_refresh),
            expires_at=expires_at,
        )
    )
    await session.commit()

    return _token_response(user, access_token, raw_refresh)


async def refresh_access_token(
    raw_refresh: str, session: AsyncSession
) -> TokenResponse:
    """Rotate a refresh token: revoke the old one, issue a new pair."""
    now = _now()
    token_hash = _hash_token(raw_refresh)

    # 1. Find a valid (non-revoked, non-expired) token with this hash
    result = await session.execute(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        )
    )
    rt = result.scalar_one_or_none()
    if rt is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token is invalid, expired, or already revoked",
        )

    # 2. Load the owner
    result = await session.execute(select(User).where(User.id == rt.user_id))
    user = result.scalar_one()

    # 3. Revoke old token (rotation — each token can only be used once)
    rt.revoked_at = now

    # 4. Issue new tokens
    access_token = create_access_token(user)
    new_raw, new_expires_at = create_refresh_token()

    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=_hash_token(new_raw),
            expires_at=new_expires_at,
        )
    )
    await session.commit()

    return _token_response(user, access_token, new_raw)
