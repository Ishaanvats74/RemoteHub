from auth.auth import get_current_active_user, authenticate_user, create_access_token, get_password_hash
from database.db import get_db_connection, user_exists, create_user, get_user_by_email
from fastapi import Depends, FastAPI, HTTPException, status
from slowapi import Limiter, _rate_limit_exceeded_handler
from fastapi.security import OAuth2PasswordRequestForm
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel, EmailStr
from datetime import timedelta
from dotenv import load_dotenv
from typing import Annotated
from fastapi import Request
import psycopg2
import os
load_dotenv()

ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES'),30)

class Token(BaseModel):
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

@app.get("/users/me/")
@limiter.limit("5/minute")
async def read_users_me(request: Request,current_user: Annotated[User, Depends(get_current_active_user)],) -> User:
    return current_user


@app.post("/token")
@limiter.limit("5/minute")
async def login_for_access_token(request: Request,form_data: Annotated[OAuth2PasswordRequestForm, Depends()],) -> Token:
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

    user = authenticate_user(user_db, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user['email']}, expires_delta=access_token_expires
    )
    return Token(access_token=access_token, token_type="bearer")


@app.post("/sign-up")
@limiter.limit("5/minute")
async def sign_up(request: Request,payload: SignUpRequest):
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
        print(error)
        raise HTTPException(status_code=500, detail=error)
    
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

