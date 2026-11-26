"""Starts scheduled tasks at their start time; the runtime stops them at end_at. Periodic reports."""
import threading
import time
from datetime import datetime, timedelta

from ..events import bus
from ..storage import db


def parse_hhmm(s: str | None, after: float | None = None) -> float | None:
    """'00:00' -> next occurrence (today or tomorrow); relative to `after` for end times."""
    if not s:
        return None
    h, m = map(int, s.strip().split(":"))
    base = datetime.fromtimestamp(after) if after else datetime.now()
    t = base.replace(hour=h, minute=m, second=0, microsecond=0)
    if t.timestamp() <= base.timestamp():
        t += timedelta(days=1)
    return t.timestamp()


def _loop(runner):
    last_report = time.time()
    while True:
        now = time.time()
        for r in db.query("SELECT id FROM tasks WHERE status='scheduled' AND start_at IS NOT NULL AND start_at<=?", (now,)):
            runner.start(r["id"])
        for r in db.query("SELECT id FROM tasks WHERE status='scheduled' AND end_at IS NOT NULL AND end_at<?", (now,)):
            db.execute("UPDATE tasks SET status='expired' WHERE id=?", (r["id"],))
        interval = db.get_setting("report_minutes", 30) * 60
        if runner.active and now - last_report > interval:
            last_report = now
            for tid in list(runner.active):
                row = db.query("SELECT id,title,status,progress,error_count FROM tasks WHERE id=?", (tid,))
                if row:
                    db.execute("INSERT INTO task_events(task_id,ts,level,message) VALUES(?,?,?,?)",
                               (tid, now, "report", f"Periodic report: status={row[0]['status']} progress={row[0]['progress']:.0%} errors={row[0]['error_count']}"))
                    bus.publish("report", row[0])
        time.sleep(5)


def start(runner):
    threading.Thread(target=_loop, args=(runner,), daemon=True, name="scheduler").start()
