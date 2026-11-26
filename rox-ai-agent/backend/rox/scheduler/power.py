"""Keep Windows awake during tasks (SetThreadExecutionState) + run-at-login (HKCU Run key)."""
import sys

from ..config import IS_WINDOWS

ES_CONTINUOUS = 0x80000000
ES_SYSTEM_REQUIRED = 0x00000001
ES_DISPLAY_REQUIRED = 0x00000002
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


def keep_awake(on: bool) -> bool:
    if not IS_WINDOWS:
        return False
    import ctypes
    flags = ES_CONTINUOUS | (ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED if on else 0)
    return ctypes.windll.kernel32.SetThreadExecutionState(flags) != 0


def set_run_at_login(enabled: bool, command: str) -> bool:
    if not IS_WINDOWS:
        return False
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as k:
        if enabled:
            winreg.SetValueEx(k, "ROX AI Agent", 0, winreg.REG_SZ, command)
        else:
            try: winreg.DeleteValue(k, "ROX AI Agent")
            except FileNotFoundError: pass
    return True


def is_admin() -> bool:
    if IS_WINDOWS:
        import ctypes
        try: return bool(ctypes.windll.shell32.IsUserAnAdmin())
        except Exception: return False
    import os
    return hasattr(os, "geteuid") and os.geteuid() == 0
