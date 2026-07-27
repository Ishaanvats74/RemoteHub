import json
import asyncio

async def heartbeat(ws):
    while True:

        await ws.send(json.dumps({
            "type": "heartbeat",
        }))

        await asyncio.sleep(30)

