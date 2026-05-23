from dataclasses import dataclass

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app.config import settings


@dataclass
class GoogleUserInfo:
    sub: str
    email: str
    name: str | None


def verify_google_token(token: str) -> GoogleUserInfo:
    """Validate a Google id_token and return basic user info.

    Uses Google's public keys to verify the signature and the configured
    GOOGLE_CLIENT_ID to verify the ``aud`` claim — so only tokens issued
    for this specific app are accepted.

    Raises:
        ValueError: if the token is invalid, expired, or issued for a
                    different client.
    """
    try:
        idinfo = id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            # Empty string disables aud validation in dev (no client id set).
            # In production GOOGLE_CLIENT_ID must be configured.
            settings.google_client_id or None,
        )
    except Exception as exc:
        raise ValueError(f"Invalid Google token: {exc}") from exc

    return GoogleUserInfo(
        sub=idinfo["sub"],
        email=idinfo["email"],
        name=idinfo.get("name"),
    )
