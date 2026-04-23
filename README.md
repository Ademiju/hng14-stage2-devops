# hng14-stage2-devops

This repository contains a small job-processing system made up of four services:

- `frontend`: Node.js UI and proxy for job submission and status lookup
- `api`: FastAPI service that creates jobs and exposes job status
- `worker`: Python worker that processes queued jobs
- `redis`: shared queue and job state store

It also includes a GitHub Actions CI/CD pipeline that runs these stages in order:

- `lint`
- `test`
- `build`
- `security scan`
- `integration test`
- `deploy`

## Prerequisites

For local development and Docker runs:

- Docker Engine 24+ or Docker Desktop with Docker Compose v2
- Git
- Python 3.12+

Verify the toolchain:

```powershell
docker --version
docker compose version
git --version
python --version
```

## Local Setup

1. Clone the repository:

```powershell
git clone https://github.com/Ademiju/hng14-stage2-devops
cd hng14-stage2-devops
```

2. Create the runtime env file:

```powershell
Copy-Item .env.example .env
```

3. Install local Python dependencies for API and worker development:

```powershell
python -m pip install --upgrade pip
python -m pip install -r api\requirements-dev.txt
python -m pip install -r worker\requirements-dev.txt
```

4. Update `.env` as needed. At minimum, review:

- `REDIS_PASSWORD`
- `API_HOST_PORT`
- `FRONTEND_HOST_PORT`

## Run The Stack

Start everything:

```powershell
docker compose up --build -d
```

Watch logs:

```powershell
docker compose logs -f
```

Check service state and health:

```powershell
docker compose ps
```

## Expected Result

After startup, `docker compose ps` should show these services running:

- `redis`
- `api`
- `worker`
- `frontend`

The status output should also show health checks passing for all four services.

Default URLs:

- Frontend: `http://localhost:3000`
- API health: `http://localhost:8000/health`

If you changed `FRONTEND_HOST_PORT` or `API_HOST_PORT` in `.env`, use those values instead.

## Smoke Test

Browser flow:

1. Open the frontend.
2. Submit a new job.
3. Confirm the job appears and progresses from `queued` to `processing` to `completed`.

PowerShell flow:

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

## CI/CD

The workflow lives in [.github/workflows/ci-cd.yml](C:\Users\HP\Desktop\HNG\Devops\App\hng14-stage2-devops\.github\workflows\ci-cd.yml).

Key behavior:

- `lint` runs `flake8`, `eslint`, and `hadolint`
- `test` runs API unit tests from `tests/` with mocked Redis and uploads coverage
- `build` builds all three images with layer caching, tags them with `${{ github.sha }}` and `latest`, and pushes them to a local registry service
- `security scan` scans the built images with Trivy and uploads SARIF results
- `integration test` brings the full stack up with Docker Compose in the runner and validates the frontend-driven job flow through `tests/integration.sh`
- `deploy` runs only on pushes to `main` and performs a scripted rolling update with health-check gating and rollback-on-failure behavior

## Notes

- Docker Compose reads `.env`, not `.env.example`
- GitHub Actions does not need a committed `.env`; the workflow generates `.env.ci` during the integration job
- Redis is not exposed on the host in Docker Compose
- Service startup is gated on healthy dependencies, not just container startup
