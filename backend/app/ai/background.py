"""Slow AI writing (briefs, explanations) runs in the background: the request returns at once
with "writing" and the app polls. Browsers and reverse proxies give up on minute-long requests.

In-process registry (single API worker, like the other background work)."""

import asyncio
import logging
from collections.abc import Awaitable, Callable

from app.ai.types import AIUnavailable

logger = logging.getLogger(__name__)

_tasks: dict[str, asyncio.Task] = {}
_errors: dict[str, str] = {}

BUSY = "The writer is busy or offline. Please try again in a few minutes."


def start(key: str, work: Callable[[], Awaitable[object]]) -> None:
    """Start `work` for `key` unless it's already running."""
    if key in _tasks and not _tasks[key].done():
        return
    _errors.pop(key, None)

    async def run() -> None:
        try:
            await work()
        except AIUnavailable:
            logger.exception("Background writing %s: model unavailable", key)
            _errors[key] = BUSY
        except Exception:
            logger.exception("Background writing %s failed", key)
            _errors[key] = "Something went wrong while writing. Please try again."

    _tasks[key] = asyncio.create_task(run())


def is_running(key: str) -> bool:
    task = _tasks.get(key)
    return task is not None and not task.done()


def error(key: str) -> str | None:
    return None if is_running(key) else _errors.get(key)


async def wait(key: str) -> None:
    """For tests: wait until the work for `key` has finished."""
    task = _tasks.get(key)
    if task is not None:
        await asyncio.gather(task, return_exceptions=True)


def clear() -> None:
    """For tests."""
    _tasks.clear()
    _errors.clear()
