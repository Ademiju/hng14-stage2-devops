#!/usr/bin/env bash

set -euo pipefail

DEPLOY_NETWORK="${DEPLOY_NETWORK:-job-deploy}"
REDIS_CONTAINER="${REDIS_CONTAINER:-deploy-redis}"
REDIS_HEALTH_TIMEOUT="${REDIS_HEALTH_TIMEOUT:-60}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-60}"

wait_for_health() {
  local container_name="$1"
  local timeout="$2"
  local deadline=$((SECONDS + timeout))
  local status=""

  while (( SECONDS < deadline )); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_name}")"
    if [[ "${status}" == "healthy" ]]; then
      return 0
    fi
    if [[ "${status}" == "unhealthy" ]]; then
      return 1
    fi
    sleep 2
  done

  return 1
}

ensure_network() {
  if ! docker network inspect "${DEPLOY_NETWORK}" >/dev/null 2>&1; then
    docker network create "${DEPLOY_NETWORK}" >/dev/null
  fi
}

ensure_redis() {
  if docker container inspect "${REDIS_CONTAINER}" >/dev/null 2>&1; then
    return 0
  fi

  docker run -d \
    --name "${REDIS_CONTAINER}" \
    --network "${DEPLOY_NETWORK}" \
    --health-cmd='redis-cli -a "$REDIS_PASSWORD" ping | grep PONG' \
    --health-interval=5s \
    --health-timeout=3s \
    --health-retries=12 \
    -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
    "${REDIS_IMAGE}" \
    redis-server --appendonly "${REDIS_APPENDONLY}" --requirepass "${REDIS_PASSWORD}" >/dev/null

  wait_for_health "${REDIS_CONTAINER}" "${REDIS_HEALTH_TIMEOUT}"
}

start_current_if_missing() {
  local service="$1"
  local image="$2"

  shift 2

  if docker container inspect "${service}-current" >/dev/null 2>&1; then
    return 0
  fi

  docker run -d --name "${service}-current" "$@" "${image}" >/dev/null
  wait_for_health "${service}-current" "${HEALTH_TIMEOUT_SECONDS}"
}

rolling_update() {
  local service="$1"
  local image="$2"

  shift 2

  local current="${service}-current"
  local candidate="${service}-candidate"

  docker rm -f "${candidate}" >/dev/null 2>&1 || true
  docker run -d --name "${candidate}" "$@" "${image}" >/dev/null

  if ! wait_for_health "${candidate}" "${HEALTH_TIMEOUT_SECONDS}"; then
    docker rm -f "${candidate}" >/dev/null 2>&1 || true
    echo "Candidate for ${service} failed health check within ${HEALTH_TIMEOUT_SECONDS}s" >&2
    return 1
  fi

  docker rm -f "${current}" >/dev/null 2>&1 || true
  docker rename "${candidate}" "${current}"
}

ensure_network
ensure_redis

start_current_if_missing api "${API_IMAGE_LATEST}" \
  --network "${DEPLOY_NETWORK}" \
  --health-cmd='python -c "import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8000/health\")"' \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=12 \
  -e REDIS_HOST="${REDIS_CONTAINER}" \
  -e REDIS_PORT="${API_REDIS_PORT}" \
  -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
  -e JOB_QUEUE="${JOB_QUEUE}"

start_current_if_missing worker "${WORKER_IMAGE_LATEST}" \
  --network "${DEPLOY_NETWORK}" \
  --health-cmd='python -c "import os, redis; client = redis.Redis(host=os.environ[\"REDIS_HOST\"], port=int(os.environ[\"REDIS_PORT\"]), password=os.environ.get(\"REDIS_PASSWORD\") or None, decode_responses=True); raise SystemExit(0 if client.ping() else 1)"' \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=12 \
  -e REDIS_HOST="${REDIS_CONTAINER}" \
  -e REDIS_PORT="${WORKER_REDIS_PORT}" \
  -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
  -e JOB_QUEUE="${JOB_QUEUE}" \
  -e WORKER_POLL_TIMEOUT="${WORKER_POLL_TIMEOUT}" \
  -e JOB_DURATION_SECONDS="${WORKER_JOB_DURATION_SECONDS}"

start_current_if_missing frontend "${FRONTEND_IMAGE_LATEST}" \
  --network "${DEPLOY_NETWORK}" \
  --health-cmd='wget -qO- "http://127.0.0.1:3000/health" >/dev/null || exit 1' \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=12 \
  -e API_URL="http://api-current:8000" \
  -e PORT="${FRONTEND_CONTAINER_PORT}" \
  -e HOST="${FRONTEND_HOST}"

rolling_update api "${API_IMAGE_SHA}" \
  --network "${DEPLOY_NETWORK}" \
  --health-cmd='python -c "import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8000/health\")"' \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=12 \
  -e REDIS_HOST="${REDIS_CONTAINER}" \
  -e REDIS_PORT="${API_REDIS_PORT}" \
  -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
  -e JOB_QUEUE="${JOB_QUEUE}"

rolling_update worker "${WORKER_IMAGE_SHA}" \
  --network "${DEPLOY_NETWORK}" \
  --health-cmd='python -c "import os, redis; client = redis.Redis(host=os.environ[\"REDIS_HOST\"], port=int(os.environ[\"REDIS_PORT\"]), password=os.environ.get(\"REDIS_PASSWORD\") or None, decode_responses=True); raise SystemExit(0 if client.ping() else 1)"' \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=12 \
  -e REDIS_HOST="${REDIS_CONTAINER}" \
  -e REDIS_PORT="${WORKER_REDIS_PORT}" \
  -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
  -e JOB_QUEUE="${JOB_QUEUE}" \
  -e WORKER_POLL_TIMEOUT="${WORKER_POLL_TIMEOUT}" \
  -e JOB_DURATION_SECONDS="${WORKER_JOB_DURATION_SECONDS}"

rolling_update frontend "${FRONTEND_IMAGE_SHA}" \
  --network "${DEPLOY_NETWORK}" \
  --health-cmd='wget -qO- "http://127.0.0.1:3000/health" >/dev/null || exit 1' \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=12 \
  -e API_URL="http://api-current:8000" \
  -e PORT="${FRONTEND_CONTAINER_PORT}" \
  -e HOST="${FRONTEND_HOST}"

echo "Rolling update completed successfully"
