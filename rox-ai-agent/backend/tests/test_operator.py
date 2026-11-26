import json
from types import SimpleNamespace

from rox.agents import operator_agent, runtime, system_tools as st
from rox.security import policy


def test_readonly_tools_return_real_data(tmp_path):
    info = json.loads(st.call("system_info", {}))
    assert info["cores"] >= 1 and info["ram_gb"] > 0
    procs = json.loads(st.call("list_processes", {"limit": 5}))
    assert 0 < len(procs) <= 5 and {"pid", "name", "mem_mb"} <= procs[0].keys()
    assert json.loads(st.call("disk_usage", {}))
    assert "internet" in json.loads(st.call("network_info", {}))
    root = tmp_path / "w"; root.mkdir(); (root / "a.lua").write_text("print('rox')"); (root / "b.txt").write_text("x")
    policy.set_allowed_folders([str(root)])
    hits = json.loads(st.call("find_files", {"folder": str(root), "pattern": "*.lua", "contains": "rox"}))
    assert [h["path"].endswith("a.lua") for h in hits] == [True]


def test_protected_process_and_url_guard():
    import os
    import psutil
    assert "denied" in st.call("open_url", {"url": "file:///etc/passwd"}).lower() or "only http" in st.call("open_url", {"url": "file:///x"}).lower()
    me = psutil.Process(os.getpid())
    st.PROTECTED.add(me.name().lower())
    assert "Blocked" in st.call("kill_process", {"pid": os.getpid()})


def test_operator_runs_tools_immediately(monkeypatch):
    blk = lambda **k: SimpleNamespace(model_dump=lambda exclude_none=True: k, **k)
    script = [SimpleNamespace(stop_reason="tool_use", content=[blk(type="text", text="أفحص الجهاز الآن"),
                                                               blk(type="tool_use", id="1", name="system_info", input={}, toolset_name=None),
                                                               blk(type="tool_use", id="2", name="list_processes", input={"limit": 3}, toolset_name=None)]),
              SimpleNamespace(stop_reason="end_turn", content=[blk(type="text", text="الجهاز سليم")])]
    seen = []
    monkeypatch.setattr(operator_agent.cu.ac, "create", lambda m, s, t, max_tokens=0, effort_override=None: (seen.append((m[-1], t, effort_override)), script[len(seen) - 1])[1])
    tid = runtime.create("operator", "x", "افحص جهازي")
    operator_agent.handle(runtime.TaskContext(tid), runtime.get(tid))
    results = seen[1][0]["content"]
    assert len(results) == 2 and '"cores"' in results[0]["content"]
    assert seen[0][2] == "medium"
    assert any(t.get("name") == "powershell" for t in seen[0][1])
