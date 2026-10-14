"""Live updates over one WebSocket per open app: prices for what's on screen + new notifications.

Protocol (JSON messages):
  client -> {"type": "auth", "token": "<access token>"}        (first message, within 10 s)
  client -> {"type": "subscribe", "asset_ids": [1, 2, ...]}    (replaces the previous set)
  server -> {"type": "ready"}
  server -> {"type": "quotes", "quotes": {"<asset id>": QuoteOut, ...}}   (only changed ones)
  server -> {"type": "notification", "notification": NotificationOut, "unread_count": n}
Auth failures close the socket with code 4401.

In-process registry: valid while the API runs as a single worker (see CLAUDE.md).
"""

import asyncio
import contextlib
import itertools
import logging
from dataclasses import dataclass, field
from typing import Any

from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.core.security import decode_access_token
from app.db.models import Asset, User
from app.db.session import SessionLocal
from app.market_data import service as market
from app.market_data.types import Quote

logger = logging.getLogger(__name__)

AUTH_TIMEOUT_SECONDS = 10
MAX_SUBSCRIPTIONS = 100
CLOSE_UNAUTHORIZED = 4401


def quote_payload(quote: Quote) -> dict[str, Any]:
    return {
        "price": quote.price,
        "change": quote.change,
        "change_percent": quote.change_percent,
        "previous_close": quote.previous_close,
        "currency": quote.currency,
        "as_of": quote.as_of.isoformat(),
        "market_open": quote.market_open,
    }


@dataclass(eq=False)
class Connection:
    websocket: WebSocket
    user_id: int
    asset_ids: set[int] = field(default_factory=set)
    sent: dict[int, tuple[float, float | None]] = field(default_factory=dict)
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def send(self, message: dict[str, Any]) -> bool:
        async with self.lock:
            try:
                await self.websocket.send_json(message)
                return True
            except Exception:  # client went away mid-send
                return False


class Hub:
    def __init__(self) -> None:
        self._connections: dict[int, Connection] = {}
        self._ids = itertools.count(1)

    @property
    def connection_count(self) -> int:
        return len(self._connections)

    async def serve(self, websocket: WebSocket) -> None:
        await websocket.accept()
        user_id = await self._authenticate(websocket)
        if user_id is None:
            return
        conn_id = next(self._ids)
        conn = Connection(websocket, user_id)
        self._connections[conn_id] = conn
        await conn.send({"type": "ready"})
        try:
            while True:
                message = await websocket.receive_json()
                if message.get("type") == "subscribe":
                    ids = message.get("asset_ids") or []
                    conn.asset_ids = {int(i) for i in ids[:MAX_SUBSCRIPTIONS] if str(i).isdigit()}
                    conn.sent = {k: v for k, v in conn.sent.items() if k in conn.asset_ids}
                    await self.push_quotes([conn])
        except (WebSocketDisconnect, RuntimeError, ValueError):
            pass
        finally:
            self._connections.pop(conn_id, None)

    async def _authenticate(self, websocket: WebSocket) -> int | None:
        try:
            message = await asyncio.wait_for(websocket.receive_json(), AUTH_TIMEOUT_SECONDS)
        except (TimeoutError, WebSocketDisconnect, ValueError, RuntimeError):
            message = {}
        user_id = None
        if message.get("type") == "auth" and isinstance(message.get("token"), str):
            user_id = decode_access_token(message["token"])
        if user_id is not None:
            async with SessionLocal() as session:
                user = await session.get(User, user_id)
                if user is None or not user.is_active:
                    user_id = None
        if user_id is None:
            with contextlib.suppress(Exception):
                await websocket.send_json({"type": "error", "detail": "Not signed in"})
                await websocket.close(code=CLOSE_UNAUTHORIZED)
        return user_id

    async def push_quotes(self, connections: list[Connection] | None = None) -> None:
        """Send fresh prices for subscribed assets; only what changed since the last send."""
        targets = connections if connections is not None else list(self._connections.values())
        wanted = set().union(*(c.asset_ids for c in targets)) if targets else set()
        if not wanted:
            return
        async with SessionLocal() as session:
            assets = list(
                (await session.execute(select(Asset).where(Asset.id.in_(wanted)))).scalars()
            )
        quotes = await market.quotes_for(assets, max_age=market.LIVE_QUOTE_TTL)
        for conn in targets:
            changed = {}
            for asset_id in conn.asset_ids:
                quote = quotes.get(asset_id)
                if quote is None:
                    continue
                signature = (quote.price, quote.change_percent)
                if conn.sent.get(asset_id) != signature:
                    changed[str(asset_id)] = quote_payload(quote)
                    conn.sent[asset_id] = signature
            if changed:
                await conn.send({"type": "quotes", "quotes": changed})

    async def notify_user(self, user_id: int, message: dict[str, Any]) -> None:
        for conn in [c for c in self._connections.values() if c.user_id == user_id]:
            await conn.send(message)


hub = Hub()
