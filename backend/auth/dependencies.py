from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends, HTTPException, status
from jwt.exceptions import InvalidTokenError
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel
from typing import Annotated
import jwt
import os
from dotenv import load_dotenv

from database.connection import get_db_connection
from database.users import get_user_by_id
from database.utils import hash_token

load_dotenv()

SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


class TokenData(BaseModel):
    username: str | None = None


class User(BaseModel):
    email: str
    username: str | None = None


async def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except InvalidTokenError:
        raise credentials_exception

    if payload.get("type") != "access":
        raise credentials_exception

    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        user = get_user_by_id(cur, user_id)
    except Exception:
        conn.rollback()
        raise HTTPException(status_code=500, detail="Database error")
    finally:
        cur.close()
        conn.close()

    if user is None:
        raise credentials_exception
    return user


async def get_current_active_user(current_user: Annotated[User, Depends(get_current_user)]):
    return current_user


async def get_current_device(token: Annotated[str, Depends(oauth2_scheme)]):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate device credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except InvalidTokenError:
        raise credentials_exception

    if payload.get("type") != "device":
        raise credentials_exception

    device_id = payload.get("sub")
    if device_id is None:
        raise credentials_exception

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT id, user_id, hostname, os, platform, status, token_hash, token_expires_at FROM devices WHERE id = %s",(device_id,))
        device = cur.fetchone()
    except Exception:
        raise HTTPException(status_code=500, detail="Database error")
    finally:
        cur.close()
        conn.close()

    if device is None:
        raise credentials_exception

    incoming_hash = hash_token(token)
    if device["token_hash"] != incoming_hash:
        raise credentials_exception
    if device["status"] != "active":
        raise HTTPException(status_code=401, detail="Device has been revoked")

    return device