import os
import sys

import pytest

from rox_server import remoteplay


def test_pick_windows_zip():
    assets = [{"name": "chiaki-ng-linux.AppImage"}, {"name": "chiaki-ng-macos.dmg"},
              {"name": "chiaki-ng-windows-installer.exe"}, {"name": "chiaki-ng-win_x64-portable.zip"}]
    assert remoteplay.pick_asset(assets)["name"] == "chiaki-ng-win_x64-portable.zip"
    assert remoteplay.pick_asset([{"name": "x.dmg"}]) is None


@pytest.mark.skipif(os.environ.get("ROX_NET_TESTS") != "1" or sys.platform != "win32", reason="Windows + internet only")
def test_real_install_from_official_release(tmp_path, monkeypatch):
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    exe = remoteplay.install(print)
    print("chiaki-ng exe:", exe)
    assert exe.exists() and exe.suffix == ".exe"
