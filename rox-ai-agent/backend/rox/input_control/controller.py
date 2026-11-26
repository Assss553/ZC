"""Mouse/keyboard control via pyautogui. Every call checks the emergency stop and is audited."""
import time

from ..config import IS_WINDOWS
from ..events import bus
from ..security.policy import STOP, audit

try:
    import pyautogui  # type: ignore
    pyautogui.FAILSAFE = True  # slam mouse into a corner = abort
    pyautogui.PAUSE = 0.05
except Exception:  # headless / non-windows
    pyautogui = None


class InputUnavailable(RuntimeError):
    pass


def _need():
    STOP.check()
    if pyautogui is None:
        raise InputUnavailable("pyautogui unavailable (needs a Windows desktop session)")
    return pyautogui


def _log(actor: str, action: str, **kw):
    audit(actor, "input." + action, kw, "executed")
    bus.publish("action", {"actor": actor, "action": action, **kw})


KEY_ALIASES = {"return": "enter", "esc": "escape", "super": "win", "cmd": "win", "page_up": "pageup",
               "page_down": "pagedown", "ctrl_l": "ctrl", "control": "ctrl", "del": "delete"}


def _keys(combo: str) -> list[str]:
    return [KEY_ALIASES.get(k.strip().lower(), k.strip().lower()) for k in combo.replace("+", " ").split()]


def move(x: int, y: int, actor="agent"):
    _need().moveTo(x, y, duration=0.1); _log(actor, "move", x=x, y=y)


def click(x: int | None, y: int | None, button="left", clicks=1, actor="agent"):
    g = _need()
    if x is not None and y is not None:
        g.click(x, y, clicks=clicks, interval=0.08, button=button)
    else:
        g.click(clicks=clicks, interval=0.08, button=button)
    _log(actor, "click", x=x, y=y, button=button, clicks=clicks)


def mouse_down(button="left", actor="agent"):
    _need().mouseDown(button=button); _log(actor, "mouse_down", button=button)


def mouse_up(button="left", actor="agent"):
    _need().mouseUp(button=button); _log(actor, "mouse_up", button=button)


def drag(x1, y1, x2, y2, actor="agent"):
    g = _need(); g.moveTo(x1, y1); g.dragTo(x2, y2, duration=0.4, button="left")
    _log(actor, "drag", frm=[x1, y1], to=[x2, y2])


def scroll(x, y, direction: str, amount: int = 3, actor="agent"):
    g = _need()
    if x is not None:
        g.moveTo(x, y)
    if direction in ("up", "down"):
        g.scroll(amount * 120 * (1 if direction == "up" else -1))
    else:
        g.hscroll(amount * 120 * (1 if direction == "right" else -1))
    _log(actor, "scroll", direction=direction, amount=amount)


def type_text(text: str, actor="agent"):
    g = _need()
    if text.isascii():
        g.write(text, interval=0.01)
    else:  # Arabic/Unicode: paste via clipboard
        _paste(text)
    _log(actor, "type", chars=len(text))


def _paste(text: str):
    if IS_WINDOWS:
        import ctypes  # noqa: F401
        import subprocess
        subprocess.run(["clip"], input=text.encode("utf-16-le"), check=True)
        pyautogui.hotkey("ctrl", "v")
    else:
        pyautogui.write(text)


def key(combo: str, actor="agent"):
    _need().hotkey(*_keys(combo)); _log(actor, "key", combo=combo)


def hold_key(combo: str, seconds: float, actor="agent"):
    g = _need(); ks = _keys(combo)
    for k in ks:
        g.keyDown(k)
    end = time.time() + min(seconds, 10)
    try:
        while time.time() < end:
            STOP.check(); time.sleep(0.05)
    finally:
        for k in reversed(ks):
            g.keyUp(k)
    _log(actor, "hold_key", combo=combo, seconds=seconds)


def cursor() -> tuple[int, int]:
    p = _need().position(); return int(p[0]), int(p[1])


def release_all():
    """Emergency: release held keys/buttons."""
    if pyautogui is None:
        return
    for k in ("shift", "ctrl", "alt", "win", "w", "a", "s", "d", "space"):
        try: pyautogui.keyUp(k)
        except Exception: pass
    for b in ("left", "right", "middle"):
        try: pyautogui.mouseUp(button=b)
        except Exception: pass
