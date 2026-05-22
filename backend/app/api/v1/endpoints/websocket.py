"""
WebSocket Endpoint — /api/v1/ws

Provides a persistent WebSocket connection (RFC 6455 / Protocol 13) so the
server can push real-time sync notifications to the Flutter client.

Flow:
  1. Flutter opens  ws://<host>/api/v1/ws?token=<access_token>
  2. Server verifies the JWT and registers the connection under user_id.
  3. After a successful vocabulary/history sync, the sync endpoint calls
     ConnectionManager.broadcast_sync_completed(user_id, synced_count).
  4. Flutter receives the JSON event and triggers a local Isar reload so
     both the History and Saved-Vocab tabs update their isSynced badges.

Message format (server → client):
  {
    "event":        "sync_completed",
    "synced_count": <int>,
    "timestamp":    "<ISO-8601 UTC>"
  }

Message format (client → server):
  { "ping": true }   — keepalive; server replies  { "pong": true }
"""
import logging
from datetime import datetime, timezone
from typing import Dict, List

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, status
from jose import JWTError

from app.core.security import verify_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["websocket"])


# ---------------------------------------------------------------------------
# Connection Manager (in-process singleton — sufficient for single-worker
# deployment; replace with Redis pub/sub for multi-worker setups)
# ---------------------------------------------------------------------------

class ConnectionManager:
    """Manages all active WebSocket connections, keyed by user_id."""

    def __init__(self) -> None:
        # user_id → list of open WebSocket objects
        self._connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int) -> None:
        await websocket.accept()
        self._connections.setdefault(user_id, []).append(websocket)
        logger.info("WS connected: user_id=%s (total=%d)", user_id,
                    len(self._connections[user_id]))

    def disconnect(self, websocket: WebSocket, user_id: int) -> None:
        conns = self._connections.get(user_id, [])
        if websocket in conns:
            conns.remove(websocket)
        if not conns:
            self._connections.pop(user_id, None)
        logger.info("WS disconnected: user_id=%s", user_id)

    async def broadcast_sync_completed(
        self, user_id: int, synced_count: int
    ) -> None:
        """Push a sync_completed event to all connections for this user."""
        conns = self._connections.get(user_id, [])
        if not conns:
            return

        payload = {
            "event": "sync_completed",
            "synced_count": synced_count,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        dead: List[WebSocket] = []
        for ws in list(conns):
            try:
                await ws.send_json(payload)
            except Exception as exc:  # noqa: BLE001
                logger.warning("WS send failed for user %s: %s", user_id, exc)
                dead.append(ws)

        # Clean up dead connections
        for ws in dead:
            self.disconnect(ws, user_id)

    def connection_count(self, user_id: int) -> int:
        return len(self._connections.get(user_id, []))


# Global singleton — imported by sync endpoint to call broadcast.
manager = ConnectionManager()


# ---------------------------------------------------------------------------
# WebSocket route
# ---------------------------------------------------------------------------

@router.websocket("")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(..., description="Bearer access token for auth"),
):
    """
    WebSocket endpoint — authenticated via ?token=<access_token>.

    Protocol: RFC 6455 (WebSocket protocol version 13).
    """
    # --- Authenticate before accepting ---
    try:
        payload = verify_token(token)
        user_id: int = int(payload.get("sub"))
    except (JWTError, ValueError, TypeError, Exception) as exc:
        logger.warning("WS auth failed: %s", exc)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket, user_id)

    try:
        while True:
            # Keep connection alive; handle client pings.
            data = await websocket.receive_json()
            if data.get("ping"):
                await websocket.send_json({"pong": True})
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
    except Exception as exc:  # noqa: BLE001
        logger.error("WS error for user %s: %s", user_id, exc)
        manager.disconnect(websocket, user_id)
