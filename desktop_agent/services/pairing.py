import requests
import platform
import asyncio
import socket

async def validate_token(device_token: str):
    response = await asyncio.to_thread(
        requests.get,
        "http://127.0.0.1:8000/devices/validate",
        headers={"Authorization": f"Bearer {device_token}"},
        timeout=10,
    )
    return response


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



    return response
  