import platform
import subprocess
import logging
from storage.token import load_token

logger = logging.getLogger(__name__)


def cmd_execute(command):
    data = load_token()

    if data is None:
        logger.warning("Received command but no token on disk: %s", command)
        return {
            "success": False,
            "message": "This device is not paired.",
        }

    if command.get("device_id") != data.get("device_id"):
        logger.warning(
            "Command targeted a different device (expected %s, got %s)",
            data.get("device_id"), command.get("device_id"),
        )
        return {
            "success": False,
            "message": "Command is not intended for this device.",
        }

    system = platform.system()
    command_name = command.get("command")

    try:
        match command_name:

            # ---------------- Shutdown ----------------
            case "shutdown":
                match system:
                    case "Windows":
                        subprocess.Popen(["shutdown", "/s", "/t", "0"])
                    case "Linux":
                        subprocess.Popen(["systemctl", "poweroff"])
                    case "Darwin":
                        subprocess.Popen(["osascript", "-e", 'tell app "System Events" to shut down'])
                    case _:
                        raise Exception("Unsupported OS")

            # ---------------- Restart ----------------
            case "restart":
                match system:
                    case "Windows":
                        subprocess.Popen(["shutdown", "/r", "/t", "0"])
                    case "Linux":
                        subprocess.Popen(["systemctl", "reboot"])
                    case "Darwin":
                        subprocess.Popen(["osascript", "-e", 'tell app "System Events" to restart'])
                    case _:
                        raise Exception("Unsupported OS")

            # ---------------- Sleep ----------------
            case "sleep":
                match system:
                    case "Windows":
                        subprocess.Popen(["rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0"])
                    case "Linux":
                        subprocess.Popen(["systemctl", "suspend"])
                    case "Darwin":
                        subprocess.Popen(["pmset", "sleepnow"])
                    case _:
                        raise Exception("Unsupported OS")

            # ---------------- Lock ----------------
            case "lock":
                match system:
                    case "Windows":
                        subprocess.Popen(["rundll32.exe", "user32.dll,LockWorkStation"])
                    case "Linux":
                        subprocess.Popen(["loginctl", "lock-session"])
                    case "Darwin":
                        subprocess.Popen([
                            "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
                            "-suspend",
                        ])
                    case _:
                        raise Exception("Unsupported OS")

            case _:
                logger.warning("Unknown command received: %s", command_name)
                return {
                    "success": False,
                    "message": f"Unknown command '{command_name}'",
                }

        logger.info("Command '%s' executed successfully.", command_name)
        return {
            "success": True,
            "message": f"{command_name} executed successfully.",
        }

    except Exception as e:
        logger.exception("Command '%s' failed", command_name)
        return {
            "success": False,
            "message": str(e),
        }