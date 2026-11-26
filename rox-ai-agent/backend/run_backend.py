"""Backend entry (dev and PyInstaller). Any startup crash is written to <data>/logs/backend-crash.log."""
import sys
import traceback


def _ensure_streams():
    """Windowed (no-console) builds have sys.stdout/stderr = None, which crashes logging setups. Point them at a log file."""
    if sys.stdout is None or sys.stderr is None:
        try:
            from rox.config import data_dir
            f = open(data_dir() / "logs" / "backend.log", "a", encoding="utf-8", buffering=1)  # noqa: SIM115
        except Exception:  # noqa: BLE001
            import os
            f = open(os.devnull, "w")  # noqa: SIM115
        if sys.stdout is None:
            sys.stdout = f
        if sys.stderr is None:
            sys.stderr = f


def main():
    _ensure_streams()
    try:
        from rox.server import main as serve
        serve()
    except Exception:  # noqa: BLE001
        msg = traceback.format_exc()
        try:
            from rox.config import data_dir
            (data_dir() / "logs" / "backend-crash.log").write_text(msg, encoding="utf-8")
        except Exception:  # noqa: BLE001
            pass
        print(msg, file=sys.stderr, flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
