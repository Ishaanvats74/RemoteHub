import asyncio
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
import psycopg2
import secrets
import jwt
import os
from uuid import UUID
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

limiter = Limiter(key_func=user_rate_limit)
app = FastAPI()
manager = ConnectionManager()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
origins = [
    "http://localhost.tiangolo.com",
    "https://localhost.tiangolo.com",
    "http://localhost",
    "http://localhost:8080",
    "http://localhost:60566/"
]

app.add_middleware(
    CORSMiddleware,
    # allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status": "ok"}


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

    except psycopg2.DatabaseError:
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
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        if user_exists(cur, payload.email):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")

        hashed = get_password_hash(payload.password)
        create_user(cur, payload.username, payload.email, hashed)
        return MessageResponse(message="User created successfully")

    except HTTPException:
        raise

    except psycopg2.DatabaseError:
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
    except psycopg2.DatabaseError:
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

    except psycopg2.DatabaseError:
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
    except psycopg2.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")
    finally:
        cur.close()
        conn.close()


@app.post("/devices/pair",response_model=PairDeviceResponse,status_code=status.HTTP_201_CREATED,)
@limiter.limit("2/minute")
async def pair(request: Request,payload: DevicePairRequest):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        device = pair_device(cur,payload.code,payload.hostname,payload.os,payload.platform)

        device_token = create_device_token(cur, device["id"])

        return PairDeviceResponse(message="Pairing completed",device_id=device["id"],device_token=device_token)

    except HTTPException:
        raise

    except psycopg2.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error",)

    finally:
        cur.close()
        conn.close()


@app.websocket("/ws/desktop")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    device = None

    try:
        auth_message = await websocket.receive_json()
        token = auth_message.get("token")

        if token is None:
            await websocket.close(code=1008)
            return

        device = authenticate_device(token)
        if device is None:
            await websocket.close(code=1008)
            return

        print(f"Desktop connected: {device['hostname']}")

        await manager.connect_desktop(user_id=str(device["user_id"]), device_id=str(device["id"]), websocket=websocket)
        conn = get_db_connection()
        cur = conn.cursor(row_factory=dict_row)

        try:
            set_device_status(cur, device["id"],'active')
        except psycopg2.DatabaseError:
            print("Failed to mark device online.")
            await websocket.close(code=1011)
            return
        finally:
            cur.close()
            conn.close()

        while True:
            message = await websocket.receive_json()

            print("================================")
            print("Desktop sent:", message)
            print("================================")

            message_type = message.get("type")

            if message_type is None:
                print("WARNING: Desktop message has no type!")
                continue

            match message_type:
                case "hardware_specs":
                    await manager.send_to_user(
                        str(device["user_id"]),
                        message
                    )

                case "telemetry":
                    manager.update_telemetry(str(device["id"]),message.get("data", {}))

                    await manager.send_to_user(str(device["user_id"]),message)

                case "command_result":
                    await manager.send_to_user(str(device["user_id"]),message)

                case "heartbeat":
                    conn = get_db_connection()
                    cur = conn.cursor(row_factory=dict_row)

                    try:
                        update_last_seen(cur, device["id"])
                    except psycopg2.DatabaseError:
                        print("Failed to update heartbeat.")
                        await websocket.close(code=1011)
                        return
                    finally:
                        cur.close()
                        conn.close()

                case _:
                    print(f"Unknown websocket message: {message_type}")

    except WebSocketDisconnect:
        print("Desktop disconnected.")

    except Exception as e:
        print(f"WebSocket error: {e}")

    finally:
        if device:
            manager.disconnect_desktop(str(device["user_id"]),str(device["id"]))

            conn = get_db_connection()
            cur = conn.cursor(row_factory=dict_row)

            try:
                set_device_status(cur, device["id"],'offline')
            except psycopg2.DatabaseError:
                print("Failed to mark device offline.")
            finally:
                cur.close()
                conn.close()

            print(f"{device['hostname']} disconnected")

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

    except psycopg2.DatabaseError:
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
    user = None
    try:
        auth = await websocket.receive_json()
        print(auth)
        token = auth.get("token")
        print("Token:", token)
        if token is None:
            await websocket.close(code=1008)
            return

        user = authenticate_user_token(token)
        print("Authenticated user:", user)
        if user is None:
            print("Authentication failed:")
            await websocket.close(code=1008)
            return

        print(f"Mobile connected: {user['id']}")

        await manager.connect_mobile(str(user["id"]),websocket)

        while True:
            message = await websocket.receive_json()

            message_type = message.get("type")

            match message_type:

                case "command":
                    await manager.send_to_device(message["device_id"],message)

                case _:
                    print(f"Unknown message: {message_type}")

    except WebSocketDisconnect:
        print("Mobile disconnected")

    finally:
        if user:
            manager.disconnect_mobile(str(user["id"]),websocket)


@app.get("/devices", response_model=list[DeviceResponse])
def get_all_devices(current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        devices = get_devices(cur, current_user["id"])
        return devices

    except HTTPException:
        raise

    except psycopg2.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")

    finally:
        cur.close()
        conn.close()


@app.get("/devices/{device_id}")
def get_single_device(device_id: str,current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        device = get_device(cur,device_id,current_user["id"])
        return device

    except HTTPException:
        raise

    except psycopg2.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")

    finally:
        cur.close()
        conn.close()




@app.get("/devices/{device_id}/telemetry")
def get_device_telemetry(device_id: UUID,current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(row_factory=dict_row)

    try:
        get_device(cur, str(device_id), current_user["id"])
        telemetry = manager.get_telemetry(str(device_id))
        if telemetry is None:
            raise HTTPException(status_code=404,detail="No telemetry available.")
        return telemetry

    except HTTPException:
        raise

    except psycopg2.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")

    finally:
        cur.close()
        conn.close()


@app.get("/devices/validate")
@limiter.limit("20/minute")
async def validate_device_token(request: Request, authorization: str | None = Header(None)):
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
  