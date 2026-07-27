def user_exists(cur,email: str) -> bool:
    cur.execute("SELECT 1 FROM users WHERE email = %s", (email,))
    return cur.fetchone() is not None

def create_user(cur,username: str,email: str,hashed_password: str) -> None:
    cur.execute("INSERT INTO users (username, email, hashed_password) VALUES (%s, %s, %s)",(username, email, hashed_password))

def get_user_by_email(cur,email: str) -> dict | None:
    cur.execute("SELECT id, username, email, hashed_password FROM users WHERE email = %s",(email,))
    return cur.fetchone()

def get_user_by_id(cur,user_id: str) -> dict | None:
    cur.execute("SELECT id, username, email, hashed_password FROM users WHERE id = %s",(user_id,))
    return cur.fetchone()