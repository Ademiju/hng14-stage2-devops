from pathlib import Path
import sys
from unittest.mock import Mock

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from api import main


client = TestClient(main.app)


def test_create_job_queues_and_persists_status(monkeypatch):
    redis_mock = Mock()
    monkeypatch.setattr(main, "r", redis_mock)

    response = client.post("/jobs")

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "queued"
    assert body["job_id"]
    redis_mock.lpush.assert_called_once_with(main.JOB_QUEUE, body["job_id"])
    redis_mock.hset.assert_called_once_with(f"job:{body['job_id']}", "status", "queued")


def test_get_job_returns_existing_status(monkeypatch):
    redis_mock = Mock()
    redis_mock.hget.return_value = "completed"
    monkeypatch.setattr(main, "r", redis_mock)

    response = client.get("/jobs/test-job")

    assert response.status_code == 200
    assert response.json() == {"job_id": "test-job", "status": "completed"}
    redis_mock.hget.assert_called_once_with("job:test-job", "status")


def test_get_job_returns_404_when_missing(monkeypatch):
    redis_mock = Mock()
    redis_mock.hget.return_value = None
    monkeypatch.setattr(main, "r", redis_mock)

    response = client.get("/jobs/missing-job")

    assert response.status_code == 404
    assert response.json() == {"detail": "Job not found"}


def test_healthcheck_pings_redis(monkeypatch):
    redis_mock = Mock()
    monkeypatch.setattr(main, "r", redis_mock)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    redis_mock.ping.assert_called_once_with()
