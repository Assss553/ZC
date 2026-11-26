"""Official Anthropic integration.

Two clearly separated auth/billing paths:
  * api      -> Claude API key (Console billing), stored in Windows Credential Manager.
  * claude_code -> the official Claude Code CLI (`claude`), which the user logs into with
                  `claude /login` (subscription or Console). We only *invoke* the CLI; we never
                  read its tokens/cookies.
Computer use (screen control) needs the API path: it is a Messages API tool.
"""
import json
import shutil
import subprocess
import threading

import anthropic

from ..config import DEFAULT_MODEL
from ..security import credentials
from ..storage import db

FALLBACK_BETA = "server-side-fallback-2026-07-01"
_usage_lock = threading.Lock()


def provider() -> str:
    return db.get_setting("provider", "api")


def model() -> str:
    return db.get_setting("model", DEFAULT_MODEL)


def effort() -> str:
    return db.get_setting("effort", "high")


def client() -> anthropic.Anthropic:
    key = credentials.get_secret("anthropic_api_key")
    if not key:
        raise RuntimeError("No Claude API key configured. Add one in Settings → Claude API.")
    return anthropic.Anthropic(api_key=key, max_retries=3, timeout=600)


def record_usage(usage) -> None:
    if usage is None:
        return
    with _usage_lock:
        u = db.get_setting("usage", {"input_tokens": 0, "output_tokens": 0, "cache_read_input_tokens": 0, "requests": 0})
        u["input_tokens"] += getattr(usage, "input_tokens", 0) or 0
        u["output_tokens"] += getattr(usage, "output_tokens", 0) or 0
        u["cache_read_input_tokens"] += getattr(usage, "cache_read_input_tokens", 0) or 0
        u["requests"] += 1
        db.set_setting("usage", u)


def check_budget() -> None:
    limit = db.get_setting("max_output_tokens_total", 0)
    if limit:
        u = db.get_setting("usage", {})
        if u.get("output_tokens", 0) >= limit:
            raise RuntimeError("Token budget reached (Settings → Limits). Raise it to continue.")


def create(messages: list, system: str, tools: list | None = None, max_tokens: int = 32000, effort_override: str | None = None):
    """One Messages API call (streamed to avoid HTTP timeouts). Returns the final Message."""
    check_budget()
    # system + tools are stable per agent -> cache them; effort can be overridden per agent (operator runs fast)
    kwargs = dict(model=model(), max_tokens=max_tokens, system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
                  messages=messages, thinking={"type": "adaptive"}, output_config={"effort": effort_override or effort()})
    if tools:
        kwargs["tools"] = tools
    extra = {}
    if db.get_setting("use_fallbacks", True):
        extra = dict(extra_headers={"anthropic-beta": FALLBACK_BETA}, extra_body={"fallbacks": "default"})
    with client().messages.stream(**kwargs, **extra) as stream:
        msg = stream.get_final_message()
    record_usage(msg.usage)
    return msg


def text_of(msg) -> str:
    return "".join(b.text for b in msg.content if b.type == "text")


def test_connection() -> dict:
    try:
        c = client()
        models = [m.id for m in c.models.list(limit=50)]
        return {"ok": True, "models": models, "selected": model(), "selected_available": model() in models}
    except anthropic.AuthenticationError:
        return {"ok": False, "error": "Invalid API key (401)."}
    except anthropic.PermissionDeniedError as e:
        return {"ok": False, "error": f"Permission denied: {e.message}"}
    except anthropic.APIConnectionError:
        return {"ok": False, "error": "Cannot reach api.anthropic.com (network)."}
    except anthropic.APIStatusError as e:
        return {"ok": False, "error": f"API error {e.status_code}: {e.message}"}
    except RuntimeError as e:
        return {"ok": False, "error": str(e)}


# ---------------- Claude Code CLI (account login path) ----------------
def claude_cli() -> str | None:
    return shutil.which("claude")


def claude_code_status() -> dict:
    exe = claude_cli()
    if not exe:
        return {"installed": False, "hint": "Install Claude Code: npm install -g @anthropic-ai/claude-code, then run `claude` and /login."}
    try:
        v = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=20).stdout.strip()
    except Exception as e:
        return {"installed": True, "error": str(e)}
    return {"installed": True, "version": v}


def claude_code_run(prompt: str, cwd: str, allowed_tools: str = "Read,Edit,Write,Glob,Grep", timeout: int = 1800) -> dict:
    """Run a headless Claude Code task in `cwd` using the user's own Claude Code login."""
    exe = claude_cli()
    if not exe:
        raise RuntimeError("Claude Code CLI not installed")
    p = subprocess.run([exe, "-p", prompt, "--output-format", "json", "--allowedTools", allowed_tools],
                       cwd=cwd, capture_output=True, text=True, timeout=timeout, encoding="utf-8")
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return {"result": p.stdout or p.stderr, "is_error": p.returncode != 0}
