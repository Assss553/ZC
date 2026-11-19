"""End-to-end on the TEST frame with real RapidOCR, a stub translator, and a real WebSocket client."""
import asyncio
import json

import aiohttp
import pytest

from rox_server.engine import Engine
from rox_server.net import Hub, run_in_thread
from rox_server.ocr import OCR
from rox_server.textlogic import TranslationCache
from tests.helpers import game_frame


class StubTranslator:
    status = {"en_ar": "stub"}

    def __init__(self):
        self.cache = TranslationCache()

    def translate(self, text, src):
        return f"[ar] {text}"


def test_ocr_reads_test_frame():
    blocks = OCR().read(game_frame())
    text = " | ".join(b["text"] for b in blocks)
    print("OCR:", text)
    assert "lighthouse" in text.lower()
    assert "ancient key" in text.lower()


def test_engine_and_phone_websocket():
    hub = Hub(port=9760)
    run_in_thread(hub)
    eng = Engine(None, OCR(), StubTranslator(), hub)

    async def client():
        async with aiohttp.ClientSession() as s:
            async with s.ws_connect("http://127.0.0.1:9760/ws") as ws:
                hello = json.loads((await ws.receive()).data)
                assert hello["type"] == "hello"
                await asyncio.sleep(0.3)
                await asyncio.get_running_loop().run_in_executor(None, eng.process_frame, game_frame())
                while True:
                    m = json.loads((await asyncio.wait_for(ws.receive(), 30)).data)
                    if m["type"] == "frame":
                        return m

    msg = asyncio.run(client())
    kinds = {s["kind"] for s in msg["subtitles"]}
    print("frame msg:", msg)
    assert "DIALOG" in kinds and "MISSION" in kinds
    dialog = next(s for s in msg["subtitles"] if s["kind"] == "DIALOG")
    assert dialog["speaker"] == "Elena" and dialog["translated"].startswith("[ar]")
    assert len(msg["masks"]) == 1 and msg["frame"] == [1280, 720]
    assert eng.state["lang"] == "en"
