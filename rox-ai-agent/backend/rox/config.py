"""Paths and runtime config. Data lives in %LOCALAPPDATA%\\ROX-AI-Agent on Windows."""
import os
import sys
from pathlib import Path

APP_NAME = "ROX-AI-Agent"


def data_dir() -> Path:
    base = os.environ.get("ROX_DATA_DIR")
    if base:
        p = Path(base)
    elif sys.platform == "win32":
        p = Path(os.environ.get("LOCALAPPDATA", Path.home())) / APP_NAME
    else:
        p = Path.home() / ".rox-ai-agent"
    p.mkdir(parents=True, exist_ok=True)
    (p / "logs").mkdir(exist_ok=True)
    (p / "backups").mkdir(exist_ok=True)
    return p


DEFAULT_MODEL = "claude-opus-5-5"
HOST = "127.0.0.1"
PORT = int(os.environ.get("ROX_PORT", "8765"))
IS_WINDOWS = sys.platform == "win32"
