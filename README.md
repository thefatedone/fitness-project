# NutriMind — OrbStack Setup

Local development stack for the NutriMind monorepo (FastAPI backend + Next.js
frontend) on macOS using [OrbStack](https://orbstack.dev).

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| macOS | 12+ | Apple Silicon or Intel |
| OrbStack | 1.5+ | Install from <https://orbstack.dev/download> |
| Docker Compose | bundled | Comes with OrbStack (`docker compose version`) |
| Make | any | For `make` shortcuts (optional — see `make help`) |

Verify your environment:

```bash
docker --version
docker compose version
```

OrbStack registers itself as the default Docker CLI context, so plain `docker`
and `docker compose` commands work as if Docker Desktop were installed.

## First-time setup

1. **Clone or open this folder** in your terminal:

   ```bash
   cd /path/to/fitness-project
   ```

2. **Create your local env file** from the template:

   ```bash
   cp .env.example .env
   ```

   Then edit `.env` and replace the placeholder API keys (`ANTHROPIC_API_KEY`,
   `GOOGLE_GEMINI_API_KEY`, `JWT_SECRET`, etc.). The defaults work for local
   development without external services, but AI routes and the Telegram bot
   need real keys to do anything useful.

3. **Start the stack**:

   ```bash
   make up
   # or, without make:
   docker compose up -d --build
   ```

   First run takes a few minutes because Docker has to pull base images
   (`postgres:16-alpine`, `redis:7-alpine`, `python:3.12-slim`, `node:20-alpine`)
   and build the backend + frontend images.

4. **Open the apps**:

   | URL | Service |
   |---|---|
   | <http://localhost:3000> | Next.js frontend |
   | <http://localhost:8000/api/docs> | FastAPI Swagger UI |
   | <http://localhost:8000/health> | Backend health check |
   | <http://localhost:8025> | MailHog (catches outgoing email) |
   | `localhost:5432` | Postgres (user `nutrimind`, password `secret`) |
   | `localhost:6379` | Redis |

## Architecture

```
┌──────────────────────── OrbStack VM ─────────────────────────┐
│                                                              │
│   postgres ◄───── backend ─────► mailhog                     │
│      ▲            (FastAPI)                                  │
│      │             ▲                                         │
│      │             │                                         │
│      └─── redis ◄──┴── telegram-bot  (profile: telegram)    │
│                                                              │
│   frontend (Next.js) ────► backend :8000                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
            ▲                              ▲
       host ports                      host ports
    5432, 6379, 8000, 3000, 1025, 8025
```

- Browser → backend uses `http://localhost:8000` (set in `NEXT_PUBLIC_API_URL`)
- Backend → postgres/redis uses compose DNS names (`postgres`, `redis`)
- Backend → mailhog uses compose DNS name (`mailhog`)

## Common commands

Run `make help` to see every target. The most useful ones:

```bash
make up              # build + start in background
make down            # stop, keep volumes
make logs            # tail all logs
make logs-backend    # tail backend logs only
make ps              # show container status
make shell-backend   # bash into the backend container
make shell-db        # psql into postgres
make shell-redis     # redis-cli into redis
make rebuild         # rebuild all images with --no-cache
make rebuild-backend # rebuild only backend
make clean           # STOP and DELETE volumes (wipes DB + uploads!)
make nuke            # clean + prune images and build cache
```

Without `make`:

```bash
docker compose up -d --build
docker compose down
docker compose logs -f
docker compose exec backend bash
docker compose exec postgres psql -U nutrimind -d nutrimind
docker compose exec redis redis-cli
```

## Optional services

The Telegram bot is gated behind a Compose profile so it doesn't try to
connect with empty credentials:

```bash
make up-telegram
# or: docker compose --profile telegram up -d
```

To enable it, set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_OWNER_CHAT_ID` in `.env`.

## Persistent data

| Volume | Contents |
|---|---|
| `nutrimind_postgres_data` | Postgres database files |
| `nutrimind_redis_data` | Redis AOF dump |
| `nutrimind_backend_uploads` | User-uploaded food photos (mounted at `/uploads` in the backend) |

Volumes survive `docker compose down` but are removed by `make clean`.

## Troubleshooting

**"Cannot connect to the Docker daemon"**
OrbStack isn't running. Open the OrbStack app (menu bar icon → Start) and try again.

**Backend exits immediately with `DATABASE_URL` errors**
Make sure you ran `cp .env.example .env` and that `.env` is at the project
root, not in `backend/`.

**Frontend shows network errors / 504s**
The backend hasn't finished starting. Check `docker compose ps` — wait until
`backend` shows `healthy`. The frontend depends on `backend`'s healthcheck.

**Mail isn't sending**
Outbound email goes to MailHog, not your real inbox. Open
<http://localhost:8025> to inspect messages. To use a real SMTP server, set
`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, and `SMTP_TLS` in
`.env` and override the backend's `SMTP_HOST` env block in `docker-compose.yml`.

**Port already in use**
Edit the `*_PORT` variables in `.env` (e.g. `BACKEND_PORT=8001`) and re-run
`make up`. The compose file maps `${BACKEND_PORT:-8000}:8000` so host ports
are configurable per environment.

**Frontend can't reach backend in the browser**
This almost always means `NEXT_PUBLIC_API_URL` is wrong. The browser runs on
your Mac, not in OrbStack, so it can only use `localhost:<host_port>` — not
compose DNS names. The default `http://localhost:8000` is correct for OrbStack.

**Rebuild after dependency changes**
```bash
make rebuild-backend   # requirements.txt changed
make rebuild-frontend  # package.json changed
```

**Reset everything to a clean state**
```bash
make nuke
```

## File layout

```
fitness-project/
├── docker-compose.yml      ← root-level orchestration (this setup)
├── .env                    ← local secrets (git-ignored)
├── .env.example            ← template, safe to commit
├── Makefile                ← convenience commands
├── README.md               ← you are here
├── backend/
│   ├── Dockerfile          ← FastAPI image
│   ├── telegram.Dockerfile ← Telegram bot image
│   ├── .dockerignore
│   ├── app/                ← FastAPI source
│   ├── alembic/            ← DB migrations
│   └── requirements.txt
└── nutrimind/
    ├── Dockerfile          ← Next.js image
    ├── .dockerignore
    └── src/                ← Next.js source
```

The pre-existing `nutrimind/docker-compose.yml` is left in place for
reference; the root-level `docker-compose.yml` is the one this README
documents.