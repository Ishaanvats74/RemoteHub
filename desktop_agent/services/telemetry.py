import psutil
import json
import platform
import subprocess
import re
from typing import Optional, Dict, Any


# ============ HARDWARE SPECS (ONE-TIME) ============

def get_cpu_info() -> Dict[str, Any]:
    """Get CPU name, cores, generation"""
    try:
        import cpuinfo
        cpu = cpuinfo.get_cpu_info()
        return {
            "brand": cpu.get("brand_raw", "Unknown"),
            "cores": psutil.cpu_count(logical=False),
            "threads": psutil.cpu_count(logical=True),
            "frequency_ghz": round(psutil.cpu_freq().current / 1000, 2),
        }
    except ImportError:
        return {
            "brand": platform.processor() or "Unknown",
            "cores": psutil.cpu_count(logical=False),
            "threads": psutil.cpu_count(logical=True),
            "frequency_ghz": round(psutil.cpu_freq().current / 1000, 2),
            "note": "Install 'py-cpuinfo' for detailed info: pip install py-cpuinfo"
        }


def get_ram_info() -> Dict[str, Any]:
    """Get RAM amount, type (DDR4/DDR5), speed"""
    ram_total_gb = round(psutil.virtual_memory().total / 1e9, 1)
    system = platform.system()
    ram_type = "Unknown"
    ram_speed_mhz = "Unknown"

    if system == "Windows":
        try:
            result = subprocess.run(
                ["wmic", "MEMORYCHIP", "get", "Speed,MemoryType", "/format:list"],
                capture_output=True, text=True, timeout=5
            )
            speeds = re.findall(r"Speed=(\d+)", result.stdout)
            if speeds:
                ram_speed_mhz = f"{speeds[0]} MHz"
            
            mem_types = re.findall(r"MemoryType=(\d+)", result.stdout)
            if mem_types:
                type_map = {"26": "DDR4", "34": "DDR5", "15": "SDRAM", "24": "DDR3"}
                ram_type = type_map.get(mem_types[0], "DRAM")
        except: pass

    elif system == "Darwin":  # macOS
        try:
            result = subprocess.run(
                ["system_profiler", "SPMemoryDataType"],
                capture_output=True, text=True, timeout=5
            )
            if "DDR5" in result.stdout: ram_type = "DDR5"
            elif "DDR4" in result.stdout: ram_type = "DDR4"
            else: ram_type = "Apple LPDDR"
            
            speed_match = re.search(r"Speed:\s+(\d+\s+MHz)", result.stdout)
            if speed_match: ram_speed_mhz = speed_match.group(1)
        except: pass

    elif system == "Linux":
        try:
            result = subprocess.run(["lshw", "-C", "memory"], capture_output=True, text=True, timeout=5)
            if "DDR5" in result.stdout: ram_type = "DDR5"
            elif "DDR4" in result.stdout: ram_type = "DDR4"
            elif "DDR3" in result.stdout: ram_type = "DDR3"
        except: pass

    return {
        "total_gb": ram_total_gb,
        "type": ram_type,
        "speed": ram_speed_mhz,
    }


def get_gpu_info() -> Dict[str, Any]:
    """Detect GPUs (NVIDIA, AMD, Intel, Apple M-series)"""
    system = platform.system()
    gpus = []

    try:
        import GPUtil
        gpu_list = GPUtil.getGPUs()
        for gpu in gpu_list:
            gpus.append({
                "name": gpu.name,
                "memory_gb": round(gpu.memoryTotal / 1024, 1),
                "type": "NVIDIA"
            })
        if gpus:
            return {"gpus": gpus}
    except ImportError: pass

    if system == "Windows":
        try:
            result = subprocess.run(
                ["wmic", "path", "win32_videocontroller", "get", "name"],
                capture_output=True, text=True, timeout=5
            )
            gpu_names = [line.strip() for line in result.stdout.split('\n') if line.strip() and "Name" not in line]
            for name in gpu_names:
                gpu_type = "NVIDIA" if "NVIDIA" in name else "AMD" if "AMD" in name or "Radeon" in name else "Intel"
                gpus.append({"name": name, "type": gpu_type})
            if gpus:
                return {"gpus": gpus}
        except: pass

    if system == "Darwin":
        try:
            result = subprocess.run(
                ["system_profiler", "SPDisplaysDataType"],
                capture_output=True, text=True, timeout=5
            )
            gpus.append({"name": "Apple Silicon Integrated GPU", "type": "Apple"})
        except: pass

    if system == "Linux":
        try:
            result = subprocess.run(["lspci"], capture_output=True, text=True, timeout=5)
            vga_lines = [line for line in result.stdout.split('\n') if 'VGA' in line or '3D' in line]
            for line in vga_lines:
                gpus.append({"name": line.split(': ', 1)[-1][:50]})
            if gpus:
                return {"gpus": gpus}
        except: pass

    return {"gpus": gpus, "note": "Install GPUtil for detailed NVIDIA/AMD: pip install GPUtil"}


def get_mac_processor() -> Optional[Dict]:
    """Detect M1/M2/M3/M4 on macOS"""
    if platform.system() != "Darwin":
        return None
    
    try:
        result = subprocess.run(
            ["sysctl", "machdep.cpu.brand_string"],
            capture_output=True, text=True, timeout=5
        )
        brand = result.stdout.split(': ', 1)[-1].strip() if result.stdout else "Unknown"
        
        # Parse M-series
        for chip in ["M4 Pro", "M4 Max", "M4", "M3 Pro", "M3 Max", "M3", "M2 Pro", "M2 Max", "M2", "M1 Pro", "M1 Max", "M1"]:
            if chip in brand:
                return {"brand": brand, "apple_silicon": chip}
        
        return {"brand": brand}
    except:
        return None


def get_hardware_specs() -> Dict[str, Any]:
    """Get all static hardware info (call once on startup)"""
    system = platform.system()
    specs = {
        "os": system,
        "os_version": platform.release(),
        "cpu": get_cpu_info(),
        "ram": get_ram_info(),
        "gpu": get_gpu_info(),
    }
    
    if system == "Darwin":
        specs["mac"] = get_mac_processor()
    
    return specs


# ============ REAL-TIME STATS (LIVE) ============

def get_cpu_temp():
    """Get CPU package temperature or average"""
    if hasattr(psutil, "sensors_temperatures"):
        temps = psutil.sensors_temperatures()
    else:
        return 
    for entry in temps.get("coretemp", []):
        if "Package" in entry.label:
            return entry.current

    core_temps = [e.current for e in temps.get("coretemp", [])]
    return round(sum(core_temps) / len(core_temps), 1) if core_temps else None


def get_all_temps():
    """Get all sensor temperatures"""
    if hasattr(psutil, "sensors_temperatures"):
        temps = psutil.sensors_temperatures()
    else:
        return {}
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
    """Get fan RPM data"""
    fans = {}
    if hasattr(psutil, "sensors_fans"):
        try:
            fans = psutil.sensors_fans()
        except Exception:
            fans = {}
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
    """Get battery status and remaining time"""
    battery = psutil.sensors_battery()
    if battery is None:
        return None

    if battery.power_plugged or battery.secsleft in (psutil.POWER_TIME_UNLIMITED, -1):
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


def get_gpu_live():
    """Get real-time GPU stats (load, temp, memory) if available"""
    try:
        import GPUtil
        gpus = GPUtil.getGPUs()
        if gpus:
            gpu = gpus[0]
            return {
                "name": gpu.name,
                "usage": round(gpu.load * 100, 1),
                "temperature": gpu.temperature,
                "memory_used_mb": round(gpu.memoryUsed, 1),
                "memory_total_mb": round(gpu.memoryTotal, 1),
            }
    except Exception:
        pass
    return None


def get_live_stats():
    """Get real-time monitoring stats"""
    cpu_percent = psutil.cpu_percent(interval=None)
    ram = psutil.virtual_memory()
    try:
        disk = psutil.disk_usage("C:\\") if platform.system() == "Windows" else psutil.disk_usage("/")
    except Exception:
        disk = psutil.disk_usage("/")
    
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
        "gpu": get_gpu_live(),
        "temperatures": get_all_temps(),
        "fans": get_fan_speeds(),
        "battery": get_battery_info(),
    }
