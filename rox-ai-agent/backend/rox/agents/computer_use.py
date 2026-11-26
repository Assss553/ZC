"""Shared Claude computer-use loop (computer_toolset_20260801) + custom tools.
Used by the Computer agent (full screen) and the Game agent (window region + key allow-list)."""
import base64
import json
import time
from typing import Callable

from ..events import bus
from ..input_control import controller as ic
from ..integrations import anthropic_client as ac
from ..vision import capture

TOOLSET_NAME = "computer"


class Screen:
    """Maps between model coordinates (scaled screenshot) and real screen coordinates."""

    def __init__(self, region: dict | None = None, max_side: int = 1280):
        self.region, self.max_side, self.scale = region, max_side, 1.0
        self.last_frame: bytes | None = None

    def shot(self) -> dict:
        data, _size, self.scale = capture.capture(self.region, max_side=self.max_side, fmt="PNG")
        self.last_frame = data
        bus.publish("agent_frame", {"b64": base64.b64encode(capture.capture(self.region, 900, 55)[0]).decode()})
        return {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(data).decode()}}

    def real(self, xy) -> tuple[int, int]:
        x, y = int(xy[0] / self.scale), int(xy[1] / self.scale)
        if self.region:
            x += self.region["left"]; y += self.region["top"]
        return x, y

    def zoom(self, region) -> dict:
        x0, y0 = self.real(region[:2]); x1, y1 = self.real(region[2:])
        data, _s, _sc = capture.capture({"left": x0, "top": y0, "width": max(x1 - x0, 8), "height": max(y1 - y0, 8)}, self.max_side, fmt="PNG")
        return {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(data).decode()}}


def toolset_of(block) -> str | None:
    return getattr(block, "toolset_name", None) or (getattr(block, "model_extra", None) or {}).get("toolset_name")


def execute_member(name: str, inp: dict, screen: Screen, actor: str, key_filter: Callable[[str], bool] | None):
    """Run one computer-toolset member call. Returns tool_result content (str or list)."""
    c = inp.get("coordinate")
    btn = {"left_click": "left", "right_click": "right", "middle_click": "middle"}
    if name == "screenshot":
        return [screen.shot()]
    if name == "zoom":
        return [screen.zoom(inp.get("region", [0, 0, 400, 300]))]
    if name == "cursor_position":
        return json.dumps(ic.cursor())
    if name in ("key", "hold_key", "type") and key_filter and not key_filter(inp.get("text", "")):
        return f"Blocked by adapter: key/text '{inp.get('text','')}' is not allowed for this game."
    if name in btn:
        xy = screen.real(c) if c else (None, None)
        ic.click(*xy, button=btn[name], actor=actor)
    elif name == "double_click":
        ic.click(*(screen.real(c) if c else (None, None)), clicks=2, actor=actor)
    elif name == "triple_click":
        ic.click(*(screen.real(c) if c else (None, None)), clicks=3, actor=actor)
    elif name == "mouse_move":
        ic.move(*screen.real(c), actor=actor)
    elif name == "left_click_drag":
        ic.drag(*screen.real(inp["start_coordinate"]), *screen.real(c), actor=actor)
    elif name == "left_mouse_down":
        ic.mouse_down(actor=actor)
    elif name == "left_mouse_up":
        ic.mouse_up(actor=actor)
    elif name == "scroll":
        xy = screen.real(c) if c else (None, None)
        ic.scroll(*xy, inp.get("scroll_direction", "down"), int(inp.get("scroll_amount", 3)), actor=actor)
    elif name == "type":
        ic.type_text(inp.get("text", ""), actor=actor)
    elif name == "key":
        ic.key(inp.get("text", ""), actor=actor)
    elif name == "hold_key":
        ic.hold_key(inp.get("text", ""), float(inp.get("duration", 1)), actor=actor)
    elif name == "wait":
        time.sleep(min(float(inp.get("duration", 1)), 30))
    else:
        return f"Unsupported action: {name}"
    return "OK"


def run_loop(ctx, system: str, first_user: list, custom_tools: list[dict], custom_handler: Callable,
             screen: Screen, actor: str, key_filter=None, max_turns: int = 200, on_turn: Callable | None = None) -> str:
    """Generic agent loop. Persists the transcript (minus images) for crash recovery."""
    tools = [{"type": "computer_toolset_20260801"}] + custom_tools
    messages = [{"role": "user", "content": first_user}]
    final_text = ""
    consecutive_errors = 0
    for turn in range(max_turns):
        ctx.checkpoint()
        if ctx.injected:  # user modified the task mid-run
            messages.append({"role": "user", "content": "Update from the user: " + "\n".join(ctx.injected)})
            ctx.injected.clear()
        try:
            msg = ac.create(messages, system, tools)
            consecutive_errors = 0
        except Exception as e:
            consecutive_errors += 1
            ctx.log("error", f"API error: {e}")
            if consecutive_errors >= 3:
                raise
            time.sleep(5 * consecutive_errors); continue
        if msg.stop_reason == "refusal":
            ctx.log("warn", "Claude declined this request (refusal).")
            return "refused"
        messages.append({"role": "assistant", "content": [b.model_dump(exclude_none=True) for b in msg.content]})
        for b in msg.content:
            if b.type == "text" and b.text.strip():
                final_text = b.text
                bus.publish("agent_say", {"task_id": ctx.id, "text": b.text})
                ctx.log("info", b.text)
            elif b.type == "thinking" and getattr(b, "thinking", ""):
                bus.publish("agent_think", {"task_id": ctx.id, "text": b.thinking})
        uses = [b for b in msg.content if b.type == "tool_use"]
        if not uses:
            if msg.stop_reason == "pause_turn":
                continue
            return final_text
        results = []
        for u in uses:
            ctx.checkpoint()
            toolset = toolset_of(u)
            entry = {"type": "tool_result", "tool_use_id": u.id}
            try:
                if toolset == TOOLSET_NAME:
                    bus.publish("decision", {"task_id": ctx.id, "action": u.name, "input": u.input})
                    entry["content"] = execute_member(u.name, dict(u.input), screen, actor, key_filter)
                    entry["toolset_name"] = TOOLSET_NAME
                else:
                    entry["content"] = custom_handler(u.name, dict(u.input))
            except (ic.InputUnavailable, capture.CaptureUnavailable) as e:
                entry.update(content=str(e), is_error=True)
                if toolset == TOOLSET_NAME:
                    entry["toolset_name"] = TOOLSET_NAME
                ctx.log("error", str(e))
            except Exception as e:
                if type(e).__name__ in ("EmergencyStop", "TaskStopped"):
                    raise
                entry.update(content=f"Error: {e}", is_error=True)
                if toolset == TOOLSET_NAME:
                    entry["toolset_name"] = TOOLSET_NAME
                ctx.log("error", f"{u.name}: {e}")
            results.append(entry)
        messages.append({"role": "user", "content": results})
        if on_turn:
            on_turn(turn, messages)
        ctx.save_state({"turn": turn, "last_text": final_text})
    ctx.log("warn", "Reached max turns")
    return final_text


def plan_tool() -> dict:
    return {"name": "update_plan", "description": "Publish/refresh the step-by-step plan and mark progress. Call at the start and whenever a step finishes.",
            "input_schema": {"type": "object", "properties": {"steps": {"type": "array", "items": {"type": "object", "properties": {
                "title": {"type": "string"}, "status": {"type": "string", "enum": ["pending", "active", "done", "failed"]}},
                "required": ["title", "status"], "additionalProperties": False}}}, "required": ["steps"], "additionalProperties": False}}


def ask_user_tool() -> dict:
    return {"name": "ask_user", "description": "Ask the user for help when you cannot continue (stuck, ambiguous, needs a login). Pauses the task until they answer.",
            "input_schema": {"type": "object", "properties": {"question": {"type": "string"}}, "required": ["question"], "additionalProperties": False}}


def wait_for_user(ctx, question: str, timeout: float = 3600) -> str:
    bus.publish("help_request", {"task_id": ctx.id, "question": question})
    ctx.log("warn", f"Needs help: {question}")
    end = time.time() + timeout
    while time.time() < end:
        ctx.checkpoint()
        if ctx.injected:
            ans = "\n".join(ctx.injected); ctx.injected.clear(); return ans
        time.sleep(0.5)
    return "No answer from the user. Stop safely."
