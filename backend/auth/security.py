import jwt
import os
from datetime import datetime, timedelta, timezone
from pwdlib import PasswordHash
from dotenv import load_dotenv
from database.utils import hash_token
from database.connection import get_db_connection
from database.devices import check_device
from fastapi import  HTTPException, status
from psycopg2.extras import RealDictCursor
load_dotenv()


SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
password_hash = PasswordHash.recommended()


def verify_password(plain_password, hashed_password):
    return password_hash.verify(plain_password, hashed_password)


def get_password_hash(password):
    return password_hash.hash(password)


def authenticate_user(user_db, password: str):
    if not verify_password(password, user_db['hashed_password']):
        return False
    return user_db


def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return {"encoded_jwt": encoded_jwt, "expire": expire}


def create_refresh_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(days=15))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return {"encoded_jwt": encoded_jwt, "expire": expire}


def authenticate_device(token):
    token_hash = hash_token(token)
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        user = check_device(cur,token_hash)
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error")
    finally:
        cur.close()
        conn.close()
    print(user)
    if not user:
        return
    return user

    