import json

class AgentController:

    def __init__(self, window):
        self.window = window
        self.ws_task = None
        

    async def startup(self):
        with open(self.window.file_path) as f:
            token = json.load(f)
            if token:
                print(token)
        self.window.show_connected_page()



    # async def pair(self):
    #     ...

    # async def disconnect(self):
    #     ...