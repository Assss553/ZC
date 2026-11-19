"""ROX Server pipeline: capture → Safe Vision → OCR → translate → publish to overlay + phones."""
import logging
import threading
import time

from .safevision import Tracker, detect
from .textlogic import classify, guess_language

log = logging.getLogger("rox.engine")


class Engine:
    def __init__(self, capture_factory, ocr, translator, hub, settings=None):
        self.capture_factory = capture_factory
        self.ocr, self.translator, self.hub = ocr, translator, hub
        self.settings = {"interval": 0.7, "ocr_scale": 1.0, "safe": True, "sensitivity": 0.5, "lang": "auto", "translate": True}
        self.settings.update(settings or {})
        self.tracker = Tracker()
        self.running = False
        self.thread = None
        self.state = {"fps": 0.0, "ocr_ms": 0, "lang": "", "frames": 0, "error": ""}
        self.subtitles = []
        self.masks = []
        self.frame_size = (0, 0)
        self.listeners = []  # callables(engine) called after each cycle
        self.history = []
        self.region = None

    def start(self):
        if self.running:
            return
        self.running = True
        self.thread = threading.Thread(target=self._loop, name="rox-engine", daemon=True)
        self.thread.start()

    def stop(self):
        self.running = False
        self.subtitles, self.masks = [], []
        self._publish_status()

    def _publish_status(self):
        self.hub.publish({"type": "status", "running": self.running, **self.state, "frame": list(self.frame_size),
                          "models": dict(getattr(self.translator, "status", {}))})

    def process_frame(self, rgb, now=None):
        """One full analysis cycle on an RGB frame (also used by the tests)."""
        now = time.time() if now is None else now
        h, w = rgb.shape[:2]
        self.frame_size = (w, h)
        s = self.settings
        masks = []
        if s["safe"]:
            dets = detect(rgb[::2, ::2], s["sensitivity"])
            for d in dets:
                d["box"] = tuple(v * 2 for v in d["box"])
            tracks, _ = self.tracker.update(dets, now)
            masks = [{"box": list(t["box"]), "category": t["category"], "id": t["id"]} for t in tracks]
        subs = []
        if s["translate"] and self.ocr is not None:
            t0 = time.time()
            blocks = self.ocr.read(rgb)
            self.state["ocr_ms"] = int((time.time() - t0) * 1000)
            alltext = " ".join(b["text"] for b in blocks)
            lang = s["lang"] if s["lang"] != "auto" else guess_language(alltext)
            self.state["lang"] = lang
            for b in blocks:
                kind, speaker, body = classify(b["text"], b["box"], w, h)
                tr = self.translator.translate(body, lang) if lang not in ("und", "ar") else None
                if not tr:
                    continue
                item = {"original": body, "translated": tr, "kind": kind, "speaker": speaker, "box": list(b["box"])}
                subs.append(item)
                if not self.translator.cache.seen_recently(body, now):
                    self.history.append({"time": now, "lang": lang, **item})
                    self.history = self.history[-3000:]
        self.subtitles, self.masks = subs, masks
        self.state["frames"] += 1
        self.hub.publish({"type": "frame", "frame": [w, h], "subtitles": subs, "masks": masks})
        return subs, masks

    def _loop(self):
        cap = None
        last = 0.0
        frames, t_fps = 0, time.time()
        while self.running:
            try:
                if cap is None:
                    cap = self.capture_factory()
                rgb, self.region = cap.grab()
                self.process_frame(rgb)
                self.state["error"] = ""
                frames += 1
                if time.time() - t_fps >= 2:
                    self.state["fps"] = round(frames / (time.time() - t_fps), 1); frames, t_fps = 0, time.time()
                    self._publish_status()
                for cb in self.listeners:
                    cb(self)
            except Exception as e:
                log.exception("cycle failed")
                self.state["error"] = str(e)
                cap = None
                time.sleep(1)
            dt = time.time() - last
            time.sleep(max(0.0, self.settings["interval"] - dt))
            last = time.time()
        self._publish_status()
