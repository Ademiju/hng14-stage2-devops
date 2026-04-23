#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.ci"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-job-ci}"

cleanup() {
  docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}" down -v --remove-orphans || true
}

trap cleanup EXIT

docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}" up -d --wait --no-build

frontend_url="http://127.0.0.1:${FRONTEND_HOST_PORT}"

for attempt in {1..30}; do
  if curl -fsS "${frontend_url}/health" >/dev/null; then
    break
  fi
  sleep 2
done

submit_response="$(curl -fsS -X POST "${frontend_url}/submit")"

if [[ -z "${submit_response}" ]]; then
  echo "Frontend submit endpoint returned an empty response" >&2
  exit 1
fi

job_id="$(
  printf '%s' "${submit_response}" \
    | python -c "import json,sys; print(json.load(sys.stdin)['job_id'])"
)"

if [[ -z "${job_id}" ]]; then
  echo "Failed to retrieve job id from frontend submit response" >&2
  exit 1
fi

deadline=$((SECONDS + 60))
final_status=""

while (( SECONDS < deadline )); do
  final_status="$(
    curl -fsS "${frontend_url}/status/${job_id}" \
      | python -c "import json,sys; print(json.load(sys.stdin).get('status', ''))"
  )"

  if [[ "${final_status}" == "completed" ]]; then
    break
  fi

  sleep 2
done

if [[ "${final_status}" != "completed" ]]; then
  echo "Expected completed status for job ${job_id}, got '${final_status}'" >&2
  exit 1
fi

echo "Integration test passed for job ${job_id}"
