# db.py
import psycopg2
from .config import config
import hashlib


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
    cur.execute("INSERT INTO users (username, email, hashed_password) VALUES (%s, %s, %s)", (username, email, hashed_password),)
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
