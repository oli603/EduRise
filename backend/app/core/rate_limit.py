import time
from typing import Dict, Tuple
from fastapi import HTTPException, status, Request
from .config import get_settings

settings = get_settings()

# In-memory sliding window rate limiter: key -> (request_count, window_start_time)
_RATE_LIMIT_STORE: Dict[str, Tuple[int, float]] = {}


def check_rate_limit(key: str, max_requests: int = None, window_seconds: int = 60) -> bool:
    """
    Token-bucket / sliding window rate limiter.
    Returns True if request is allowed, raises 429 if rate limit exceeded.
    """
    if max_requests is None:
        max_requests = settings.RATE_LIMIT_PER_MINUTE

    now = time.time()
    if key not in _RATE_LIMIT_STORE:
        _RATE_LIMIT_STORE[key] = (1, now)
        return True

    count, start_time = _RATE_LIMIT_STORE[key]
    elapsed = now - start_time

    if elapsed > window_seconds:
        _RATE_LIMIT_STORE[key] = (1, now)
        return True
    else:
        if count >= max_requests:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Please wait {int(window_seconds - elapsed)} seconds before trying again.",
            )
        _RATE_LIMIT_STORE[key] = (count + 1, start_time)
        return True
