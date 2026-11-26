"""In-process pub/sub fan-out to WebSocket clients."""
import asyncio
import threading
import time
from collections import deque


class Bus:
    def __init__(self) -> None:
        self._subs: set[asyncio.Queue] = set()
        self._loop: asyncio.AbstractEventLoop | None = None
        self.recent: deque = deque(maxlen=200)
        self._lock = threading.Lock()

    def bind(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    def subscribe(self) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue(maxsize=500)
        self._subs.add(q)
        return q

    def unsubscribe(self, q: asyncio.Queue) -> None:
        self._subs.discard(q)

    def publish(self, kind: str, data: dict) -> None:
        evt = {"type": kind, "ts": time.time(), "data": data}
        if kind == "action":
            with self._lock:
                self.recent.append(evt)
        if not self._loop:
            return
        for q in list(self._subs):
            self._loop.call_soon_threadsafe(_put, q, evt)


def _put(q: asyncio.Queue, evt: dict) -> None:
    if not q.full():
        q.put_nowait(evt)


bus = Bus()
