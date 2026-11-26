"""Custom tools shared by agents: shell commands (risk-gated), app launch."""
import subprocess

from ..config import IS_WINDOWS
from ..events import bus
from ..security.policy import APPROVALS, audit, classify_command, resolve_allowed


def run_command_tool() -> dict:
    return {"name": "run_command", "description": "Run a shell command (PowerShell on Windows) inside an allowed folder. Deleting files, installing software or anything risky requires user approval; security/elevation changes are blocked.",
            "input_schema": {"type": "object", "properties": {"command": {"type": "string"}, "cwd": {"type": "string"},
                             "timeout_s": {"type": "integer"}}, "required": ["command", "cwd"], "additionalProperties": False}}


def open_app_tool() -> dict:
    return {"name": "open_app", "description": "Launch an application or open a file/folder/URL with its default handler (e.g. 'code', 'notepad', a path).",
            "input_schema": {"type": "object", "properties": {"target": {"type": "string"}, "args": {"type": "array", "items": {"type": "string"}}},
                             "required": ["target"], "additionalProperties": False}}


def run_command(actor: str, command: str, cwd: str, timeout_s: int = 300) -> str:
    wd = resolve_allowed(cwd)
    risk = classify_command(command)
    if risk and not APPROVALS.request(actor, risk, {"command": command, "cwd": str(wd)}):
        return f"Denied: '{risk}' action was not approved by the user."
    audit(actor, "run_command", {"command": command, "cwd": str(wd)}, "executed")
    bus.publish("action", {"actor": actor, "action": "run_command", "command": command})
    argv = ["powershell", "-NoProfile", "-NonInteractive", "-Command", command] if IS_WINDOWS else ["bash", "-lc", command]
    try:
        p = subprocess.run(argv, cwd=wd, capture_output=True, text=True, timeout=min(timeout_s or 300, 1800), encoding="utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        return "Timed out"
    out = (p.stdout[-6000:] + ("\n[stderr]\n" + p.stderr[-4000:] if p.stderr else ""))
    return f"exit={p.returncode}\n{out}"


def open_app(actor: str, target: str, args: list[str] | None = None) -> str:
    from ..security.policy import classify_text
    low = target.lower()
    if any(x in low for x in ("regedit", "gpedit", "secpol", "windowsdefender:", "ms-settings:windowsdefender")):
        audit(actor, "open_app", {"target": target}, "blocked"); return "Blocked: security settings are off-limits."
    if low.endswith((".msi", "setup.exe", "installer.exe")) and not APPROVALS.request(actor, "install_software", {"target": target}):
        return "Denied by user."
    audit(actor, "open_app", {"target": target, "args": args}, "executed")
    bus.publish("action", {"actor": actor, "action": "open_app", "target": target})
    if IS_WINDOWS:
        if args:
            subprocess.Popen([target, *args], shell=False)
        else:
            subprocess.Popen(["cmd", "/c", "start", "", target], shell=False)
    else:
        subprocess.Popen(["xdg-open", target])
    return "launched"
