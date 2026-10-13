import asyncio
from dataclasses import dataclass

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app.core.config import settings

_request = google_requests.Request()


@dataclass
class GoogleIdentity:
    subject: str
    email: str
    email_verified: bool
    name: str


class GoogleAuthError(Exception):
    pass


def _verify(token: str) -> GoogleIdentity:
    if not settings.google_client_ids:
        raise GoogleAuthError("Google sign-in is not configured")
    try:
        # audience=None here, checked below against every allowed client id (web + android).
        claims = id_token.verify_oauth2_token(
            token, _request, audience=None, clock_skew_in_seconds=10
        )
    except ValueError as exc:
        raise GoogleAuthError("Invalid Google token") from exc
    if claims.get("aud") not in settings.google_client_ids:
        raise GoogleAuthError("Google token was issued for another app")
    if claims.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise GoogleAuthError("Invalid Google token issuer")
    if not claims.get("email"):
        raise GoogleAuthError("Google account has no email")
    return GoogleIdentity(
        subject=str(claims["sub"]),
        email=str(claims["email"]).lower(),
        email_verified=bool(claims.get("email_verified")),
        name=str(claims.get("name") or ""),
    )


async def verify_google_id_token(token: str) -> GoogleIdentity:
    """Verify a Google ID token (signature, expiry, audience, issuer). Network call for certs."""
    return await asyncio.to_thread(_verify, token)
