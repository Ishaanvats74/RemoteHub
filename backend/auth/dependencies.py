from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends, HTTPException, Request, status
from jwt.exceptions import InvalidTokenError
from psycopg.rows import dict_row
from pydantic import BaseModel
from typing import Annotated
import jwt
import os
from dotenv import load_dotenv
from database.connection import get_db_connection
from database.users import get_user_by_id
from psycopg import DatabaseError

load_dotenv()

SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
credentials_exception = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,detail="Invalid credentials",headers={"WWW-Authenticate": "Bearer"})

class User(BaseModel):
    email: str
    username:str
    
def get_current_user(request: Request, token: Annotated[str, Depends(oauth2_scheme)]):
    payload = decode_token(token, "access")
    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)
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
    request.state.user = user
    return user


async def get_current_active_user(current_user: Annotated[dict, Depends(get_current_user)]):
    return current_user


def get_current_device(token: Annotated[str, Depends(oauth2_scheme)]):
    from auth.security import authenticate_device

    device = authenticate_device(token)
    if device is None:
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