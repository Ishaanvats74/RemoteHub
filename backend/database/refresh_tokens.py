from .utils import hash_token

def insert_refresh_token(cur, user_id, expires_at, refresh_token):
    token_hash = hash_token(refresh_token)
    cur.execute(
        "INSERT INTO refresh_tokens (user_id, token_hash, revoked, expires_at) VALUES (%s, %s, %s, %s)",
        (user_id, token_hash, False, expires_at)
    )

def get_refresh_token_record(cur, refresh_token):
    token_hash = hash_token(refresh_token)
    cur.execute("SELECT * FROM refresh_tokens WHERE token_hash = %s", (token_hash,))
    return cur.fetchone()

def revoke_refresh_token(cur, refresh_token):
    token_hash = hash_token(refresh_token)
    cur.execute("UPDATE refresh_tokens SET revoked = true WHERE token_hash = %s", (token_hash,))

def revoke_all_refresh_tokens_for_user(cur, user_id):
    cur.execute("UPDATE refresh_tokens SET revoked = true WHERE user_id = %s", (user_id,))