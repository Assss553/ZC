"""Task runtime: each task runs in a thread, can be paused/resumed/stopped, and persists state to SQLite
so it can be resumed after an app crash/restart."""
import json
import threading
import time
import traceback

from ..events import bus
from ..security.policy import STOP, EmergencyStop
from ..storage import db


class TaskStopped(Exception):
    pass


class TaskContext:
    def __init__(self, task_id: int):
        self.id = task_id
        self.pause_ev = threading.Event(); self.pause_ev.set()
        self.stop_ev = threading.Event()
        self.injected: list[str] = []  # user edits to the task while running

    # ---- control ----
    def checkpoint(self) -> None:
        STOP.check()
        if self.stop_ev.is_set():
            raise TaskStopped()
        if not self.pause_ev.is_set():
            self.set_status("paused")
            while not self.pause_ev.wait(0.3):
                STOP.check()
                if self.stop_ev.is_set():
                    raise TaskStopped()
            self.set_status("running")
        row = get(self.id)
        if row and row["end_at"] and time.time() > row["end_at"]:
            self.log("info", "Time window ended; stopping task.")
            raise TaskStopped()

    # ---- persistence ----
    def set_status(self, status: str) -> None:
        db.execute("UPDATE tasks SET status=?, updated=? WHERE id=?", (status, db.now(), self.id))
        bus.publish("task", {"id": self.id, "status": status})

    def set_plan(self, steps: list[dict]) -> None:
        db.execute("UPDATE tasks SET plan=?, updated=? WHERE id=?", (json.dumps(steps, ensure_ascii=False), db.now(), self.id))
        done = sum(1 for s in steps if s.get("status") == "done")
        self.set_progress(done / len(steps) if steps else 0)
        bus.publish("plan", {"id": self.id, "steps": steps})

    def set_progress(self, p: float) -> None:
        db.execute("UPDATE tasks SET progress=? WHERE id=?", (max(0.0, min(1.0, p)), self.id))
        bus.publish("task", {"id": self.id, "progress": p})

    def save_state(self, state: dict) -> None:
        db.execute("UPDATE tasks SET state=?, updated=? WHERE id=?", (json.dumps(state, ensure_ascii=False, default=str), db.now(), self.id))

    def load_state(self) -> dict:
        row = get(self.id)
        return json.loads(row["state"]) if row and row["state"] else {}

    def log(self, level: str, message: str) -> None:
        db.execute("INSERT INTO task_events(task_id,ts,level,message) VALUES(?,?,?,?)", (self.id, db.now(), level, message[:4000]))
        if level == "error":
            db.execute("UPDATE tasks SET error_count=error_count+1, last_error=? WHERE id=?", (message[:1000], self.id))
        bus.publish("log", {"task_id": self.id, "level": level, "message": message})


def get(task_id: int) -> dict | None:
    rows = db.query("SELECT * FROM tasks WHERE id=?", (task_id,))
    return rows[0] if rows else None


def create(kind: str, title: str, prompt: str, state: dict | None = None, start_at: float | None = None,
           end_at: float | None = None) -> int:
    status = "scheduled" if start_at and start_at > time.time() else "queued"
    return db.execute("INSERT INTO tasks(kind,title,prompt,status,state,start_at,end_at,created,updated) VALUES(?,?,?,?,?,?,?,?,?)",
                      (kind, title, prompt, status, json.dumps(state or {}, ensure_ascii=False), start_at, end_at, db.now(), db.now()))


class Runner:
    def __init__(self) -> None:
        self.active: dict[int, TaskContext] = {}
        self.handlers: dict = {}
        self._lock = threading.Lock()

    def register(self, kind: str, fn) -> None:
        self.handlers[kind] = fn

    def start(self, task_id: int) -> None:
        row = get(task_id)
        if not row or task_id in self.active:
            return
        ctx = TaskContext(task_id)
        with self._lock:
            self.active[task_id] = ctx
        threading.Thread(target=self._run, args=(ctx, row), daemon=True, name=f"task-{task_id}").start()

    def _run(self, ctx: TaskContext, row: dict) -> None:
        from ..scheduler.power import keep_awake
        keep_awake(True)
        ctx.set_status("running")
        try:
            self.handlers[row["kind"]](ctx, row)
            ctx.set_status("completed"); ctx.set_progress(1.0)
        except TaskStopped:
            ctx.set_status("stopped")
        except EmergencyStop:
            ctx.set_status("stopped"); ctx.log("warn", "Emergency stop")
        except Exception as e:
            ctx.log("error", f"{e}\n{traceback.format_exc()[-1500:]}")
            ctx.set_status("failed")
        finally:
            with self._lock:
                self.active.pop(ctx.id, None)
                if not self.active:
                    keep_awake(False)

    def pause(self, tid: int): (c := self.active.get(tid)) and c.pause_ev.clear()
    def resume(self, tid: int): (c := self.active.get(tid)) and c.pause_ev.set()

    def stop(self, tid: int):
        c = self.active.get(tid)
        if c:
            c.stop_ev.set(); c.pause_ev.set()
        else:
            db.execute("UPDATE tasks SET status='stopped' WHERE id=? AND status IN ('queued','scheduled','interrupted','paused')", (tid,))

    def inject(self, tid: int, text: str) -> bool:
        c = self.active.get(tid)
        if c:
            c.injected.append(text); return True
        return False

    def stop_all(self):
        for tid in list(self.active):
            self.stop(tid)


RUNNER = Runner()


def recover_after_restart() -> list[int]:
    """Tasks that were running when the app died are marked 'interrupted'; resumable ones restart if enabled."""
    rows = db.query("SELECT id FROM tasks WHERE status IN ('running','paused')")
    ids = [r["id"] for r in rows]
    for i in ids:
        db.execute("UPDATE tasks SET status='interrupted' WHERE id=?", (i,))
    if db.get_setting("auto_resume", False):
        for i in ids:
            RUNNER.start(i)
    return ids
