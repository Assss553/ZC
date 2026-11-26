from fastapi.testclient import TestClient


def test_api_smoke(tmp_path):
    from rox import server
    with TestClient(server.app) as c:
        s = c.get("/api/status").json()
        assert "cpu" in s and s["api_key_set"] is False
        assert c.post("/api/claude/key", json={"api_key": "nope"}).status_code == 400
        assert c.post("/api/claude/key", json={"api_key": "sk-ant-api03-xxxxxxxxxxxxxxxx"}).json()["ok"]
        st = c.get("/api/settings").json()
        assert st["api_key_masked"] and "xxxxxxxxxxxx" not in st["api_key_masked"]
        proj = tmp_path / "p"; proj.mkdir()
        c.post("/api/settings", json={"allowed_folders": [str(proj)], "effort": "medium"})
        assert c.post("/api/files/write", json={"path": str(proj / "a.lua"), "content": "print('hi')"}).json()["ok"]
        assert c.get("/api/files/read", params={"path": str(proj / "a.lua")}).json()["content"] == "print('hi')"
        assert c.get("/api/files/read", params={"path": "/etc/passwd"}).status_code == 403
        assert len(c.get("/api/games/adapters").json()) >= 3
        r = c.post("/api/tasks", json={"kind": "coding", "title": "t", "prompt": "x", "state": {"root": "/"}, "start_now": False})
        assert r.status_code == 400  # root not allowed
        r = c.post("/api/tasks", json={"kind": "game", "title": "g", "prompt": "play", "start_at_local": "23:59", "end_at_local": "06:00", "state": {"adapter": "game2048", "window": "x"}})
        assert r.json()["status"] == "scheduled"
        assert c.post("/api/emergency-stop").json()["ok"]
        assert c.get("/api/status").json()["emergency_stop"] is True
        c.post("/api/emergency-stop/reset")
        assert any(a["action"] == "emergency_stop" for a in c.get("/api/audit").json())
