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
    await ws.send(json.dumps(get_hardware_specs()))
    while True:
        stats = await asyncio.to_thread(get_live_stats)

        await ws.send(json.dumps({
            "type": "telemetry",
            "data": stats
        }))

        await asyncio.sleep(1)

async def receive_commands(ws):
    while True:
        message = json.loads(await ws.recv())

        if message.get("type") == "command":
            command = message["command"]

            result = cmd_execute(command)

            await ws.send(json.dumps({
                "type": "command_result",
                "device_id": message["device_id"],
                "command": command,
                "success": result["success"],
                "output": result["output"],
            }))
            
async def ws_client(token):
    delay = 1

    while True:
        try:
            print("Connecting to server...")

            async with websockets.connect(URL) as ws:
                print("Connected!")
                delay = 1

                await ws.send(json.dumps({
                    "token": token
                }))

                await asyncio.gather(
                    send_telemetry(ws),
                    receive_commands(ws),
                    heartbeat(ws),
                )

        except (websockets.ConnectionClosed,OSError,asyncio.TimeoutError,) as e:
            print(f"Connection lost: {e}")
            print(f"Reconnecting in {delay} second(s)...")
            await asyncio.sleep(delay)
            delay = min(delay * 2, MAX_DELAY)

        except Exception as e:
            traceback.print_exc()
            print(f"Unexpected websocket error: {e}")
            await asyncio.sleep(delay)
            delay = min(delay * 2, MAX_DELAY)

