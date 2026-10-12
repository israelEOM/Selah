"""Selah worker.

    python -m selah_worker run                 poll Supabase for jobs
    python -m selah_worker pipeline <url> [days]  run every step for one sermon now
    python -m selah_worker make-admin <email>  give an existing account the admin role
    python -m selah_worker check               verify the Supabase connection
"""
import logging
import sys
import time
from datetime import datetime, timezone

from selah_worker.config import settings
from selah_worker.db import client
from selah_worker.pipeline import HANDLERS, run_all

log = logging.getLogger("selah")

def make_admin(email: str) -> None:
    db = client()
    page = 1
    while True:
        users = db.auth.admin.list_users(page=page, per_page=200)
        match = next((u for u in users if (u.email or "").lower() == email.lower()), None)
        if match or len(users) < 200:
            break
        page += 1
    if not match:
        sys.exit(f"No account found for {email}. Create it in the app first, then run this again.")
    db.table("profiles").update({"role": "admin"}).eq("id", match.id).execute()
    print(f"{email} is now an admin.")


def check() -> None:
    row = client().table("church_settings").select("church_name").single().execute()
    print(f"Connected to Supabase. Church: {row.data['church_name']}")


def next_job(job: dict) -> dict | None:
    """A job may carry a chain of later steps; each one is queued when the previous succeeds."""
    chain = job["payload"].get("chain") or []
    if not chain:
        return None
    return {
        "sermon_id": job["sermon_id"], "created_by": job.get("created_by"), "step": chain[0]["step"],
        "payload": (chain[0].get("payload") or {}) | {"chain": chain[1:]},
    }


def _process(db, job: dict) -> None:
    log.info("Job %s (%s) started", job["id"], job["step"])
    update = {"finished_at": datetime.now(timezone.utc).isoformat()}
    try:
        handler = HANDLERS.get(job["step"])
        if handler is None:
            raise RuntimeError(f"Step '{job['step']}' is not implemented yet.")
        result = handler(job)
        usage = {k: result[k] for k in ("model", "prompt_version", "input_tokens", "output_tokens") if k in result}
        update |= {"status": "succeeded", "result": result} | usage
    except Exception as exc:  # the admin sees the message and can retry
        log.exception("Job %s failed", job["id"])
        update |= {"status": "failed", "error": str(exc)[:2000]}
    db.table("jobs").update(update).eq("id", job["id"]).execute()
    follow_up = next_job(job) if update["status"] == "succeeded" else None
    if follow_up:
        db.table("jobs").insert(follow_up).execute()


def run() -> None:
    db = client()
    # There is one worker, so a job still marked running was cut off by a previous stop.
    db.table("jobs").update({
        "status": "failed", "error": "El worker se detuvo durante este paso. Reintenta.",
        "finished_at": datetime.now(timezone.utc).isoformat(),
    }).eq("status", "running").execute()
    log.info("Worker started; polling every %ss", settings.poll_seconds)
    while True:
        try:
            jobs = db.rpc("claim_job").execute().data
            if jobs:
                _process(db, jobs[0])
                continue
        except Exception:  # a dropped connection must not stop the worker
            log.exception("Connection problem; retrying shortly")
            time.sleep(10)
        time.sleep(settings.poll_seconds)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)  # one line per poll is noise
    args = sys.argv[1:]
    if args == ["run"]:
        run()
    elif len(args) == 2 and args[0] == "make-admin":
        make_admin(args[1])
    elif len(args) in (2, 3) and args[0] == "pipeline":
        run_all(args[1], days=int(args[2]) if len(args) == 3 else 5)
    elif args == ["check"]:
        check()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
