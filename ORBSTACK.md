# NutriMind — OrbStack Setup

Local development stack for the NutriMind monorepo (FastAPI backend + Next.js
frontend) on macOS using [OrbStack](https://orbstack.dev).

The whole stack runs through one `docker-compose.yml` at the repo root, with
**profiles** so you only run what you actually need.

## Profiles at a glance

| Profile | Services | When to use it |
|---|---|---|
| _(default)_ | postgres, redis, backend, frontend, mailhog | Everyday dev — `make up` |
| `telegram` | telegram-bot | When you want to test the Telegram integration |
| `elk` | elasticsearch, kibana, logstash, filebeat, metricbeat, apm-server | When you want full observability (logs, host metrics, APM traces) |

Combine: `--profile telegram --profile elk` runs everything.

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| macOS | 12+ | Apple Silicon or Intel |
| OrbStack | 1.5+ | <https://orbstack.dev/download> |
| Docker Compose | bundled | Comes with OrbStack (`docker compose version`) |
| Make | any | For `make` shortcuts (optional) |

Verify your environment:

```bash
docker --version
docker compose version
```

OrbStack registers itself as the default Docker CLI context, so plain `docker`
and `docker compose` commands work as if Docker Desktop were installed.

## First-time setup

1. **Open this folder** in your terminal:

   ```bash
   cd /Users/alexanderpepanian/AlexanderApps/fitness-project
   ```

2. **Create your local env file**:

   ```bash
   cp .env.example .env
   ```

   Then edit `.env` and replace the placeholder API keys (`ANTHROPIC_API_KEY`,
   `GOOGLE_GEMINI_API_KEY`, `JWT_SECRET`, …). Defaults work for local dev but
   AI routes and the Telegram bot need real keys to be useful.

3. **Start the core stack**:

   ```bash
   make up
   # or, without make:
   docker compose up -d --build
   ```

   First run takes a few minutes — Docker pulls base images and builds the
   backend + frontend.

4. **Open the apps**:

   | URL | Service |
   |---|---|
   | <http://localhost:3000> | Next.js frontend |
   | <http://localhost:8000/api/docs> | FastAPI Swagger UI |
   | <http://localhost:8000/health> | Backend health check |
   | <http://localhost:8025> | MailHog (catches outgoing email) |
   | `localhost:5432` | Postgres (`nutrimind` / `secret`) |
   | `localhost:6379` | Redis |

5. **Add profiles later as needed**:

   ```bash
   make up-telegram   # adds the telegram bot
   make up-elk        # adds Elasticsearch, Kibana, Logstash, Beats, APM
   make up-full       # everything (heavy on RAM)
   ```

## Architecture

```
┌──────────────────────────── OrbStack VM ────────────────────────────┐
│                                                                   │
│   postgres ◄───── backend ─────► mailhog                           │
│      ▲            (FastAPI)                                       │
│      │             ▲                                              │
│      │             │                                              │
│      └─── redis ◄──┴── telegram-bot   (profile: telegram)         │
│                                                                   │
│   frontend (Next.js) ────► backend :8000                          │
│                                                                   │
│   ┌── profile: elk ──────────────────────────────────────────┐    │
│   │  filebeat ──► logstash ──► elasticsearch ◄── kibana      │    │
│   │  metricbeat ──────────────► elasticsearch                │    │
│   │  apm-server ──────────────► elasticsearch ◄── backend    │    │
│   └──────────────────────────────────────────────────────────┘    │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
            ▲                                ▲
       host ports                         host ports
    5432, 6379, 8000, 3000, 1025, 8025
    9200, 5601, 5044, 8200   (profile: elk)
```

- Browser → backend uses `http://localhost:8000` (set via `NEXT_PUBLIC_API_URL`)
- Backend → postgres / redis / mailhog uses compose DNS names
- Backend → apm-server uses compose DNS name `apm-server` (port 8200)

## Common commands

```bash
make help            # show every target
make up              # core stack
make up-telegram     # + telegram-bot
make up-elk          # + ELK stack
make up-full         # everything
make down            # stop everything (keeps volumes)
make stop            # stop containers without removing them
make ps              # show running services (all profiles)
make logs            # tail logs for all running services
make logs-backend    # tail backend only
make shell-backend   # bash into backend
make shell-db        # psql into postgres
make shell-redis     # redis-cli into redis
make rebuild         # rebuild all images with --no-cache
make rebuild-backend # rebuild only backend
make clean           # stop and DELETE volumes (wipes DB!)
make nuke            # clean + prune images and build cache
make profiles-list   # show which services are in which profile
```

Without `make`:

```bash
docker compose up -d --build
docker compose --profile telegram --profile elk up -d
docker compose down
docker compose exec backend bash
docker compose exec postgres psql -U nutrimind -d nutrimind
docker compose exec redis redis-cli
```

## Switching profiles on/off

You can add or remove profile services without restarting the core stack:

```bash
# core is up; add telegram bot
docker compose --profile telegram up -d telegram-bot

# add the ELK stack
docker compose --profile elk up -d

# stop just the ELK services, keep core running
docker compose --profile elk stop elasticsearch kibana logstash filebeat metricbeat apm-server

# stop just the telegram bot
docker compose stop telegram-bot
```

## Persistent data

| Volume | Contents |
|---|---|
| `nutrimind_postgres_data` | Postgres database files |
| `nutrimind_redis_data` | Redis AOF dump |
| `nutrimind_backend_uploads` | User-uploaded food photos (mounted at `/uploads`) |
| `nutrimind_elasticsearch_data` | Elasticsearch indices (profile: `elk`) |

Volumes survive `docker compose down` but are removed by `make clean`.

## Enabling APM in the backend

When you start the `elk` profile, `apm-server` becomes reachable at
`http://apm-server:8200` from inside the compose network. To have the backend
ship traces to it:

1. Edit `.env` and set:

   ```env
   ELASTIC_APM_ENABLED=true
   ELASTIC_APM_SERVER_URL=http://apm-server:8200
   ```

2. Rebuild and restart the backend:

   ```bash
   make rebuild-backend
   make up
   ```

3. Open <http://localhost:5601> → APM → Services to inspect traces.

## Troubleshooting

**"Cannot connect to the Docker daemon"**
OrbStack isn't running. Open the OrbStack app (menu bar → Start) and retry.

**Backend exits immediately with `DATABASE_URL` errors**
Make sure `.env` exists at the project root (not just `.env.example`). The
compose file reads `env_file: .env` from the same directory as
`docker-compose.yml`.

**Frontend shows network errors / 504s**
The backend hasn't finished initializing. Check `make ps` — wait until
`backend` shows `healthy` (usually 30–60 s on first run).

**Mail isn't sending**
Outbound email goes to MailHog, not your real inbox. Open
<http://localhost:8025> to inspect messages. To use real SMTP, set
`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_TLS` in `.env`
and override the `SMTP_HOST` env block in `docker-compose.yml`.

**Port already in use**
Edit `*_PORT` in `.env` (e.g. `BACKEND_PORT=8001`) and `make up`. The compose
file maps `${BACKEND_PORT:-8000}:8000`, so host ports are per-environment.

**Frontend can't reach backend in the browser**
`NEXT_PUBLIC_API_URL` must be a host-reachable URL (`http://localhost:8000`),
not a compose DNS name. The browser runs on your Mac, not in OrbStack, so it
can only see host-mapped ports.

**ELK containers won't start / OOM killed**
Elasticsearch is memory-hungry. Bump `ES_HEAP` in `.env` (e.g. `ES_HEAP=1g`)
and ensure Docker Desktop / OrbStack has at least 4 GB allocated.

**OrbStack shows the wrong project**
If you have multiple Docker Compose projects with overlapping service names,
use `docker compose -p nutrimind ...` to disambiguate.

**Reset everything**
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
├── README.md               ← project overview (built-in)
├── ORBSTACK.md             ← this file
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
    ├── infrastructure/     ← ELK pipeline configs (filebeat, metricbeat, logstash, apm)
    ├── logs/               ← backend log dir shared with filebeat
    └── src/                ← Next.js source
```

The pre-existing `nutrimind/docker-compose.yml` is left in place for
reference; the root-level `docker-compose.yml` is the one this guide
documents.