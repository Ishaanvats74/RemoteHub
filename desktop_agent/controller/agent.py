from PySide6.QtWidgets import QMessageBox
from desktop_agent.agent.main import ws_client
from qasync import  asyncSlot
import requests
import platform
import asyncio
import socket
import json

class AgentController:
    def __init__(self, window):
        self.window = window
        
    async def startup(self):
        with open(self.window.file_path) as f:
            token = json.load(f)
            
        if token:
            if self.window.ws_task is None:
                self.window.ws_task = asyncio.create_task(ws_client(token["device_token"]))
            self.window.show_connected_page()

        else:
            self.window.show_pair_page()

    @asyncSlot()
    async def pair_device(self,code):
        
        os_name = platform.system()
        platform_info = platform.platform()
        hostname = socket.gethostname()
        data = {"code": code, "hostname": hostname, "os": os_name, "platform": platform_info}

        try:
            response = await asyncio.to_thread(requests.post,"http://127.0.0.1:8000/devices/pair",json=data,timeout=10,)
            response.raise_for_status()
            result = response.json()

            if "device_token" not in result:
                self.show_error("Server returned an invalid response.")
                return

            if self.window.ws_task is None:
                self.window.ws_task = asyncio.create_task(ws_client(result["device_token"]))

            self.window.show_connected_page()

        except requests.exceptions.Timeout:
            self.show_error("Connection timed out.")
        except requests.exceptions.ConnectionError:
            self.show_error("Unable to connect to the server.")
        except requests.exceptions.HTTPError:
            try:
                error = response.json().get("detail", response.text)
            except Exception:
                error = response.text
            self.show_error(error)
        except requests.exceptions.RequestException as e:
            self.show_error(str(e))
        except json.JSONDecodeError:
            self.show_error("Server returned an invalid response.")
        except Exception as e:
            self.show_error(f"Unexpected error:\n{e}")
 
    @asyncSlot()
    async def disconnect(self):
        if self.window.ws_task:
            self.window.ws_task.cancel()

            try:
                await self.window.ws_task
            except asyncio.CancelledError:
                pass

            self.window.ws_task = None
            self.window.show_pair_page()

    def show_error(self, message):
        QMessageBox.warning(self.window, "Validation Error", message)