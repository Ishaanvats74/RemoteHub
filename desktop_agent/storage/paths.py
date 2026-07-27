from pathlib import Path
from platformdirs import user_config_dir

APP_NAME = "RemoteHub"
APP_AUTHOR = "RemoteHub"


def get_app_data_dir() -> Path:
    APP_DIR = Path(user_config_dir(APP_NAME, APP_AUTHOR))
    APP_DIR.mkdir(parents=True, exist_ok=True)
    return APP_DIR