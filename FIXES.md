# FIXES

| File | Line(s) | Problem | Change |
| --- | --- | --- | --- |
| `api/main.py` | 10-20 | Redis was hardcoded to `localhost:6379` with no password support, which works on a developer machine but fails when Redis runs in a separate container. | Replaced the hardcoded client with env-driven Redis settings (`REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`) and enabled `decode_responses=True`. |
| `api/main.py` | 25 | The queue name was hardcoded as `job`, making the queue contract brittle and inconsistent across services. | Switched the API to use an env-driven `JOB_QUEUE` value shared with the worker. |
| `api/main.py` | 27-30 | Job creation returned HTTP 200 and omitted the initial status, which is a poor API contract for resource creation. | Changed the endpoint to return HTTP 201 with both `job_id` and the initial `queued` status. |
| `api/main.py` | 34-37 | Missing jobs returned a JSON error body with HTTP 200 instead of a real 404. | Raised `HTTPException(status_code=404)` for unknown jobs. |
| `api/main.py` | 40-43 | The API had no health endpoint for container orchestration or smoke checks. | Added `/health` that pings Redis and returns `{"status": "ok"}`. |
| `worker/worker.py` | 7-19 | The worker also hardcoded Redis to `localhost` and ignored password/auth config, so it would break in containers. | Replaced the Redis client with the same env-driven config used by the API and enabled decoded responses. |
| `worker/worker.py` | 27-32 | Jobs went straight from `queued` to `completed`, so the status API could not show in-flight work. | Added an intermediate `processing` status before simulated job execution. |
| `worker/worker.py` | 34-45 | The worker had an endless loop with no signal handling, which makes controlled shutdowns unreliable in containers. | Added `SIGINT`/`SIGTERM` handlers and a clean shutdown path. |
| `worker/worker.py` | 10-12, 38 | The queue name and poll timing were hardcoded, making runtime tuning impossible. | Added `JOB_QUEUE`, `WORKER_POLL_TIMEOUT`, and `JOB_DURATION_SECONDS` environment controls. |
| `frontend/app.js` | 6-8 | The frontend was hardcoded to call `http://localhost:8000`, which fails when the frontend runs inside a container. | Made the API target, bind host, and bind port configurable with `API_URL`, `HOST`, and `PORT`. |
| `frontend/app.js` | 18-43 | Both proxy routes collapsed all upstream failures into a generic HTTP 500, hiding real API errors like 404 and making troubleshooting harder. | Preserved upstream status/data when available and returned 502 only when the API is unreachable. |
| `frontend/app.js` | 20, 34 | Axios calls had no timeout, so the frontend could hang indefinitely on a dead API. | Added 5-second request timeouts to both API calls. |
| `frontend/app.js` | 46-51 | The frontend service had no health endpoint. | Added `/health` for simple service checks. |
| `frontend/app.js` | 14-16 | There was no explicit root route, leaving index serving implicit through static middleware. | Added `/` to serve `views/index.html` directly. |
| `frontend/views/index.html` | 21-37 | Submitting a job assumed success and would break the UI if the backend returned an error payload. | Added client-side error handling for job submission and surfaced the backend error message in the page. |
| `frontend/views/index.html` | 40-55 | Polling assumed every response was valid JSON with a `status`, so failures produced misleading rendering and endless retries. | Added polling error handling and stopped retries once a terminal state is reached. |
| `frontend/views/index.html` | 67 | The rendered job row contained a mojibake dash (`â€”`), which is a visible encoding bug in the UI. | Replaced it with a safe ASCII separator. |
| `frontend/views/index.html` | 21 | `jobIds` was collected but never used. | Removed the dead client-side array. |
| `api/.env` | 1-2 | A real-looking Redis password was committed to the repository, which is a secret-handling failure. | Removed the tracked `.env`, added `api/.env.example`, and introduced ignore rules for `.env` files. |
| `.env.example` | 1 | The repository had no root env template for Compose. | Added a root `.env.example` containing the required `REDIS_PASSWORD` variable. |
| `.gitignore` | 1-11 | Env files, Python bytecode, and `node_modules` were not ignored, increasing the risk of leaking local config and shipping build junk. | Added ignore rules for env files, Python cache files, coverage output, and `node_modules`, while keeping `*.env.example` trackable. |
| `api/Dockerfile` | 1-15 | The API had no container build definition, so it could not be built or run consistently in production. | Added a Python image build that installs requirements and runs Uvicorn on `0.0.0.0:8000`. |
| `worker/Dockerfile` | 1-13 | The worker had no container build definition. | Added a Python image build that installs requirements and starts `worker.py`. |
| `frontend/Dockerfile` | 1-12 | The frontend had no container build definition. | Added a Node image build that installs dependencies and runs `npm start`. |
| `api/.dockerignore` | 1-6 | The API build context had no exclusions, so local virtualenv and env files could be copied into images. | Added a `.dockerignore` for caches, virtualenvs, and `.env`. |
| `api/__init__.py` | 1 | The API package relied on implicit import behavior, which is more fragile in test and CI environments. | Added an explicit package marker so test imports like `from api import main` resolve consistently. |
| `api/requirements-dev.txt` | 1-5 | Local development and CI test tooling dependencies were not grouped anywhere, leading to `No module named ...` errors for FastAPI-related work and test commands in a fresh environment. | Added a dev requirements file that installs the API runtime dependencies plus `pytest`, `pytest-cov`, `httpx`, and `flake8` in one step. |
| `worker/requirements-dev.txt` | 1-2 | The worker had no equivalent local dev dependency entry point, so a fresh environment could still hit `No module named redis` when working on the worker service. | Added a worker dev requirements file that installs the worker runtime dependencies plus `flake8` in one step. |
| `worker/.dockerignore` | 1-6 | The worker build context had the same leakage risk. | Added a matching `.dockerignore`. |
| `frontend/.dockerignore` | 1-3 | The frontend build context could include `node_modules` and local env files. | Added a `.dockerignore` to keep the image build clean. |
| `docker-compose.yml` | 1-57 | The repo had no orchestration config tying the frontend, API, worker, and Redis together. | Added a Compose stack that builds all three services, wires service discovery correctly, exposes the frontend/API, and injects the shared Redis settings. |
| `docker-compose.yml` | 5-12, 56-57 | Redis persistence was enabled without a mounted volume, so data would still be lost when the container was recreated. | Added a named `redis-data` volume mounted at `/data`. |
| `docker-compose.yml` | 4, 17, 32, 45 | Services had no restart policy, reducing resilience after failures or host restarts. | Added `restart: unless-stopped` to Redis, API, worker, and frontend. |
| `docker-compose.yml` | 8-12, 23-25, 38-40 | Startup ordering was not defined, which would cause race conditions between Redis, API, and worker. | Added Redis health checks and `depends_on` conditions so the API and worker wait for Redis readiness. |
| `README.md` | 3-128 | The README gave no usable instructions for bringing the system up or preparing a clean local Python environment. | Added Compose-based run instructions, success criteria, and the explicit `pip install -r api\requirements-dev.txt` and `pip install -r worker\requirements-dev.txt` steps for local Python dependencies. |
