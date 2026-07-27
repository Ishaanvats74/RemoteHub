from PySide6.QtWidgets import QMessageBox
from agent.info import ws_client
from qasync import asyncSlot
from services.pairing import pairing
from storage.token import save_token,load_token,delete_token
import requests
import platform
import asyncio
import socket
import json


class AgentController:
    def __init__(self, window):
        self.window = window

    async def startup(self):
        try:
           token = load_token()
        except (FileNotFoundError, json.JSONDecodeError):
            token = None

        if token and "device_token" in token:
            if self.window.ws_task is None:
                self.window.ws_task = asyncio.create_task(ws_client(token["device_token"]))
            self.window.show_connected_page()
        else:
            self.window.show_pair_page()

    @asyncSlot(str)
    async def pair_device(self, code):
        try:
            response = pairing(code)

            if "device_token" not in response:
                self.show_error("Server returned an invalid response.")
                self.window.pair_page.set_loading(False)
                return

            # Save token
            save_token(response)
            
            if self.window.ws_task is None:
                self.window.ws_task = asyncio.create_task(
                    ws_client(response["device_token"])
                )

            self.window.pair_page.set_loading(False)
            self.window.pair_page.clear_code()
            self.window.show_connected_page()

        except requests.exceptions.Timeout:
            self.window.pair_page.set_loading(False)
            self.show_error("Connection timed out.")

        except requests.exceptions.ConnectionError:
            self.window.pair_page.set_loading(False)
            self.show_error("Unable to connect to the server.")

        except requests.exceptions.HTTPError:
            self.window.pair_page.set_loading(False)

            try:
                error = response.json().get("detail", response.text)
            except Exception:
                error = response.text

            self.show_error(error)

        except requests.exceptions.RequestException as e:
            self.window.pair_page.set_loading(False)
            self.show_error(str(e))

        except json.JSONDecodeError:
            self.window.pair_page.set_loading(False)
            self.show_error("Server returned an invalid response.")

        except Exception as e:
            self.window.pair_page.set_loading(False)
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
        QMessageBox.warning(
            self.window,
            "RemoteHub",
            message,
        )