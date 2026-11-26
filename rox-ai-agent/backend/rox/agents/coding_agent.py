"""AI Coding Agent: creates/edits real files in an allowed project folder, with backups, diffs, review and undo."""
import difflib
import json
import shutil
import time
from pathlib import Path

from ..config import data_dir
from ..events import bus
from ..integrations import anthropic_client as ac
from ..security.policy import APPROVALS, audit, resolve_allowed
from ..storage import db
from . import computer_use as cu
from . import tools_common as tc

SYSTEM = """You are ROX Coding Agent, a senior engineer. The user writes Arabic or English; reply in their language.
Project root: {root}. Use the file tools to create real files (Lua/FiveM, HTML/CSS/JS, Python, React, ...).
Call update_plan first. Read before you edit. Run tests/linters/builds with run_command when available and fix failures.
Keep files complete (no placeholders). End with a summary of files created/changed and how to run the project."""

SKIP = {"node_modules", ".git", "__pycache__", ".venv", "dist", "build"}


def backups_root(task_id: int) -> Path:
    p = data_dir() / "backups" / f"task-{task_id}"; p.mkdir(parents=True, exist_ok=True); return p


def record_change(task_id: int, path: Path, before: str | None, after: str | None):
    changes = db.get_setting(f"changes:{task_id}", [])
    bk = None
    if before is not None:
        bk = backups_root(task_id) / f"{int(time.time()*1000)}_{path.name}"
        bk.write_text(before, encoding="utf-8")
    diff = "".join(difflib.unified_diff((before or "").splitlines(True), (after or "").splitlines(True), f"a/{path.name}", f"b/{path.name}"))
    changes.append({"path": str(path), "backup": str(bk) if bk else None, "created": before is None, "diff": diff[:20000], "ts": time.time()})
    db.set_setting(f"changes:{task_id}", changes)
    bus.publish("file_change", {"task_id": task_id, "path": str(path), "diff": diff[:5000]})


def list_changes(task_id: int) -> list[dict]:
    return db.get_setting(f"changes:{task_id}", [])


def revert(task_id: int) -> list[str]:
    """Undo all changes of a task in reverse order."""
    reverted = []
    for ch in reversed(list_changes(task_id)):
        p = resolve_allowed(ch["path"])
        if ch["created"]:
            if p.exists():
                bk = backups_root(task_id) / f"undo_{int(time.time()*1000)}_{p.name}"
                shutil.move(str(p), bk)  # moved to backups, never hard-deleted
        elif ch["backup"]:
            p.write_text(Path(ch["backup"]).read_text(encoding="utf-8"), encoding="utf-8")
        reverted.append(str(p))
    db.set_setting(f"changes:{task_id}", [])
    audit("user", "revert_task", {"task_id": task_id, "files": len(reverted)}, "executed")
    return reverted


def file_tools() -> list[dict]:
    o = lambda props, req: {"type": "object", "properties": props, "required": req, "additionalProperties": False}
    s = {"type": "string"}
    return [
        {"name": "list_dir", "description": "List files under a folder (relative to project root).", "input_schema": o({"path": s}, ["path"])},
        {"name": "read_file", "description": "Read a UTF-8 text file.", "input_schema": o({"path": s}, ["path"])},
        {"name": "write_file", "description": "Create or overwrite a file with full content. Backups are made automatically.", "input_schema": o({"path": s, "content": s}, ["path", "content"]), "eager_input_streaming": True},
        {"name": "replace_in_file", "description": "Replace an exact unique snippet in a file.", "input_schema": o({"path": s, "old": s, "new": s}, ["path", "old", "new"])},
        {"name": "delete_file", "description": "Delete a file (requires user approval; a backup is kept).", "input_schema": o({"path": s}, ["path"])},
        {"name": "search", "description": "Search text in project files.", "input_schema": o({"query": s}, ["query"])},
    ]


def make_handler(ctx, root: Path, review: bool):
    def P(rel): return resolve_allowed(rel, str(root))

    def write(path: Path, content: str):
        before = path.read_text(encoding="utf-8", errors="replace") if path.exists() else None
        if review:
            diff = "".join(difflib.unified_diff((before or "").splitlines(True), content.splitlines(True), "before", "after"))
            if not APPROVALS.request("coding_agent", "file_write_review", {"path": str(path), "diff": diff[:8000]}):
                return "User rejected this change."
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        record_change(ctx.id, path, before, content)
        audit("coding_agent", "write_file", {"path": str(path), "bytes": len(content)}, "executed")
        return f"wrote {path} ({len(content)} chars)"

    def handler(name, inp):
        ctx.checkpoint()
        if name == "update_plan":
            ctx.set_plan(inp["steps"]); return "ok"
        if name == "ask_user":
            return cu.wait_for_user(ctx, inp["question"])
        if name == "list_dir":
            base = P(inp["path"] or ".")
            out = []
            for p in sorted(base.rglob("*")):
                if any(part in SKIP for part in p.parts):
                    continue
                out.append(str(p.relative_to(base)) + ("/" if p.is_dir() else ""))
                if len(out) > 400:
                    out.append("…"); break
            return "\n".join(out) or "(empty)"
        if name == "read_file":
            return P(inp["path"]).read_text(encoding="utf-8", errors="replace")[:60000]
        if name == "write_file":
            return write(P(inp["path"]), inp["content"])
        if name == "replace_in_file":
            p = P(inp["path"]); txt = p.read_text(encoding="utf-8")
            if txt.count(inp["old"]) != 1:
                return f"Error: snippet found {txt.count(inp['old'])} times (must be exactly 1)."
            return write(p, txt.replace(inp["old"], inp["new"]))
        if name == "delete_file":
            p = P(inp["path"])
            if not APPROVALS.request("coding_agent", "delete_files", {"path": str(p)}):
                return "Denied by user."
            shutil.move(str(p), backups_root(ctx.id) / f"deleted_{int(time.time())}_{p.name}")
            return "deleted (backup kept)"
        if name == "search":
            hits = []
            for p in root.rglob("*"):
                if p.is_file() and not any(x in SKIP for x in p.parts) and p.stat().st_size < 2_000_000:
                    for i, line in enumerate(p.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
                        if inp["query"] in line:
                            hits.append(f"{p.relative_to(root)}:{i}: {line.strip()[:200]}")
                if len(hits) > 200:
                    break
            return "\n".join(hits) or "no matches"
        if name == "run_command":
            return tc.run_command("coding_agent", inp["command"], inp.get("cwd") or str(root), inp.get("timeout_s", 300))
        return f"unknown tool {name}"
    return handler


def handle(ctx, row):
    st = ctx.load_state()
    root = resolve_allowed(st["root"]); root.mkdir(parents=True, exist_ok=True)
    review = bool(st.get("review", False))
    if st.get("engine") == "claude_code":  # use the user's Claude Code login instead of API billing
        ctx.log("info", "Running via Claude Code CLI (account login)…")
        res = ac.claude_code_run(row["prompt"], str(root))
        ctx.log("info", str(res.get("result", res))[:4000]); return
    handler = make_handler(ctx, root, review)
    tools = [cu.plan_tool(), cu.ask_user_tool(), tc.run_command_tool()] + file_tools()
    run_text_loop(ctx, SYSTEM.format(root=root), row["prompt"], tools, handler)


def run_text_loop(ctx, system, prompt, tools, handler, max_turns=120):
    messages = [{"role": "user", "content": prompt}]
    for _ in range(max_turns):
        ctx.checkpoint()
        if ctx.injected:
            messages.append({"role": "user", "content": "Update from the user: " + "\n".join(ctx.injected)}); ctx.injected.clear()
        msg = ac.create(messages, system, tools, max_tokens=64000)
        if msg.stop_reason == "refusal":
            ctx.log("warn", "Claude declined (refusal)."); return
        messages.append({"role": "assistant", "content": [b.model_dump(exclude_none=True) for b in msg.content]})
        uses = [b for b in msg.content if b.type == "tool_use"]
        for b in msg.content:
            if b.type == "text" and b.text.strip():
                ctx.log("info", b.text); bus.publish("agent_say", {"task_id": ctx.id, "text": b.text})
        if msg.stop_reason == "max_tokens" and uses:
            messages.append({"role": "user", "content": [{"type": "tool_result", "tool_use_id": u.id, "is_error": True,
                             "content": "Output was cut off; resend smaller pieces."} for u in uses]}); continue
        if not uses:
            if msg.stop_reason == "pause_turn":
                continue
            return
        results = []
        for u in uses:
            bus.publish("decision", {"task_id": ctx.id, "action": u.name, "input": {k: (v if len(str(v)) < 300 else str(v)[:300] + "…") for k, v in u.input.items()}})
            try:
                if not isinstance(u.input, dict):
                    raise ValueError("invalid tool input")
                results.append({"type": "tool_result", "tool_use_id": u.id, "content": str(handler(u.name, dict(u.input)))})
            except Exception as e:
                if type(e).__name__ in ("EmergencyStop", "TaskStopped"):
                    raise
                ctx.log("error", f"{u.name}: {e}")
                results.append({"type": "tool_result", "tool_use_id": u.id, "content": f"Error: {e}", "is_error": True})
        messages.append({"role": "user", "content": results})
        ctx.save_state({**ctx.load_state(), "turns": len(messages)})
