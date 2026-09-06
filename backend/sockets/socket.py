from collections import defaultdict
from fastapi import WebSocket
from datetime import datetime, UTC
import logging

logger = logging.getLogger(__name__)


class ConnectionManager:
    def __init__(self) -> None:
        self.desktop_connections: dict[str, WebSocket] = {}
        self.mobile_connections: dict[str, set[WebSocket]] = defaultdict(set)
        self.user_devices: dict[str, set[str]] = defaultdict(set)
        self.telemetry: dict[str, dict[str, object]] = {}

    # -------------------------------------------------
    # Desktop
    # -------------------------------------------------

    async def connect_desktop(self, user_id: str, device_id: str, websocket: WebSocket) -> None:
        old = self.desktop_connections.get(device_id)
        if old:
            try:
                await old.close()
            except Exception:
                logger.debug("Failed to close stale desktop connection for device %s", device_id)

        self.desktop_connections[device_id] = websocket
        self.user_devices[user_id].add(device_id)
        logger.info("Desktop connected: user=%s device=%s", user_id, device_id)

    def disconnect_desktop(self, user_id: str, device_id: str) -> None:
        self.desktop_connections.pop(device_id, None)
        self.telemetry.pop(device_id, None)

        if user_id in self.user_devices:
            self.user_devices[user_id].discard(device_id)

            if not self.user_devices[user_id]:
                del self.user_devices[user_id]

        logger.info("Desktop disconnected: user=%s device=%s", user_id, device_id)

    # -------------------------------------------------
    # Mobile
    # -------------------------------------------------

    async def connect_mobile(self, user_id: str, websocket: WebSocket) -> None:
        self.mobile_connections[user_id].add(websocket)
        logger.info(
            "Mobile connected: user=%s (total connections for user: %d)",
            user_id, len(self.mobile_connections[user_id]),
        )

    def disconnect_mobile(self, user_id: str, websocket: WebSocket) -> None:
        if user_id not in self.mobile_connections:
            return

        self.mobile_connections[user_id].discard(websocket)

        if not self.mobile_connections[user_id]:
            del self.mobile_connections[user_id]

        logger.info("Mobile disconnected: user=%s", user_id)

    # -------------------------------------------------
    # Telemetry
    # -------------------------------------------------

    def update_telemetry(self, device_id: str, data: dict) -> None:
        self.telemetry[device_id] = {"timestamp": datetime.now(UTC).isoformat(), "data": data}

    def get_telemetry(self, device_id: str) -> dict | None:
        return self.telemetry.get(device_id)

    # -------------------------------------------------
    # Send Data
    # -------------------------------------------------

    async def send_to_device(self, device_id: str, payload: dict) -> bool:
        websocket = self.desktop_connections.get(device_id)
        if websocket is None:
            logger.warning("send_to_device: device %s not connected", device_id)
            return False

        try:
            await websocket.send_json(payload)
            return True

        except Exception:
            logger.warning("send_to_device: failed to send to device %s, dropping connection", device_id)
            self.desktop_connections.pop(device_id, None)
            self.telemetry.pop(device_id, None)
            return False

    async def send_to_user(self, user_id: str, payload: dict) -> None:
        if user_id not in self.mobile_connections:
            logger.debug("send_to_user: no mobile connections for user %s", user_id)
            return

        dead_connections = []

        for websocket in self.mobile_connections[user_id]:
            try:
                await websocket.send_json(payload)
            except Exception:
                dead_connections.append(websocket)

        for websocket in dead_connections:
            self.mobile_connections[user_id].discard(websocket)

        if dead_connections:
            logger.debug(
                "send_to_user: dropped %d dead connection(s) for user %s",
                len(dead_connections), user_id,
            )

        if not self.mobile_connections[user_id]:
            del self.mobile_connections[user_id]

    # -------------------------------------------------
    # Helpers
    # -------------------------------------------------

    def is_device_online(self, device_id: str) -> bool:
        return device_id in self.desktop_connections

    def get_user_devices(self, user_id: str) -> list[str]:
        return list(self.user_devices.get(user_id, []))

    def get_online_device_count(self) -> int:
        return len(self.desktop_connections)

    def get_online_mobile_count(self) -> int:
        return sum(len(v) for v in self.mobile_connections.values())