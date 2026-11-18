"""ROX Game Translator - مترجم الألعاب الفوري إلى العربية.

يلتقط نافذة اللعبة (PS Remote Play أو جهاز التقاط)، يقرأ النص بـ OCR،
يترجمه للعربية ويعرضه في نافذة شفافة فوق اللعبة.
"""
import json
import os
import threading
import time
import tkinter as tk

import arabic_reshaper
import mss
import numpy as np
from bidi.algorithm import get_display
from deep_translator import GoogleTranslator
from PIL import Image

CONFIG_FILE = os.path.join(os.path.dirname(__file__), "config.json")
CACHE_FILE = os.path.join(os.path.dirname(__file__), "cache.json")
DEFAULTS = {"source_lang": "en", "interval": 1.0, "min_conf": 0.4,
            "font_size": 22, "region": None}


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def ar(text):
    """تشكيل الحروف العربية وترتيبها لتظهر صحيحة في tkinter."""
    return get_display(arabic_reshaper.reshape(text))


class RegionPicker:
    """شاشة كاملة شفافة يحدد فيها المستخدم منطقة النص بالسحب."""

    def __init__(self, root):
        self.result = None
        self.win = tk.Toplevel(root)
        self.win.attributes("-fullscreen", True)
        self.win.attributes("-alpha", 0.3)
        self.win.attributes("-topmost", True)
        self.cv = tk.Canvas(self.win, bg="black", cursor="cross")
        self.cv.pack(fill="both", expand=True)
        self.cv.create_text(self.win.winfo_screenwidth() // 2, 60, fill="white",
                            font=("Arial", 26),
                            text=ar("اسحب بالماوس حول منطقة الحوار / القوائم  -  Esc للإلغاء"))
        self.cv.bind("<ButtonPress-1>", self.down)
        self.cv.bind("<B1-Motion>", self.move)
        self.cv.bind("<ButtonRelease-1>", self.up)
        self.win.bind("<Escape>", lambda e: self.win.destroy())
        self.rect = None
        self.win.grab_set()
        root.wait_window(self.win)

    def down(self, e):
        self.x0, self.y0 = e.x_root, e.y_root
        self.rect = self.cv.create_rectangle(e.x, e.y, e.x, e.y, outline="red", width=3)

    def move(self, e):
        self.cv.coords(self.rect, self.x0 - self.win.winfo_rootx(), self.y0 - self.win.winfo_rooty(),
                       e.x, e.y)

    def up(self, e):
        x1, y1 = min(self.x0, e.x_root), min(self.y0, e.y_root)
        x2, y2 = max(self.x0, e.x_root), max(self.y0, e.y_root)
        if x2 - x1 > 20 and y2 - y1 > 10:
            self.result = {"left": x1, "top": y1, "width": x2 - x1, "height": y2 - y1}
        self.win.destroy()


class Translator:
    def __init__(self, cfg):
        self.cfg = cfg
        self.cache = load_json(CACHE_FILE, {})
        self.gt = GoogleTranslator(source=cfg["source_lang"], target="ar")
        print("تحميل محرك قراءة النص (أول مرة قد تأخذ دقيقة)...")
        import easyocr
        langs = ["en"] if cfg["source_lang"] in ("en", "auto") else [cfg["source_lang"], "en"]
        self.reader = easyocr.Reader(langs, gpu=False)

    def read(self, img):
        res = self.reader.readtext(np.array(img), paragraph=False)
        res = [r for r in res if r[2] >= self.cfg["min_conf"]]
        res.sort(key=lambda r: (round(r[0][0][1] / 20), r[0][0][0]))  # ترتيب سطر بسطر
        lines, last_y = [], None
        for box, txt, _ in res:
            y = box[0][1]
            if last_y is not None and abs(y - last_y) < 20:
                lines[-1] += " " + txt
            else:
                lines.append(txt)
            last_y = y
        return "\n".join(lines).strip()

    def translate(self, text):
        key = text.lower()
        if key in self.cache:  # القوائم والكلمات المتكررة تُترجم مرة واحدة
            return self.cache[key]
        try:
            out = self.gt.translate(text) or ""
        except Exception as e:  # مشكلة إنترنت مثلاً
            return f"[خطأ في الترجمة: {e}]"
        self.cache[key] = out
        if len(self.cache) % 10 == 0:
            save_json(CACHE_FILE, self.cache)
        return out


class App:
    def __init__(self):
        self.cfg = {**DEFAULTS, **load_json(CONFIG_FILE, {})}
        self.root = tk.Tk()
        self.root.title("ROX Game Translator")
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 0.85)
        self.root.configure(bg="#111")
        self.root.geometry("900x220+100+50")

        bar = tk.Frame(self.root, bg="#222")
        bar.pack(fill="x")
        for label, cmd in [("تحديد المنطقة", self.pick), ("تشغيل/إيقاف", self.toggle),
                           ("أصغر", lambda: self.font(-2)), ("أكبر", lambda: self.font(2))]:
            tk.Button(bar, text=ar(label), command=cmd, bg="#333", fg="white",
                      relief="flat").pack(side="right", padx=3, pady=3)
        self.status = tk.Label(bar, text="", bg="#222", fg="#0f0")
        self.status.pack(side="left", padx=6)

        self.label = tk.Label(self.root, text=ar("اضغط \"تحديد المنطقة\" ثم \"تشغيل\""),
                              bg="#111", fg="white", justify="right", anchor="ne",
                              font=("Arial", self.cfg["font_size"], "bold"), wraplength=880)
        self.label.pack(fill="both", expand=True, padx=10, pady=6)
        self.root.bind("<Configure>", lambda e: self.label.config(wraplength=self.root.winfo_width() - 20))
        self.root.bind("<F8>", lambda e: self.toggle())

        self.running = False
        self.engine = None
        self.last_text = ""
        self.root.protocol("WM_DELETE_WINDOW", self.quit)

    def font(self, d):
        self.cfg["font_size"] = max(10, self.cfg["font_size"] + d)
        self.label.config(font=("Arial", self.cfg["font_size"], "bold"))
        save_json(CONFIG_FILE, self.cfg)

    def pick(self):
        self.root.withdraw()
        r = RegionPicker(self.root).result
        self.root.deiconify()
        if r:
            self.cfg["region"] = r
            save_json(CONFIG_FILE, self.cfg)
            self.set_status("تم حفظ المنطقة")

    def set_status(self, t):
        self.status.config(text=ar(t))

    def show(self, t):
        self.root.after(0, lambda: self.label.config(text=ar(t)))

    def toggle(self):
        if not self.cfg["region"]:
            return self.set_status("حدد المنطقة أولاً")
        self.running = not self.running
        self.set_status("يعمل... (F8 للإيقاف)" if self.running else "متوقف")
        if self.running:
            threading.Thread(target=self.loop, daemon=True).start()

    def loop(self):
        if self.engine is None:
            self.show("جاري تحميل المحرك...")
            self.engine = Translator(self.cfg)
        with mss.mss() as sct:
            while self.running:
                shot = sct.grab(self.cfg["region"])
                img = Image.frombytes("RGB", shot.size, shot.rgb)
                text = self.engine.read(img)
                if text and text != self.last_text:  # لا نعيد الترجمة إذا لم يتغير الحوار
                    self.last_text = text
                    self.show(self.engine.translate(text))
                time.sleep(self.cfg["interval"])

    def quit(self):
        self.running = False
        if self.engine:
            save_json(CACHE_FILE, self.engine.cache)
        self.root.destroy()


if __name__ == "__main__":
    App().root.mainloop()
