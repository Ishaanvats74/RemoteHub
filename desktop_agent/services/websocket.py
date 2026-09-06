from .telemetry import get_hardware_specs, get_live_stats
from .heartbeat import heartbeat
import websockets
import asyncio
import json
import logging
from commands.executor import cmd_execute

logger = logging.getLogger(__name__)

URL = "ws://127.0.0.1:8000/ws/desktop"
MAX_DELAY = 30


async def send_telemetry(ws):
    try:
        await ws.send(json.dumps({
            "type": "hardware_specs",
            "data": get_hardware_specs()
        }))

        while True:
            stats = await asyncio.to_thread(get_live_stats)

            await ws.send(json.dumps({
                "type": "telemetry",
                "data": stats
            }))

            await asyncio.sleep(1)

    except Exception:
        logger.exception("Telemetry task failed")
        raise


async def receive_commands(ws):
    try:
        while True:
            message = json.loads(await ws.recv())
            logger.debug("Received from server: %s", message)

            if message.get("type") == "command":
                command = message["command"]

                result = cmd_execute(message)

                await ws.send(json.dumps({
                    "type": "command_result",
                    "device_id": message["device_id"],
                    "command": command,
                    "result": result,
                }))

    except Exception:
        logger.exception("Command receive task failed")
        raise


async def ws_client(token, on_invalid_token=None, on_error=None):
    """
    Connects to the desktop websocket and keeps it alive with reconnect/backoff.

    on_invalid_token: called (awaited) when the server rejects the token
                       (close code 1008). Reconnect loop stops after this.
    on_error:         called (awaited) with a human-readable message on
                       recoverable errors (network issues, unexpected
                       exceptions), so the UI can surface it if it wants to.
                       The loop keeps retrying after this.
    """
    delay = 1

    while True:
        try:
            logger.info("Connecting to server...")

            async with websockets.connect(URL) as ws:
                logger.info("Connected")
                delay = 1

                await ws.send(json.dumps({"token": token}))

                tasks = [
                    asyncio.create_task(send_telemetry(ws)),
                    asyncio.create_task(receive_commands(ws)),
                    asyncio.create_task(heartbeat(ws)),
                ]

                done, pending = await asyncio.wait(
                    tasks,
                    return_when=asyncio.FIRST_EXCEPTION,
                )

                for task in done:
                    exception = task.exception()
                    if exception:
                        logger.error(
                            "WebSocket task failed: %s: %s",
                            type(exception).__name__,
                            exception,
                        )

                for task in pending:
                    task.cancel()

                await asyncio.gather(*pending, return_exceptions=True)

        except websockets.ConnectionClosed as e:
            logger.warning("Connection closed: code=%s, reason=%s", e.code, e.reason)

            if e.code == 1008:
                logger.warning("Device token rejected by server (invalid/revoked).")
                if on_invalid_token:
                    await on_invalid_token()
                return  # stop retrying — this token is dead

        except (OSError, asyncio.TimeoutError) as e:
            logger.warning("Connection error: %s", e)
            if on_error:
                await on_error(f"Connection error: {e}")

        except Exception as e:
            logger.exception("Unexpected error in ws_client")
            if on_error:
                await on_error(f"Unexpected error: {e}")

        logger.info("Reconnecting in %s second(s)...", delay)
        await asyncio.sleep(delay)
        delay = min(delay * 2, MAX_DELAY)