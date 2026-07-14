# database/devices.py
import jwt
import os
from datetime import datetime, timedelta, timezone
from .utils import hash_token
from dotenv import load_dotenv
load_dotenv()
SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv('REFRESH_TOKEN_EXPIRE_DAYS',30))

def create_device_token(cur, device_id):
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(device_id),
        "type": "device",
        "exp": expire,
    }
    raw_token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

    token_hash = hash_token(raw_token)
    cur.execute(
        "UPDATE devices SET token_hash = %s, token_expires_at = %s WHERE id = %s",
        (token_hash, expire, device_id)
    )
    return raw_token