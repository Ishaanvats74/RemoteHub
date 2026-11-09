from .telemetry import get_hardware_specs, get_live_stats
from .heartbeat import heartbeat
from .pairing import SERVER_URL
import websockets
import asyncio
import json
import logging
from commands.executor import cmd_execute

logger = logging.getLogger(__name__)

URL = f"ws{SERVER_URL[4:]}/ws/desktop"
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


async def ws_client(token, on_invalid_token, on_error, on_connected):
    delay = 1
    while True:
        try:
            async with websockets.connect(URL) as ws:
                await ws.send(json.dumps({"token": token}))
                auth = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
                if auth.get("type") != "authenticated":
                    raise ValueError("Missing server authentication acknowledgement")
                await on_connected()
                delay = 1

                tasks = [
                    asyncio.create_task(send_telemetry(ws)),
                    asyncio.create_task(receive_commands(ws)),
                    asyncio.create_task(heartbeat(ws)),
                ]
                try:
                    done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
                    for task in done:
                        task.result()
                finally:
                    for task in tasks:
                        task.cancel()
                    await asyncio.gather(*tasks, return_exceptions=True)

        except websockets.ConnectionClosed as exc:
            if exc.rcvd and exc.rcvd.code == 1008:
                await on_invalid_token()
                return
            await on_error("Connection closed")
        except Exception as exc:
            await on_error(str(exc))

        await asyncio.sleep(delay)
        delay = min(delay * 2, MAX_DELAY)
