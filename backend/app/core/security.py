import base64
import json
import time
from typing import Optional, Dict, Any
import httpx
from fastapi import Header, HTTPException, status, Depends
from pydantic import BaseModel
from .config import get_settings

settings = get_settings()


class AuthenticatedUser(BaseModel):
    uid: str
    email: Optional[str] = None
    role: str = "student"
    stream: str = "natural"
    is_paid: bool = False
    access_status: str = "active"


from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

_auth_request = google_requests.Request()


async def get_current_user(
    authorization: Optional[str] = Header(None, alias="Authorization"),
) -> AuthenticatedUser:
    """
    Verifies Firebase Authentication ID token passed in Authorization: Bearer <token>.
    Cryptographically verifies the token signature against Google's public keys.
    Supports development/test tokens in non-production environments.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split("Bearer ", 1)[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Empty bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 1. Development / Test token bypass for automated testing (only in dev/test)
    if settings.ENVIRONMENT in ["development", "test"] and token.startswith("test_token_"):
        parts = token.split("_")
        uid = "_".join(parts[2:]) if len(parts) > 2 else "test_student"
        role = "admin" if "admin" in token else "student"
        is_paid = "free" not in token and "unpaid" not in token
        stream = "social" if "social" in token else "natural"

        return AuthenticatedUser(
            uid=uid,
            email=f"{uid}@edurise.edu",
            role=role,
            stream=stream,
            is_paid=is_paid,
            access_status="active",
        )

    # 2. Cryptographic Firebase Token validation against Google's public certificates
    try:
        claims = google_id_token.verify_firebase_token(
            token,
            _auth_request,
            audience=settings.FIREBASE_PROJECT_ID if settings.FIREBASE_PROJECT_ID else None,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or unverifiable authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Extract authoritative UID from verified claims
    uid = claims.get("user_id") or claims.get("sub")
    if not uid or not isinstance(uid, str) or not uid.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is missing authoritative user identifier.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = claims.get("email")
    role = claims.get("role", "student")
    if role not in ["student", "admin", "founder"]:
        role = "student"

    # Check bootstrap founders/admins by email whitelist
    if email and email.lower() in ["olanamengistu2@gmail.com", "tamiratboja@gmail.com"]:
        role = "admin"

    stream = claims.get("stream", "natural")
    if stream not in ["natural", "social"]:
        stream = "natural"

    # is_paid strictly defaults to False (fail-closed)
    raw_is_paid = claims.get("is_paid", False)
    is_paid = True if raw_is_paid is True or raw_is_paid == "true" else False

    access_status = claims.get("access_status", "active")

    return AuthenticatedUser(
        uid=uid.strip(),
        email=email,
        role=role,
        stream=stream,
        is_paid=is_paid,
        access_status=access_status,
    )



async def require_admin(
    user: AuthenticatedUser = Depends(get_current_user),
) -> AuthenticatedUser:
    if user.role not in ["admin", "founder"] and (
        not user.email
        or user.email.lower()
        not in [
            "olanamengistu2@gmail.com",
            "tamiratboja@gmail.com",
        ]
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrative privileges required.",
        )
    return user


async def require_paid_user(
    user: AuthenticatedUser = Depends(get_current_user),
) -> AuthenticatedUser:
    if not user.is_paid and user.role not in ["admin", "founder"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Active paid subscription required to access this feature.",
        )
    return user

