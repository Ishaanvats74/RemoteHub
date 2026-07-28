from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends, HTTPException, status
from jwt.exceptions import InvalidTokenError
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel
from typing import Annotated
import jwt
import os
from dotenv import load_dotenv
from database.devices import get_device_by_id
from database.connection import get_db_connection
from database.users import get_user_by_id
from database.utils import hash_token
from psycopg2 import DatabaseError

load_dotenv()

SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
credentials_exception = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,detail="Invalid credentials",headers={"WWW-Authenticate": "Bearer"})

class User(BaseModel):
    email: str
    username:str
    
async def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]):
    payload = decode_token(token, "access")
    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        user = get_user_by_id(cur, user_id)
    except DatabaseError:
        raise HTTPException(
            status_code=500,
            detail="Database error",
        )
    finally:
        cur.close()
        conn.close()

    if user is None:
        raise credentials_exception
    return user


async def get_current_active_user(current_user: Annotated[dict, Depends(get_current_user)]):
    return current_user


async def get_current_device(token: Annotated[str, Depends(oauth2_scheme)]):
    payload = decode_token(token, "device")

    device_id = payload.get("sub")
    if device_id is None:
        raise credentials_exception

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        device = get_device_by_id(cur, device_id)
    except DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")
    
    finally:
        cur.close()
        conn.close()

    if device is None:
        raise credentials_exception

    if device["token_hash"] != hash_token(token):
        raise credentials_exception

    return device


def decode_token(token: str,expected_type: str) -> dict[str]:
    try:
        payload = jwt.decode(token,SECRET_KEY,algorithms=[ALGORITHM],)
    except InvalidTokenError:
        raise credentials_exception

    if payload.get("type") != expected_type:
        raise credentials_exception

    return payload