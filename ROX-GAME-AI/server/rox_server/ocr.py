"""On-PC OCR with RapidOCR (PaddleOCR models on ONNX Runtime). GPU via onnxruntime-directml/cuda if installed."""
import logging

import numpy as np

log = logging.getLogger("rox.ocr")


class OCR:
    def __init__(self):
        from rapidocr_onnxruntime import RapidOCR
        self.engine = RapidOCR()

    def read(self, rgb: np.ndarray, scale_back: float = 1.0):
        """Returns list of dict(text, box=(l,t,r,b), score)."""
        result, _ = self.engine(rgb)
        out = []
        for item in result or []:
            pts, text, score = item[0], item[1], float(item[2])
            if not text or len(text.strip()) < 2 or score < 0.5:
                continue
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            box = (int(min(xs) * scale_back), int(min(ys) * scale_back), int(max(xs) * scale_back), int(max(ys) * scale_back))
            out.append({"text": text.strip(), "box": box, "score": score})
        return merge_lines(out)


def merge_lines(blocks, gap=1.2):
    """Merge OCR lines that belong to the same paragraph (dialogue boxes span several lines)."""
    blocks = sorted(blocks, key=lambda b: (b["box"][1], b["box"][0]))
    merged = []
    for b in blocks:
        if merged:
            m = merged[-1]
            ml, mt, mr, mb = m["box"]
            l, t, r, b2 = b["box"]
            h = mb - mt
            if 0 <= t - mb < h * gap and abs(l - ml) < h * 2:
                m["text"] += " " + b["text"]
                m["box"] = (min(ml, l), mt, max(mr, r), max(mb, b2))
                continue
        merged.append(dict(b))
    return merged
