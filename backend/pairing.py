from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4
import os
import secrets

from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response
from psycopg.rows import dict_row
from slowapi.util import get_remote_address
from pydantic import BaseModel, Field

from auth.dependencies import get_current_active_user
from database.connection import get_db_connection
from database.devices import DEVICE_TOKEN_PREFIX, create_device_token, get_device
from database.utils import hash_token


class DesktopInfo(BaseModel):
    hostname: str = Field(min_length=1, max_length=255)
    os: str = Field(min_length=1, max_length=64)
    platform: str = Field(min_length=1, max_length=255)


class PairingCode(BaseModel):
    code: str = Field(pattern=r"^[0-9]{6}$")


class Decision(BaseModel):
    approve: bool


def cursor():
    with get_db_connection() as conn, conn.transaction(), conn.cursor(row_factory=dict_row) as cur:
        yield cur


def desktop_session(cur, session_id, authorization, *, lock=False):
    scheme, _, secret = authorization.partition(" ")
    if scheme.lower() != "bearer" or not secret:
        raise HTTPException(401, "Missing pairing credential")
    query = "SELECT * FROM desktop_pairing_sessions WHERE id = %s"
    cur.execute(query + (" FOR UPDATE" if lock else ""), (session_id,))
    session = cur.fetchone()
    if session is None or not secrets.compare_digest(session["secret_hash"], hash_token(secret)):
        raise HTTPException(404, "Pairing session not found")
    if session["expires_at"] <= datetime.now(timezone.utc):
        raise HTTPException(410, "Pairing code expired")
    return session, secret


def device_token(secret, device_id):
    # The random desktop secret lets retries recover the same token without storing plaintext.
    return DEVICE_TOKEN_PREFIX + hash_token(f"device:{device_id}:{secret}")


def session_status(session):
    return {
        "session_id": session["id"],
        "status": session["state"],
        "hostname": session["hostname"],
        "expires_at": session["expires_at"],
        "device_id": session["device_id"],
    }


def pairing_router(limiter):
    router = APIRouter(prefix="/pairing", tags=["pairing"])

    @router.post("/sessions", status_code=201)
    @limiter.limit("10/minute")
    def create_session(request: Request, response: Response, info: DesktopInfo, cur=Depends(cursor, scope="function")):
        response.headers["Cache-Control"] = "no-store"
        session_id = uuid4()
        secret = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=int(os.getenv("PAIRING_CODE_EXPIRE_MINUTES", "10"))
        )
        cur.execute("DELETE FROM desktop_pairing_sessions WHERE expires_at <= now()")
        for _ in range(10):
            code = f"{secrets.randbelow(1_000_000):06d}"
            cur.execute(
                """
                INSERT INTO desktop_pairing_sessions
                    (id, code, secret_hash, hostname, os, platform, expires_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (code) DO NOTHING RETURNING id
                """,
                (session_id, code, hash_token(secret), info.hostname, info.os, info.platform, expires_at),
            )
            if cur.fetchone():
                return {
                    "session_id": session_id, "code": code,
                    "secret": secret, "expires_at": expires_at,
                }
        raise HTTPException(503, "Unable to generate a pairing code. Try again.")

    @router.post("/requests")
    @limiter.limit("30/minute", key_func=get_remote_address)
    @limiter.limit("6/minute")
    def request_pairing(request: Request, payload: PairingCode,
                        user=Depends(get_current_active_user), cur=Depends(cursor, scope="function")):
        cur.execute(
            "SELECT * FROM desktop_pairing_sessions WHERE code = %s FOR UPDATE",
            (payload.code,),
        )
        session = cur.fetchone()
        if not session or session["expires_at"] <= datetime.now(timezone.utc):
            raise HTTPException(404, "Pairing code is invalid or expired")
        if session["user_id"] == user["id"]:
            return session_status(session)
        if session["state"] != "open":
            raise HTTPException(409, "This code is already in use. Generate a new code on the laptop.")
        cur.execute(
            """
            UPDATE desktop_pairing_sessions
            SET user_id = %s, requester = %s, state = 'pending'
            WHERE id = %s RETURNING *
            """,
            (user["id"], user["email"], session["id"]),
        )
        return session_status(cur.fetchone())

    @router.get("/requests/{session_id}")
    @limiter.limit("120/minute")
    def mobile_status(request: Request, session_id: UUID,
                      user=Depends(get_current_active_user), cur=Depends(cursor, scope="function")):
        cur.execute(
            "SELECT * FROM desktop_pairing_sessions WHERE id = %s AND user_id = %s",
            (session_id, user["id"]),
        )
        session = cur.fetchone()
        if session is None:
            raise HTTPException(404, "Pairing request not found")
        if session["expires_at"] <= datetime.now(timezone.utc):
            raise HTTPException(410, "Pairing code expired")
        result = session_status(session)
        if session["device_id"]:
            device = get_device(cur, session["device_id"], user["id"])
            result["online"] = device is not None and device["status"] == "online"
        return result

    @router.get("/sessions/{session_id}")
    @limiter.limit("120/minute")
    def desktop_status(request: Request, response: Response, session_id: UUID,
                       authorization: str = Header(""), cur=Depends(cursor, scope="function")):
        response.headers["Cache-Control"] = "no-store"
        session, secret = desktop_session(cur, session_id, authorization)
        result = {**session_status(session), "requester": session["requester"]}
        if session["state"] == "approved":
            cur.execute("SELECT token_hash, token_expires_at, status FROM devices WHERE id = %s", (session["device_id"],))
            device = cur.fetchone()
            token = device_token(secret, session["device_id"])
            if (
                not device
                or device["status"] == "revoked"
                or not device["token_expires_at"]
                or device["token_expires_at"] <= datetime.now(timezone.utc)
                or device["token_hash"] != hash_token(token)
            ):
                raise HTTPException(410, "Device credential is no longer available")
            result["device_token"] = token
        return result

    @router.post("/sessions/{session_id}/decision")
    @limiter.limit("20/minute")
    def decide(request: Request, session_id: UUID, payload: Decision,
               authorization: str = Header(""), cur=Depends(cursor, scope="function")):
        session, secret = desktop_session(cur, session_id, authorization, lock=True)
        target = "approved" if payload.approve else "denied"
        if session["state"] == target:
            return session_status(session)
        if session["state"] != "pending":
            raise HTTPException(409, "No pending pairing request")
        device_id = None
        if payload.approve:
            cur.execute(
                """
                INSERT INTO devices (user_id, hostname, os, platform, status)
                VALUES (%s, %s, %s, %s, 'offline') RETURNING id
                """,
                (session["user_id"], session["hostname"], session["os"], session["platform"]),
            )
            device_id = cur.fetchone()["id"]
            create_device_token(cur, device_id, device_token(secret, device_id))
        cur.execute(
            """
            UPDATE desktop_pairing_sessions SET state = %s, device_id = %s
            WHERE id = %s RETURNING *
            """,
            (target, device_id, session_id),
        )
        return session_status(cur.fetchone())

    return router
