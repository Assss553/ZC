"""Chat: real Claude conversation. Classifies intent (chat / computer / coding / game), proposes a plan,
and lets the user confirm before a task starts."""
import json

from ..integrations import anthropic_client as ac
from ..storage import db

SYSTEM = """You are ROX AI Agent inside a Windows desktop app. Reply in the user's language (Arabic or English).
Capabilities: Computer agent (controls mouse/keyboard via screenshots), Coding agent (creates/edits files in allowed
folders), Game agent (plays supported single-player games via adapters), Scheduler (time windows).
For every message, answer naturally. If the user asks you to DO something on the PC, also call propose_task with the
best agent and a concise numbered plan. Do not claim you already did anything — the task only starts when the user approves."""

PROPOSE = {"name": "propose_task", "description": "Propose an executable task for user approval.",
           "input_schema": {"type": "object", "additionalProperties": False, "required": ["kind", "title", "prompt", "plan"],
                            "properties": {"kind": {"type": "string", "enum": ["computer", "coding", "game"]},
                                           "title": {"type": "string"}, "prompt": {"type": "string", "description": "Full instructions for the agent"},
                                           "plan": {"type": "array", "items": {"type": "string"}},
                                           "start_at_local": {"type": "string", "description": "Optional HH:MM start time"},
                                           "end_at_local": {"type": "string", "description": "Optional HH:MM end time"}}}}


def new_conversation(title: str) -> int:
    return db.execute("INSERT INTO conversations(title,created) VALUES(?,?)", (title[:80], db.now()))


def history(cid: int) -> list[dict]:
    return db.query("SELECT id,role,content,created FROM messages WHERE conversation_id=? ORDER BY id", (cid,))


def send(cid: int, text: str, images: list[dict] | None = None) -> dict:
    """images: [{media_type, data(b64)}]"""
    user_content = [{"type": "image", "source": {"type": "base64", "media_type": i["media_type"], "data": i["data"]}} for i in (images or [])]
    user_content.append({"type": "text", "text": text})
    db.execute("INSERT INTO messages(conversation_id,role,content,created) VALUES(?,?,?,?)",
               (cid, "user", json.dumps({"text": text, "images": len(images or [])}, ensure_ascii=False), db.now()))
    msgs = []
    for m in history(cid)[:-1][-30:]:
        c = json.loads(m["content"])
        msgs.append({"role": m["role"], "content": c.get("text") or "(empty)"})
    msgs.append({"role": "user", "content": user_content})
    msg = ac.create(msgs, SYSTEM, [PROPOSE], max_tokens=16000)
    if msg.stop_reason == "refusal":
        reply, proposal = "⚠️ Claude declined this request.", None
    else:
        reply = ac.text_of(msg)
        proposal = next((dict(b.input) for b in msg.content if b.type == "tool_use" and b.name == "propose_task"), None)
    db.execute("INSERT INTO messages(conversation_id,role,content,created) VALUES(?,?,?,?)",
               (cid, "assistant", json.dumps({"text": reply, "proposal": proposal}, ensure_ascii=False), db.now()))
    return {"reply": reply, "proposal": proposal}
