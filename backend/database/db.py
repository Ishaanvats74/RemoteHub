# db.py
import psycopg2
from .config import config


def get_db_connection():
    """Connect to the PostgreSQL database server and return the connection."""
    try:
        params = config()
        conn = psycopg2.connect(**params)
        conn.autocommit = True
        return conn
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)

def user_exists(cur, email) -> bool:
    cur.execute("SELECT 1 FROM users WHERE email = %s", (email,))
    return cur.fetchone() is not None

def create_user(cur, username, email, hashed_password) -> str:
    cur.execute(
        "INSERT INTO users (username, email, hashed_password) VALUES (%s, %s, %s)",
        (username, email, hashed_password),
    )
    return "user created successfully"


def get_user_by_email(cur,email):
    cur.execute("SELECT id, username, email, hashed_password FROM users WHERE email = %s", (email,))
    return cur.fetchone()
    

