from services.websocket import ws_client
from qasync import asyncSlot
from services.pairing import pairing, validate_token
from storage.token import save_token, load_token, delete_token
import requests
import asyncio
import json
import logging
from PySide6.QtCore import QObject, Signal

logger = logging.getLogger(__name__)


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
            try:
                response = await validate_token(token["device_token"])

                if response.status_code == 200:
                    self._start_ws(token["device_token"])
                    self.show_connected.emit()
                    return
                else:
                    logger.warning("Stored device token is invalid or revoked.")
                    delete_token()

            except requests.exceptions.RequestException as e:
                # Server unreachable right now — don't nuke the token over a
                # transient network issue. Let the websocket's own reconnect
                # loop handle it; if the server rejects the token once it's
                # back up, _on_invalid_token will clean up then.
                logger.warning("Could not reach server to validate token: %s", e)
                self._start_ws(token["device_token"])
                self.show_connected.emit()
                return

        delete_token()
        self.show_pair.emit()

    def _start_ws(self, device_token):
        if self.ws_task is None:
            self.ws_task = asyncio.create_task(
                ws_client(device_token, self._on_invalid_token, self._on_ws_error)
            )

    async def _on_invalid_token(self):
        """Called when the server rejects our device token (revoked/invalid)."""
        logger.info("Device token rejected by server. Clearing local token.")
        delete_token()
        self.ws_task = None
        self.show_error.emit("This device's connection was revoked. Please pair again.")
        self.show_pair.emit()

    async def _on_ws_error(self, message: str):
        """Called on recoverable websocket errors (network blips, unexpected exceptions)."""
        logger.warning("WebSocket error: %s", message)
        self.show_error.emit(message)

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

            save_token(data)
            self._start_ws(data["device_token"])

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
            logger.exception("Unexpected error during pairing")
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

        delete_token()
        self.show_pair.emit()

    def error(self, message):
        self.show_error.emit(message)