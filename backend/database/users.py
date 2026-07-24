def user_exists(cur, email) -> bool:
    cur.execute("SELECT 1 FROM users WHERE email = %s", (email,))
    return cur.fetchone() is not None

def create_user(cur, username, email, hashed_password):
    cur.execute("INSERT INTO users (username, email, hashed_password) VALUES (%s, %s, %s)",(username, email, hashed_password))

def get_user_by_email(cur, email):
    cur.execute("SELECT id, username, email, hashed_password FROM users WHERE email = %s",(email,))
    return cur.fetchone()