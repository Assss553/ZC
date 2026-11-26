"""Direct OS tools for the Operator agent: fast, exact, and auditable — used before falling back to mouse/vision.
Read-only tools run immediately; anything that changes the system goes through policy approvals."""
import fnmatch
import json
import os
import platform
import shutil
import socket
import subprocess
import time
import webbrowser
from pathlib import Path

import psutil

from ..config import IS_WINDOWS
from ..events import bus
from ..security.policy import APPROVALS, audit, classify_command, resolve_allowed
from ..vision import capture

ACTOR = "operator"
PROTECTED = {"system", "smss.exe", "csrss.exe", "wininit.exe", "winlogon.exe", "services.exe", "lsass.exe", "svchost.exe",
             "explorer.exe", "dwm.exe", "msmpeng.exe", "securityhealthservice.exe", "init", "systemd", "python.exe", "electron.exe", "rox ai agent.exe"}


def _ps(cmd: str, timeout=60) -> str:
    if not IS_WINDOWS:
        return "Windows only"
    p = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", cmd], capture_output=True, text=True,
                       timeout=timeout, encoding="utf-8", errors="replace")
    return (p.stdout or p.stderr).strip()[-15000:]


def _gb(n): return round(n / 2**30, 1)


# ---------------- read-only ----------------
def system_info(_=None):
    vm, du = psutil.virtual_memory(), psutil.disk_usage(Path.home().anchor or "/")
    b = psutil.sensors_battery() if hasattr(psutil, "sensors_battery") else None
    return {"os": f"{platform.system()} {platform.release()} ({platform.version()})", "machine": platform.node(),
            "cpu": platform.processor(), "cores": psutil.cpu_count(), "cpu_percent": psutil.cpu_percent(interval=0.3),
            "ram_gb": _gb(vm.total), "ram_used_percent": vm.percent, "system_disk_free_gb": _gb(du.free), "system_disk_used_percent": du.percent,
            "uptime_h": round((time.time() - psutil.boot_time()) / 3600, 1), "battery": {"percent": b.percent, "plugged": b.power_plugged} if b else None,
            "user": os.environ.get("USERNAME") or os.environ.get("USER")}


def list_processes(inp):
    sort = inp.get("sort", "memory"); q = (inp.get("name") or "").lower(); limit = int(inp.get("limit", 25))
    rows = []
    for p in psutil.process_iter(["pid", "name", "memory_info", "cpu_percent", "username"]):
        try:
            n = p.info["name"] or ""
            if q and q not in n.lower():
                continue
            rows.append({"pid": p.info["pid"], "name": n, "mem_mb": round((p.info["memory_info"].rss if p.info["memory_info"] else 0) / 2**20),
                         "cpu": p.info["cpu_percent"] or 0.0})
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    rows.sort(key=lambda r: r["mem_mb"] if sort == "memory" else r["cpu"], reverse=True)
    return rows[:limit]


def disk_usage(_=None):
    out = []
    for part in psutil.disk_partitions(all=False):
        try:
            u = psutil.disk_usage(part.mountpoint)
            out.append({"drive": part.mountpoint, "fs": part.fstype, "total_gb": _gb(u.total), "free_gb": _gb(u.free), "used_percent": u.percent})
        except (PermissionError, OSError):
            pass
    return out


def network_info(_=None):
    addrs = {n: [a.address for a in a_list if a.family == socket.AF_INET] for n, a_list in psutil.net_if_addrs().items()}
    stats = {n: s.isup for n, s in psutil.net_if_stats().items()}
    online = False
    try:
        socket.create_connection(("1.1.1.1", 53), timeout=2).close(); online = True
    except OSError:
        pass
    io = psutil.net_io_counters()
    return {"internet": online, "interfaces": [{"name": n, "up": stats.get(n), "ipv4": a} for n, a in addrs.items() if a],
            "sent_mb": round(io.bytes_sent / 2**20), "recv_mb": round(io.bytes_recv / 2**20)}


def installed_apps(inp):
    q = (inp.get("name") or "").replace("'", "")
    flt = f"| Where-Object {{ $_.DisplayName -like '*{q}*' }}" if q else ""
    return _ps("Get-ItemProperty HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*, HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*, "
               f"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* -ErrorAction SilentlyContinue | Where-Object DisplayName {flt} | "
               "Select-Object DisplayName, DisplayVersion, Publisher | Sort-Object DisplayName | Select-Object -First 150 | ConvertTo-Json -Compress")


def startup_apps(_=None):
    return _ps("Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location | ConvertTo-Json -Compress")


def services(inp):
    q = (inp.get("name") or "").replace("'", "")
    return _ps(f"Get-Service -ErrorAction SilentlyContinue | Where-Object {{ $_.Name -like '*{q}*' -or $_.DisplayName -like '*{q}*' }} | "
               "Select-Object Name, DisplayName, Status, StartType | Select-Object -First 60 | ConvertTo-Json -Compress")


def recent_errors(inp):
    from .doctor import windows_app_errors
    return windows_app_errors(int(inp.get("days", 3)))[:20]


def find_files(inp):
    root = resolve_allowed(inp["folder"]); pat = inp.get("pattern", "*"); txt = inp.get("contains"); out = []
    for p in root.rglob("*"):
        if len(out) >= 200:
            break
        if not p.is_file() or any(s in {"node_modules", ".git", "__pycache__"} for s in p.parts) or not fnmatch.fnmatch(p.name.lower(), pat.lower()):
            continue
        if txt:
            try:
                if p.stat().st_size > 3_000_000 or txt not in p.read_text(encoding="utf-8", errors="ignore"):
                    continue
            except OSError:
                continue
        st = p.stat(); out.append({"path": str(p), "kb": st.st_size // 1024, "modified": time.strftime("%Y-%m-%d %H:%M", time.localtime(st.st_mtime))})
    return out


def read_text(inp):
    return resolve_allowed(inp["path"]).read_text(encoding="utf-8", errors="replace")[:40000]


def clipboard_get(_=None):
    return _ps("Get-Clipboard -Raw") if IS_WINDOWS else "Windows only"


def windows(_=None):
    return capture.list_windows()


# ---------------- actions ----------------
def open_url(inp):
    url = inp["url"]
    if not url.startswith(("http://", "https://")):
        return "Only http(s) URLs"
    audit(ACTOR, "open_url", {"url": url}, "executed"); webbrowser.open(url); return "opened"


def launch_app(inp):
    """Launch by friendly name via Start Menu shortcut search (e.g. 'Visual Studio Code', 'Steam', 'Discord')."""
    name = inp["name"]
    from .tools_common import open_app
    if not IS_WINDOWS:
        return open_app(ACTOR, name)
    safe = name.replace("'", "")
    found = _ps("$d=@(\"$env:APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\",\"$env:ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\",\"$env:USERPROFILE\\Desktop\",\"$env:PUBLIC\\Desktop\");"
                f"Get-ChildItem $d -Recurse -Include *.lnk,*.url -ErrorAction SilentlyContinue | Where-Object {{ $_.BaseName -like '*{safe}*' }} | Select-Object -First 1 -ExpandProperty FullName")
    target = found.splitlines()[0].strip() if found.strip() else None
    if not target:
        r = _ps(f"(Get-StartApps | Where-Object {{ $_.Name -like '*{safe}*' }} | Select-Object -First 1).AppID")
        if r.strip():
            subprocess.Popen(["explorer.exe", f"shell:AppsFolder\\{r.strip()}"]); audit(ACTOR, "launch_app", {"name": name, "appid": r.strip()}, "executed")
            bus.publish("action", {"actor": ACTOR, "action": "launch_app", "target": name}); return f"launched (store app) {r.strip()}"
        return open_app(ACTOR, name)  # fall back to PATH/protocol (e.g. 'code', 'notepad', 'ms-settings:')
    return open_app(ACTOR, target)


def window_action(inp):
    if not IS_WINDOWS:
        return "Windows only"
    import pygetwindow as gw  # type: ignore
    title, act = inp["title"], inp["action"]
    ws = [w for w in gw.getAllWindows() if title.lower() in w.title.lower() and w.title.strip()]
    if not ws:
        return f"No window matching '{title}'"
    w = ws[0]
    if act == "close" and not APPROVALS.request(ACTOR, "close_window", {"title": w.title}):
        return "Denied by user."
    {"focus": w.activate, "minimize": w.minimize, "maximize": w.maximize, "restore": w.restore, "close": w.close}[act]()
    audit(ACTOR, "window_" + act, {"title": w.title}, "executed"); bus.publish("action", {"actor": ACTOR, "action": "window_" + act, "target": w.title})
    return f"{act}: {w.title}"


def kill_process(inp):
    pid = int(inp["pid"])
    try:
        p = psutil.Process(pid); name = p.name()
    except psutil.NoSuchProcess:
        return "No such process"
    if name.lower() in PROTECTED:
        audit(ACTOR, "kill_process", {"pid": pid, "name": name}, "blocked"); return f"Blocked: {name} is a protected system process."
    if not APPROVALS.request(ACTOR, "kill_process", {"pid": pid, "name": name}):
        return "Denied by user."
    p.terminate()
    try:
        p.wait(5)
    except psutil.TimeoutExpired:
        p.kill()
    return f"terminated {name} ({pid})"


def clipboard_set(inp):
    if not IS_WINDOWS:
        return "Windows only"
    subprocess.run(["clip"], input=inp["text"].encode("utf-16-le"), check=True); audit(ACTOR, "clipboard_set", {"chars": len(inp["text"])}, "executed")
    return "copied"


def powershell(inp):
    cmd = inp["command"]
    risk = classify_command(cmd)
    if risk and not APPROVALS.request(ACTOR, risk, {"command": cmd}):
        return f"Denied: '{risk}' action was not approved."
    audit(ACTOR, "powershell", {"command": cmd}, "executed"); bus.publish("action", {"actor": ACTOR, "action": "powershell", "command": cmd})
    if not IS_WINDOWS:
        p = subprocess.run(["bash", "-lc", cmd], capture_output=True, text=True, timeout=120)
        return f"exit={p.returncode}\n{(p.stdout + p.stderr)[-8000:]}"
    return _ps(cmd, timeout=int(inp.get("timeout_s", 120)))


# ---------------- registry ----------------
S, I, O = {"type": "string"}, {"type": "integer"}, lambda props, req=(): {"type": "object", "properties": props, "required": list(req), "additionalProperties": False}
TOOLS = {
    "system_info": (system_info, "OS, CPU, RAM, disk, battery, uptime.", O({})),
    "list_processes": (list_processes, "Running processes sorted by memory or cpu; optional name filter.", O({"name": S, "sort": {"type": "string", "enum": ["memory", "cpu"]}, "limit": I})),
    "disk_usage": (disk_usage, "Free/used space for every drive.", O({})),
    "network_info": (network_info, "Internet connectivity, adapters, IPv4, traffic.", O({})),
    "installed_apps": (installed_apps, "Installed programs (name/version/publisher), optional name filter.", O({"name": S})),
    "startup_apps": (startup_apps, "Programs that start with Windows.", O({})),
    "services": (services, "Windows services status, filter by name.", O({"name": S}, ["name"])),
    "recent_app_crashes": (recent_errors, "Application crash/hang events from the Windows event log.", O({"days": I})),
    "list_windows": (windows, "Open windows with titles and positions.", O({})),
    "find_files": (find_files, "Find files in an allowed folder by glob pattern and/or containing text.", O({"folder": S, "pattern": S, "contains": S}, ["folder"])),
    "read_text_file": (read_text, "Read a text file inside allowed folders.", O({"path": S}, ["path"])),
    "clipboard_get": (clipboard_get, "Read clipboard text.", O({})),
    "launch_app": (launch_app, "Launch an app by friendly name (Start Menu search), command (code, notepad) or protocol (ms-settings:display).", O({"name": S}, ["name"])),
    "open_url": (open_url, "Open a web page in the default browser.", O({"url": S}, ["url"])),
    "window_action": (window_action, "focus/minimize/maximize/restore/close a window by title substring (close asks approval).", O({"title": S, "action": {"type": "string", "enum": ["focus", "minimize", "maximize", "restore", "close"]}}, ["title", "action"])),
    "kill_process": (kill_process, "Terminate a process by pid (asks approval; system processes are blocked).", O({"pid": I}, ["pid"])),
    "clipboard_set": (clipboard_set, "Put text on the clipboard.", O({"text": S}, ["text"])),
    "powershell": (powershell, "Run a PowerShell command (risky commands ask approval; security changes are blocked). Prefer the specific tools above.", O({"command": S, "timeout_s": I}, ["command"])),
}


def tool_defs() -> list[dict]:
    return [{"name": n, "description": d, "input_schema": s} for n, (_f, d, s) in TOOLS.items()]


def call(name: str, inp: dict):
    fn = TOOLS[name][0]
    r = fn(inp)
    return r if isinstance(r, str) else json.dumps(r, ensure_ascii=False, default=str)[:20000]
