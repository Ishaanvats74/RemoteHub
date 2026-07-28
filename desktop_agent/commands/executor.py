import platform
import subprocess
from storage.token import load_token

def cmd_execute(command):
    # Make sure the command is for this device
    data = load_token()
    print(data)
    print(command)
    if command['device_id'] != data['device_id']:
        return {
            "success": False,
            "message": "Command is not intended for this device."
        }

    system = platform.system()

    try:
        match command['command']:

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
                        subprocess.Popen([
                            "rundll32.exe",
                            "powrprof.dll,SetSuspendState",
                            "0,1,0"
                        ])

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
                        subprocess.Popen([
                            "rundll32.exe",
                            "user32.dll,LockWorkStation"
                        ])

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
                return {
                    "success": False,
                    "message": f"Unknown command '{command}'"
                }

        return {
            "success": True,
            "message": f"{command} executed successfully."
        }

    except Exception as e:
        return {
            "success": False,
            "message": str(e)
        }



