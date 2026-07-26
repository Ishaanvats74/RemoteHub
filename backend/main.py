from database.refresh_tokens import insert_refresh_token,get_refresh_token_record,revoke_refresh_token,revoke_all_refresh_tokens_for_user
from database.devices import create_device_token, update_last_seen, set_device_online,set_device_offline, get_device, get_devices
from auth.security import authenticate_user,create_access_token,create_refresh_token,get_password_hash,authenticate_device
from fastapi import Depends, FastAPI, HTTPException, Request, status, WebSocket, WebSocketDisconnect
from auth.dependencies import get_current_active_user, User, get_current_user
from database.users import user_exists, create_user, get_user_by_email, get_user_by_id
from database.pairing import insert_pairing_code, pair_device
from slowapi import Limiter, _rate_limit_exceeded_handler
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta, datetime, timezone
from sockets.socket import ConnectionManager
from database.connection import get_db_connection
from slowapi.errors import RateLimitExceeded
from jwt.exceptions import InvalidTokenError
from slowapi.util import get_remote_address
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel, EmailStr,Field
from dotenv import load_dotenv
from typing import Annotated
import psycopg2
import secrets
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

# def user_rate_limit(request: Request):
#     user = getattr(request.state, "user", None)

#     if user:
#         return str(user["id"])

#     return get_remote_address(request)

limiter = Limiter(key_func=get_remote_address)
app = FastAPI()
manager = ConnectionManager()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


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
    cur = conn.cursor(cursor_factory=RealDictCursor)
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
    cur = conn.cursor(cursor_factory=RealDictCursor)

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
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        token_record = get_refresh_token_record(cur, payload.refresh_token)
    except psycopg2.DatabaseError:
        raise HTTPException(status_code=500,detail="Database error")
    
    finally:
        cur.close()
        conn.close()

    if token_record is None:
        raise HTTPException(status_code=401, detail="Refresh token not recognized")
    if token_record["revoked"]:
        raise HTTPException(status_code=401, detail="Refresh token has been revoked, please log in again")
    user = get_user_by_id(cur, user_id)

    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    new_access_token = create_access_token(data={"sub": user_id, "email": decoded.get("email"),"type": "access",}, expires_delta=access_token_expires)

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


@app.websocket("/ws/desktop")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        auth_message = await websocket.receive_json()
        device = authenticate_device(auth_message["token"])

        if not device:
            await websocket.close(code=1008)
            return
        print("Desktop user:", device["user_id"])
        print("Desktop device:", device["id"])
        await manager.connect_desktop(user_id=str(device["user_id"]), device_id=str(device["id"]), websocket=websocket)
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            set_device_online(cur, device["id"])
        except HTTPException:
            raise
        except (Exception, psycopg2.DatabaseError) as error:
            raise HTTPException(status_code=500, detail=str(error))
        finally:
            cur.close()
            conn.close()

        print(f"{device['hostname']} connected")

        while True:
            message = await websocket.receive_json()

            match message["type"]:

                case "telemetry":
                    manager.update_telemetry(str(device["id"]),message["data"])
                    await manager.send_to_user(str(device["user_id"]),message)

                case "command_result":
                    await manager.send_to_user(str(device["user_id"]),message)
                    print("message")

                case "heartbeat":
                    conn = get_db_connection()
                    cur = conn.cursor(cursor_factory=RealDictCursor)
                    
                    try:
                        update_last_seen(cur,device["id"])  
                    except HTTPException:
                        raise
                    except (Exception, psycopg2.DatabaseError) as error:
                        raise HTTPException(status_code=500, detail=str(error))
                    finally:
                        cur.close()
                        conn.close()
                    continue

                case _:
                    print("Unknown message")

    except WebSocketDisconnect:
        manager.disconnect_desktop(str(device["user_id"]),str(device["id"]))
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        try:
            set_device_offline(cur, device["id"])
        except HTTPException:
            raise
        except (Exception, psycopg2.DatabaseError) as error:
            raise HTTPException(status_code=500, detail=str(error))
        finally:
            cur.close()
            conn.close()
        
        print(f"{device['hostname']} disconnected")


@app.websocket("/ws/mobile")
async def mobile_ws(websocket: WebSocket):
    await websocket.accept()
    print('connected')
    auth = await websocket.receive_json()
    print(auth)
    user = await get_current_user(auth["token"])
    print("Mobile user:", user["id"])
    await manager.connect_mobile(str(user["id"]),websocket)

    try:
        while True:
            message = await websocket.receive_json()
            if message["type"] == "command":
                await manager.send_to_device(message["device_id"],message)

    except WebSocketDisconnect:
        manager.disconnect_mobile(str(user["id"]),websocket)


@app.get("/devices")
def get_all_devices(current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        return get_devices(cur, current_user["id"])

    except HTTPException:
        raise

    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=str(error))

    finally:
        cur.close()
        conn.close()


@app.get("/devices/{device_id}")
def get_single_device(device_id: str, current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        return get_device(cur, device_id, current_user["id"])

    except HTTPException:
        raise

    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=str(error))

    finally:
        cur.close()
        conn.close()


@app.get("/devices/{device_id}/telemetry")
def get_device_telemetry(device_id: str, current_user=Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # Verify that this device belongs to the logged-in user
        get_device(cur, device_id, current_user["id"])

        telemetry = manager.get_telemetry(device_id)

        if telemetry is None:
            raise HTTPException(
                status_code=404,
                detail="No telemetry available."
            )

        return telemetry

    except HTTPException:
        raise

    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=str(error))

    finally:
        cur.close()
        conn.close()


 

