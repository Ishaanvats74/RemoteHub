from services.websocket import ws_client
from qasync import asyncSlot
from services.pairing import pairing
from storage.token import save_token,load_token,delete_token
import requests
import asyncio
import json
from PySide6.QtCore import QObject, Signal

class AgentController(QObject):
    show_pair = Signal()
    show_connected = Signal()
    show_error = Signal(str)
    def __init__(self, window):
        super().__init__()
        self.window = window
        self.ws_task = None

    async def startup(self):
        try:
           token = load_token()
        except (FileNotFoundError, json.JSONDecodeError):
            token = None

        if token and "device_token" in token:
            if self.ws_task is None:
                self.ws_task = asyncio.create_task(ws_client(token["device_token"]))
            self.show_connected.emit()
        else:
            self.show_pair.emit()

    @asyncSlot(str)
    async def pair_device(self, code):
        try:
            response = await pairing(code)
            response.raise_for_status()
            data = response.json()
            if "device_token" not in data:
                self.error("Server returned an invalid response.")
                self.window.pair_page.set_loading(False)
                return

            # Save token
            save_token(data)
            
            if self.ws_task is None:
                self.ws_task = asyncio.create_task(
                    ws_client(data["device_token"])
                )

            self.window.pair_page.set_loading(False)
            self.window.pair_page.clear_code()
            self.show_connected.emit()

        except requests.exceptions.Timeout:
            self.window.pair_page.set_loading(False)
            self.error("Connection timed out.")

        except requests.exceptions.ConnectionError:
            self.window.pair_page.set_loading(False)
            self.error("Unable to connect to the server.")

        except requests.exceptions.HTTPError:
            self.window.pair_page.set_loading(False)

            try:
                error = response.json().get("detail", response.text)
            except Exception:
                error = response.text

            self.error(error)

        except requests.exceptions.RequestException as e:
            self.window.pair_page.set_loading(False)
            self.error(str(e))

        except json.JSONDecodeError:
            self.window.pair_page.set_loading(False)
            self.error("Server returned an invalid response.")

        except Exception as e:
            self.window.pair_page.set_loading(False)
            self.error(f"Unexpected error:\n{e}")

    @asyncSlot()
    async def disconnect(self):
        if self.ws_task:
            self.ws_task.cancel()

            try:
                await self.ws_task
            except asyncio.CancelledError:
                pass

            self.ws_task = None

        self.show_pair.emit()

    def error(self, message):
        self.show_error.emit(message)