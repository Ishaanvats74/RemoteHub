from database.devices import get_device_by_token_hash
from auth.dependencies import decode_token
from datetime import datetime, timedelta, timezone
from database.connection import get_db_connection
from psycopg2.extras import RealDictCursor
from fastapi import HTTPException, status
from database.utils import hash_token
from psycopg2 import DatabaseError
from pwdlib import PasswordHash
from dotenv import load_dotenv
from typing import TypedDict   
import jwt
import os
load_dotenv()


SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
password_hash = PasswordHash.recommended()

class TokenData(TypedDict):
    encoded_jwt: str
    expire: datetime

def verify_password(plain_password: str,hashed_password: str) -> bool:
    return password_hash.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return password_hash.hash(password)


def authenticate_user(user_db: dict,password: str,) -> dict | None:
    if verify_password(password, user_db["hashed_password"]):
        return user_db
    return None


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> TokenData:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=15))
    to_encode["exp"] = expire
    encoded_jwt = jwt.encode(to_encode,SECRET_KEY,algorithm=ALGORITHM)
    return {"encoded_jwt": encoded_jwt,"expire": expire}


def create_refresh_token(data: dict,expires_delta: timedelta | None = None) -> TokenData:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(days=15))
    to_encode["exp"] = expire
    encoded_jwt = jwt.encode(to_encode,SECRET_KEY,algorithm=ALGORITHM)
    return {"encoded_jwt": encoded_jwt,"expire": expire}

def authenticate_device(token: str):
    try:
        decode_token(token, "device")
    except HTTPException:
        return None
    token_hash = hash_token(token)
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        device = get_device_by_token_hash(cur, token_hash)
    except DatabaseError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error",
        )
    finally:
        cur.close()
        conn.close()

    if device is None:
        return None

    return device

    