# hng14-stage2-devops

This repository runs a four-service job processing stack:

- `frontend`: Node.js UI for submitting and tracking jobs
- `api`: FastAPI service for job creation and status lookup
- `worker`: Python worker that consumes queued jobs
- `redis`: shared queue and job-status store

## Prerequisites

Install these on a clean machine before running anything:

- Docker Engine 24+ or Docker Desktop with Docker Compose v2
- Git

Verify the tools are available:

```powershell
docker --version
docker compose version
git --version
python --version
```

## First-Time Setup

1. Clone the repository:

```powershell
git clone <your-repo-url>
cd hng14-stage2-devops
```

2. Create the runtime environment file from the template:

```powershell
Copy-Item .env.example .env
```

3. Install Python dependencies for local API development and tests:

```powershell
python -m pip install --upgrade pip
python -m pip install -r api\requirements-dev.txt
python -m pip install -r worker\requirements-dev.txt
```

4. Edit `.env` and set at minimum:

- `REDIS_PASSWORD` to a real password
- `API_HOST_PORT` if `8000` is already in use
- `FRONTEND_HOST_PORT` if `3000` is already in use

## Bring The Full Stack Up

Build and start everything:

```powershell
docker compose up --build -d
```

Follow startup logs:

```powershell
docker compose logs -f
```

Check container health and state:

```powershell
docker compose ps
```

## What Successful Startup Looks Like

`docker compose ps` should show these services in `running` state:

- `redis`
- `api`
- `worker`
- `frontend`

The `STATUS` column should include healthy checks for:

- `redis`
- `api`
- `worker`
- `frontend`

Expected endpoints after startup:

- By default, frontend: `http://localhost:3000`
- By default, API health: `http://localhost:8000/health`

If you changed `FRONTEND_HOST_PORT` or `API_HOST_PORT` in `.env`, use those values instead.

Manual smoke test:

1. Open the frontend in a browser.
2. Click `Submit New Job`.
3. A job id should appear.
4. The job status should progress from `queued` to `processing` to `completed`.

API smoke test from the terminal:

```powershell
$job = Invoke-RestMethod -Method Post -Uri http://localhost:3000/submit
$job
Invoke-RestMethod -Uri "http://localhost:3000/status/$($job.job_id)"
```

## Useful Commands

Stop the stack:

```powershell
docker compose down
```

Stop the stack and remove Redis data:

```powershell
docker compose down -v
```

Rebuild after code changes:

```powershell
docker compose up --build -d
```

## Notes

- All service wiring, ports, resource limits, healthcheck timing, and image/build settings come from `.env`.
- Redis is not published to the host; it is only reachable on the internal Docker network.
- Service startup is gated on healthy dependencies, not just container creation.
