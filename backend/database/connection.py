import os

import psycopg
from dotenv import load_dotenv

load_dotenv()


def get_db_connection():
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise psycopg.OperationalError("DATABASE_URL is not configured")
    return psycopg.connect(database_url, autocommit=True, connect_timeout=10)
