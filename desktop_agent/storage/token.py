from pathlib import Path
import json

from .paths import get_app_data_dir

TOKEN_FILE = get_app_data_dir() / "token.json"


def load_token():
    try:
        with open(TOKEN_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def save_token(data):
    with open(TOKEN_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)


def delete_token():
    if TOKEN_FILE.exists():
        TOKEN_FILE.unlink()