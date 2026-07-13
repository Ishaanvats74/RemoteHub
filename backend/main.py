from database.db import get_db_connection, user_exists, create_user, get_user_by_email, revoke_refresh_token, insert_refresh_token, check_if_refresh_token_revked, revoke_all_other_refresh_token
from auth.auth import get_current_active_user, authenticate_user, create_access_token,create_refresh_token, get_password_hash
from fastapi import Depends, FastAPI, HTTPException, status
from slowapi import Limiter, _rate_limit_exceeded_handler
from fastapi.security import OAuth2PasswordRequestForm
from slowapi.errors import RateLimitExceeded
from jwt.exceptions import InvalidTokenError
from slowapi.util import get_remote_address
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel, EmailStr
from datetime import timedelta
from dotenv import load_dotenv
from typing import Annotated
from fastapi import Request
import psycopg2
import jwt
import os
load_dotenv()

ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES'),30)
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv('REFRESH_TOKEN_EXPIRE_DAYS'),15)
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

class User(BaseModel):
    email: str 
    username: str | None = None

class SignUpRequest(BaseModel):
    username: str
    email: EmailStr
    password: str

limiter = Limiter(key_func=get_remote_address)
app = FastAPI()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/users/me/")
@limiter.limit("5/minute")
async def read_users_me(request: Request,current_user: Annotated[User, Depends(get_current_active_user)],) -> User:
    return current_user

@app.post("/auth/login")
@limiter.limit("5/minute")
async def login_for_access_token(request: Request,form_data: Annotated[OAuth2PasswordRequestForm, Depends()],) -> TokenPair:

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        user_db = get_user_by_email(cur,form_data.username)
        
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error")
    
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    if user_db is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password", headers={"WWW-Authenticate": "Bearer"})
    
    user = authenticate_user(user_db, form_data.password)

    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password", headers={"WWW-Authenticate": "Bearer"})
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(data={"sub": user['email'],"type":"access"}, expires_delta=access_token_expires)

    refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_token = create_refresh_token(data={"sub": user['email'],"type":"refresh"}, expires_delta=refresh_token_expires)

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        revoke_all_other_refresh_token(cur,user_db['id'])
        insert_refresh_token(cur,user_db['id'],refresh_token['expire'],refresh_token['encoded_jwt'])
        
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error")

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    return TokenPair(access_token=access_token['encoded_jwt'],refresh_token=refresh_token['encoded_jwt'],token_type="bearer",)

@app.post("/auth/register")
@limiter.limit("5/minute")
async def sign_up(request: Request,payload: SignUpRequest):

    if len(payload.email) == 0 or payload.email == None:
        raise

    if len(payload.password) == 0 or len(payload.password) <= 5 or payload.password == None:
        raise

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
        raise HTTPException(status_code=500, detail=error)
    
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

@app.post('/auth/refresh')
@limiter.limit("10/minute")
async def refresh(request: Request, payload: RefreshRequest) -> AccessToken:
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
        token_record=check_if_refresh_token_revked(cur,payload.refresh_token)

    except Exception:
        raise HTTPException(status_code=500, detail="database error")
   
    finally:
        if cur:
            cur.close()
        if conn:
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
async def refresh(request: Request, payload: RefreshRequest):

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        revoke_refresh_token(cur,payload.refresh_token)
        return {"message": "Logged out successfully"}
    
    except HTTPException:
        raise 

    except (Exception, psycopg2.DatabaseError) as error:
        raise HTTPException(status_code=500, detail=error)
    
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()
