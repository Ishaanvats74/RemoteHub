from .telemetry import get_hardware_specs, get_live_stats
from .heartbeat import heartbeat
import websockets
import asyncio
import json
from commands.executor import cmd_execute
import traceback

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

    except Exception as e:
        print("TELEMETRY ERROR:", repr(e))
        raise

async def receive_commands(ws):
    try:
        while True:
            print("Waiting for server message...")

            message = json.loads(await ws.recv())

            print("Received from server:", message)

            if message.get("type") == "command":
                command = message["command"]

                result = cmd_execute(message)

                await ws.send(json.dumps({
                    "type": "command_result",
                    "device_id": message["device_id"],
                    "command": command,
                }))

    except Exception as e:
        print("RECEIVE ERROR:", repr(e))
        raise
            
async def ws_client(token):
    delay = 1

    while True:
        try:
            print("Connecting to server...")

            async with websockets.connect(URL) as ws:
                print("Connected!")
                delay = 1

                # Authenticate
                await ws.send(json.dumps({
                    "token": token
                }))

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
                        print(
                            f"WebSocket task failed: "
                            f"{type(exception).__name__}: {exception}"
                        )

                for task in pending:
                    task.cancel()

                await asyncio.gather(
                    *pending,
                    return_exceptions=True
                )

        except websockets.ConnectionClosed as e:
            print(
                f"Connection closed: "
                f"code={e.code}, reason={e.reason}"
            )

        except (OSError, asyncio.TimeoutError) as e:
            print(f"Connection error: {e}")

        except Exception:
            traceback.print_exc()

        print(f"Reconnecting in {delay} second(s)...")
        await asyncio.sleep(delay)
        delay = min(delay * 2, MAX_DELAY)
