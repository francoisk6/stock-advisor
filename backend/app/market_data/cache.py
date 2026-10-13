import asyncio
import time
from collections.abc import Awaitable, Callable
from typing import Any

from app.market_data.types import ProviderError


class TTLCache:
    """In-process cache for upstream data, shared by all users of this worker.

    - One fetch per key at a time: concurrent requests wait for the same result.
    - If a refresh fails, the last good value is served (up to `stale_for`) instead of an error,
      which keeps the app usable while a free data source is rate limiting us.
    """

    def __init__(self, stale_for: float = 6 * 3600, max_entries: int = 5000) -> None:
        self._values: dict[str, tuple[float, Any]] = {}
        self._locks: dict[str, asyncio.Lock] = {}
        self._stale_for = stale_for
        self._max_entries = max_entries

    async def get_or_fetch(self, key: str, ttl: float, fetch: Callable[[], Awaitable[Any]]) -> Any:
        cached = self._values.get(key)
        if cached and time.monotonic() - cached[0] < ttl:
            return cached[1]
        lock = self._locks.setdefault(key, asyncio.Lock())
        async with lock:
            cached = self._values.get(key)
            if cached and time.monotonic() - cached[0] < ttl:
                return cached[1]
            try:
                value = await fetch()
            except ProviderError:
                if cached and time.monotonic() - cached[0] < self._stale_for:
                    return cached[1]
                raise
            self._store(key, value)
            return value

    def peek(self, key: str, ttl: float) -> Any | None:
        cached = self._values.get(key)
        if cached and time.monotonic() - cached[0] < ttl:
            return cached[1]
        return None

    def put(self, key: str, value: Any) -> None:
        self._store(key, value)

    def _store(self, key: str, value: Any) -> None:
        if len(self._values) >= self._max_entries:
            oldest = min(self._values, key=lambda k: self._values[k][0])
            self._values.pop(oldest, None)
            self._locks.pop(oldest, None)
        self._values[key] = (time.monotonic(), value)

    def clear(self) -> None:
        self._values.clear()
        self._locks.clear()
