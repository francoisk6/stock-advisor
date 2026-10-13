import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status


class RateLimiter:
    """In-memory sliding-window limiter. Per process — fine while we run a single API worker."""

    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def hit(self, key: str, limit: int, window_seconds: int) -> bool:
        """Record a hit; return False if the key is over its limit."""
        now = time.monotonic()
        hits = self._hits[key]
        while hits and hits[0] <= now - window_seconds:
            hits.popleft()
        if len(hits) >= limit:
            return False
        hits.append(now)
        return True

    def reset(self) -> None:
        self._hits.clear()


limiter = RateLimiter()


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def enforce(key: str, limit: int, window_seconds: int) -> None:
    if not limiter.hit(key, limit, window_seconds):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many attempts. Please wait a few minutes and try again.",
        )
