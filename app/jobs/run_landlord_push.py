"""
Entry point for Heroku Scheduler / cron.

Heroku: add job with
  python -m app.jobs.run_landlord_push

Requires DATABASE_URL, FCM credentials (same as web dyno).
"""

from __future__ import annotations

import os
import sys


def main() -> int:
    # Ensure repo root on path when run from Heroku
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    if root not in sys.path:
        sys.path.insert(0, root)

    try:
        from dotenv import load_dotenv

        load_dotenv()
    except ImportError:
        pass

    from app.db.migrations import ensure_runtime_migrations
    from app.services.landlord_push_scheduler import run_scheduled_landlord_pushes

    ensure_runtime_migrations()
    run_scheduled_landlord_pushes()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
