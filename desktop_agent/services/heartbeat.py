import json
import asyncio

async def heartbeat(ws):
    try:
        while True:
            print("Sending heartbeat...")

            await ws.send(json.dumps({
                "type": "heartbeat",
            }))

            await asyncio.sleep(30)

    except Exception as e:
        print("HEARTBEAT ERROR:", repr(e))
        raise