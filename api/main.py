import os
import uuid

import redis
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD") or None
JOB_QUEUE = os.getenv("JOB_QUEUE", "jobs")

r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    decode_responses=True,
)


@app.post("/jobs")
def create_job():
    job_id = str(uuid.uuid4())
    r.lpush(JOB_QUEUE, job_id)
    r.hset(f"job:{job_id}", "status", "queued")
    return JSONResponse(
        content={"job_id": job_id, "status": "queued"},
        status_code=201,
    )


@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    status = r.hget(f"job:{job_id}", "status")
    if not status:
        raise HTTPException(status_code=404, detail="Job not found")
    return {"job_id": job_id, "status": status}


@app.get("/health")
def healthcheck():
    r.ping()
    return {"status": "ok"}
