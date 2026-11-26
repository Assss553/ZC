declare global { interface Window { rox?: { token: string; port: number; toggleFullscreen: () => void } } }
const PORT = window.rox?.port ?? 8765;
export const TOKEN = window.rox?.token ?? "";
export const BASE = `http://127.0.0.1:${PORT}`;
export const WS = `ws://127.0.0.1:${PORT}`;

export async function api<T = any>(path: string, opts: { method?: string; body?: unknown } = {}): Promise<T> {
  const r = await fetch(BASE + path, {
    method: opts.method ?? (opts.body ? "POST" : "GET"),
    headers: { "content-type": "application/json", "x-rox-token": TOKEN },
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.detail ?? `HTTP ${r.status}`);
  return data as T;
}

export type RoxEvent = { type: string; ts: number; data: any };
type Listener = (e: RoxEvent) => void;
const listeners = new Set<Listener>();
let sock: WebSocket | null = null;
function connect() {
  sock = new WebSocket(`${WS}/ws/events?token=${encodeURIComponent(TOKEN)}`);
  sock.onmessage = (m) => { const e = JSON.parse(m.data); listeners.forEach((l) => l(e)); };
  sock.onclose = () => setTimeout(connect, 1500);
}
export function onEvent(l: Listener) { if (!sock) connect(); listeners.add(l); return () => { listeners.delete(l); }; }
