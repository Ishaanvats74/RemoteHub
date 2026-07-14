import socket
import platform
import time
import psutil


def get_cpu_temp():
    temps = psutil.sensors_temperatures()
    for entry in temps.get('coretemp', []):
        if 'Package' in entry.label:
            return entry.current
    core_temps = [e.current for e in temps.get('coretemp', [])]
    return round(sum(core_temps) / len(core_temps), 1) if core_temps else None


def get_all_temps():
    """Return every temperature sensor, labeled cleanly, not as raw namedtuples."""
    temps = psutil.sensors_temperatures()
    result = {}
    for sensor_name, entries in temps.items():
        readings = []
        for entry in entries:
            label = entry.label if entry.label else sensor_name
            readings.append(f"{label}: {entry.current}°C")
        result[sensor_name] = readings
    return result


def get_fan_speeds():
    """Return every fan sensor, labeled cleanly, not as raw namedtuples."""
    fans = psutil.sensors_fans()
    result = {}
    for sensor_name, entries in fans.items():
        readings = []
        for i, entry in enumerate(entries):
            label = entry.label if entry.label else f"fan {i}"
            readings.append(f"{label}: {entry.current} RPM")
        result[sensor_name] = readings
    return result


def get_battery_info():
    battery = psutil.sensors_battery()
    if battery is None:
        return None

    percent = round(battery.percent, 1)
    plugged = battery.power_plugged
    unknown_time = battery.secsleft in (psutil.POWER_TIME_UNLIMITED, -1)

    if plugged or unknown_time:
        # If plugged in, or if the OS can't calculate time remaining,
        # treat it as charging — an unknown countdown almost always
        # means the battery isn't discharging normally.
        status = "Charging"
        time_remaining = "Charging"
    else:
        status = "On battery"
        hours, remainder = divmod(battery.secsleft, 3600)
        minutes = remainder // 60
        time_remaining = f"{int(hours)}h {int(minutes)}m remaining"

    return {
        "percent": percent,
        "plugged_in": plugged,
        "status": status,
        "time_remaining": time_remaining,
    }


def print_live_stats():
    cpu_percent = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    cpu_temp = get_cpu_temp()
    all_temps = get_all_temps()
    fans = get_fan_speeds()
    battery = get_battery_info()

    print("-" * 40)
    print(f"CPU usage     : {cpu_percent}%")
    print(f"CPU temp      : {cpu_temp}°C" if cpu_temp is not None else "CPU temp      : N/A")
    print(f"RAM usage     : {ram.percent}%  ({round(ram.used / 1e9, 2)} GB used)")
    print(f"Disk usage    : {disk.percent}%  ({round(disk.used / 1e9, 2)} GB used)")

    print("Temperatures  :")
    if all_temps:
        for sensor, readings in all_temps.items():
            print(f"  {sensor}:")
            for r in readings:
                print(f"    {r}")
    else:
        print("  N/A")

    print("Fans          :")
    if fans:
        for sensor, readings in fans.items():
            print(f"  {sensor}:")
            for r in readings:
                print(f"    {r}")
    else:
        print("  N/A")

    if battery:
        print(f"Battery       : {battery['percent']}%  ({battery['status']}, {battery['time_remaining']})")
    else:
        print("Battery       : N/A (no battery detected)")


if __name__ == "__main__":
    while True:
        print_live_stats()
        # time.sleep(2)