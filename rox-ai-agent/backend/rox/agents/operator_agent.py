"""Operator: the 'do it now' agent. Executes the user's request immediately using direct system tools first,
then mouse/keyboard/vision (computer use) for anything that needs the GUI. Streams every step to the UI."""
import platform
import time

from ..security.policy import allowed_folders
from ..storage import db
from . import computer_use as cu
from . import system_tools as st

SYSTEM = """You are ROX Operator, running directly on the user's real {os} PC. The user is watching. Reply in the user's language (Arabic or English).
Act IMMEDIATELY — do not ask for confirmation for safe steps; the system asks the user itself for risky ones.
Strategy (fastest, most reliable first):
 1. Direct tools (system_info, list_processes, installed_apps, find_files, launch_app, window_action, powershell…) for anything they can do.
 2. Computer use (screenshot, click, type, key) only for GUI work those tools can't do. After GUI actions take a screenshot to verify.
For a multi-step task call update_plan first and keep it current. Before each tool call write one short line saying what you're doing.
Inspection requests ("افحص", "check", "why is it slow"): gather real data with the tools, then give a clear diagnosis with numbers and concrete next steps.
Never delete user files, install software, buy, send messages, or change security settings without the approval the tools request. Never type passwords.
Allowed folders for file access: {folders}. Finish with a short result summary."""


def handle(ctx, row):
    def custom(name, inp):
        if name == "update_plan":
            ctx.set_plan(inp["steps"]); return "ok"
        if name == "ask_user":
            return cu.wait_for_user(ctx, inp["question"])
        if name in st.TOOLS:
            t0 = time.time(); r = st.call(name, inp)
            ctx.log("tool", f"{name} ({int((time.time() - t0) * 1000)}ms)")
            return r
        return f"unknown tool {name}"

    system = SYSTEM.format(os=f"{platform.system()} {platform.release()}", folders=", ".join(allowed_folders()) or "(none)")
    cu.run_loop(ctx, system, [{"type": "text", "text": row["prompt"]}], [cu.plan_tool(), cu.ask_user_tool()] + st.tool_defs(),
                custom, cu.Screen(), "operator", max_turns=150, effort=db.get_setting("operator_effort", "medium"))
