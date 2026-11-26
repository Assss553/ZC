import { useEffect, useRef, useState } from "react";
import { api, onEvent, RoxEvent, TOKEN, WS } from "../api";
import { useT } from "../i18n";
import { ZoomIn, ZoomOut, Pause, Play, Maximize2, CheckCircle2, CircleDot, XCircle, Circle, AlertTriangle, LifeBuoy, Square } from "lucide-react";

export function usePoll<T>(path: string, ms = 2000, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    const tick = () => api<T>(path).then((d) => { if (alive) { setData(d); setErr(null); } }).catch((e) => alive && setErr(String(e.message ?? e)));
    tick(); const id = setInterval(tick, ms);
    return () => { alive = false; clearInterval(id); };
  }, [path, ms, ...deps]);
  return { data, err, setData };
}

export function useEvents(filter: (e: RoxEvent) => boolean, max = 200) {
  const [items, setItems] = useState<RoxEvent[]>([]);
  const f = useRef(filter); f.current = filter;
  useEffect(() => onEvent((e) => { if (f.current(e)) setItems((s) => [e, ...s].slice(0, max)); }), [max]);
  return items;
}

/** Real live stream over WebSocket (JPEG frames from mss). */
export function ScreenView({ window: win = "", fps = 8, title }: { window?: string; fps?: number; title: string }) {
  const [src, setSrc] = useState<string>(""); const [err, setErr] = useState<string>(""); const [zoom, setZoom] = useState(1);
  const [rate, setRate] = useState(0); const [on, setOn] = useState(true); const frames = useRef<number[]>([]);
  useEffect(() => {
    if (!on) return;
    const ws = new WebSocket(`${WS}/ws/screen?token=${encodeURIComponent(TOKEN)}&fps=${fps}&window=${encodeURIComponent(win)}`);
    ws.onmessage = (m) => {
      const d = JSON.parse(m.data);
      if (d.error) { setErr(d.error); return; }
      setErr(""); setSrc("data:image/jpeg;base64," + d.frame);
      const now = performance.now(); frames.current = [...frames.current.filter((t) => now - t < 2000), now]; setRate(frames.current.length / 2);
    };
    ws.onerror = () => setErr("backend offline");
    return () => ws.close();
  }, [win, fps, on]);
  return (
    <div className="card">
      <div className="row" style={{ justifyContent: "space-between", marginBottom: 8 }}>
        <h2 style={{ margin: 0 }}>{title}</h2>
        <div className="row">
          <span className="pill or">{rate.toFixed(1)} fps</span>
          <button className="btn ib" onClick={() => setZoom((z) => Math.max(1, z - 0.25))}><ZoomOut size={15} /></button>
          <span className="small mute">{Math.round(zoom * 100)}%</span>
          <button className="btn ib" onClick={() => setZoom((z) => Math.min(3, z + 0.25))}><ZoomIn size={15} /></button>
          <button className="btn ib" onClick={() => setOn(!on)}>{on ? <Pause size={15} /> : <Play size={15} />}</button>
          <button className="btn ib" onClick={() => window.rox?.toggleFullscreen()}><Maximize2 size={15} /></button>
        </div>
      </div>
      <div className="screen" style={{ overflow: "auto" }}>
        {src ? <img src={src} style={{ width: `${zoom * 100}%` }} alt="live" /> : <span className="mute small">{err || "…"}</span>}
        {err && src && <div className="ov"><span className="pill bad">{err}</span></div>}
      </div>
    </div>
  );
}

export function Approvals() {
  const t = useT();
  const [list, setList] = useState<any[]>([]);
  const [help, setHelp] = useState<any | null>(null); const [ans, setAns] = useState("");
  useEffect(() => onEvent((e) => {
    if (e.type === "approval") setList((l) => [...l.filter((x) => x.id !== e.data.id), e.data]);
    if (e.type === "help_request") setHelp(e.data);
  }), []);
  const answer = async (id: string, approve: boolean) => { await api(`/api/approvals/${id}`, { body: { approve } }).catch(() => {}); setList((l) => l.filter((x) => x.id !== id)); };
  const a = list[0];
  if (a) return (
    <div className="modal"><div className="card">
      <h1 className="row"><AlertTriangle color="var(--warn)" /> {t("approvalNeeded")}</h1>
      <p><span className="pill warn">{a.category}</span> <span className="mute small">{a.actor}</span></p>
      <pre className="mono">{a.detail?.diff ?? JSON.stringify(a.detail, null, 2)}</pre>
      <div className="row"><button className="btn pri" onClick={() => answer(a.id, true)}>{t("approve")}</button>
        <button className="btn danger" onClick={() => answer(a.id, false)}>{t("deny")}</button></div>
    </div></div>);
  if (help) return (
    <div className="modal"><div className="card">
      <h1 className="row"><LifeBuoy color="var(--orange)" /> {t("helpNeeded")}</h1><p>{help.question}</p>
      <textarea rows={3} value={ans} onChange={(e) => setAns(e.target.value)} />
      <div className="row" style={{ marginTop: 10 }}>
        <button className="btn pri" onClick={async () => { await api(`/api/tasks/${help.task_id}/message`, { body: { text: ans } }).catch(() => {}); setHelp(null); setAns(""); }}>{t("reply")}</button>
        <button className="btn danger" onClick={async () => { await api(`/api/tasks/${help.task_id}/stop`, { body: {} }); setHelp(null); }}>{t("stop")}</button>
      </div>
    </div></div>);
  return null;
}

export function PlanView({ steps }: { steps: { title: string; status: string }[] }) {
  if (!steps?.length) return <div className="mute small">—</div>;
  const icon: Record<string, JSX.Element> = { done: <CheckCircle2 size={15} color="var(--ok)" />, active: <CircleDot size={15} color="var(--orange)" className="spin-slow" />, failed: <XCircle size={15} color="var(--bad)" />, pending: <Circle size={15} color="#555" /> };
  return <div>{steps.map((s, i) => <div key={i} className="small row" style={{ padding: "3px 0", flexWrap: "nowrap" }}>{icon[s.status] ?? icon.pending} {s.title}</div>)}</div>;
}

export function TaskControls({ task }: { task: any }) {
  const t = useT();
  if (!task) return null;
  const op = (o: string) => api(`/api/tasks/${task.id}/${o}`, { body: {} }).catch((e) => alert(e.message));
  return <div className="row">
    <span className="pill or">#{task.id} {task.status}</span>
    <button className="btn" onClick={() => op("pause")} aria-disabled={task.status !== "running"}><Pause size={13} /> {t("pause")}</button>
    <button className="btn" onClick={() => op("resume")} aria-disabled={!["paused", "interrupted", "stopped"].includes(task.status)}><Play size={13} /> {t("resume")}</button>
    <button className="btn danger" onClick={() => op("stop")}><Square size={13} /> {t("stop")}</button>
  </div>;
}

export function TaskLog({ taskId }: { taskId: number | null }) {
  const { data } = usePoll<any>(taskId ? `/api/tasks/${taskId}` : "/api/status", 2000, [taskId]);
  if (!taskId || !data?.events) return <div className="mute small">—</div>;
  return <div className="log">{data.events.map((e: any) => <div key={e.id}><span className={`pill ${e.level === "error" ? "bad" : e.level === "warn" ? "warn" : ""}`}>{e.level}</span> <span className="mute">{new Date(e.ts * 1000).toLocaleTimeString()}</span> {e.message}</div>)}</div>;
}

export const fmtDur = (s: number) => `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m ${s % 60}s`;
