from database.refresh_tokens import insert_refresh_token,get_refresh_token_record,revoke_refresh_token,revoke_all_refresh_tokens_for_user
from auth.security import authenticate_user,create_access_token,create_refresh_token,get_password_hash,authenticate_device
from fastapi import Depends, FastAPI, HTTPException, Request, status, WebSocket, WebSocketDisconnect
from database.users import user_exists, create_user, get_user_by_email
from database.pairing import insert_pairing_code, pair_device
from auth.dependencies import get_current_active_user, User
from slowapi import Limiter, _rate_limit_exceeded_handler
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta, datetime, timezone
from database.connection import get_db_connection
from database.devices import create_device_token
from slowapi.errors import RateLimitExceeded
from jwt.exceptions import InvalidTokenError
from slowapi.util import get_remote_address
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel, EmailStr
from dotenv import load_dotenv
from typing import Annotated
import psycopg2
import secrets
import asyncio
import jwt
import os

load_dotenv()

ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES', 30))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv('REFRESH_TOKEN_EXPIRE_DAYS', 15))
PAIRING_CODE_EXPIRE_MINUTES = int(os.getenv('PAIRING_CODE_EXPIRE_MINUTES', 10))
SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str


class RefreshRequest(BaseModel):
    refresh_token: str


class AccessToken(BaseModel):
    access_token: str
    token_type: str


class SignUpRequest(BaseModel):
    username: str
    email: EmailStr
    password: str


class DevicePairRequest(BaseModel):
    code: str
    hostname: str | None = None
    os: str | None = None
    platform: str | None = None


limiter = Limiter(key_func=get_remote_address)
app = FastAPI()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/users/me/")
@limiter.limit("10/minute")
async def read_users_me(request: Request, current_user: Annotated[User, Depends(get_current_active_user)]) -> User:
    return current_user


@app.post("/token")
@limiter.limit("10/minute")
async def login_for_access_token(request: Request, form_data: Annotated[OAuth2PasswordRequestForm, Depends()],) -> TokenPair:
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        user_db = get_user_by_email(cur, form_data.username)
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error")
    finally:
        cur.close()
        conn.close()

    if user_db is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password", headers={"WWW-Authenticate": "Bearer"})

    user = authenticate_user(user_db, form_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password", headers={"WWW-Authenticate": "Bearer"})

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(data={"sub": user['email'], "type": "access"}, expires_delta=access_token_expires)

    refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_token = create_refresh_token(data={"sub": user['email'], "type": "refresh"}, expires_delta=refresh_token_expires)

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        revoke_all_refresh_tokens_for_user(cur, user_db['id'])
        insert_refresh_token(cur, user_db['id'], refresh_token['expire'], refresh_token['encoded_jwt'])
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error")
    finally:
        cur.close()
        conn.close()

    return TokenPair(access_token=access_token['encoded_jwt'], refresh_token=refresh_token['encoded_jwt'], token_type="bearer")


@app.post("/auth/register")
@limiter.limit("2/minute")
async def sign_up(request: Request, payload: SignUpRequest):
    if not payload.email:
        raise HTTPException(status_code=400, detail="Email is required")
    if not payload.password or len(payload.password) <= 5:
        raise HTTPException(status_code=400, detail="Password must be longer than 5 characters")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if user_exists(cur, payload.email):
            raise HTTPException(status_code=400, detail="User already exists")
        hashed = get_password_hash(payload.password)
        create_user(cur, payload.username, payload.email, hashed)
        return {"message": "user created successfully"}
    except HTTPException:
        raise
    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=str(error))
    finally:
        cur.close()
        conn.close()


@app.post('/auth/refresh')
@limiter.limit("10/minute")
async def refresh_access_token(request: Request, payload: RefreshRequest) -> AccessToken:
    try:
        decoded = jwt.decode(payload.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
    except InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    if decoded.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid token type")

    email = decoded.get("sub")
    if email is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        token_record = get_refresh_token_record(cur, payload.refresh_token)
    except Exception:
        raise HTTPException(status_code=500, detail="Database error")
    finally:
        cur.close()
        conn.close()

    if token_record is None:
        raise HTTPException(status_code=401, detail="Refresh token not recognized")
    if token_record["revoked"]:
        raise HTTPException(status_code=401, detail="Refresh token has been revoked, please log in again")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    new_access_token = create_access_token(data={"sub": email, "type": "access"}, expires_delta=access_token_expires)

    return AccessToken(access_token=new_access_token['encoded_jwt'], token_type="bearer")


@app.post('/auth/logout')
@limiter.limit("10/minute")
async def logout(request: Request, payload: RefreshRequest):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        revoke_refresh_token(cur, payload.refresh_token)
        return {"message": "Logged out successfully"}
    except HTTPException:
        raise
    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=str(error))
    finally:
        cur.close()
        conn.close()


@app.get('/devices/pairing_code')
@limiter.limit("10/minute")
async def pairing_code(request: Request, current_user: Annotated[User, Depends(get_current_active_user)]):
    code = ''.join(secrets.choice('0123456789') for _ in range(6))
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=PAIRING_CODE_EXPIRE_MINUTES)
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        insert_pairing_code(cur, current_user['id'], code, expires_at)
        return {"code": code}
    except HTTPException:
        raise
    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=str(error))
    finally:
        cur.close()
        conn.close()


@app.post('/devices/pair')
@limiter.limit("2/minute")
async def pair(request: Request, payload: DevicePairRequest):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        device = pair_device(cur, payload.code, payload.hostname, payload.os, payload.platform)
        device_token = create_device_token(cur, device["id"])
        return {"message": "pairing completed", "device_id": device["id"],  "device_token": device_token}
    except HTTPException:
        raise
    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=str(error))
    finally:
        cur.close()
        conn.close()


latest_stats = None
@app.websocket("/ws/device")
async def websocket_endpoint(websocket: WebSocket):
    global latest_stats
    await websocket.accept()
    device = await websocket.receive_json()
    if not authenticate_device("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNTQ2MGUwNS02YmZhLTRkNDEtYTBiOC1lYWEyNWFmMDhlYmIiLCJ0eXBlIjoiZGV2aWNlIiwiZXhwIjoxNzg1MzIwMDY4fQ.9DONSHocslQJNsd7OL-bZOZA7ltW2biSOddcYxMXZnE"):
        await websocket.close()
        return print("Desktop disconnected")
         
    print("Desktop connected")

    try:
        while True:
            latest_stats = await websocket.receive_json()
            print(latest_stats)

    except WebSocketDisconnect:
        print("Desktop disconnected")


@app.websocket("/ws/mobile")
async def mobile_ws(websocket: WebSocket):
    global latest_stats
    await websocket.accept()
    print("Phone connected")
    try:
        while True:
            if latest_stats:
                await websocket.send_json(latest_stats)
            await asyncio.sleep(1)
    except WebSocketDisconnect:
        print("Phone disconnected")




 

