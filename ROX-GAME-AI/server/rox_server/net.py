"""LAN link to the ROX phone app: UDP discovery + WebSocket feed (translations, masks, status)."""
import asyncio
import json
import logging
import socket
import threading

from aiohttp import web, WSMsgType

log = logging.getLogger("rox.net")
WS_PORT = 9750
DISCOVERY_PORT = 9751
MAGIC = b"ROX_DISCOVER"


class Hub:
    def __init__(self, name="ROX Server", port=WS_PORT):
        self.name, self.port = name, port
        self.clients = set()
        self.loop = None
        self.last_status = {}
        self._runner = None
        self.on_command = None  # callback(dict)

    # --- websocket ---
    async def _ws(self, request):
        ws = web.WebSocketResponse(heartbeat=10)
        await ws.prepare(request)
        self.clients.add(ws)
        log.info("phone connected %s (%d)", request.remote, len(self.clients))
        await ws.send_str(json.dumps({"type": "hello", "name": self.name, "status": self.last_status}))
        try:
            async for msg in ws:
                if msg.type == WSMsgType.TEXT and self.on_command:
                    try:
                        self.on_command(json.loads(msg.data))
                    except Exception as e:
                        log.warning("bad command: %s", e)
        finally:
            self.clients.discard(ws)
            log.info("phone disconnected (%d)", len(self.clients))
        return ws

    async def _status(self, _):
        return web.json_response({"name": self.name, "clients": len(self.clients), **self.last_status})

    async def start(self):
        self.loop = asyncio.get_running_loop()
        app = web.Application()
        app.router.add_get("/ws", self._ws)
        app.router.add_get("/status", self._status)
        self._runner = web.AppRunner(app)
        await self._runner.setup()
        await web.TCPSite(self._runner, "0.0.0.0", self.port).start()
        self.loop.create_task(self._discovery())
        log.info("ROX Server listening on :%d (discovery udp %d)", self.port, DISCOVERY_PORT)

    async def stop(self):
        for c in list(self.clients):
            await c.close()
        if self._runner:
            await self._runner.cleanup()

    async def _discovery(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("0.0.0.0", DISCOVERY_PORT))
        s.setblocking(False)
        loop = asyncio.get_running_loop()
        reply = json.dumps({"rox": "server", "name": self.name, "port": self.port}).encode()
        while True:
            try:
                data, addr = await loop.sock_recvfrom(s, 512)
                if data.startswith(MAGIC):
                    await loop.sock_sendto(s, reply, addr)
            except (BlockingIOError, InterruptedError):
                await asyncio.sleep(0.05)
            except Exception as e:
                log.warning("discovery error: %s", e)
                await asyncio.sleep(0.5)

    # --- thread-safe publish ---
    def publish(self, msg: dict):
        if msg.get("type") == "status":
            self.last_status = msg
        if not self.loop:
            return
        data = json.dumps(msg, ensure_ascii=False)
        for c in list(self.clients):
            asyncio.run_coroutine_threadsafe(self._safe_send(c, data), self.loop)

    async def _safe_send(self, c, data):
        try:
            await c.send_str(data)
        except Exception:
            self.clients.discard(c)


def run_in_thread(hub: Hub):
    ready = threading.Event()

    def main():
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(hub.start())
        ready.set()
        loop.run_forever()

    th = threading.Thread(target=main, name="rox-net", daemon=True)
    th.start()
    ready.wait(10)
    return th


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()
