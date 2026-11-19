"""Transparent, click-through, always-on-top window drawn over the Remote Play client window:
Arabic subtitles + Safe Vision masks. Windows only (uses WS_EX_LAYERED | WS_EX_TRANSPARENT)."""
import sys
import tkinter as tk

KEY = "#010101"


class Overlay:
    def __init__(self, root):
        self.win = tk.Toplevel(root)
        self.win.overrideredirect(True)
        self.win.attributes("-topmost", True)
        self.win.configure(bg=KEY)
        if sys.platform == "win32":
            self.win.attributes("-transparentcolor", KEY)
        self.canvas = tk.Canvas(self.win, bg=KEY, highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.win.update_idletasks()
        self._click_through()
        self.win.withdraw()
        self.visible = False

    def _click_through(self):
        if sys.platform != "win32":
            return
        import ctypes
        hwnd = ctypes.windll.user32.GetParent(self.win.winfo_id())
        GWL_EXSTYLE, WS_EX_LAYERED, WS_EX_TRANSPARENT = -20, 0x80000, 0x20
        style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
        ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED | WS_EX_TRANSPARENT)
        # Exclude the overlay from screen capture (Windows 10 2004+), so ROX never re-reads its own subtitles/masks
        WDA_EXCLUDEFROMCAPTURE = 0x11
        ctypes.windll.user32.SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)

    def show(self, region):
        self.win.geometry(f"{region['width']}x{region['height']}+{region['left']}+{region['top']}")
        if not self.visible:
            self.win.deiconify(); self.visible = True

    def hide(self):
        if self.visible:
            self.win.withdraw(); self.visible = False

    def draw(self, subtitles, masks, frame_size):
        c = self.canvas
        c.delete("all")
        W, H = self.win.winfo_width(), self.win.winfo_height()
        fw, fh = frame_size
        if fw == 0:
            return
        sx, sy = W / fw, H / fh
        for m in masks:
            l, t, r, b = m["box"]
            c.create_rectangle(l * sx, t * sy, r * sx, b * sy, fill="#000000", outline="")
        lines = [((s["speaker"] + ": ") if s["speaker"] else "") + s["translated"] for s in subtitles if s["kind"] in ("DIALOG", "MISSION", "NOTIFICATION", "SIGN", "OTHER")][:4]
        if not lines:
            return
        text = "\n".join(lines)
        y = H - 40
        item = c.create_text(W / 2, y, text=text, fill="#FFFFFF", font=("Segoe UI", max(14, int(H / 34)), "bold"), anchor="s", justify="center", width=W * 0.9)
        x1, y1, x2, y2 = c.bbox(item)
        bg = c.create_rectangle(x1 - 14, y1 - 8, x2 + 14, y2 + 8, fill="#0A0A0A", outline="#FF7A00", width=2)
        c.tag_lower(bg, item)
