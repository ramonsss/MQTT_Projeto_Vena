from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.schemas import GoogleLoginRequest, RefreshRequest, TokenResponse
from app.auth.service import login_with_google, refresh_access_token
from app.db.session import get_session

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/google", response_model=TokenResponse)
async def google_login(
    body: GoogleLoginRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    return await login_with_google(body.id_token, session)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    body: RefreshRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    return await refresh_access_token(body.refresh_token, session)
