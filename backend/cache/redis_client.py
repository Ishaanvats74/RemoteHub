import logging
import os
import json

from redis.asyncio import Redis
from redis.exceptions import RedisError

logger = logging.getLogger(__name__)


class RedisCache:
    def __init__(self):
        self.client = None

    def start(self):
        if url := os.getenv("REDIS_URL"):
            self.client = Redis.from_url(
                url, decode_responses=True, socket_timeout=0.25, socket_connect_timeout=0.25
            )

    async def close(self):
        if self.client is not None:
            await self.client.aclose()
            self.client = None

    async def get_telemetry(self, device_id):
        if self.client is not None:
            try:
                raw = await self.client.get(f"remotehub:telemetry:{device_id}")
                return json.loads(raw) if raw else None
            except (RedisError, ValueError):
                logger.debug("Could not read cached telemetry")

    async def set_telemetry(self, device_id, payload):
        if self.client is not None:
            try:
                await self.client.set(f"remotehub:telemetry:{device_id}", json.dumps(payload), ex=120)
            except RedisError:
                logger.debug("Could not cache telemetry")


redis_cache = RedisCache()
