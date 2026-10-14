from fastapi import APIRouter, WebSocket

from app.realtime.hub import hub

router = APIRouter(tags=["live"])


@router.websocket("/ws")
async def live_updates(websocket: WebSocket) -> None:
    """Live prices and notifications; see app/realtime/hub.py for the message protocol."""
    await hub.serve(websocket)
