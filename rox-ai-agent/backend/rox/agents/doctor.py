"""App Doctor: detect project type, run real checks, parse issues, then let Claude fix them while the user watches.
Checks are fixed, read-only commands (type-check, lint, tests, syntax parse). Nothing is installed automatically."""
import json
import re
import shutil
import subprocess
import time
from pathlib import Path

from ..config import IS_WINDOWS
from ..events import bus
from ..security.policy import resolve_allowed
from . import coding_agent as ca
from . import computer_use as cu
from . import tools_common as tc

SKIP = ca.SKIP
MAX_FILES = 3000


def _files(root: Path, exts: tuple[str, ...]):
    n = 0
    for p in root.rglob("*"):
        if p.suffix.lower() in exts and p.is_file() and not any(s in SKIP for s in p.parts):
            n += 1
            if n > MAX_FILES:
                return
            yield p


def _run(cmd: list[str], cwd: Path, timeout=300) -> tuple[int, str]:
    if IS_WINDOWS and cmd[0] in ("npx", "npm"):
        cmd = ["cmd", "/c", *cmd]
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, encoding="utf-8", errors="replace")
        return p.returncode, (p.stdout + "\n" + p.stderr).strip()[-12000:]
    except FileNotFoundError:
        return 127, f"{cmd[0]} not found"
    except subprocess.TimeoutExpired:
        return 124, "timed out"


def _rel(root: Path, f: str) -> str:
    try:
        return str(Path(f).resolve().relative_to(root))
    except Exception:
        return f


# ---------------- individual checks: each returns list of issues ----------------
def check_python(root: Path) -> list[dict]:
    out = []
    for p in _files(root, (".py",)):
        try:
            compile(p.read_text(encoding="utf-8", errors="replace"), str(p), "exec")
        except SyntaxError as e:
            out.append({"file": _rel(root, str(p)), "line": e.lineno or 0, "message": f"SyntaxError: {e.msg}", "source": "python"})
    return out


def check_json(root: Path) -> list[dict]:
    out = []
    for p in _files(root, (".json",)):
        if p.name in ("tsconfig.json", "jsconfig.json") or p.name.startswith("tsconfig."):
            continue  # JSONC allowed
        try:
            json.loads(p.read_text(encoding="utf-8-sig"))
        except json.JSONDecodeError as e:
            out.append({"file": _rel(root, str(p)), "line": e.lineno, "message": f"Invalid JSON: {e.msg}", "source": "json"})
    return out


LUA_BLOCK = re.compile(r"\b(function|if|for|while|do|repeat|until|end)\b")


def check_lua(root: Path) -> list[dict]:
    out = []
    luac = shutil.which("luac") or shutil.which("luac5.4") or shutil.which("luac54")
    for p in _files(root, (".lua",)):
        if luac:
            code, txt = _run([luac, "-p", str(p)], root, 30)
            if code != 0:
                m = re.search(r":(\d+):\s*(.*)", txt)
                out.append({"file": _rel(root, str(p)), "line": int(m.group(1)) if m else 0, "message": (m.group(2) if m else txt)[:300], "source": "luac"})
        else:  # heuristic block balance when luac is not installed
            src = re.sub(r"--\[\[.*?\]\]|--[^\n]*|\"(?:\\.|[^\"])*\"|'(?:\\.|[^'])*'|\[\[.*?\]\]", "", p.read_text(encoding="utf-8", errors="replace"), flags=re.S)
            depth = 0
            for tok in LUA_BLOCK.findall(src):
                if tok in ("function", "if", "do", "repeat"):
                    depth += 1
                elif tok in ("end", "until"):
                    depth -= 1
            if depth != 0:
                out.append({"file": _rel(root, str(p)), "line": 0, "message": f"Unbalanced blocks ({'missing' if depth > 0 else 'extra'} {abs(depth)} 'end') — heuristic, install luac for exact errors", "source": "lua"})
    # FiveM: files referenced in fxmanifest must exist
    for man in _files(root, (".lua",)):
        if man.name in ("fxmanifest.lua", "__resource.lua"):
            for ref in re.findall(r"['\"]([^'\"*]+\.(?:lua|js|html|css|json))['\"]", man.read_text(encoding="utf-8", errors="replace")):
                if not ref.startswith("@") and not (man.parent / ref).exists():
                    out.append({"file": _rel(root, str(man)), "line": 0, "message": f"Referenced file not found: {ref}", "source": "fivem"})
    return out


def check_html(root: Path) -> list[dict]:
    out = []
    for p in _files(root, (".html", ".htm")):
        txt = p.read_text(encoding="utf-8", errors="replace")
        for i, line in enumerate(txt.splitlines(), 1):
            for ref in re.findall(r"(?:src|href)=[\"']([^\"'#?]+)[\"']", line):
                if re.match(r"^(https?:|//|data:|mailto:|tel:|javascript:|\{)", ref) or ref.startswith("/"):
                    continue
                if not (p.parent / ref).exists():
                    out.append({"file": _rel(root, str(p)), "line": i, "message": f"Missing local file: {ref}", "source": "html"})
    return out


TSC_RE = re.compile(r"^(.+?)\((\d+),\d+\): error (TS\d+: .+)$", re.M)


def check_node(root: Path) -> tuple[list[dict], list[dict]]:
    issues, runs = [], []
    pkg = root / "package.json"
    if not pkg.exists():
        return issues, runs
    try:
        scripts = json.loads(pkg.read_text(encoding="utf-8-sig")).get("scripts", {})
    except json.JSONDecodeError:
        return issues, runs
    if not (root / "node_modules").exists():
        issues.append({"file": "package.json", "line": 0, "message": "Dependencies not installed (node_modules missing) — run npm install", "source": "npm"})
        return issues, runs
    if (root / "tsconfig.json").exists():
        code, txt = _run(["npx", "--no-install", "tsc", "--noEmit", "-p", "."], root)
        runs.append({"name": "TypeScript", "ok": code == 0, "output": txt})
        issues += [{"file": m[0].strip(), "line": int(m[1]), "message": m[2], "source": "tsc"} for m in TSC_RE.findall(txt)]
    for s in ("lint", "test"):
        if s in scripts:
            env_cmd = ["npm", "run", s, "--silent"] + (["--", "--watchAll=false"] if s == "test" and "jest" in scripts[s] else [])
            code, txt = _run(env_cmd, root, 600)
            runs.append({"name": f"npm run {s}", "ok": code == 0, "output": txt})
            if code != 0:
                issues.append({"file": "package.json", "line": 0, "message": f"`npm run {s}` failed (see output)", "source": s})
    return issues, runs


def check_pytest(root: Path) -> tuple[list[dict], list[dict]]:
    if not any((root / d).is_dir() for d in ("tests", "test")) or not list(_files(root, (".py",))):
        return [], []
    py = shutil.which("python") or shutil.which("python3") or "python"
    code, txt = _run([py, "-m", "pytest", "-q", "-x", "--no-header"], root, 600)
    if code == 5 or "No module named pytest" in txt:
        return [], [{"name": "pytest", "ok": True, "output": txt}]
    issues = [{"file": m[0], "line": int(m[1]), "message": m[2][:300], "source": "pytest"} for m in re.findall(r"^(\S+\.py):(\d+): (.+)$", txt, re.M)]
    if code != 0 and not issues:
        issues.append({"file": "", "line": 0, "message": "pytest failed (see output)", "source": "pytest"})
    return issues, [{"name": "pytest", "ok": code == 0, "output": txt}]


def detect(root: Path) -> list[str]:
    kinds = []
    if (root / "package.json").exists(): kinds.append("node")
    if any(True for _ in _files(root, (".py",))): kinds.append("python")
    if any(True for _ in _files(root, (".lua",))): kinds.append("lua/fivem")
    if any(True for _ in _files(root, (".html", ".htm"))): kinds.append("web")
    return kinds or ["unknown"]


def scan(root_s: str, task_id: int | None = None) -> dict:
    root = resolve_allowed(root_s)
    t0 = time.time()
    steps = [("Python syntax", check_python), ("JSON", check_json), ("Lua / FiveM", check_lua), ("HTML links", check_html)]
    checks, issues = [], []

    def emit(name, state, output="", n=0):
        bus.publish("doctor", {"task_id": task_id, "check": name, "state": state, "output": output[-3000:], "issues": n})

    for name, fn in steps:
        emit(name, "running")
        found = fn(root)
        issues += found
        checks.append({"name": name, "ok": not found, "output": "\n".join(f"{i['file']}:{i['line']} {i['message']}" for i in found)})
        emit(name, "done", checks[-1]["output"], len(found))
    for name, fn in (("Node / TypeScript", check_node), ("pytest", check_pytest)):
        emit(name, "running")
        found, runs = fn(root)
        issues += found; checks += runs
        emit(name, "done", "\n\n".join(r["output"] for r in runs), len(found))
    return {"root": str(root), "kinds": detect(root), "checks": checks, "issues": issues, "ms": int((time.time() - t0) * 1000)}


# ---------------- Windows: recent app crashes (read-only) ----------------
def windows_app_errors(days: int = 7) -> list[dict]:
    if not IS_WINDOWS:
        return []
    ps = (f"Get-WinEvent -FilterHashtable @{{LogName='Application'; Id=1000,1001,1002; StartTime=(Get-Date).AddDays(-{int(days)})}} "
          "-MaxEvents 60 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,ProviderName,Message | ConvertTo-Json -Depth 2")
    code, txt = _run(["powershell", "-NoProfile", "-Command", ps], Path.home(), 60)
    try:
        data = json.loads(txt) if txt.strip().startswith(("[", "{")) else []
    except json.JSONDecodeError:
        return []
    data = [data] if isinstance(data, dict) else data
    out = []
    for e in data:
        msg = e.get("Message") or ""
        app = re.search(r"(?:Faulting application name|Application Name|اسم التطبيق)[:\s]+([^\s,]+)", msg)
        out.append({"time": str(e.get("TimeCreated")), "id": e.get("Id"), "provider": e.get("ProviderName"),
                    "app": app.group(1) if app else "", "message": msg[:1200]})
    return out


# ---------------- AI repair loop ----------------
SYSTEM = """You are ROX App Doctor. The user is WATCHING you repair their project live. Reply in the user's language (Arabic or English).
Project root: {root}. Detected: {kinds}.
Workflow: 1) call update_plan with the issues you will fix. 2) Read the relevant file before editing. 3) Fix with minimal, correct edits
(replace_in_file preferred). 4) call run_checks to verify. 5) Repeat until run_checks reports no issues or only issues you cannot fix
(explain why). Before each edit, say in one short line what you are fixing and why. Never delete user code to silence errors.
You may run_command for safe project-local commands (e.g. npm install). Finish with a summary: fixed / remaining / how to verify."""


def run_checks_tool() -> dict:
    return {"name": "run_checks", "description": "Re-run all project checks and return the current issues.",
            "input_schema": {"type": "object", "properties": {}, "additionalProperties": False}}


def handle(ctx, row):
    st = ctx.load_state()
    root = resolve_allowed(st["root"])
    report = scan(str(root), ctx.id)
    ctx.log("info", f"Scan: {len(report['issues'])} issue(s) in {report['ms']}ms ({', '.join(report['kinds'])})")
    bus.publish("doctor_report", {"task_id": ctx.id, **report})
    if not report["issues"] and not row["prompt"].strip():
        ctx.log("info", "No issues found. Nothing to fix."); return
    if st.get("scan_only"):
        return
    base = ca.make_handler(ctx, root, bool(st.get("review", False)))

    def handler(name, inp):
        if name == "run_checks":
            r = scan(str(root), ctx.id)
            bus.publish("doctor_report", {"task_id": ctx.id, **r})
            ctx.log("info", f"Re-check: {len(r['issues'])} issue(s)")
            return json.dumps({"issues": r["issues"][:80], "failed_checks": [{"name": c["name"], "output": c["output"][-3000:]} for c in r["checks"] if not c["ok"]]}, ensure_ascii=False)
        return base(name, inp)

    issues_txt = json.dumps(report["issues"][:80], ensure_ascii=False, indent=1)
    failed = "\n\n".join(f"## {c['name']}\n{c['output'][-3000:]}" for c in report["checks"] if not c["ok"])
    prompt = f"User request: {row['prompt'] or 'Find and fix all errors.'}\n\nIssues found by the checks:\n{issues_txt}\n\nFailed check output:\n{failed}"
    tools = [cu.plan_tool(), cu.ask_user_tool(), tc.run_command_tool(), run_checks_tool()] + ca.file_tools()
    ca.run_text_loop(ctx, SYSTEM.format(root=root, kinds=", ".join(report["kinds"])), prompt, tools, handler, max_turns=80)
