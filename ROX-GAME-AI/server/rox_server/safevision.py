"""Safe Vision on the PC (numpy). Heuristic exposed-skin regions + IoU tracker, like the phone app."""
import numpy as np


def skin_mask(rgb: np.ndarray) -> np.ndarray:
    r = rgb[..., 0].astype(np.float32); g = rgb[..., 1].astype(np.float32); b = rgb[..., 2].astype(np.float32)
    y = 0.299 * r + 0.587 * g + 0.114 * b
    cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
    cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
    return (y > 45) & (cb >= 77) & (cb <= 127) & (cr >= 135) & (cr <= 173) & (r > g) & (r > b)


def detect(rgb: np.ndarray, sensitivity=0.5, cell=8):
    h, w = rgb.shape[:2]
    gh, gw = h // cell, w // cell
    if gh == 0 or gw == 0:
        return []
    m = skin_mask(rgb[: gh * cell, : gw * cell]).reshape(gh, cell, gw, cell).mean(axis=(1, 3))
    on = m >= (0.75 - 0.4 * sensitivity)
    min_cells = max(4, int(24 - 18 * sensitivity))
    seen = np.zeros_like(on)
    out = []
    for y0 in range(gh):
        for x0 in range(gw):
            if not on[y0, x0] or seen[y0, x0]:
                continue
            stack = [(y0, x0)]; seen[y0, x0] = True; cells = []
            while stack:
                y, x = stack.pop(); cells.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < gh and 0 <= nx < gw and on[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; stack.append((ny, nx))
            if len(cells) < min_cells:
                continue
            ys = [c[0] for c in cells]; xs = [c[1] for c in cells]
            box = (min(xs) * cell, min(ys) * cell, (max(xs) + 1) * cell, (max(ys) + 1) * cell)
            if (box[2] - box[0]) * (box[3] - box[1]) > 0.85 * w * h:
                continue
            out.append({"box": box, "score": float(np.mean([m[c] for c in cells])), "category": "exposed_skin"})
    return out


def iou(a, b):
    l, t, r, bt = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, r - l) * max(0, bt - t)
    if inter == 0:
        return 0.0
    area = lambda x: (x[2] - x[0]) * (x[3] - x[1])
    return inter / (area(a) + area(b) - inter)


class Tracker:
    def __init__(self, hold=0.9, thr=0.15):
        self.hold, self.thr, self.tracks, self.next_id = hold, thr, [], 1

    def update(self, dets, now):
        used = set(); new_tracks = []
        for t in self.tracks:
            best, bi = self.thr, -1
            for i, d in enumerate(dets):
                if i not in used and iou(t["box"], d["box"]) > best:
                    best, bi = iou(t["box"], d["box"]), i
            if bi >= 0:
                used.add(bi); t = dict(t, box=dets[bi]["box"], last=now, hits=t["hits"] + 1); new_tracks.append(t)
            elif now - t["last"] <= self.hold:
                new_tracks.append(t)
        fresh = []
        for i, d in enumerate(dets):
            if i not in used:
                t = {"id": self.next_id, "box": d["box"], "category": d["category"], "last": now, "hits": 1}
                self.next_id += 1; new_tracks.append(t); fresh.append(t)
        self.tracks = new_tracks
        return self.tracks, fresh


def apply_mask(rgb: np.ndarray, box, mode="blur", strength=18, pad=0.15):
    h, w = rgb.shape[:2]
    l, t, r, b = box
    dx, dy = int((r - l) * pad), int((b - t) * pad)
    l, t, r, b = max(0, l - dx), max(0, t - dy), min(w, r + dx), min(h, b + dy)
    if r <= l or b <= t:
        return rgb
    roi = rgb[t:b, l:r]
    if mode == "black":
        roi[:] = 0
    else:
        k = max(2, strength)
        small = roi[::k, ::k]
        up = np.repeat(np.repeat(small, k, axis=0), k, axis=1)[: roi.shape[0], : roi.shape[1]]
        roi[:] = up
    return rgb
