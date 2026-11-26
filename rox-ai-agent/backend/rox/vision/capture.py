"""Real screen capture (mss) + window enumeration (pygetwindow on Windows)."""
import base64
import io

from PIL import Image

from ..config import IS_WINDOWS

try:
    import mss  # type: ignore
except Exception:  # pragma: no cover
    mss = None


class CaptureUnavailable(RuntimeError):
    pass


def _grab(region: dict | None = None) -> Image.Image:
    if mss is None:
        raise CaptureUnavailable("mss not installed")
    try:
        with (getattr(mss, "MSS", None) or mss.mss)() as sct:
            mon = region or sct.monitors[1]
            raw = sct.grab(mon)
            return Image.frombytes("RGB", raw.size, raw.bgra, "raw", "BGRX")
    except Exception as e:  # no display (e.g. headless server)
        raise CaptureUnavailable(f"Screen capture failed: {e}") from e


def screen_size() -> tuple[int, int]:
    if mss is None:
        raise CaptureUnavailable("mss not installed")
    with (getattr(mss, "MSS", None) or mss.mss)() as sct:
        m = sct.monitors[1]
        return m["width"], m["height"]


def list_windows() -> list[dict]:
    if not IS_WINDOWS:
        return []
    import pygetwindow as gw  # type: ignore
    out = []
    for w in gw.getAllWindows():
        if w.title.strip() and w.width > 50 and w.height > 50 and not w.isMinimized:
            out.append({"title": w.title, "left": w.left, "top": w.top, "width": w.width, "height": w.height})
    return out


def window_region(title: str) -> dict | None:
    for w in list_windows():
        if w["title"] == title:
            return {"left": max(w["left"], 0), "top": max(w["top"], 0), "width": w["width"], "height": w["height"]}
    return None


def focus_window(title: str) -> bool:
    if not IS_WINDOWS:
        return False
    import pygetwindow as gw  # type: ignore
    for w in gw.getWindowsWithTitle(title):
        try:
            w.activate()
            return True
        except Exception:
            return False
    return False


def capture(region: dict | None = None, max_side: int = 1280, quality: int = 70, fmt: str = "JPEG") -> tuple[bytes, tuple[int, int], float]:
    """Returns (bytes, (w,h) after scaling, scale factor real->scaled)."""
    img = _grab(region)
    scale = min(1.0, max_side / max(img.size))
    if scale < 1.0:
        img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, fmt, quality=quality) if fmt == "JPEG" else img.save(buf, fmt)
    return buf.getvalue(), img.size, scale


def capture_b64_png(region: dict | None = None, max_side: int = 1280) -> tuple[str, tuple[int, int], float]:
    data, size, scale = capture(region, max_side=max_side, fmt="PNG")
    return base64.b64encode(data).decode(), size, scale


def frame_diff(a: bytes, b: bytes) -> float:
    """0..1 difference between two encoded frames; used to detect a frozen game."""
    ia = Image.open(io.BytesIO(a)).convert("L").resize((64, 36))
    ib = Image.open(io.BytesIO(b)).convert("L").resize((64, 36))
    pa, pb = ia.tobytes(), ib.tobytes()
    return sum(abs(x - y) for x, y in zip(pa, pb)) / (255 * len(pa))
