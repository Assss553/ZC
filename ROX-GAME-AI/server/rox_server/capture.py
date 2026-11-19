"""Captures the window of the official Remote Play client (chiaki-ng / PS Remote Play for PC).
ROX does not touch the stream protocol: it reads pixels of a window on your own PC."""
import sys

import numpy as np

CLIENT_TITLES = ["chiaki", "ps remote play", "remote play", "playstation"]


def list_windows():
    """[(hwnd, title)] of visible top-level windows (Windows only)."""
    if sys.platform != "win32":
        return []
    import win32gui
    out = []

    def cb(h, _):
        if win32gui.IsWindowVisible(h):
            t = win32gui.GetWindowText(h)
            if t.strip():
                out.append((h, t))
    win32gui.EnumWindows(cb, None)
    return out


def find_client_window():
    for h, t in list_windows():
        if any(k in t.lower() for k in CLIENT_TITLES) and "rox" not in t.lower():
            return h, t
    return None


def window_rect(hwnd):
    import win32gui
    l, t, r, b = win32gui.GetClientRect(hwnd)
    x, y = win32gui.ClientToScreen(hwnd, (0, 0))
    return x, y, x + (r - l), y + (b - t)


class Capture:
    def __init__(self, hwnd=None):
        import mss
        self.sct = mss.mss()
        self.hwnd = hwnd

    def region(self):
        if self.hwnd is not None and sys.platform == "win32":
            l, t, r, b = window_rect(self.hwnd)
            return {"left": l, "top": t, "width": max(1, r - l), "height": max(1, b - t)}
        mon = self.sct.monitors[1]
        return {"left": mon["left"], "top": mon["top"], "width": mon["width"], "height": mon["height"]}

    def grab(self):
        reg = self.region()
        shot = self.sct.grab(reg)
        rgb = np.asarray(shot)[..., :3][..., ::-1].copy()  # BGRA -> RGB
        return rgb, reg
