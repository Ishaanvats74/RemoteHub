import socket
import platform
import requests

code = input("Enter pairing code: ").strip()

payload = {
    "code": code,
    "hostname": socket.gethostname(),
    "os": platform.system(),
    "platform": platform.platform(),
}

result = requests.post('http://127.0.0.1:8000/devices/pair', json=payload)
print(result.status_code)
print(result.json())