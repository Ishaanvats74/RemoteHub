import json
import asyncio
import logging

logger = logging.getLogger(__name__)


async def heartbeat(ws):
    try:
        while True:
            logger.debug("Sending heartbeat...")

            await ws.send(json.dumps({
                "type": "heartbeat",
            }))

            await asyncio.sleep(30)

    except Exception:
        logger.exception("Heartbeat task failed")
        raise