import psycopg2
from .config import config

def get_db_connection():
    params = config()
    conn = psycopg2.connect(**params)
    conn.autocommit = True
    return conn