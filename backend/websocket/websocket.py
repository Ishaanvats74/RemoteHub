from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.desktops = {}
        self.phones = {}
        self.user_devices = {}

    async def connect_desktop(self, user_id: str, websocket: WebSocket):
        await websocket.accept()

        # Replace any previous desktop connection
        self.desktops[user_id] = websocket

    def disconnect_desktop(self, user_id: str):
        self.desktops.pop(user_id, None)

    async def connect_phone(self, user_id: str, websocket: WebSocket):
        await websocket.accept()

        if user_id not in self.phones:
            self.phones[user_id] = []

        self.phones[user_id].append(websocket)

    def disconnect_phone(self, user_id: str, websocket: WebSocket):
        if user_id not in self.phones:
            return

        if websocket in self.phones[user_id]:
            self.phones[user_id].remove(websocket)

        if not self.phones[user_id]:
            del self.phones[user_id]

    async def send_to_phone(self, user_id: str, data: dict):
        if user_id not in self.phones:
            return

        for phone in self.phones[user_id]:
            await phone.send_json(data)

    async def send_to_desktop(self, user_id: str, data: dict):
        desktop = self.desktops.get(user_id)

        if desktop is None:
            return

        await desktop.send_json(data)