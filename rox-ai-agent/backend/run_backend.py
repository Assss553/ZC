"""Backend entry (dev and PyInstaller). Any startup crash is written to <data>/logs/backend-crash.log."""
import sys
import traceback


def main():
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
