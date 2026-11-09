import asyncio
import logging
from contextlib import asynccontextmanager
from starlette.concurrency import run_in_threadpool
from cache.redis_client import redis_cache
from pairing import pairing_router
from database.refresh_tokens import insert_refresh_token,get_refresh_token_record,revoke_refresh_token,revoke_all_refresh_tokens_for_user
from database.devices import create_device_token, update_last_seen, set_device_status, get_device, get_devices
from auth.security import authenticate_user,create_access_token,create_refresh_token,get_password_hash,authenticate_device
from fastapi import Depends, FastAPI, HTTPException, Request, status, WebSocket, WebSocketDisconnect
from auth.dependencies import get_current_active_user, User, get_current_user
from database.users import user_exists, create_user, get_user_by_email, get_user_by_id
from database.pairing import insert_pairing_code, pair_device, delete_active_pairing_codes
from slowapi import Limiter, _rate_limit_exceeded_handler
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta, datetime, timezone
from sockets.socket import ConnectionManager
from database.connection import get_db_connection
from slowapi.errors import RateLimitExceeded
from jwt.exceptions import InvalidTokenError
from slowapi.util import get_remote_address
from psycopg.rows import dict_row
from pydantic import BaseModel, EmailStr,Field
from dotenv import load_dotenv
from typing import Annotated
import psycopg
import secrets
import jwt
import os
from uuid import UUID
from redis.exceptions import RedisError
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Header

load_dotenv()

ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES', 30))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv('REFRESH_TOKEN_EXPIRE_DAYS', 15))
PAIRING_CODE_EXPIRE_MINUTES = int(os.getenv('PAIRING_CODE_EXPIRE_MINUTES', 10))
SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
PAIRING_CODE_LENGTH = 6

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
    username: str = Field(min_length=3, max_length=30)
    email: EmailStr
    password: str = Field(min_length=6)

class DevicePairRequest(BaseModel):
    code: str
    hostname: str | None = None
    os: str | None = None
    platform: str | None = None

class MessageResponse(BaseModel):
    message: str

class PairingCodeResponse(BaseModel):
    code: str

class PairDeviceResponse(BaseModel):
    message: str
    device_id: UUID
    device_token: str

class DeviceResponse(BaseModel):
    id: UUID
    user_id: UUID
    hostname: str
    os: str
    platform: str
    status: str
    last_seen: datetime | None
    created_at: datetime

def user_rate_limit(request: Request):
    user = getattr(request.state, "user", None)

    if user:
        return str(user["id"])

    return get_remote_address(request)

logger = logging.getLogger(__name__)
limiter = Limiter(key_func=user_rate_limit, storage_uri=os.getenv("REDIS_URL") or None)


@asynccontextmanager
async def lifespan(app):
    redis_cache.start()
    try:
        yield
    finally:
        await redis_cache.close()


app = FastAPI(lifespan=lifespan)
manager = ConnectionManager()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.include_router(pairing_router(limiter))

cors_origins = [
    origin.strip().rstrip("/")
    for origin in os.getenv("CORS_ORIGINS", "").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)

@app.get("/health")
def health():
    return {"status": "ok"}


def check_database():
    with get_db_connection() as conn, conn.cursor() as cur:
        cur.execute("""
            SELECT 1
            FROM users, devices, refresh_tokens, pairing_codes, desktop_pairing_sessions
            WHERE false
        """)


@app.get("/ready")
async def readiness():
    try:
        await run_in_threadpool(check_database)
        if redis_cache.client is not None:
            await redis_cache.client.ping()
    except (psycopg.Error, RedisError):
        raise HTTPException(503, "Backend dependencies unavailable")
    return {"status": "ready"}


@app.get("/users/me/")
@limiter.limit("10/minute")
async def read_users_me(request: Request, current_user: Annotated[User, Depends(get_current_active_user)]):
    return {"id": current_user['id'],"username": current_user['username'],"email": current_user['email']}


@app.post("/token")
@limiter.limit("10/minute")
async def login_for_access_token(request: Request, form_data: Annotated[OAuth2PasswordRequestForm, Depends()],) -> TokenPair:
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)
    try:
        user_db = get_user_by_email(cur, form_data.username)
        if user_db is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No user exist", headers={"WWW-Authenticate": "Bearer"})

        user = authenticate_user(user_db, form_data.password)
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect password", headers={"WWW-Authenticate": "Bearer"})

        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        access_token = create_access_token(data={"sub": str(user["id"]), "email": user["email"],"type": "access" }, expires_delta=access_token_expires)
        refresh_token = create_refresh_token(data={"sub": str(user["id"]), "email": user["email"], "type": "refresh"}, expires_delta=refresh_token_expires)

        revoke_all_refresh_tokens_for_user(cur, user_db['id'])
        insert_refresh_token(cur, user_db['id'], refresh_token['expire'], refresh_token['encoded_jwt'])

    except HTTPException:
        conn.rollback()
        raise

    except psycopg.DatabaseError:
        conn.rollback()
        raise HTTPException(
            status_code=500,
            detail="Database error"
        )
    finally:
        cur.close()
        conn.close()

    return TokenPair(access_token=access_token['encoded_jwt'], refresh_token=refresh_token['encoded_jwt'], token_type="bearer")


@app.post("/auth/register", status_code=status.HTTP_201_CREATED, response_model=MessageResponse)
@limiter.limit("2/minute")
async def sign_up(request: Request, payload: SignUpRequest):
    print("connection started")
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)
    print("connection successful")

    try:
        if user_exists(cur, payload.email):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")

        hashed = get_password_hash(payload.password)
        create_user(cur, payload.username, payload.email, hashed)
        return MessageResponse(message="User created successfully")

    except HTTPException:
        raise

    except psycopg.DatabaseError:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error")

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

    user_id = decoded.get("sub")
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)
    try:
        token_record = get_refresh_token_record(cur, payload.refresh_token)
        user = get_user_by_id(cur, user_id)
    except psycopg.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")
    
    finally:
        cur.close()
        conn.close()

    if token_record is None:
        raise HTTPException(status_code=401, detail="Refresh token not recognized")
    if token_record["revoked"]:
        raise HTTPException(status_code=401, detail="Refresh token has been revoked, please log in again")
    
    

    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    new_access_token = create_access_token(data={"sub": user_id, "email": decoded.get("email"),"type": "access",}, expires_delta=access_token_expires)

    return AccessToken(access_token=new_access_token['encoded_jwt'], token_type="bearer")



@app.post("/auth/logout",response_model=MessageResponse)
@limiter.limit("10/minute")
async def logout(request: Request, payload: RefreshRequest):
    try:
        decoded = jwt.decode(payload.refresh_token,SECRET_KEY,algorithms=[ALGORITHM])
    except InvalidTokenError:
        raise HTTPException(status_code=401,detail="Invalid or expired refresh token")

    if decoded.get("type") != "refresh":
        raise HTTPException(status_code=401,detail="Invalid token type")

    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        token = get_refresh_token_record(cur, payload.refresh_token)

        if token is None:
            raise HTTPException(status_code=401,detail="Refresh token not recognized")

        if token["revoked"]:
            return {"message": "Already logged out"}

        revoke_refresh_token(cur, payload.refresh_token)

        return MessageResponse(message="Logged out successfully")

    except HTTPException:
        raise

    except psycopg.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")

    finally:
        cur.close()
        conn.close()

@app.post('/devices/pairing_code',response_model=PairingCodeResponse)
@limiter.limit("10/minute")
async def pairing_code(request: Request, current_user: Annotated[User, Depends(get_current_active_user)]):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)
    try:
        delete_active_pairing_codes(cur, current_user["id"])
        code = ''.join(secrets.choice('0123456789') for _ in range(PAIRING_CODE_LENGTH))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=PAIRING_CODE_EXPIRE_MINUTES)
        insert_pairing_code(cur, current_user['id'], code, expires_at)
        return PairingCodeResponse(code=code)
    except HTTPException:
        raise
    except psycopg.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")
    finally:
        cur.close()
        conn.close()

@app.post(
    "/devices/pair",
    response_model=PairDeviceResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("2/minute")
async def pair(request: Request, payload: DevicePairRequest):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        with conn.transaction():
            device = pair_device(
                cur, payload.code, payload.hostname or "Desktop",
                payload.os or "Unknown", payload.platform or "Unknown",
            )
            device_token = create_device_token(cur, device["id"])

        # 3. Tell the user's mobile app that pairing succeeded
        await manager.send_to_user(
            str(device["user_id"]),
            {
                "type": "device_paired",
                "device_id": str(device["id"]),
                "hostname": device["hostname"],
                "os": device["os"],
                "platform": device["platform"],
            }
        )

        # 4. Return response to the device that entered the code
        return PairDeviceResponse(
            message="Pairing completed",
            device_id=device["id"],
            device_token=device_token
        )

    except HTTPException:
        conn.rollback()
        raise

    except psycopg.DatabaseError:
        conn.rollback()
        raise HTTPException(
            status_code=500,
            detail="Database error"
        )

    finally:
        cur.close()
        conn.close()


async def receive_object(websocket):
    message = await websocket.receive_json()
    if not isinstance(message, dict):
        raise ValueError("WebSocket message must be a JSON object")
    return message


def update_presence(device_id, online):
    with get_db_connection() as conn, conn.cursor() as cur:
        if online:
            update_last_seen(cur, device_id)
        else:
            set_device_status(cur, device_id, "offline")


@app.websocket("/ws/desktop")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    user_id = device_id = None
    try:
        auth = await asyncio.wait_for(receive_object(websocket), timeout=10)
        token = auth.get("token")
        device = await run_in_threadpool(authenticate_device, token) if isinstance(token, str) else None
        if device is None or device["status"] == "revoked":
            await websocket.close(code=1008)
            return

        user_id, device_id = str(device["user_id"]), str(device["id"])
        await manager.connect_desktop(user_id, device_id, websocket)
        await run_in_threadpool(update_presence, device_id, True)
        await websocket.send_json({"type": "authenticated"})
        await manager.send_to_user(user_id, {
            "type": "device_status", "device_id": device_id, "status": "online",
        })

        while True:
            message = await receive_object(websocket)
            message["device_id"] = device_id
            match message.get("type"):
                case "hardware_specs" | "command_result":
                    await manager.send_to_user(user_id, message)
                case "telemetry":
                    await manager.update_telemetry(device_id, message.get("data", {}))
                    await manager.send_to_user(user_id, message)
                case "heartbeat":
                    await run_in_threadpool(update_presence, device_id, True)

    except WebSocketDisconnect:
        pass
    except (ValueError, TimeoutError):
        await websocket.close(code=1008)
    except Exception:
        logger.exception("Desktop WebSocket failed")
        await websocket.close(code=1011)
    finally:
        if device_id and manager.disconnect_desktop(user_id, device_id, websocket):
            await run_in_threadpool(update_presence, device_id, False)
            if not manager.is_device_online(device_id):
                await manager.send_to_user(user_id, {
                    "type": "device_status", "device_id": device_id, "status": "offline",
                })


def authenticate_user_token(token: str):
    credentials_exception = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,detail="Could not validate credentials",)

    try:
        payload = jwt.decode(token,SECRET_KEY,algorithms=[ALGORITHM])

    except InvalidTokenError:
        raise credentials_exception

    if payload.get("type") != "access":
        raise credentials_exception

    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        user = get_user_by_id(cur, user_id)

    except psycopg.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")

    finally:
        cur.close()
        conn.close()

    if user is None:
        raise credentials_exception

    return user

@app.websocket("/ws/mobile")
async def mobile_ws(websocket: WebSocket):
    await websocket.accept()
    user_id = None
    try:
        auth = await asyncio.wait_for(receive_object(websocket), timeout=10)
        token = auth.get("token")
        if not isinstance(token, str):
            await websocket.close(code=1008)
            return
        user = await run_in_threadpool(authenticate_user_token, token)
        user_id = str(user["id"])
        await manager.connect_mobile(user_id, websocket)
        await websocket.send_json({"type": "authenticated"})

        while True:
            message = await receive_object(websocket)
            device_id = message.get("device_id")
            command = message.get("command")
            if (
                message.get("type") == "command"
                and command in ("shutdown", "restart", "sleep", "lock")
                and isinstance(device_id, str)
                and device_id in manager.user_devices.get(user_id, ())
            ):
                await manager.send_to_device(device_id, {
                    "type": "command", "device_id": device_id, "command": command,
                })

    except WebSocketDisconnect:
        pass
    except (ValueError, TimeoutError, HTTPException):
        await websocket.close(code=1008)
    finally:
        if user_id:
            manager.disconnect_mobile(user_id, websocket)


@app.get("/devices", response_model=list[DeviceResponse])
def get_all_devices(current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        devices = get_devices(cur, current_user["id"])
        return devices

    except HTTPException:
        raise

    except psycopg.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")

    finally:
        cur.close()
        conn.close()


@app.get("/devices/validate")
@limiter.limit("20/minute")
def validate_device_token(request: Request, authorization: str | None = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing device token")

    token = authorization.split(" ", 1)[1]
    device = authenticate_device(token)

    if device is None:
        raise HTTPException(status_code=401, detail="Invalid or revoked device token")

    if device.get("status") == "revoked":
        raise HTTPException(status_code=401, detail="Device has been revoked")

    return {
        "valid": True,
        "device_id": str(device["id"]),
        "hostname": device["hostname"],
    }

@app.get("/devices/{device_id}")
def get_single_device(device_id: UUID,current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        device = get_device(cur,device_id,current_user["id"])
        if device is None:
            raise HTTPException(404, "Device not found")
        return device

    except HTTPException:
        raise

    except psycopg.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")

    finally:
        cur.close()
        conn.close()




@app.get("/devices/{device_id}/telemetry")
async def get_device_telemetry(device_id: UUID, current_user=Depends(get_current_user)):
    def lookup_device():
        with get_db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            return get_device(cur, device_id, current_user["id"])

    if await run_in_threadpool(lookup_device) is None:
        raise HTTPException(404, "Device not found")
    telemetry = await manager.get_telemetry(str(device_id))
    if telemetry is None:
        raise HTTPException(404, "No telemetry available.")
    return telemetry
