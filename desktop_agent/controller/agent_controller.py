import asyncio
import logging
import socket
from datetime import datetime, timezone

import requests
from PySide6.QtCore import QObject, Signal
from qasync import asyncSlot

from services.pairing import create_session, pairing_request
from services.websocket import ws_client
from storage.token import delete_token, load_token, save_token

logger = logging.getLogger(__name__)


class AgentController(QObject):
    show_pair = Signal()
    show_connected = Signal()

    def __init__(self, window):
        super().__init__()
        self.window = window
        self.ws_task = None
        self.poll_task = None
        self.session = None

    async def startup(self):
        token = load_token()
        if token and token.get("device_token"):
            self._start_ws(token["device_token"])
        else:
            await self._generate_code()

    def _start_ws(self, device_token):
        if self.ws_task is None:
            page = self.window.connected_page
            page.set_device(socket.gethostname())
            page.set_status("Connecting...")
            self.show_connected.emit()
            self.ws_task = asyncio.create_task(
                ws_client(device_token, self._on_invalid_token, self._on_ws_error, self._on_connected)
            )

    async def _on_connected(self):
        self.window.connected_page.set_status("Online")

    async def _on_invalid_token(self):
        delete_token()
        self.ws_task = None
        await self._generate_code()

    async def _on_ws_error(self, message):
        logger.warning("WebSocket error: %s", message)
        self.window.connected_page.set_status("Reconnecting...")

    @asyncSlot()
    async def generate_code(self):
        await self._generate_code()

    async def _generate_code(self):
        page = self.window.pair_page
        if self.poll_task:
            self.poll_task.cancel()
        self.session = None
        self.show_pair.emit()
        page.set_decision_enabled(True)
        page.show_state("Generating code...")
        try:
            session = await create_session()
            self.session = session
            page.show_state("Enter this code in the RemoteHub phone app.", code=session["code"])
            self.poll_task = asyncio.create_task(self._poll_session(session))
        except (requests.RequestException, ValueError):
            page.show_state("Could not generate a code. Check the server connection.", retry=True)

    async def _poll_session(self, session):
        page = self.window.pair_page
        path = f"/sessions/{session['session_id']}"
        expires_at = datetime.fromisoformat(session["expires_at"])
        while datetime.now(timezone.utc) < expires_at:
            try:
                result = await pairing_request("GET", path, secret=session["secret"])
                match result["status"]:
                    case "pending":
                        page.show_state(f"Pairing requested by {result['requester']}.",
                                        code=session["code"], approval=True)
                    case "approved":
                        save_token({"device_token": result["device_token"], "device_id": result["device_id"]})
                        self.session = None
                        self._start_ws(result["device_token"])
                        return
                    case "denied":
                        page.show_state("Pairing declined.", retry=True)
                        return
                    case "open":
                        page.show_state("Enter this code in the RemoteHub phone app.", code=session["code"])
            except requests.HTTPError as exc:
                if exc.response.status_code in (401, 404, 410):
                    break
                page.show_state("Waiting for the server...", code=session["code"])
            except (requests.RequestException, ValueError):
                page.show_state("Waiting for the server...", code=session["code"])
            except OSError:
                page.show_state("Could not save the device credential. Retrying...", code=session["code"])
            await asyncio.sleep(2)
        page.show_state("This code expired. Generate a new one to pair.", retry=True)

    @asyncSlot(bool)
    async def decide(self, approve):
        session = self.session
        if not session:
            return
        page = self.window.pair_page
        page.set_decision_enabled(False)
        try:
            await pairing_request(
                "POST", f"/sessions/{session['session_id']}/decision",
                secret=session["secret"], payload={"approve": approve},
            )
        except (requests.RequestException, ValueError):
            # A lost response may still have committed the decision. Polling reconciles it.
            if self.session is session:
                page.set_decision_enabled(True)

    @asyncSlot()
    async def disconnect(self):
        if self.ws_task:
            self.ws_task.cancel()
            await asyncio.gather(self.ws_task, return_exceptions=True)
            self.ws_task = None
        delete_token()
        await self._generate_code()
