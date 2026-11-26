"""ROX AI Agent backend — FastAPI on 127.0.0.1 only. The Electron shell passes a per-launch token."""
import asyncio
import base64
import os
import time

import psutil
from fastapi import Depends, FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from . import config
from .agents import chat, coding_agent, computer_agent, game_agent, runtime
from .agents.game_adapters.base import ADAPTERS
from .events import bus
from .input_control import controller as ic
from .integrations import anthropic_client as ac
from .scheduler import power, scheduler
from .scheduler.scheduler import parse_hhmm
from .security import credentials, policy
from .storage import db
from .vision import capture

TOKEN = os.environ.get("ROX_TOKEN", "")
START = time.time()
app = FastAPI(title="ROX AI Agent")
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost:5173", "http://localhost:4173", "app://rox", "null"], allow_methods=["*"], allow_headers=["*"])


@app.exception_handler(PermissionError)
async def _perm(_req, exc):
    from fastapi.responses import JSONResponse
    return JSONResponse({"detail": str(exc)}, status_code=403)


def auth(request: Request):
    if TOKEN and request.headers.get("x-rox-token") != TOKEN:
        raise HTTPException(401, "bad token")


A = [Depends(auth)]
runtime.RUNNER.register("computer", computer_agent.handle)
runtime.RUNNER.register("coding", coding_agent.handle)
runtime.RUNNER.register("game", game_agent.handle)


@app.on_event("startup")
async def _startup():
    bus.bind(asyncio.get_running_loop())
    interrupted = runtime.recover_after_restart()
    scheduler.start(runtime.RUNNER)
    policy.audit("system", "startup", {"interrupted_tasks": interrupted, "admin": power.is_admin()}, "executed")


# ---------------- status ----------------
@app.get("/api/status", dependencies=A)
def status():
    vm = psutil.virtual_memory()
    key = credentials.get_secret("anthropic_api_key")
    running = db.query("SELECT id,kind,title,status,progress,plan FROM tasks WHERE status IN ('running','paused') ORDER BY id DESC LIMIT 1")
    return {"cpu": psutil.cpu_percent(interval=None), "ram": vm.percent, "ram_used_gb": round(vm.used / 2**30, 1),
            "uptime_s": int(time.time() - START), "platform": os.name, "is_windows": config.IS_WINDOWS,
            "is_admin": power.is_admin(), "emergency_stop": policy.STOP.active,
            "provider": ac.provider(), "model": ac.model(), "api_key_set": bool(key),
            "usage": db.get_setting("usage", {}), "current_task": running[0] if running else None,
            "active_tasks": list(runtime.RUNNER.active), "recent_actions": list(bus.recent)[-25:],
            "capture_available": _capture_ok(), "input_available": ic.pyautogui is not None}


def _capture_ok():
    try:
        capture.screen_size(); return True
    except Exception:
        return False


# ---------------- settings / Claude ----------------
class KeyIn(BaseModel):
    api_key: str


class SettingsIn(BaseModel):
    provider: str | None = None
    model: str | None = None
    effort: str | None = None
    use_fallbacks: bool | None = None
    allowed_folders: list[str] | None = None
    max_output_tokens_total: int | None = None
    report_minutes: int | None = None
    auto_resume: bool | None = None
    run_at_login: bool | None = None
    language: str | None = None


@app.get("/api/settings", dependencies=A)
def get_settings():
    return {"provider": ac.provider(), "model": ac.model(), "effort": ac.effort(), "use_fallbacks": db.get_setting("use_fallbacks", True),
            "allowed_folders": policy.allowed_folders(), "max_output_tokens_total": db.get_setting("max_output_tokens_total", 0),
            "report_minutes": db.get_setting("report_minutes", 30), "auto_resume": db.get_setting("auto_resume", False),
            "run_at_login": db.get_setting("run_at_login", False), "language": db.get_setting("language", "ar"),
            "api_key_masked": credentials.mask(credentials.get_secret("anthropic_api_key")),
            "claude_code": ac.claude_code_status()}


@app.post("/api/settings", dependencies=A)
def save_settings(s: SettingsIn):
    if s.provider and s.provider not in ("api", "claude_code", "local"):
        raise HTTPException(400, "unknown provider")
    for k, v in s.model_dump(exclude_none=True).items():
        if k == "allowed_folders":
            policy.set_allowed_folders(v)
        elif k == "run_at_login":
            exe = os.environ.get("ROX_EXE_PATH")
            if exe:
                power.set_run_at_login(v, f'"{exe}"')
            db.set_setting(k, v)
        else:
            db.set_setting(k, v)
    policy.audit("user", "settings_changed", {k: v for k, v in s.model_dump(exclude_none=True).items()}, "executed")
    return get_settings()


@app.post("/api/claude/key", dependencies=A)
def set_key(k: KeyIn):
    key = k.api_key.strip()
    if not key.startswith("sk-ant-"):
        raise HTTPException(400, "This does not look like an Anthropic API key (sk-ant-…)")
    credentials.set_secret("anthropic_api_key", key)
    policy.audit("user", "api_key_saved", {}, "executed")
    return {"ok": True, "masked": credentials.mask(key)}


@app.delete("/api/claude/key", dependencies=A)
def del_key():
    credentials.delete_secret("anthropic_api_key"); policy.audit("user", "api_key_deleted", {}, "executed"); return {"ok": True}


@app.post("/api/claude/test", dependencies=A)
def test_claude():
    return ac.test_connection()


# ---------------- screen ----------------
@app.get("/api/windows", dependencies=A)
def windows():
    return capture.list_windows()


@app.websocket("/ws/screen")
async def ws_screen(ws: WebSocket, token: str = "", window: str = "", fps: float = 8, side: int = 1280):
    if TOKEN and token != TOKEN:
        await ws.close(code=4401); return
    await ws.accept()
    fps = max(1.0, min(fps, 30.0))
    try:
        while True:
            t0 = time.time()
            region = capture.window_region(window) if window else None
            try:
                data, size, _ = await asyncio.to_thread(capture.capture, region, side, 60)
                await ws.send_json({"frame": base64.b64encode(data).decode(), "w": size[0], "h": size[1],
                                    "capture_ms": int((time.time() - t0) * 1000)})
            except capture.CaptureUnavailable as e:
                await ws.send_json({"error": str(e)}); await asyncio.sleep(2)
            await asyncio.sleep(max(0, 1 / fps - (time.time() - t0)))
    except (WebSocketDisconnect, RuntimeError):
        pass


@app.websocket("/ws/events")
async def ws_events(ws: WebSocket, token: str = ""):
    if TOKEN and token != TOKEN:
        await ws.close(code=4401); return
    await ws.accept()
    q = bus.subscribe()
    try:
        for a in policy.APPROVALS.pending():
            await ws.send_json({"type": "approval", "data": a})
        while True:
            await ws.send_json(await q.get())
    except (WebSocketDisconnect, RuntimeError):
        pass
    finally:
        bus.unsubscribe(q)


# ---------------- manual input test ----------------
class InputIn(BaseModel):
    action: str
    x: int | None = None
    y: int | None = None
    text: str | None = None


@app.post("/api/input/test", dependencies=A)
def input_test(i: InputIn):
    try:
        if i.action == "move": ic.move(i.x, i.y, actor="user")
        elif i.action == "click": ic.click(i.x, i.y, actor="user")
        elif i.action == "type": ic.type_text(i.text or "", actor="user")
        elif i.action == "key": ic.key(i.text or "", actor="user")
        elif i.action == "cursor": return {"cursor": ic.cursor()}
        else: raise HTTPException(400, "unknown action")
    except (ic.InputUnavailable, policy.EmergencyStop) as e:
        raise HTTPException(409, str(e))
    return {"ok": True}


# ---------------- safety ----------------
@app.post("/api/emergency-stop", dependencies=A)
def emergency_stop():
    policy.STOP.trigger(); runtime.RUNNER.stop_all(); ic.release_all(); policy.APPROVALS.wake()
    return {"ok": True}


@app.post("/api/emergency-stop/reset", dependencies=A)
def emergency_reset():
    policy.STOP.clear(); policy.audit("user", "emergency_stop_reset", {}, "executed"); return {"ok": True}


class ApprovalIn(BaseModel):
    approve: bool


@app.post("/api/approvals/{aid}", dependencies=A)
def answer_approval(aid: str, a: ApprovalIn):
    if not policy.APPROVALS.answer(aid, a.approve):
        raise HTTPException(404, "no such approval")
    return {"ok": True}


@app.get("/api/audit", dependencies=A)
def audit_log(limit: int = 300):
    return db.query("SELECT * FROM audit ORDER BY id DESC LIMIT ?", (limit,))


# ---------------- chat ----------------
class ChatIn(BaseModel):
    conversation_id: int | None = None
    text: str
    images: list[dict] = []
    attach_screenshot: bool = False


@app.get("/api/conversations", dependencies=A)
def conversations():
    return db.query("SELECT * FROM conversations ORDER BY id DESC LIMIT 100")


@app.get("/api/conversations/{cid}", dependencies=A)
def conversation(cid: int):
    return chat.history(cid)


@app.post("/api/chat", dependencies=A)
def chat_send(c: ChatIn):
    cid = c.conversation_id or chat.new_conversation(c.text)
    imgs = list(c.images)
    if c.attach_screenshot:
        b64, _s, _sc = capture.capture_b64_png(max_side=1280)
        imgs.append({"media_type": "image/png", "data": b64})
    try:
        r = chat.send(cid, c.text, imgs)
    except RuntimeError as e:
        raise HTTPException(400, str(e))
    return {"conversation_id": cid, **r}


# ---------------- tasks ----------------
class TaskIn(BaseModel):
    kind: str
    title: str
    prompt: str
    start_at_local: str | None = None
    end_at_local: str | None = None
    duration_minutes: int | None = None
    state: dict = {}
    start_now: bool = True


@app.post("/api/tasks", dependencies=A)
def create_task(t: TaskIn):
    if t.kind not in runtime.RUNNER.handlers:
        raise HTTPException(400, "unknown kind")
    if t.kind == "coding":
        try:
            policy.resolve_allowed(t.state.get("root", ""))
        except PermissionError as e:
            raise HTTPException(400, f"{e}. Add the folder in Settings → Allowed folders.")
    start = parse_hhmm(t.start_at_local)
    end = parse_hhmm(t.end_at_local, after=start or time.time())
    if t.duration_minutes and not end:
        end = (start or time.time()) + t.duration_minutes * 60
    tid = runtime.create(t.kind, t.title, t.prompt, t.state, start, end)
    policy.audit("user", "task_created", {"id": tid, "kind": t.kind, "title": t.title}, "executed")
    if t.start_now and not start:
        runtime.RUNNER.start(tid)
    return runtime.get(tid)


@app.get("/api/tasks", dependencies=A)
def tasks():
    return db.query("SELECT * FROM tasks ORDER BY id DESC LIMIT 200")


@app.get("/api/tasks/{tid}", dependencies=A)
def task(tid: int):
    return {"task": runtime.get(tid), "events": db.query("SELECT * FROM task_events WHERE task_id=? ORDER BY id DESC LIMIT 500", (tid,)),
            "changes": coding_agent.list_changes(tid)}


class MsgIn(BaseModel):
    text: str


@app.post("/api/tasks/{tid}/{op}", dependencies=A)
def task_op(tid: int, op: str, body: MsgIn | None = None):
    r = runtime.RUNNER
    if op == "start": r.start(tid)
    elif op == "pause": r.pause(tid)
    elif op == "resume":
        if tid in r.active: r.resume(tid)
        else: r.start(tid)
    elif op == "stop": r.stop(tid)
    elif op == "message":
        if not body or not r.inject(tid, body.text): raise HTTPException(409, "task not running")
    elif op == "revert": return {"reverted": coding_agent.revert(tid)}
    else: raise HTTPException(400, "bad op")
    policy.audit("user", f"task_{op}", {"id": tid}, "executed")
    return {"ok": True}


@app.get("/api/games/adapters", dependencies=A)
def adapters():
    return [{"id": a.id, "name": a.name, "window_hint": a.window_hint, "description": a.description, "tags": a.tags,
             "allowed_keys": sorted(a.allowed_keys) if a.allowed_keys is not None else None} for a in ADAPTERS.values()]


# ---------------- files (editor) ----------------
@app.get("/api/files/tree", dependencies=A)
def file_tree(root: str):
    base = policy.resolve_allowed(root)
    out = []
    for p in sorted(base.rglob("*")):
        if any(x in coding_agent.SKIP for x in p.parts): continue
        out.append({"path": str(p), "rel": str(p.relative_to(base)), "dir": p.is_dir()})
        if len(out) > 2000: break
    return out


@app.get("/api/files/read", dependencies=A)
def file_read(path: str):
    p = policy.resolve_allowed(path)
    return {"path": str(p), "content": p.read_text(encoding="utf-8", errors="replace")}


class WriteIn(BaseModel):
    path: str
    content: str


@app.post("/api/files/write", dependencies=A)
def file_write(w: WriteIn):
    p = policy.resolve_allowed(w.path)
    before = p.read_text(encoding="utf-8", errors="replace") if p.exists() else None
    p.parent.mkdir(parents=True, exist_ok=True); p.write_text(w.content, encoding="utf-8")
    coding_agent.record_change(0, p, before, w.content)  # task 0 = manual edits
    policy.audit("user", "file_write", {"path": str(p)}, "executed")
    return {"ok": True}


def main():
    import uvicorn
    uvicorn.run(app, host=config.HOST, port=config.PORT, log_level="warning")


if __name__ == "__main__":
    main()
