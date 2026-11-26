"""Template matching (OpenCV) for the Studio: find a saved asset on screen with a confidence score."""
import base64
import re
import time
from pathlib import Path

import cv2
import numpy as np

from ..config import data_dir
from . import capture

METHODS = {"template_fast": cv2.TM_CCOEFF_NORMED, "template_precise": cv2.TM_CCORR_NORMED}


def assets_dir() -> Path:
    p = data_dir() / "assets"; p.mkdir(exist_ok=True); return p


def safe_name(name: str) -> str:
    n = re.sub(r"[^\w\-]+", "_", name).strip("_")[:60]
    if not n:
        raise ValueError("bad asset name")
    return n


def save_asset_from_screen(name: str, region: dict) -> dict:
    img = capture._grab(region)
    if float(np.asarray(img.convert("L")).std()) < 6:
        raise ValueError("Selected region is almost a flat color; pick something more distinctive")
    path = assets_dir() / f"{safe_name(name)}.png"
    img.save(path)
    return {"name": path.stem, "w": img.width, "h": img.height}


def list_assets() -> list[dict]:
    out = []
    for p in sorted(assets_dir().glob("*.png")):
        out.append({"name": p.stem, "b64": base64.b64encode(p.read_bytes()).decode()})
    return out


def delete_asset(name: str) -> None:
    (assets_dir() / f"{safe_name(name)}.png").unlink(missing_ok=True)


def find(name: str, area: dict | None = None, threshold: float = 0.85, method: str = "template_fast", gray: bool = False) -> dict:
    tpl_path = assets_dir() / f"{safe_name(name)}.png"
    if not tpl_path.exists():
        raise FileNotFoundError(f"asset not found: {name}")
    t0 = time.time()
    hay = cv2.cvtColor(np.array(capture._grab(area)), cv2.COLOR_RGB2BGR)
    tpl = cv2.imread(str(tpl_path))
    if float(tpl.std()) < 6:  # featureless template -> matches anywhere, refuse to trust it
        return {"found": False, "confidence": 0.0, "reason": "asset has almost no detail; capture a more distinctive region"}
    if gray:
        hay, tpl = cv2.cvtColor(hay, cv2.COLOR_BGR2GRAY), cv2.cvtColor(tpl, cv2.COLOR_BGR2GRAY)
    if tpl.shape[0] > hay.shape[0] or tpl.shape[1] > hay.shape[1]:
        return {"found": False, "confidence": 0.0, "reason": "template larger than search area"}
    res = cv2.matchTemplate(hay, tpl, METHODS.get(method, cv2.TM_CCOEFF_NORMED))
    _, score, _, loc = cv2.minMaxLoc(res)
    ox, oy = (area["left"], area["top"]) if area else (0, 0)
    h, w = tpl.shape[:2]
    return {"found": score >= threshold, "confidence": round(float(score), 4), "x": ox + loc[0], "y": oy + loc[1], "w": w, "h": h,
            "cx": ox + loc[0] + w // 2, "cy": oy + loc[1] + h // 2, "ms": int((time.time() - t0) * 1000)}
