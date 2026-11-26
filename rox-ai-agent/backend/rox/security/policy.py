"""Safety layer: emergency stop, approvals, folder allow-list, risky-action classification, audit log."""
import json
import re
import threading
import uuid
from pathlib import Path

from ..storage import db


class EmergencyStop(Exception):
    pass


class _StopFlag:
    def __init__(self) -> None:
        self._ev = threading.Event()

    def trigger(self) -> None:
        self._ev.set()
        audit("user", "emergency_stop", {}, "executed")

    def clear(self) -> None:
        self._ev.clear()

    @property
    def active(self) -> bool:
        return self._ev.is_set()

    def check(self) -> None:
        if self._ev.is_set():
            raise EmergencyStop("Emergency stop is active")


STOP = _StopFlag()


def audit(actor: str, action: str, detail: dict, decision: str) -> None:
    safe = {k: ("<redacted>" if "key" in k.lower() or "password" in k.lower() else v) for k, v in detail.items()}
    db.execute("INSERT INTO audit(ts,actor,action,detail,decision) VALUES(?,?,?,?,?)",
               (db.now(), actor, action, json.dumps(safe, ensure_ascii=False)[:4000], decision))


# ---------- folder permissions ----------
def allowed_folders() -> list[str]:
    return db.get_setting("allowed_folders", [])


def set_allowed_folders(folders: list[str]) -> None:
    db.set_setting("allowed_folders", [str(Path(f).expanduser().resolve()) for f in folders])
    audit("user", "set_allowed_folders", {"folders": folders}, "executed")


def resolve_allowed(path: str, base: str | None = None) -> Path:
    p = Path(path).expanduser()
    if not p.is_absolute() and base:
        p = Path(base) / p
    p = p.resolve()
    for f in allowed_folders():
        root = Path(f)
        if p == root or root in p.parents:
            return p
    raise PermissionError(f"Path is outside allowed folders: {p}")


# ---------- risky actions ----------
RISK_PATTERNS = [
    (r"\b(del|erase|rmdir|rd|remove-item|rm)\b", "delete_files"),
    (r"\b(format|diskpart|bcdedit|cipher\s+/w)\b", "system_destructive"),
    (r"\b(winget|choco|scoop|msiexec|pip\s+install|npm\s+(i|install)\s+-g|setup\.exe)\b", "install_software"),
    (r"\b(set-mppreference|netsh\s+advfirewall|reg\s+(add|delete)|set-executionpolicy|uac)\b", "security_settings"),
    (r"\b(runas|start-process\b.*-verb\s+runas)\b", "elevation"),
    (r"\b(shutdown|restart-computer)\b", "power"),
]
BLOCKED = {"system_destructive", "security_settings", "elevation"}
TEXT_RISK = [
    (r"(buy|purchase|checkout|pay|payment|اشتر|ادفع|شراء|دفع)", "financial"),
    (r"(send message|send email|post |أرسل|ارسل|نشر)", "send_message"),
]


def classify_command(cmd: str) -> str | None:
    low = cmd.lower()
    for pat, cat in RISK_PATTERNS:
        if re.search(pat, low):
            return cat
    return None


def classify_text(text: str) -> str | None:
    low = text.lower()
    for pat, cat in TEXT_RISK:
        if re.search(pat, low):
            return cat
    return None


# ---------- approvals (UI answers via /api/approvals) ----------
class Approvals:
    def __init__(self) -> None:
        self._pending: dict[str, dict] = {}
        self._cv = threading.Condition()

    def request(self, actor: str, category: str, detail: dict, timeout: float = 300) -> bool:
        if category in BLOCKED:
            audit(actor, category, detail, "blocked")
            return False
        aid = uuid.uuid4().hex[:10]
        with self._cv:
            self._pending[aid] = {"id": aid, "actor": actor, "category": category, "detail": detail, "answer": None}
            from ..events import bus
            bus.publish("approval", self._pending[aid])
            ok = self._cv.wait_for(lambda: self._pending[aid]["answer"] is not None or STOP.active, timeout)
            answer = self._pending.pop(aid)["answer"] if ok else None
        decision = "approved" if answer else "denied"
        audit(actor, category, detail, decision)
        return bool(answer)

    def answer(self, aid: str, approve: bool) -> bool:
        with self._cv:
            if aid not in self._pending:
                return False
            self._pending[aid]["answer"] = approve
            self._cv.notify_all()
            return True

    def pending(self) -> list[dict]:
        with self._cv:
            return list(self._pending.values())

    def wake(self) -> None:
        with self._cv:
            self._cv.notify_all()


APPROVALS = Approvals()
