import websockets
import asyncio
import psutil
import json

def get_cpu_temp():
    temps = psutil.sensors_temperatures()
    for entry in temps.get("coretemp", []):
        if "Package" in entry.label:
            return entry.current

    core_temps = [e.current for e in temps.get("coretemp", [])]
    return round(sum(core_temps) / len(core_temps), 1) if core_temps else None


def get_all_temps():
    temps = psutil.sensors_temperatures()
    result = {}

    for sensor_name, entries in temps.items():
        result[sensor_name] = [
            {
                "label": entry.label or sensor_name,
                "temperature": entry.current,
            }
            for entry in entries
        ]

    return result


def get_fan_speeds():
    fans = psutil.sensors_fans()
    result = {}

    for sensor_name, entries in fans.items():
        result[sensor_name] = [
            {
                "label": entry.label or f"fan {i}",
                "rpm": entry.current,
            }
            for i, entry in enumerate(entries)
        ]

    return result


def get_battery_info():
    battery = psutil.sensors_battery()

    if battery is None:
        return None

    if (
        battery.power_plugged
        or battery.secsleft in (psutil.POWER_TIME_UNLIMITED, -1)
    ):
        status = "Charging"
        time_remaining = "Charging"
    else:
        hours, remainder = divmod(battery.secsleft, 3600)
        minutes = remainder // 60
        status = "On battery"
        time_remaining = f"{hours}h {minutes}m"

    return {
        "percent": round(battery.percent, 1),
        "plugged_in": battery.power_plugged,
        "status": status,
        "time_remaining": time_remaining,
    }

def get_live_stats():
    cpu_percent = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    print("live stats")
    return {
        "cpu": {
            "usage": cpu_percent,
            "temperature": get_cpu_temp(),
        },
        "memory": {
            "usage": ram.percent,
            "used_gb": round(ram.used / 1e9, 2),
            "total_gb": round(ram.total / 1e9, 2),
        },
        "disk": {
            "usage": disk.percent,
            "used_gb": round(disk.used / 1e9, 2),
            "total_gb": round(disk.total / 1e9, 2),
        },
        "temperatures": get_all_temps(),
        "fans": get_fan_speeds(),
        "battery": get_battery_info(),
    }
# The main function that will handle connection and communication
# with the server
async def ws_client():
    print("WebSocket: Client Connected.")
    url = "ws://127.0.0.1:8000/ws/device"
    # Connect to the server
    async with websockets.connect(url) as ws:
        
        # Stay alive forever, listen to incoming msgs
        while True:
            usage = get_live_stats()
            print(usage)
            await ws.send(json.dumps(usage))

 
# Start the connection
asyncio.run(ws_client())