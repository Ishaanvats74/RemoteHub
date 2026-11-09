import asyncio
import os
import platform
import socket

import requests

SERVER_URL = os.getenv("REMOTEHUB_SERVER_URL", "http://127.0.0.1:8000").rstrip("/")


async def pairing_request(method, path, *, secret=None, payload=None):
    response = await asyncio.to_thread(
        requests.request,
        method,
        f"{SERVER_URL}/pairing{path}",
        headers={"Authorization": f"Bearer {secret}"} if secret else {},
        json=payload,
        timeout=8,
    )
    response.raise_for_status()
    return response.json()


async def create_session():
    return await pairing_request("POST", "/sessions", payload={
        "hostname": socket.gethostname(),
        "os": platform.system(),
        "platform": platform.platform(),
    })
