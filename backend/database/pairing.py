from datetime import datetime, timezone
from fastapi import HTTPException

def insert_pairing_code(cur, user_id, code, expires_at):
    cur.execute("INSERT INTO pairing_codes (user_id, code, expires_at, is_used) VALUES (%s, %s, %s, %s)",(user_id, code, expires_at, False))

def delete_active_pairing_codes(cur , user_id):
    cur.execute("DELETE FROM pairing_codes WHERE user_id = %s;",(user_id,))

def pair_device(cur, code, hostname, os_name, platform):
    cur.execute("SELECT * FROM pairing_codes WHERE code = %s",(code,))
    pairing_row = cur.fetchone()

    if pairing_row is None:
        raise HTTPException(400, "Invalid pairing code")

    if pairing_row["expires_at"] < datetime.now(timezone.utc):
        raise HTTPException(400, "Pairing code expired")

    cur.execute("INSERT INTO devices (user_id, hostname, os, platform, status) VALUES (%s, %s, %s, %s, %s) RETURNING id, user_id, hostname, os, platform",(pairing_row["user_id"],hostname,os_name,platform,"offline"))
    device = cur.fetchone()
    cur.execute("DELETE FROM pairing_codes WHERE code = %s",(code,))
    return device