# RemoteHub

RemoteHub is a remote device management application that lets you
monitor and control your computer from an Android phone. It connects an
Android app to a desktop agent through a FastAPI backend.

## Features

-   Monitor live system information such as CPU, RAM, battery, and
    temperature where supported.
-   View paired devices and their connection status.
-   Lock a connected computer remotely.
-   Shut down a connected computer remotely.
-   Pair a computer with a temporary pairing code.
-   Use WebSockets for live telemetry and remote-command communication.
-   **Planned:** restart and sleep commands, notifications, and
    Bluetooth fallback for nearby control when Wi-Fi or internet is
    unavailable.

> Current project notes confirm that ping, lock, and shutdown commands
> are implemented. Restart, sleep, and Bluetooth fallback are planned,
> not yet confirmed as working.

## Tech Stack

-   **Android:** Kotlin, XML layouts
-   **Backend:** Python, FastAPI
-   **Database:** PostgreSQL
-   **Desktop Agent:** Python, PySide6
-   **Networking:** REST APIs and WebSockets
-   **ORM / Migrations:** SQLAlchemy 2.x and Alembic

## Architecture

``` text
Android App
   | REST API / WebSocket
   v
FastAPI Backend <----> PostgreSQL
   ^
   | WebSocket
Desktop Agent (Python / PySide6)
   |
Computer operating system
```

The backend authenticates users, stores device records, and routes
telemetry and commands between the Android app and the paired desktop
agent. The mobile app does not connect directly to the desktop over the
internet.

## API Endpoints

The following endpoints are documented in the project notes. Confirm
exact paths and schemas in the running FastAPI `/docs` page, as
implementation may differ.

  -------------------------------------------------------------------------
  Method                  Endpoint                  Purpose
  ----------------------- ------------------------- -----------------------
  `POST`                  `/auth/register`          Create an account

  `POST`                  `/auth/login`             Sign in and receive
                                                    tokens

  `POST`                  `/auth/refresh`           Refresh an access token

  `POST`                  `/auth/logout`            Revoke a refresh token
                                                    / log out

  `GET`                   `/users/me`               Get the authenticated
                                                    user's profile

  `GET`                   `/health`                 Check backend health

  `GET` or `POST`\*       `/devices/pairing-code`   Generate a temporary
                                                    pairing code

  `POST`                  `/devices/pair`           Pair a desktop agent

  `GET`\*                 `/devices`                List the user's devices

  WebSocket               `/ws/device`              Desktop agent
                                                    connection for
                                                    telemetry and commands

  WebSocket               `/ws/mobile`              Mobile connection for
                                                    telemetry and command
                                                    requests
  -------------------------------------------------------------------------

\*The project notes recommend `POST /devices/pairing-code`; an earlier
implementation may use a different method/path. `GET /devices` is part
of the documented mobile workflow, but verify it exists in the current
code.

### WebSocket Message Flow

-   **Desktop → Backend:** authentication, hardware information, live
    telemetry, command results, heartbeats.
-   **Backend → Desktop:** authorized remote commands.
-   **Mobile → Backend:** authentication and command requests.
-   **Backend → Mobile:** live telemetry, device status, and command
    responses.

A documented command message has this general shape:

``` json
{
  "type": "command",
  "device_id": "<device-id>",
  "command": "lock"
}
```

Supported command names and the complete message schemas should be
checked in the desktop executor and backend WebSocket handlers.

## Database Schema

The project notes identify four main PostgreSQL tables. The fields below
summarize the documented design; they are **not a verified dump of the
current database migrations**.

### `users`

  Column            Purpose
  ----------------- ----------------------------------
  `id`              Primary key
  `email`           User email; should be unique
  `password_hash`   Hashed password, never plaintext
  `is_verified`     Email/account verification state
  `created_at`      Creation timestamp
  `updated_at`      Last update timestamp

### `refresh_tokens`

  Column         Purpose
  -------------- ------------------------------------
  `id`           Primary key
  `user_id`      Foreign key to `users.id`
  `token_hash`   Hashed refresh token
  `expires_at`   Token expiration time
  `revoked`      Whether the token has been revoked
  `created_at`   Creation timestamp

### `devices`

  Column         Purpose
  -------------- -------------------------------------------------
  `id`           Device identifier / primary key
  `user_id`      Foreign key to the owning user
  `hostname`     Computer name
  `platform`     Platform information
  `status`       Connection state, such as `online` or `offline`
  `last_seen`    Last heartbeat/connection timestamp
  `created_at`   Registration timestamp

Device-token hashes and additional OS/version metadata may also be
present depending on the current implementation.

### `pairing_codes`

  Column         Purpose
  -------------- --------------------------------------------
  `id`           Primary key
  `user_id`      Foreign key to the user requesting pairing
  `code`         Temporary pairing code (store securely)
  `expires_at`   Expiration time
  `is_used`      Prevents reuse after successful pairing
  `created_at`   Creation timestamp

Pairing codes should expire quickly and be invalidated after use. Device
tokens should be stored securely by the desktop agent, and only their
hashes should be stored server-side.

## Getting Started

1.  Clone the repository.
2.  Configure the backend environment variables.
3.  Start the backend and PostgreSQL using the project's local
    development setup.
4.  Open the Android project in Android Studio.
5.  Set the correct backend URL for your emulator or physical phone.
6.  Run the desktop agent and pair it using a pairing code.

For an Android Emulator, `10.0.2.2` usually points to the development
host. For a physical phone, use the host computer's LAN IP and ensure
both devices can reach the backend. Use HTTPS/WSS in production.

Check the project's configuration files and FastAPI `/docs` for exact
run commands, environment variables, and current API contracts.
