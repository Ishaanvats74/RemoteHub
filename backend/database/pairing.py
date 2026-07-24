from datetime import datetime, timezone
from fastapi import HTTPException

def insert_pairing_code(cur, user_id, code, expires_at):
    cur.execute("INSERT INTO pairing_codes (user_id, code, expires_at, is_used) VALUES (%s, %s, %s, %s)",(user_id, code, expires_at, False))

def pair_device(cur, code, hostname, os_name, platform):
    cur.execute("SELECT * FROM pairing_codes WHERE code = %s", (code,))
    pairing_row = cur.fetchone()

    if pairing_row is None:
        raise HTTPException(status_code=400, detail="Invalid pairing code")
    if pairing_row["is_used"]:
        raise HTTPException(status_code=400, detail="Pairing code already used")
    if pairing_row["expires_at"] < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Pairing code expired")

    cur.execute("INSERT INTO devices (user_id, hostname, os, platform, status) VALUES (%s, %s, %s, %s, %s) RETURNING id",(pairing_row["user_id"], hostname, os_name, platform, "active"))
    device_row = cur.fetchone()

    cur.execute("UPDATE pairing_codes SET is_used = true WHERE code = %s", (code,))
    return device_row