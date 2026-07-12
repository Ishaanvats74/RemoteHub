# db.py
import psycopg2
from .config import config
from psycopg2.extras import RealDictCursor

def get_db_connection():
    """Connect to the PostgreSQL database server and return the connection."""
    try:
        params = config()
        conn = psycopg2.connect(**params)
        return conn.cursor(cursor_factory=RealDictCursor)
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)

def user_exists(cur, email) -> bool:
    cur.execute("SELECT 1 FROM users WHERE email = %s", (email,))
    return cur.fetchone() is not None

def create_user(cur, name, email, password_hash) -> str:
    cur.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
        (name, email, password_hash),
    )
    return "user created successfully"


def get_user_by_email(cur,email):
    cur.execute("SELECT id, name, email, password_hash FROM users WHERE email = %s", (email,))
    return cur.fetchone()
    

