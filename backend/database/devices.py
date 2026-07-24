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
    payload = {"sub": str(device_id), "type": "device", "exp": expire}
    raw_token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    
    token_hash = hash_token(raw_token)
    cur.execute("UPDATE devices SET token_hash = %s, token_expires_at = %s WHERE id = %s", (token_hash, expire, device_id))
    return raw_token


def check_device(cur, token_hash):
    cur.execute("SELECT id,user_id, hostname, os, platform, status, token_hash, token_expires_at FROM devices WHERE token_hash = %s ", (token_hash,))
    return cur.fetchone()

def update_last_seen(cur, device_id):
    cur.execute("UPDATE devices SET last_seen = %s, status = %s WHERE id = %s ",(datetime.now(timezone.utc),"online",device_id,))


def set_device_online(cur, device_id):
    cur.execute("UPDATE devices SET status = 'online' WHERE id = %s ",(device_id,))


def set_device_offline(cur, device_id):
    cur.execute("UPDATE devices SET status = 'offline' WHERE id = %s ",(device_id,))