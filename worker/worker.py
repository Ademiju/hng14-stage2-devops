import os
import signal
import time

import redis

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD") or None
JOB_QUEUE = os.getenv("JOB_QUEUE", "jobs")
POLL_TIMEOUT = int(os.getenv("WORKER_POLL_TIMEOUT", "5"))
JOB_DURATION_SECONDS = int(os.getenv("JOB_DURATION_SECONDS", "2"))

r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    decode_responses=True,
)
running = True


def stop_worker(_signum, _frame):
    global running
    running = False


def process_job(job_id):
    print(f"Processing job {job_id}")
    r.hset(f"job:{job_id}", "status", "processing")
    time.sleep(JOB_DURATION_SECONDS)
    r.hset(f"job:{job_id}", "status", "completed")
    print(f"Done: {job_id}")

signal.signal(signal.SIGINT, stop_worker)
signal.signal(signal.SIGTERM, stop_worker)


while running:
    job = r.brpop(JOB_QUEUE, timeout=POLL_TIMEOUT)
    if not job:
        continue

    _, job_id = job
    process_job(job_id)

print("Worker stopped")
