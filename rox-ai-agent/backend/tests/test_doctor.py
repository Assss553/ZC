from rox.agents import doctor, runtime
from rox.security import policy


def test_scan_finds_real_issues(tmp_path):
    root = tmp_path / "proj"; root.mkdir()
    policy.set_allowed_folders([str(root)])
    (root / "ok.py").write_text("x = 1\n")
    (root / "bad.py").write_text("def f(:\n    pass\n")
    (root / "data.json").write_text('{"a": 1,}')
    (root / "index.html").write_text('<link href="style.css"><script src="https://cdn.x/y.js"></script>')
    (root / "fxmanifest.lua").write_text("client_scripts { 'client.lua' }\n")
    (root / "server.lua").write_text("function a()\n if x then\n print(1)\nend\n")
    r = doctor.scan(str(root))
    msgs = {(i["source"], i["file"]) for i in r["issues"]}
    assert ("python", "bad.py") in msgs and ("json", "data.json") in msgs
    assert ("html", "index.html") in msgs
    assert ("fivem", "fxmanifest.lua") in msgs
    assert any(i["file"] == "server.lua" for i in r["issues"])
    assert not any(i["file"] == "ok.py" for i in r["issues"])
    assert {"python", "lua/fivem", "web"} <= set(r["kinds"])


def test_doctor_fix_loop_with_fake_claude(tmp_path, monkeypatch):
    from types import SimpleNamespace
    root = tmp_path / "p"; root.mkdir(); policy.set_allowed_folders([str(root)])
    (root / "bad.py").write_text("def f(:\n    return 1\n")
    blk = lambda **k: SimpleNamespace(model_dump=lambda exclude_none=True: k, **k)
    script = [
        SimpleNamespace(stop_reason="tool_use", content=[blk(type="tool_use", id="1", name="replace_in_file", input={"path": "bad.py", "old": "def f(:", "new": "def f():"})]),
        SimpleNamespace(stop_reason="tool_use", content=[blk(type="tool_use", id="2", name="run_checks", input={})]),
        SimpleNamespace(stop_reason="end_turn", content=[blk(type="text", text="Fixed.")]),
    ]
    seen = []
    monkeypatch.setattr(doctor.ca.ac, "create", lambda m, s, t, max_tokens=0: (seen.append(m[-1]), script[len(seen) - 1])[1])
    tid = runtime.create("doctor", "fix", "", {"root": str(root)})
    doctor.handle(runtime.TaskContext(tid), runtime.get(tid))
    assert (root / "bad.py").read_text().startswith("def f():")
    assert '"issues": []' in seen[2]["content"][0]["content"]
