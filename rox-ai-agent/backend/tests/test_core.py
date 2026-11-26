import threading
import time
from types import SimpleNamespace

import pytest

from rox.agents import coding_agent, runtime
from rox.agents.game_adapters.base import ADAPTERS
from rox.scheduler.scheduler import parse_hhmm
from rox.security import credentials, policy
from rox.storage import db


def test_credentials_roundtrip_and_mask():
    credentials.set_secret("anthropic_api_key", "sk-ant-api03-abcdefghijklmnop")
    assert credentials.get_secret("anthropic_api_key").startswith("sk-ant")
    assert "abcdefgh" not in credentials.mask(credentials.get_secret("anthropic_api_key"))
    # key never lands in sqlite
    assert not db.query("SELECT * FROM settings WHERE value LIKE '%sk-ant%'")


def test_folder_permissions(tmp_path):
    proj = tmp_path / "proj"; proj.mkdir()
    policy.set_allowed_folders([str(proj)])
    assert policy.resolve_allowed("a/b.txt", str(proj)) == proj / "a" / "b.txt"
    with pytest.raises(PermissionError):
        policy.resolve_allowed(str(tmp_path / "other.txt"))
    with pytest.raises(PermissionError):
        policy.resolve_allowed("../escape.txt", str(proj))


def test_risk_classification():
    assert policy.classify_command("Remove-Item -Recurse foo") == "delete_files"
    assert policy.classify_command("winget install x") == "install_software"
    assert policy.classify_command("Set-MpPreference -DisableRealtimeMonitoring $true") == "security_settings"
    assert policy.classify_command("python main.py") is None
    assert policy.classify_text("اشتري لي هذا المنتج") == "financial"


def test_blocked_category_never_asks():
    assert policy.APPROVALS.request("t", "security_settings", {}) is False


def test_approval_flow():
    res = {}
    th = threading.Thread(target=lambda: res.setdefault("v", policy.APPROVALS.request("t", "delete_files", {"p": 1}, timeout=5)))
    th.start()
    for _ in range(50):
        if policy.APPROVALS.pending(): break
        time.sleep(0.05)
    policy.APPROVALS.answer(policy.APPROVALS.pending()[0]["id"], True); th.join()
    assert res["v"] is True
    assert db.query("SELECT * FROM audit WHERE action='delete_files' AND decision='approved'")


def test_emergency_stop():
    policy.STOP.trigger()
    with pytest.raises(policy.EmergencyStop):
        policy.STOP.check()


def test_parse_hhmm_end_after_start():
    s = parse_hhmm("00:00"); e = parse_hhmm("06:00", after=s)
    assert 0 < e - s <= 6 * 3600


def test_adapter_key_filter():
    a = ADAPTERS["game2048"]
    assert a.key_filter("left") and not a.key_filter("alt+f4") and not a.key_filter("")


def test_coding_tools_write_backup_revert(tmp_path):
    proj = tmp_path / "site"; proj.mkdir(); policy.set_allowed_folders([str(proj)])
    tid = runtime.create("coding", "t", "p", {"root": str(proj)})
    ctx = runtime.TaskContext(tid)
    h = coding_agent.make_handler(ctx, proj, review=False)
    h("write_file", {"path": "index.html", "content": "<h1>v1</h1>"})
    h("replace_in_file", {"path": "index.html", "old": "v1", "new": "v2"})
    assert (proj / "index.html").read_text() == "<h1>v2</h1>"
    assert "index.html" in h("list_dir", {"path": "."})
    assert "index.html:1" in h("search", {"query": "v2"})
    assert len(coding_agent.list_changes(tid)) == 2
    with pytest.raises(PermissionError):
        h("write_file", {"path": "../../evil.txt", "content": "x"})
    coding_agent.revert(tid)
    assert not (proj / "index.html").exists()  # created file moved to backups, not deleted
    assert list((coding_agent.backups_root(tid)).glob("undo_*index.html"))


def test_runtime_pause_resume_stop():
    seen = []

    def slow(ctx, row):
        for i in range(200):
            ctx.checkpoint(); seen.append(i); time.sleep(0.01)
    runtime.RUNNER.register("slow", slow)
    tid = runtime.create("slow", "s", "")
    runtime.RUNNER.start(tid); time.sleep(0.1)
    runtime.RUNNER.pause(tid); time.sleep(0.2); n = len(seen); time.sleep(0.2)
    assert len(seen) <= n + 1 and runtime.get(tid)["status"] == "paused"
    runtime.RUNNER.resume(tid); time.sleep(0.1)
    runtime.RUNNER.stop(tid); time.sleep(0.2)
    assert runtime.get(tid)["status"] == "stopped"


def test_recover_marks_interrupted():
    tid = runtime.create("coding", "x", "y"); db.execute("UPDATE tasks SET status='running' WHERE id=?", (tid,))
    assert tid in runtime.recover_after_restart()
    assert runtime.get(tid)["status"] == "interrupted"


def test_computer_loop_with_fake_claude(monkeypatch):
    """Verifies toolset dispatch, toolset_name echo and plan handling without a network call."""
    from rox.agents import computer_use as cu
    calls = []
    blk = lambda **k: SimpleNamespace(model_dump=lambda exclude_none=True: k, **k)
    responses = [
        SimpleNamespace(stop_reason="tool_use", content=[
            blk(type="tool_use", id="1", name="update_plan", input={"steps": [{"title": "a", "status": "done"}]}, toolset_name=None),
            blk(type="tool_use", id="2", name="key", input={"text": "left"}, toolset_name="computer")]),
        SimpleNamespace(stop_reason="end_turn", content=[blk(type="text", text="done")]),
    ]

    def fake_create(messages, system, tools, max_tokens=0):
        calls.append(messages[-1]); return responses[len(calls) - 1]
    monkeypatch.setattr(cu.ac, "create", fake_create)
    monkeypatch.setattr(cu.ic, "key", lambda text, actor: None)
    tid = runtime.create("computer", "t", "p"); ctx = runtime.TaskContext(tid)
    plan = lambda n, i: (ctx.set_plan(i["steps"]), "ok")[1]
    out = cu.run_loop(ctx, "sys", [{"type": "text", "text": "go"}], [cu.plan_tool()], plan, cu.Screen(), "test")
    assert out == "done"
    results = calls[1]["content"]
    assert results[1]["toolset_name"] == "computer" and results[1]["content"] == "OK"
    assert "toolset_name" not in results[0]
    assert runtime.get(tid)["progress"] == 1.0


def test_timeline_validation_and_run(monkeypatch):
    from rox.agents import timeline
    with pytest.raises(ValueError):
        timeline.save_all([{"id": "x", "actions": [{"type": "hack"}]}])
    clicks = []
    monkeypatch.setattr(timeline.ic, "click", lambda x, y, button="left", clicks_=1, actor="", **k: clicks.append((x, y)))
    monkeypatch.setattr(timeline.match, "find", lambda *a, **k: {"found": True, "confidence": 0.97, "cx": 50, "cy": 60})
    timeline.save_all([{"id": "t1", "name": "Farm", "actions": [{"type": "target", "asset": "a"}, {"type": "click"}, {"type": "delay", "ms": 10}]}])
    tid = runtime.create("timeline", "Farm", "", {"timeline_id": "t1", "loops": 2})
    timeline.handle(runtime.TaskContext(tid), runtime.get(tid))
    assert clicks == [(50, 60), (50, 60)]


def test_template_match_real(monkeypatch):
    import numpy as np
    from PIL import Image
    from rox.vision import match
    rng = np.random.default_rng(1)
    screen = Image.fromarray(rng.integers(0, 255, (300, 400, 3), dtype=np.uint8))
    monkeypatch.setattr(match.capture, "_grab", lambda area=None: screen.crop((area["left"], area["top"], area["left"] + area["width"], area["top"] + area["height"])) if area else screen)
    match.save_asset_from_screen("enemy", {"left": 120, "top": 80, "width": 40, "height": 30})
    r = match.find("enemy")
    assert r["found"] and r["confidence"] > 0.99 and (r["x"], r["y"]) == (120, 80)


def test_flat_asset_rejected(monkeypatch):
    from PIL import Image
    from rox.vision import match
    flat = Image.new("RGB", (200, 200), (40, 80, 40))
    monkeypatch.setattr(match.capture, "_grab", lambda area=None: flat)
    with pytest.raises(ValueError):
        match.save_asset_from_screen("flat", {"left": 0, "top": 0, "width": 20, "height": 20})
