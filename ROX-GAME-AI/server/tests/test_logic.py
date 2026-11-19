import numpy as np

from rox_server.safevision import Tracker, apply_mask, detect
from rox_server.textlogic import TranslationCache, classify, guess_language
from tests.helpers import game_frame


def test_language_guess():
    assert guess_language("We must find the key") == "en"
    assert guess_language("古い鍵を見つけなければならない") == "ja"
    assert guess_language("열쇠를 찾아야 해") == "ko"
    assert guess_language("我们必须找到钥匙") == "zh"


def test_classify():
    assert classify("Elena: We must find the ancient key.", (150, 600, 1100, 650), 1280, 720)[:2] == ("DIALOG", "Elena")
    assert classify("Mission: Reach the old lighthouse", (40, 40, 600, 80), 1280, 720)[0] == "MISSION"
    assert classify("Inventory", (40, 480, 200, 510), 1280, 720)[0] == "MENU"
    assert classify("Trophy unlocked", (980, 30, 1250, 70), 1280, 720)[0] == "NOTIFICATION"


def test_cache():
    c = TranslationCache(repeat_window=10)
    c.put("Hello  World", "مرحبا")
    assert c.get("hello world") == "مرحبا"
    assert not c.seen_recently("x", 0) and c.seen_recently("X", 5) and not c.seen_recently("x", 100)


def test_safevision_detects_tracks_and_masks():
    t = Tracker()
    ids = set()
    for i in range(6):
        frame = game_frame(cx=300 + i * 40)
        dets = detect(frame, 0.5)
        assert len(dets) == 1
        tracks, _ = t.update(dets, i * 0.1)
        ids.add(tracks[0]["id"])
        apply_mask(frame, tracks[0]["box"], "black")
        assert (frame[285, 300 + i * 40] == 0).all()
    assert len(ids) == 1, "same object must keep one track id"
    tracks, _ = t.update([], 5.0)
    assert tracks == []


def test_clean_frame_no_detection():
    assert detect(np.full((360, 640, 3), (24, 34, 30), np.uint8), 1.0) == []
