"""ROX Server GUI (Arabic). Run: python -m rox_server.app"""
import logging
import queue
import sys
import threading
import tkinter as tk
import webbrowser
from tkinter import ttk

from . import __version__
from .net import Hub, lan_ip, run_in_thread

BLACK, PANEL, ORANGE, WHITE, GREY = "#0A0A0A", "#161616", "#FF7A00", "#FFFFFF", "#B5B5B5"
CHIAKI_URL = "https://github.com/streetpea/chiaki-ng/releases/latest"
LANGS = [("تلقائي", "auto"), ("English", "en"), ("日本語", "ja"), ("中文", "zh"), ("한국어", "ko"), ("Français", "fr"), ("Deutsch", "de"), ("Español", "es")]

log_q = queue.Queue()


class QHandler(logging.Handler):
    def emit(self, record):
        log_q.put(self.format(record))


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    h = QHandler(); h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s", "%H:%M:%S"))
    logging.getLogger().addHandler(h)
    log = logging.getLogger("rox.app")

    hub = Hub(name=f"ROX Server ({lan_ip()})")
    run_in_thread(hub)

    root = tk.Tk()
    root.title(f"ROX Server {__version__}")
    root.geometry("560x720")
    root.configure(bg=BLACK)
    style = ttk.Style(); style.theme_use("clam")
    style.configure("TCombobox", fieldbackground=PANEL, background=PANEL, foreground=WHITE)

    def label(parent, text, size=11, color=WHITE, bold=False):
        return tk.Label(parent, text=text, bg=parent["bg"], fg=color, font=("Segoe UI", size, "bold" if bold else "normal"), justify="right", anchor="e", wraplength=500)

    def button(parent, text, cmd, primary=True):
        return tk.Button(parent, text=text, command=cmd, bg=ORANGE if primary else PANEL, fg=BLACK if primary else WHITE,
                         activebackground=ORANGE, relief="flat", font=("Segoe UI", 11, "bold"), padx=14, pady=6)

    def card(title):
        f = tk.Frame(root, bg=PANEL, padx=12, pady=10)
        f.pack(fill="x", padx=12, pady=6)
        label(f, title, 12, ORANGE, True).pack(fill="x")
        return f

    label(root, "ROX SERVER", 20, WHITE, True).pack(fill="x", padx=12, pady=(12, 0))
    status_var = tk.StringVar(value=f"عنوان السيرفر على شبكتك: {lan_ip()}:{hub.port}")
    label(root, "", 10, GREY).pack()
    tk.Label(root, textvariable=status_var, bg=BLACK, fg=GREY, font=("Segoe UI", 10)).pack(fill="x", padx=12)

    c1 = card("1) ربط السوني واللعب على الكمبيوتر")
    label(c1, "اضغط الزر: يثبّت ROX عميل Remote Play الرسمي مفتوح المصدر (chiaki-ng) ويشغّله. سجّل الدخول في صفحة Sony الرسمية التي تظهر، ثم أدخل رمز الاقتران من البلايستيشن: الإعدادات ← إعدادات الاتصال بالتشغيل عن بُعد ← إضافة جهاز. ROX لا يرى بريدك أو كلمة مرورك. بعد ظهور اللعبة يبدأ ROX تلقائيًا.", 10, GREY).pack(fill="x")
    rp_var = tk.StringVar(value="")
    tk.Label(c1, textvariable=rp_var, bg=PANEL, fg=ORANGE, font=("Segoe UI", 10), anchor="e").pack(fill="x")

    def connect_sony():
        from . import remoteplay

        def work():
            try:
                exe = remoteplay.install(lambda m: root.after(0, rp_var.set, m))
                root.after(0, rp_var.set, "تم التشغيل — سجّل الدخول واقترن بجهازك، ثم ابدأ البث")
                remoteplay.launch(exe)
                root.after(0, wait_for_stream)
            except Exception as e:
                log.exception("Remote Play setup failed")
                root.after(0, rp_var.set, f"خطأ: {e}")
        threading.Thread(target=work, daemon=True).start()

    def wait_for_stream(tries=[0]):
        """Auto-detect the stream window and AUTO START (checks every 3 s for 10 min)."""
        from .capture import find_client_window
        found = find_client_window()
        if found and "engine" not in engine_box or (found and not engine_box["engine"].running):
            refresh(); win_var.set(found[1]); rp_var.set("تم اكتشاف نافذة اللعبة — بدء ROX تلقائيًا"); start(); return
        tries[0] += 1
        if tries[0] < 200:
            root.after(3000, wait_for_stream)

    button(c1, "ربط السوني والعب على الكمبيوتر", connect_sony).pack(anchor="e", pady=4)
    button(c1, "الموقع الرسمي لـ chiaki-ng", lambda: webbrowser.open(CHIAKI_URL), False).pack(anchor="e")

    c2 = card("2) نافذة اللعبة")
    win_var = tk.StringVar()
    combo = ttk.Combobox(c2, textvariable=win_var, state="readonly", width=60)
    combo.pack(fill="x", pady=4)
    windows = {}

    def refresh():
        from .capture import find_client_window, list_windows
        windows.clear()
        items = ["الشاشة كاملة"]
        windows["الشاشة كاملة"] = None
        for hw, t in list_windows():
            windows[t] = hw; items.append(t)
        combo["values"] = items
        found = find_client_window()
        win_var.set(found[1] if found else items[0])
    button(c2, "تحديث القائمة", refresh, False).pack(anchor="e")

    c3 = card("3) الإعدادات")
    lang_var = tk.StringVar(value=LANGS[0][0])
    row = tk.Frame(c3, bg=PANEL); row.pack(fill="x")
    ttk.Combobox(row, textvariable=lang_var, values=[l[0] for l in LANGS], state="readonly", width=14).pack(side="left")
    label(row, "لغة اللعبة").pack(side="right")
    safe_var = tk.BooleanVar(value=True)
    tk.Checkbutton(c3, text="تفعيل Safe Vision (حجب المشاهد)", variable=safe_var, bg=PANEL, fg=WHITE, selectcolor=BLACK, activebackground=PANEL, anchor="e").pack(fill="x")
    overlay_var = tk.BooleanVar(value=True)
    tk.Checkbutton(c3, text="عرض الترجمة فوق نافذة اللعبة على الكمبيوتر", variable=overlay_var, bg=PANEL, fg=WHITE, selectcolor=BLACK, activebackground=PANEL, anchor="e").pack(fill="x")

    engine_box = {}
    overlay_box = {}

    def start():
        try:
            from .capture import Capture
            from .engine import Engine
            from .ocr import OCR
            from .overlay import Overlay
            from .translate import Translator
        except Exception as e:
            log.exception("missing component"); status_var.set(f"خطأ: {e}"); return
        hwnd = windows.get(win_var.get())
        lang = dict(LANGS)[lang_var.get()]
        if "engine" not in engine_box:
            status_var.set("جارٍ تحميل محركات الذكاء الاصطناعي…"); root.update()
            tr = Translator("ar")
            engine_box["engine"] = Engine(lambda: Capture(hwnd), OCR(), tr, hub)
            overlay_box["o"] = Overlay(root)
            threading.Thread(target=lambda: tr.prepare(lang if lang != "auto" else "en"), daemon=True).start()
        eng = engine_box["engine"]
        eng.capture_factory = lambda: Capture(hwnd)
        eng.settings.update(lang=lang, safe=safe_var.get())
        eng.start()
        status_var.set(f"يعمل — {lan_ip()}:{hub.port} — المعالج: {eng.translator.device}")
        log.info("ROX Server started on window: %s", win_var.get())

    def stop():
        if "engine" in engine_box:
            engine_box["engine"].stop()
        if "o" in overlay_box:
            overlay_box["o"].hide()
        status_var.set("متوقف")

    rowb = tk.Frame(root, bg=BLACK); rowb.pack(fill="x", padx=12, pady=6)
    button(rowb, "AUTO START", start).pack(side="right", padx=4)
    button(rowb, "STOP", stop, False).pack(side="right", padx=4)

    c4 = card("الترجمة الحالية")
    subs_var = tk.StringVar(value="—")
    tk.Label(c4, textvariable=subs_var, bg=PANEL, fg=WHITE, font=("Segoe UI", 12), justify="right", anchor="e", wraplength=500).pack(fill="x")

    logs = tk.Text(root, height=8, bg=PANEL, fg=GREY, relief="flat", font=("Consolas", 9))
    logs.pack(fill="both", expand=True, padx=12, pady=(0, 12))

    follow = {"n": 0}

    def follow_stream_window(eng):
        """Every ~3 s: if a bigger Remote Play window appeared (the stream), capture that one."""
        follow["n"] += 1
        if follow["n"] % 10 or not eng.running or sys.platform != "win32":
            return
        from .capture import Capture, find_client_window
        found = find_client_window()
        if found and windows.get(win_var.get()) != found[0]:
            windows[found[1]] = found[0]; win_var.set(found[1])
            eng.capture_factory = lambda h=found[0]: Capture(h); eng.capture_version += 1
            log.info("Switched capture to window: %s", found[1])

    def tick():
        while not log_q.empty():
            logs.insert("end", log_q.get() + "\n"); logs.see("end")
        eng = engine_box.get("engine")
        if eng and eng.running:
            follow_stream_window(eng)
            subs_var.set("\n".join(((s["speaker"] + ": ") if s["speaker"] else "") + s["translated"] for s in eng.subtitles[:6]) or "—")
            o = overlay_box.get("o")
            if o and overlay_var.get():
                try:
                    if eng.region:
                        o.show(eng.region); o.draw(eng.subtitles, eng.masks, eng.frame_size)
                except Exception as e:
                    log.warning("overlay: %s", e)
            elif o:
                o.hide()
            status_var.set(f"يعمل — {lan_ip()}:{hub.port} — هواتف متصلة: {len(hub.clients)} — {eng.state['fps']} إطار/ث — OCR {eng.state['ocr_ms']}ms — اللغة {eng.state['lang']}")
        root.after(300, tick)

    refresh()
    tick()
    root.protocol("WM_DELETE_WINDOW", lambda: (stop(), root.destroy()))
    root.mainloop()


if __name__ == "__main__":
    sys.exit(main())
