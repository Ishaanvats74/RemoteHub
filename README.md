# RemoteHub setup

Run the backend and Redis on the same machine. Neon hosts the persistent database over the internet. Redis runs locally and holds short-lived telemetry and rate limits.

## 1. Initialize Neon

1. Create a Neon project or choose an existing project and database.
2. Open the Neon SQL Editor on that database. Run [000_base.sql](backend/migrations/000_base.sql), then [001_desktop_pairing.sql](backend/migrations/001_desktop_pairing.sql). Together they create all five tables and their indexes. For an existing RemoteHub database already on Neon, apply the pairing migration if it has not been applied.
3. In the Neon dashboard, open **Connect** and copy the **pooled** connection string for the same database. Keep the TLS parameters from Neon.

To carry over accounts and paired devices from a local database, import its schema and data into Neon before pointing the backend at it. For a local source, use a PostgreSQL dump and restore with Neon's direct connection string, then apply any missing RemoteHub migrations.

See the [Neon SQL Editor guide](https://neon.com/docs/get-started/query-with-neon-sql-editor) and [Neon connection pooling guide](https://neon.com/docs/connect/connection-pooling).

## 2. Start local Redis

Start Docker Desktop, then run these commands from the project root:

```powershell
docker compose up -d redis
docker compose exec redis redis-cli ping
```

The check should print `PONG`. [compose.yaml](compose.yaml) publishes Redis on the backend machine's loopback interface. Redis needs no SQL schema or seed data. The [Python Redis client](backend/cache/redis_client.py) writes telemetry keys with a two-minute expiry, and the backend rate limiter creates its own keys. This Redis service is ephemeral. Restarting it clears the cache and rate-limit counters.

## 3. Configure and start the backend

Install [the backend requirements](backend/requirements.txt) and create `backend/.env` using [the example](backend/.env.example). Set these values:

```dotenv
DATABASE_URL=postgresql://ROLE:PASSWORD@YOUR-POOLED-NEON-HOST/DATABASE?sslmode=require&channel_binding=require
REDIS_URL=redis://127.0.0.1:6379/0
SECRET_KEY=replace-with-a-random-secret
ALGORITHM=HS256
```

Paste the connection string supplied by Neon in place of the sample. Generate the signing secret with `python -c "import secrets; print(secrets.token_hex(32))"`. Keep both credentials in `backend/.env`.

```powershell
Set-Location backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
```

Open `http://127.0.0.1:8000/ready` on the backend machine. It returns `{"status":"ready"}` once the database migration and configured Redis are reachable. Use one worker because live WebSocket routing stays in that process. For public deployment, use an HTTPS reverse proxy with WebSocket support and configure trusted forwarded headers.

## 4. Connect the laptop and phone

Launch the laptop agent with `python desktop_agent/main.py` from the project root. Set `REMOTEHUB_SERVER_URL` before launching if the backend runs on a different machine. In the phone app, set the backend address in **Settings**. On a physical phone, use the backend machine's LAN address or HTTPS hostname.

Sign in on the phone, open **Pair a laptop**, and enter the laptop's six-digit code. Select **Approve** on the laptop after checking the requesting account. Both apps update automatically when the laptop connects.

### Flutter web on the backend machine

Set `CORS_ORIGINS=http://localhost:63484,http://127.0.0.1:63484` in `backend/.env` and restart the backend. From `mobile_app`, run:

```powershell
flutter run -d chrome --web-port 63484
```

The port in the Flutter browser address must match an allowed origin. Set the app's backend URL to `http://127.0.0.1:8000` when both run on the same machine.
