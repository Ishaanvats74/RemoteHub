# import psycopg2
# from .config import config
import psycopg
import os
from dotenv import load_dotenv
load_dotenv()

# def get_db_connection():
#     params = config()
#     conn = psycopg2.connect(**params)
#     conn.autocommit = True
#     return conn

conn_string = os.getenv("DATABASE_URL")

def get_db_connection():
    conn = psycopg.connect(conn_string)
    conn.autocommit = True
    return conn