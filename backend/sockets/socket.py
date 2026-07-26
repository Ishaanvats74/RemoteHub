from collections import defaultdict
from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        # device_id -> desktop websocket
        self.devices: dict[str, WebSocket] = {}

        # user_id -> mobile websocket(s)
        self.mobile_connections: dict[str, set[WebSocket]] = defaultdict(set)

        # user_id -> connected device ids
        self.user_devices: dict[str, set[str]] = defaultdict(set)

        # device_id -> latest telemetry
        self.telemetry: dict[str, dict] = {}

    # -------------------------------------------------
    # Desktop
    # -------------------------------------------------

    async def connect_desktop(self, user_id: str, device_id: str, websocket: WebSocket):

        # Replace old connection if reconnecting
        old = self.devices.get(device_id)
        if old:
            try:
                await old.close()
            except Exception:
                pass

        self.devices[device_id] = websocket
        self.user_devices[user_id].add(device_id)

    def disconnect_desktop(self,user_id: str,device_id: str):
        self.devices.pop(device_id, None)
        self.telemetry.pop(device_id, None)

        if user_id in self.user_devices:
            self.user_devices[user_id].discard(device_id)

            if not self.user_devices[user_id]:
                del self.user_devices[user_id]

    # -------------------------------------------------
    # Mobile
    # -------------------------------------------------

    async def connect_mobile(self,user_id: str,websocket: WebSocket):
        self.mobile_connections[user_id].add(websocket)
        print("Mobile connected:", self.mobile_connections)

    def disconnect_mobile(self,user_id: str,websocket: WebSocket):
        if user_id not in self.mobile_connections:
            return

        self.mobile_connections[user_id].discard(websocket)

        if not self.mobile_connections[user_id]:
            del self.mobile_connections[user_id]

    # -------------------------------------------------
    # Telemetry
    # -------------------------------------------------

    def update_telemetry(self,device_id: str,data: dict):
        self.telemetry[device_id] = data

    def get_telemetry(
        self,
        device_id: str,
    ):
        return self.telemetry.get(device_id)

    # -------------------------------------------------
    # Send Data
    # -------------------------------------------------

    async def send_to_device(
        self,
        device_id: str,
        payload: dict,
    ) -> bool:

        websocket = self.devices.get(device_id)

        if websocket is None:
            return False

        try:
            await websocket.send_json(payload)
            return True

        except Exception:
            return False

    async def send_to_user(self,user_id: str,payload: dict):
        print("Sending to user:", user_id)
        print("Connected mobiles:", self.mobile_connections.keys())
        if user_id not in self.mobile_connections:
            print("No mobile connected for this user!")
            return

        dead_connections = []

        for websocket in self.mobile_connections[user_id]:
            try:
                await websocket.send_json(payload)
            except Exception:
                dead_connections.append(websocket)

        for websocket in dead_connections:
            self.mobile_connections[user_id].discard(websocket)

    # -------------------------------------------------
    # Helpers
    # -------------------------------------------------

    def is_device_online(
        self,
        device_id: str,
    ) -> bool:
        return device_id in self.devices

    def get_user_devices(
        self,
        user_id: str,
    ):
        return list(self.user_devices.get(user_id, []))

    def get_online_device_count(self):
        return len(self.devices)

    def get_online_mobile_count(self):
        return sum(len(v) for v in self.mobile_connections.values())