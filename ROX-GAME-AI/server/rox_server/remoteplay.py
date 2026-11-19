"""Installs and launches the official open-source Remote Play client chiaki-ng (unmodified, from its
own GitHub releases) so the user gets one-button "connect to PlayStation" inside ROX Server.
chiaki-ng runs as a separate program (AGPL-3.0, source: https://github.com/streetpea/chiaki-ng);
it handles Sony's official sign-in page, the PIN pairing and the stream itself."""
import json
import logging
import os
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

log = logging.getLogger("rox.remoteplay")
API = "https://api.github.com/repos/streetpea/chiaki-ng/releases/latest"
UA = {"User-Agent": "ROX-Server/1.0", "Accept": "application/vnd.github+json"}


def install_dir() -> Path:
    base = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "ROX" / "chiaki-ng"
    base.mkdir(parents=True, exist_ok=True)
    return base


def find_exe(root: Path = None):
    root = root or install_dir()
    cands = [p for p in root.rglob("*.exe") if p.name.lower().startswith("chiaki")]
    cands.sort(key=lambda p: (len(p.parts), p.name))
    return cands[0] if cands else None


def pick_asset(assets):
    """Choose the portable Windows zip from a release's assets."""
    def score(a):
        n = a["name"].lower()
        if not n.endswith(".zip") or not ("win" in n or "windows" in n):
            return -1
        return 2 if "portable" in n else 1
    best = max(assets, key=score, default=None)
    return best if best and score(best) > 0 else None


def install(progress=lambda msg: None):
    exe = find_exe()
    if exe:
        return exe
    progress("جارٍ البحث عن آخر إصدار رسمي من chiaki-ng…")
    with urllib.request.urlopen(urllib.request.Request(API, headers=UA), timeout=30) as r:
        rel = json.loads(r.read())
    asset = pick_asset(rel.get("assets", []))
    if not asset:
        raise RuntimeError("لم يتم العثور على نسخة Windows في الإصدار الرسمي")
    progress(f"جارٍ تنزيل {asset['name']} ({asset['size'] // 1_000_000} MB)…")
    tmp = install_dir() / asset["name"]
    req = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": "ROX-Server/1.0"})
    with urllib.request.urlopen(req, timeout=300) as r, open(tmp, "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    progress("جارٍ فك الضغط…")
    with zipfile.ZipFile(tmp) as z:
        z.extractall(install_dir() / rel.get("tag_name", "latest"))
    tmp.unlink()
    exe = find_exe()
    if not exe:
        raise RuntimeError("تم التنزيل لكن لم يوجد ملف التشغيل")
    log.info("chiaki-ng %s installed at %s", rel.get("tag_name"), exe)
    return exe


def launch(exe: Path):
    if sys.platform != "win32":
        raise RuntimeError("Windows only")
    return subprocess.Popen([str(exe)], cwd=str(exe.parent))
