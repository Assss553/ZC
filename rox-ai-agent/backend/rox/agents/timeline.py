"""Timeline (macro) engine for the Studio: ordered actions — target (find asset), click, key, type, delay.
Runs as a normal task: pause / resume / stop / emergency stop / audit all apply."""
import time

from ..input_control import controller as ic
from ..storage import db
from ..vision import match

ACTIONS = {"target", "click", "key", "type", "delay", "wait_target"}


def get_all() -> list[dict]:
    return db.get_setting("timelines", [])


def save_all(tls: list[dict]) -> None:
    for t in tls:
        for a in t.get("actions", []):
            if a.get("type") not in ACTIONS:
                raise ValueError(f"unknown action {a.get('type')}")
    db.set_setting("timelines", tls)


def handle(ctx, row):
    st = ctx.load_state()
    tl = next((t for t in get_all() if t["id"] == st.get("timeline_id")), None)
    if not tl:
        raise RuntimeError("timeline not found")
    loops = max(1, int(st.get("loops", 1)))
    acts = tl["actions"]
    last = None  # last found target center
    for n in range(loops if not row["end_at"] else 10**9):
        for i, a in enumerate(acts):
            ctx.checkpoint()
            ctx.set_progress((i + 1) / max(len(acts), 1))
            t = a["type"]
            if t in ("target", "wait_target"):
                deadline = time.time() + (a.get("timeout_ms", 0) / 1000 if t == "wait_target" else 0)
                while True:
                    r = match.find(a["asset"], a.get("area"), a.get("threshold", 0.85), a.get("method", "template_fast"))
                    if r["found"] or time.time() >= deadline:
                        break
                    ctx.checkpoint(); time.sleep(0.25)
                ctx.log("info", f"[{n+1}.{i+1}] target {a['asset']}: {r['confidence']:.0%} {'✓' if r['found'] else '✗'}")
                last = (r["cx"], r["cy"]) if r["found"] else None
                if not r["found"] and a.get("required", True):
                    ctx.log("warn", "Target not found — skipping rest of this pass"); break
            elif t == "click":
                xy = (a["x"], a["y"]) if a.get("x") is not None else last
                if xy is None:
                    ctx.log("warn", "click: no coordinates and no previous target"); continue
                ic.click(*xy, button=a.get("button", "left"), clicks=a.get("clicks", 1), actor="timeline")
            elif t == "key":
                ic.key(a["keys"], actor="timeline")
            elif t == "type":
                ic.type_text(a["text"], actor="timeline")
            elif t == "delay":
                end = time.time() + a.get("ms", 1000) / 1000
                while time.time() < end:
                    ctx.checkpoint(); time.sleep(0.05)
        ctx.save_state({**st, "pass": n + 1})
