import psycopg2
from .config import config
import hashlib
from fastapi import  HTTPException
from datetime import datetime, timezone 


def get_db_connection():
    """Connect to the PostgreSQL database server and return the connection."""
    try:
        params = config()
        conn = psycopg2.connect(**params)
        conn.autocommit = True
        return conn
    except (Exception, psycopg2.DatabaseError) as error:
        raise

def user_exists(cur, email) -> bool:
    cur.execute("SELECT 1 FROM users WHERE email = %s", (email,))
    return cur.fetchone() is not None

def create_user(cur, username, email, hashed_password) -> str:
    cur.execute("INSERT INTO users (username, email, hashed_password) VALUES (%s, %s, %s)", (username, email, hashed_password))
    return "user created successfully"

def get_user_by_email(cur,email):
    cur.execute("SELECT id, username, email, hashed_password FROM users WHERE email = %s", (email,))
    return cur.fetchone()
    
def insert_refresh_token(cur,user_id,expire,refresh_token):
    sha256 = hashlib.sha256()
    sha256.update(refresh_token.encode())
    string_hash = sha256.hexdigest()
    cur.execute("insert into refresh_tokens (user_id,token_hash,revoked,expires_at) values (%s,%s,%s,%s)",(user_id,string_hash,False,expire))
    return {"message": "inserted token successfully"}

def check_if_refresh_token_revked(cur,refresh_token):
    sha256 = hashlib.sha256()
    sha256.update(refresh_token.encode())
    string_hash = sha256.hexdigest()
    cur.execute("select * from refresh_tokens where token_hash = %s",(string_hash,))
    return cur.fetchone()

def revoke_refresh_token(cur,refresh_token):
    sha256 = hashlib.sha256()
    sha256.update(refresh_token.encode())
    string_hash = sha256.hexdigest()
    cur.execute("update refresh_tokens set revoked=true where token_hash=%s",(string_hash,))

def revoke_all_other_refresh_token(cur,user_id):
    cur.execute("update refresh_tokens set revoked = true where user_id=%s",(user_id,))
    return {"message": "inserted token successfully"}

def insert_code(cur,user_id,code,refresh_token_expires):
    cur.execute("insert into pairing_codes (user_id,code,expires_at,is_Used) values (%s,%s,%s,%s)",(user_id,code,refresh_token_expires,False))
    return {"message": "code Inserted"}

def pair_device(cur, code, hostname, os_name, platform):
    cur.execute(
        "SELECT * FROM pairing_codes WHERE code = %s",
        (code,)
    )
    pairing_row = cur.fetchone()

    if pairing_row is None:
        raise HTTPException(status_code=400, detail="Invalid pairing code")
    if pairing_row["is_used"]:
        raise HTTPException(status_code=400, detail="Pairing code already used")
    if pairing_row["expires_at"] < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Pairing code expired")

    cur.execute(
        "INSERT INTO devices (user_id, hostname, os, platform, status) VALUES (%s, %s, %s, %s, %s) RETURNING id, device_uuid",
        (pairing_row["user_id"], hostname, os_name, platform, "active")
    )
    device_row = cur.fetchone()

    cur.execute(
        "UPDATE pairing_codes SET is_used = true WHERE code = %s",
        (code,)
    )
    return device_row