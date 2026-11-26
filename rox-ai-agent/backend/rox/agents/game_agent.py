"""AI Game Agent: select window -> capture -> understand -> plan -> act -> observe -> correct -> log."""
import time

from ..events import bus
from ..security.policy import audit
from ..vision import capture
from . import computer_use as cu
from . import runtime
from .game_adapters.base import ADAPTERS

SYSTEM = """You are ROX Game Agent playing a single-player game for the user, who is watching.
Game: {name}. {hints}
The screenshots show ONLY the game window; coordinates are relative to it.
Loop: look -> decide -> act (a few inputs) -> screenshot -> check the result -> correct mistakes.
Call update_plan with the mission broken into steps and keep it current. Briefly state each decision in one line before acting.
Never click purchase/store/ads/chat/online-matchmaking, never type in chat, never change system settings.
If the game is frozen, a login/purchase is needed, or you are stuck for many attempts, call ask_user.
Mission: {mission}"""


def handle(ctx, row):
    st = ctx.load_state()
    adapter = ADAPTERS.get(st.get("adapter", "generic"), ADAPTERS["generic"])
    title = st.get("window")
    if not title:
        raise RuntimeError("No game window selected")
    if not capture.window_region(title):
        raise RuntimeError(f"Window not found: {title}")
    capture.focus_window(title); time.sleep(0.6)
    screen = cu.Screen(capture.window_region(title))
    audit("game_agent", "start", {"adapter": adapter.id, "window": title}, "executed")
    frozen = {"same": 0, "prev": None, "errors": 0}

    def on_turn(turn, _messages):
        # refresh window position, detect freezes, pace
        reg = capture.window_region(title)
        if reg is None:
            ctx.log("error", "Game window disappeared (closed/crashed?)")
            ans = cu.wait_for_user(ctx, "The game window is gone. Restart the game and reply 'continue', or stop the task.")
            reg = capture.window_region(title)
            if reg is None:
                raise RuntimeError("Game window not available: " + ans)
        screen.region = reg
        if screen.last_frame and frozen["prev"]:
            d = capture.frame_diff(frozen["prev"], screen.last_frame)
            frozen["same"] = frozen["same"] + 1 if d < 0.002 else 0
            if frozen["same"] >= 8:
                ctx.log("warn", "Screen hasn't changed for 8 turns — game may be frozen or agent is stuck.")
                cu.wait_for_user(ctx, "The game screen hasn't changed for a while. Is it frozen? Reply with guidance.")
                frozen["same"] = 0
        frozen["prev"] = screen.last_frame
        row2 = runtime.get(ctx.id)
        if row2 and row2["error_count"] - frozen["errors"] >= 6:
            frozen["errors"] = row2["error_count"]
            cu.wait_for_user(ctx, "Repeated errors while playing. Please check the game and reply.")
        if adapter.turn_delay:
            time.sleep(adapter.turn_delay)
        bus.publish("game_status", {"task_id": ctx.id, "turn": turn})

    def custom(name, inp):
        if name == "update_plan":
            ctx.set_plan(inp["steps"]); return "ok"
        if name == "ask_user":
            return cu.wait_for_user(ctx, inp["question"])
        return "unknown tool"

    def key_filter(text):
        return adapter.key_filter(text)

    system = SYSTEM.format(name=adapter.name, hints=adapter.hints, mission=row["prompt"])
    # A long session is many short episodes so context stays small.
    while True:
        ctx.checkpoint()
        cu.run_loop(ctx, system, [{"type": "text", "text": "Start/continue the mission. Take a screenshot first."}],
                    [cu.plan_tool(), cu.ask_user_tool()], custom, screen, "game_agent",
                    key_filter=key_filter if adapter.allowed_keys is not None else None, max_turns=60, on_turn=on_turn)
        r = runtime.get(ctx.id)
        if not (r and r["end_at"]):   # no time window -> single episode
            return
