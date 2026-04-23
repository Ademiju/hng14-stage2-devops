#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.ci"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-job-ci}"

set -a
source "${ENV_FILE}"
set +a

cleanup() {
  docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}" down -v --remove-orphans || true
}

trap cleanup EXIT

docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}" up -d --wait --no-build

for attempt in {1..30}; do
  if docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}" exec -T frontend \
    sh -lc "wget -qO- http://127.0.0.1:${FRONTEND_CONTAINER_PORT}/health >/dev/null"; then
    break
  fi
  sleep 2
done

submit_response="$(
  docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}" exec -T frontend \
    sh -lc "wget -qO- --post-data='' http://127.0.0.1:${FRONTEND_CONTAINER_PORT}/submit"
)"

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
    docker compose --project-name "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}" exec -T frontend \
      sh -lc "wget -qO- http://127.0.0.1:${FRONTEND_CONTAINER_PORT}/status/${job_id}" \
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
