"""Pure text logic: language guess, text classification, cache. Mirrors the Android app."""
import re
import time
from collections import OrderedDict

MISSION = ["mission", "quest", "objective", "task", "goal", "任务", "クエスト", "目標", "퀘스트", "임무", "objectif", "auftrag", "misión", "objetivo"]
NOTIFY = ["trophy", "unlocked", "saved", "saving", "achievement", "level up", "new item", "obtained", "acquired", "トロフィー", "奖杯", "트로피"]
ITEM = ["ammo", "weapon", "sword", "rifle", "pistol", "shield", "armor", "potion", "damage", "atk", "def", "hp", "mp", "弹药", "武器", "무기"]
_SPEAKER = re.compile(r"^([^\W\d_][^\W\d_ .'\-]{0,24}(?: [^\W\d_][^\W\d_.'\-]{0,24})?)\s*[:：]\s*(.+)$")


def guess_language(text: str) -> str:
    """Script-based language guess (fast, offline)."""
    kana = sum(1 for c in text if "぀" <= c <= "ヿ")
    hangul = sum(1 for c in text if "가" <= c <= "힯")
    cjk = sum(1 for c in text if "一" <= c <= "鿿")
    latin = sum(1 for c in text if c.isascii() and c.isalpha())
    arabic = sum(1 for c in text if "؀" <= c <= "ۿ")
    if kana > 0:
        return "ja"
    if hangul > 0:
        return "ko"
    if cjk > 0:
        return "zh"
    if arabic > latin:
        return "ar"
    return "en" if latin else "und"


def classify(text: str, box, frame_w: int, frame_h: int):
    """Returns (kind, speaker, body). box = (l, t, r, b)."""
    t = text.strip()
    low = t.lower()
    m = _SPEAKER.match(t)
    if m:
        name = m.group(1).strip().lower()
        keyword = any(name == k or name.startswith(k) for k in MISSION + NOTIFY + ITEM)
        if not keyword and len(m.group(2)) > 3:
            return "DIALOG", m.group(1).strip(), m.group(2).strip()
    if any(k in low for k in MISSION):
        return "MISSION", "", t
    if any(k in low for k in NOTIFY):
        return "NOTIFICATION", "", t
    if any(k in low for k in ITEM):
        return "ITEM", "", t
    l, tp, r, b = box
    words = len(t.split())
    cy = ((tp + b) / 2) / max(frame_h, 1)
    cx = ((l + r) / 2) / max(frame_w, 1)
    wide = (r - l) / max(frame_w, 1)
    if cy > 0.65 and wide > 0.35 and words >= 3:
        return "DIALOG", "", t
    if cy < 0.2 and cx > 0.6:
        return "NOTIFICATION", "", t
    if words <= 3 and len(t) <= 24:
        return "MENU", "", t
    if words >= 6:
        return "SIGN", "", t
    return "OTHER", "", t


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[\"'`«»“”]", "", text.lower())).strip()


class TranslationCache:
    """LRU cache + recently-seen window so identical text is never translated or logged twice."""

    def __init__(self, capacity=1000, repeat_window=20.0):
        self.capacity = capacity
        self.repeat_window = repeat_window
        self._map = OrderedDict()
        self._seen = {}

    def get(self, text):
        k = normalize(text)
        if k in self._map:
            self._map.move_to_end(k)
            return self._map[k]
        return None

    def put(self, text, translated):
        k = normalize(text)
        self._map[k] = translated
        self._map.move_to_end(k)
        while len(self._map) > self.capacity:
            self._map.popitem(last=False)

    def seen_recently(self, text, now=None):
        now = time.time() if now is None else now
        k = normalize(text)
        prev = self._seen.get(k)
        self._seen[k] = now
        return prev is not None and now - prev < self.repeat_window

    def __len__(self):
        return len(self._map)
