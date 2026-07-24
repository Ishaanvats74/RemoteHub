
import json

class AgentController:

    def __init__(self, window):
        self.window = window
        self.ws_task = None
        self.file_path = 'token.json'

    async def startup(self):
        with open(self.file_path) as f:
            token = json.load(f)
            if token:
                print(token)


    async def pair(self):
        ...

    async def disconnect(self):
        ...