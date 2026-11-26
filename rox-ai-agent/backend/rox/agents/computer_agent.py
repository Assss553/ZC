"""AI Computer Agent: understands Arabic/English requests, plans, and drives Windows with Claude computer use."""
import time

from ..security.policy import APPROVALS, allowed_folders, classify_text
from . import computer_use as cu
from . import tools_common as tc

SYSTEM = """You are ROX, a careful Windows 11 desktop agent. The user may write in Arabic or English; reply in the user's language.
Work in small verified steps: first call update_plan with a short plan, then act, then take a screenshot to verify each result,
and keep the plan updated. Prefer keyboard shortcuts and open_app/run_command over hunting with the mouse when reliable.
Rules: never delete user files, install software, send messages, buy anything or change security settings unless the
system has approved it (risky tools ask the user automatically). Never enter passwords. If stuck after 3 tries, call ask_user.
Allowed folders for file work: {folders}. Finish with a short summary of what you did."""


def handle(ctx, row):
    risk = classify_text(row["prompt"])
    if risk and not APPROVALS.request("computer_agent", risk, {"prompt": row["prompt"]}):
        ctx.log("warn", f"Task needs '{risk}' approval and was denied."); return
    screen = cu.Screen()

    def custom(name, inp):
        if name == "update_plan":
            ctx.set_plan(inp["steps"]); return "plan saved"
        if name == "ask_user":
            return cu.wait_for_user(ctx, inp["question"])
        if name == "run_command":
            return tc.run_command("computer_agent", inp["command"], inp["cwd"], inp.get("timeout_s", 300))
        if name == "open_app":
            r = tc.open_app("computer_agent", inp["target"], inp.get("args")); time.sleep(2); return r
        return f"unknown tool {name}"

    system = SYSTEM.format(folders=", ".join(allowed_folders()) or "(none yet — ask the user to add one in Settings)")
    cu.run_loop(ctx, system, [{"type": "text", "text": row["prompt"]}],
                [cu.plan_tool(), cu.ask_user_tool(), tc.run_command_tool(), tc.open_app_tool()], custom, screen, "computer_agent")
