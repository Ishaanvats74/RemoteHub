import requests
import platform
import asyncio
import socket

async def pairing(code):
    os_name = platform.system()
    platform_info = platform.platform()
    hostname = socket.gethostname()

    data = {
        "code": code,
        "hostname": hostname,
        "os": os_name,
        "platform": platform_info,
    }

    response = await asyncio.to_thread(
        requests.post,
        "http://127.0.0.1:8000/devices/pair",
        json=data,
        timeout=10,
    )

    response.raise_for_status()

    return response.json()
  