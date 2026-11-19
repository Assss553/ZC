"""The trained detector loads and stays silent on a clean game frame. True-positive accuracy cannot be
verified in CI (no explicit test images are used) — it must be verified by the user on real content."""
import numpy as np

from rox_server.engine import Engine
from rox_server.safevision import NudityDetector
from tests.helpers import game_frame


class Hub:
    def publish(self, m): pass


def test_model_loads_and_clean_frame_has_no_nudity():
    d = NudityDetector()
    assert d.detect(np.full((360, 640, 3), (24, 34, 30), np.uint8), 1.0) == []


def test_engine_masks_regions_returned_by_trained_detector():
    class Fake:
        def detect(self, rgb, sens, sugg=False):
            return [{"box": (100, 100, 200, 200), "score": 0.9, "category": "nudity"}]
    eng = Engine(None, None, None, Hub(), settings={"translate": False}, nudity=Fake())
    subs, masks = eng.process_frame(game_frame(), now=0)
    assert masks and masks[0]["category"] == "nudity" and masks[0]["box"] == [100, 100, 200, 200]
    assert eng.blocked_log[0]["category"] == "nudity"
