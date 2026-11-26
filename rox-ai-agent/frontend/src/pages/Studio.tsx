import { useEffect, useMemo, useRef, useState } from "react";
import { api, TOKEN, WS } from "../api";
import { usePoll, TaskLog, fmtDur } from "../components/common";

type Action = { id: string; type: "target" | "wait_target" | "click" | "key" | "type" | "delay"; asset?: string; threshold?: number; method?: string;
  area?: { left: number; top: number; width: number; height: number } | null; x?: number | null; y?: number | null; button?: string; keys?: string; text?: string; ms?: number; timeout_ms?: number };
type Timeline = { id: string; name: string; actions: Action[] };
const uid = () => Math.random().toString(36).slice(2, 9);
const NOMINAL = 500; // ms shown for non-delay actions on the track
const dur = (a: Action) => a.type === "delay" ? a.ms ?? 1000 : a.type === "wait_target" ? Math.max(NOMINAL, a.timeout_ms ?? 0) : NOMINAL;
const COLORS: Record<string, string> = { target: "#b8324a", wait_target: "#8c2c5a", click: "#2a6fa8", key: "#1f7a5a", type: "#1f7a5a", delay: "#b8651a" };
const LABEL: Record<string, string> = { target: "Target", wait_target: "Wait Target", click: "Click", key: "Key", type: "Type", delay: "Delay" };

/* ---------- resizable split ---------- */
function useDrag(init: number, min: number, max: number, axis: "x" | "y", invert = false) {
  const [v, setV] = useState(init);
  const start = (e: React.MouseEvent) => {
    e.preventDefault(); const s = axis === "x" ? e.clientX : e.clientY; const v0 = v;
    const rtl = document.documentElement.dir === "rtl" && axis === "x";
    const mv = (m: MouseEvent) => { let d = (axis === "x" ? m.clientX : m.clientY) - s; if (invert !== rtl) d = -d; setV(Math.min(max, Math.max(min, v0 + d))); };
    const up = () => { removeEventListener("mousemove", mv); removeEventListener("mouseup", up); };
    addEventListener("mousemove", mv); addEventListener("mouseup", up);
  };
  return [v, start] as const;
}

export default function Studio({ go }: { go: (p: any) => void }) {
  const [left, dragL] = useDrag(240, 170, 420, "x");
  const [right, dragR] = useDrag(300, 230, 480, "x", true);
  const [bottom, dragB] = useDrag(260, 140, 520, "y", true);

  const [tls, setTls] = useState<Timeline[]>([]); const [sel, setSel] = useState<string>(""); const [act, setAct] = useState<string>("");
  const [assets, setAssets] = useState<{ name: string; b64: string }[]>([]);
  const [win, setWin] = useState(""); const [selecting, setSelecting] = useState(false);
  const [match, setMatch] = useState<any>(null); const [taskId, setTaskId] = useState<number | null>(null); const [saved, setSaved] = useState(true);
  const { data: adapters } = usePoll<any[]>("/api/games/adapters", 60000);
  const { data: tasks } = usePoll<any[]>("/api/tasks", 3000);
  const { data: wins } = usePoll<any[]>("/api/windows", 20000);
  const { data: status } = usePoll<any>("/api/status", 1500);
  const { data: td } = usePoll<any>(taskId ? `/api/tasks/${taskId}` : "/api/status", 700, [taskId]);
  const running = taskId && td?.task && ["running", "paused"].includes(td.task.status) ? td.task : null;

  const loadAssets = () => api<any[]>("/api/assets").then(setAssets).catch(() => {});
  useEffect(() => { api<Timeline[]>("/api/timelines").then((t) => { const v = t.length ? t : [{ id: uid(), name: "Main", actions: [] }]; setTls(v); setSel(v[0].id); }); loadAssets(); }, []);
  const tl = tls.find((t) => t.id === sel); const action = tl?.actions.find((a) => a.id === act);
  const upd = (fn: (t: Timeline) => Timeline) => { setTls((all) => all.map((t) => t.id === sel ? fn(t) : t)); setSaved(false); };
  const updAct = (patch: Partial<Action>) => upd((t) => ({ ...t, actions: t.actions.map((a) => a.id === act ? { ...a, ...patch } : a) }));
  const save = () => api("/api/timelines", { method: "PUT", body: tls }).then(() => setSaved(true)).catch((e) => alert(e.message));
  const addAction = (type: Action["type"]) => { const a: Action = { id: uid(), type, ...(type === "delay" ? { ms: 1000 } : type.includes("target") ? { asset: assets[0]?.name, threshold: 0.85, method: "template_fast", timeout_ms: 5000 } : type === "key" ? { keys: "q" } : type === "type" ? { text: "" } : {}) };
    upd((t) => ({ ...t, actions: [...t.actions, a] })); setAct(a.id); };
  const play = async () => {
    if (running) { await api(`/api/tasks/${running.id}/stop`, { body: {} }); return; }
    if (!saved) await save();
    const r = await api<any>("/api/tasks", { body: { kind: "timeline", title: `Timeline: ${tl?.name}`, prompt: "", state: { timeline_id: sel, loops: 1 } } }).catch((e) => alert(e.message));
    if (r) setTaskId(r.id);
  };
  const testMatch = () => action?.asset && api("/api/match", { body: { asset: action.asset, threshold: action.threshold ?? 0.85, method: action.method, area: action.area } }).then(setMatch).catch((e) => alert(e.message));

  // track geometry
  const starts = useMemo(() => { let t = 0; return (tl?.actions ?? []).map((a) => { const s = t; t += dur(a); return s; }); }, [tl]);
  const total = Math.max(7000, (starts.at(-1) ?? 0) + (tl?.actions.at(-1) ? dur(tl.actions.at(-1)!) : 0) + 1000);
  const PX = 0.17; // px per ms
  const prog = running ? (running.progress ?? 0) : 0;
  const playMs = running ? prog * ((starts.at(-1) ?? 0) + (tl?.actions.at(-1) ? dur(tl.actions.at(-1)!) : 0)) : 0;

  return <div className="studio" style={{ gridTemplateColumns: `${left}px 6px 1fr 6px ${right}px`, gridTemplateRows: `1fr 6px ${bottom}px` }}>
    {/* ---------- LEFT: workspace tree ---------- */}
    <section className="pane" style={{ gridRow: 1, gridColumn: 1 }}>
      <div className="phead">PROJECT WORKSPACE</div>
      <div className="tree2">
        {(adapters ?? []).map((a) => { const mine = (tasks ?? []).filter((t) => t.kind === "game" && (t.state ?? "").includes(`"${a.id}"`)).slice(0, 4);
          return <details key={a.id} open={a.id === "generic"}><summary><span className="star">★</span> {a.name}</summary>
            <div className="leaf mute">ⓘ {a.tags.join(" · ") || "adapter"}</div>
            <div className="sub">BOTS</div>
            {mine.map((t) => <div key={t.id} className={`leaf ${t.status === "running" ? "on" : ""}`} onClick={() => setTaskId(t.id)}>🤖 #{t.id} {t.title.slice(0, 18)} {t.status === "running" && <b className="go">▶</b>}</div>)}
            <div className="leaf mute" onClick={() => go("game")}>⊕ Assign bot…</div></details>; })}
        <details open><summary><span className="star">★</span> Timelines</summary>
          {tls.map((t) => <div key={t.id} className={`leaf ${t.id === sel ? "on" : ""}`} onClick={() => setSel(t.id)}>⏱ {t.name}</div>)}</details>
      </div>
      <div className="pnav">{[["dashboard", "⌂ Home"], ["chat", "💬 Chat"], ["tasks", "⏱ Tasks"], ["settings", "⚙ Settings"]].map(([k, l]) => <div key={k} onClick={() => go(k)}>{l}</div>)}</div>
    </section>
    <div className="split v" style={{ gridRow: 1, gridColumn: 2 }} onMouseDown={dragL} />

    {/* ---------- CENTER: live view ---------- */}
    <section className="pane center" style={{ gridRow: 1, gridColumn: 3 }}>
      <LiveView win={win} selecting={selecting} match={match}
        onSelect={async (r) => { setSelecting(false); const name = prompt("Asset name / اسم العنصر:"); if (!name) return;
          await api("/api/assets", { body: { name, ...r } }).then(loadAssets).catch((e) => alert(e.message)); if (action?.type.includes("target")) updAct({ asset: name.replace(/[^\w-]+/g, "_") }); }}
        toolbar={<div className="ftool">
          <button className={`ti ${running ? "act" : ""}`} onClick={play} title="Run timeline">{running ? "■" : "▶"}</button>
          <span className="tl">{running ? running.status : "Idle"}</span>
          <select className="tsel" value={win} onChange={(e) => setWin(e.target.value)}><option value="">Full desktop</option>{(wins ?? []).map((w) => <option key={w.title}>{w.title}</option>)}</select>
          <button className={`ti ${selecting ? "act" : ""}`} onClick={() => setSelecting(!selecting)} title="Capture asset: drag a box on the view">＋</button>
          <button className="ti" onClick={() => addAction("click")} title="Add click">➚</button>
          <button className="ti" onClick={() => addAction("key")} title="Add key">⌨</button>
          <button className="ti" onClick={() => addAction("delay")} title="Add delay">◷</button>
          <button className="ti" onClick={() => window.rox?.toggleFullscreen()} title="Fullscreen">⛶</button>
          <button className="ti" onClick={() => go("settings")} title="Settings">⚙</button>
          <span className="sess"><small>SESSION</small>{status ? fmtDur(status.uptime_s) : "--"}</span>
        </div>} />
    </section>
    <div className="split v" style={{ gridRow: 1, gridColumn: 4 }} onMouseDown={dragR} />

    {/* ---------- RIGHT: target settings ---------- */}
    <section className="pane" style={{ gridRow: 1, gridColumn: 5 }}>
      <div className="phead">TARGET SETTINGS {action && <button className="x" onClick={() => { upd((t) => ({ ...t, actions: t.actions.filter((a) => a.id !== act) })); setAct(""); }}>🗑</button>}</div>
      {!action ? <div className="mute small p">Select an action on the timeline, or add one.</div> : <div className="p">
        <div className="seg">{["target", "wait_target", "click", "key", "type", "delay"].map((k) => <button key={k} className={action.type === k ? "on" : ""} onClick={() => updAct({ type: k as any })}>{LABEL[k]}</button>)}</div>
        {action.type.includes("target") && <>
          <div className="prev">{(() => { const a = assets.find((x) => x.name === action.asset); return a ? <img src={`data:image/png;base64,${a.b64}`} /> : <span className="mute small">No asset — use ＋ on the view</span>; })()}
            {match && match.confidence !== undefined && <span className={`mbadge ${match.found ? "" : "no"}`}>{Math.round(match.confidence * 100)}% MATCH</span>}</div>
          <label>Asset</label><select value={action.asset ?? ""} onChange={(e) => updAct({ asset: e.target.value })}>{assets.map((a) => <option key={a.name}>{a.name}</option>)}</select>
          <div className="sub">DETECTION</div>
          <label>Confidence threshold <b style={{ float: "inline-end" }}>{Math.round((action.threshold ?? .85) * 100)}%</b></label>
          <input type="range" min={50} max={99} value={Math.round((action.threshold ?? .85) * 100)} onChange={(e) => updAct({ threshold: +e.target.value / 100 })} />
          <label>Match method</label><select value={action.method} onChange={(e) => updAct({ method: e.target.value })}><option value="template_fast">Template Matching (Fast)</option><option value="template_precise">Template Matching (Correlation)</option></select>
          {action.type === "wait_target" && <><label>Timeout (ms)</label><input type="number" value={action.timeout_ms ?? 5000} onChange={(e) => updAct({ timeout_ms: +e.target.value })} /></>}
          <div className="sub">AREA OF INTEREST <label className="inl"><input type="checkbox" checked={!!action.area} onChange={(e) => updAct({ area: e.target.checked ? { left: 0, top: 0, width: 800, height: 600 } : null })} /> limit</label></div>
          {action.area && <div className="xywh">{(["left", "top", "width", "height"] as const).map((k) => <label key={k}><span>{k[0].toUpperCase()}</span><input type="number" value={action.area![k]} onChange={(e) => updAct({ area: { ...action.area!, [k]: +e.target.value } })} /></label>)}</div>}
          <button className="btn pri" style={{ marginTop: 12, width: "100%", textAlign: "center" }} onClick={testMatch}>Test match now</button>
          {match && <div className="small mute" style={{ marginTop: 6 }}>{match.found ? `Found at ${match.x},${match.y} in ${match.ms}ms` : "Not found above threshold"}</div>}
        </>}
        {action.type === "click" && <><label>X / Y (empty = last target)</label><div className="row" style={{ flexWrap: "nowrap" }}>
          <input type="number" value={action.x ?? ""} onChange={(e) => updAct({ x: e.target.value === "" ? null : +e.target.value })} /><input type="number" value={action.y ?? ""} onChange={(e) => updAct({ y: e.target.value === "" ? null : +e.target.value })} /></div>
          <label>Button</label><select value={action.button ?? "left"} onChange={(e) => updAct({ button: e.target.value })}><option>left</option><option>right</option><option>middle</option></select></>}
        {action.type === "key" && <><label>Keys (e.g. q, ctrl+s)</label><input value={action.keys ?? ""} onChange={(e) => updAct({ keys: e.target.value })} /></>}
        {action.type === "type" && <><label>Text</label><textarea rows={3} value={action.text ?? ""} onChange={(e) => updAct({ text: e.target.value })} /></>}
        {action.type === "delay" && <><label>Delay (ms)</label><input type="number" value={action.ms ?? 1000} onChange={(e) => updAct({ ms: +e.target.value })} /></>}
      </div>}
    </section>

    {/* ---------- BOTTOM: timelines ---------- */}
    <div className="split h" style={{ gridRow: 2, gridColumn: "1 / -1" }} onMouseDown={dragB} />
    <section className="pane bottom" style={{ gridRow: 3, gridColumn: "1 / -1" }}>
      <div className="tlcol">
        <div className="phead">TIMELINES <button className="x" onClick={() => { const t = { id: uid(), name: `Timeline ${tls.length + 1}`, actions: [] }; setTls([...tls, t]); setSel(t.id); setSaved(false); }}>＋</button></div>
        {tls.map((t) => <div key={t.id} className={`tli ${t.id === sel ? "on" : ""}`} onClick={() => setSel(t.id)} onDoubleClick={() => { const n = prompt("Name", t.name); if (n) { setTls(tls.map((x) => x.id === t.id ? { ...x, name: n } : x)); setSaved(false); } }}>
          {t.name}<span>{t.actions.length} actions</span></div>)}
      </div>
      <div className="propcol">
        <div className="row" style={{ padding: 8 }}><button className="ti" onClick={play}>{running ? "■" : "▶"}</button><span className="pill or">{(playMs / 1000).toFixed(2)}s</span>
          <button className="ti" title="Delete timeline" onClick={() => { if (tls.length > 1 && confirm("Delete timeline?")) { const r = tls.filter((t) => t.id !== sel); setTls(r); setSel(r[0].id); setSaved(false); } }}>🗑</button></div>
        <div className="sub" style={{ padding: "0 10px" }}>ASSETS</div>
        <div className="assets">{assets.map((a) => <img key={a.name} title={a.name} src={`data:image/png;base64,${a.b64}`} onClick={() => action?.type.includes("target") && updAct({ asset: a.name })} />)}
          <button className="aadd" onClick={() => setSelecting(true)}>＋</button></div>
        <div className="row" style={{ padding: 8 }}>{(["target", "click", "key", "delay"] as const).map((k) => <button key={k} className="btn small" onClick={() => addAction(k)}>+{LABEL[k]}</button>)}</div>
        <button className={`btn ${saved ? "" : "pri"}`} style={{ margin: 8, textAlign: "center" }} onClick={save}>{saved ? "Saved" : "💾 Save preset"}</button>
      </div>
      <div className="track" dir="ltr">
        <div className="ruler" style={{ width: total * PX }}>{Array.from({ length: Math.ceil(total / 1000) + 1 }, (_, i) => <span key={i} style={{ left: i * 1000 * PX }}>{i}s</span>)}</div>
        <div className="lane-l">ACTIONS LINE</div>
        <div className="lane" style={{ width: total * PX }}>{tl?.actions.map((a, i) => a.type !== "delay" &&
          <div key={a.id} className={`blk ${a.id === act ? "sel" : ""}`} style={{ left: starts[i] * PX, width: Math.max(70, dur(a) * PX), background: COLORS[a.type] }} onClick={() => setAct(a.id)}>
            {LABEL[a.type]} {a.asset ?? a.keys ?? (a.x != null ? `${a.x},${a.y}` : "")}</div>)}</div>
        <div className="lane-l or">DELAY LINE</div>
        <div className="lane" style={{ width: total * PX }}>{tl?.actions.map((a, i) => a.type === "delay" &&
          <div key={a.id} className={`blk dl ${a.id === act ? "sel" : ""}`} style={{ left: starts[i] * PX, width: Math.max(70, dur(a) * PX) }} onClick={() => setAct(a.id)}>◷ Delay ({a.ms}ms)</div>)}</div>
        {running && <div className="playhead" style={{ left: playMs * PX }}><em>{(playMs / 1000).toFixed(2)}</em></div>}
        {taskId && <div className="tlog"><TaskLog taskId={taskId} /></div>}
      </div>
    </section>
  </div>;
}

/* ---------- live view with drag-to-select + match overlay ---------- */
function LiveView({ win, selecting, onSelect, match, toolbar }: { win: string; selecting: boolean; onSelect: (r: any) => void; match: any; toolbar: React.ReactNode }) {
  const [src, setSrc] = useState(""); const [err, setErr] = useState(""); const img = useRef<HTMLImageElement>(null);
  const [scr, setScr] = useState<{ w: number; h: number } | null>(null); const [box, setBox] = useState<any>(null);
  const [region, setRegion] = useState<any>(null);
  useEffect(() => { api<any>("/api/screen/size").then(setScr).catch(() => {}); }, []);
  useEffect(() => { if (win) api<any[]>("/api/windows").then((w) => setRegion(w.find((x) => x.title === win) ?? null)); else setRegion(null); }, [win]);
  useEffect(() => {
    const ws = new WebSocket(`${WS}/ws/screen?token=${encodeURIComponent(TOKEN)}&fps=10&window=${encodeURIComponent(win)}`);
    ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.error) setErr(d.error); else { setErr(""); setSrc("data:image/jpeg;base64," + d.frame); } };
    ws.onerror = () => setErr("backend offline"); return () => ws.close();
  }, [win]);
  // convert view px -> real screen px
  const real = () => { const el = img.current!.getBoundingClientRect(); const R = region ?? { left: 0, top: 0, width: scr?.w ?? 1, height: scr?.h ?? 1 };
    return { el, R, sx: R.width / el.width, sy: R.height / el.height }; };
  const down = (e: React.MouseEvent) => { if (!selecting || !img.current) return; const { el } = real(); setBox({ x0: e.clientX - el.left, y0: e.clientY - el.top, x1: e.clientX - el.left, y1: e.clientY - el.top }); };
  const moveM = (e: React.MouseEvent) => { if (!box || !img.current) return; const { el } = real(); setBox({ ...box, x1: e.clientX - el.left, y1: e.clientY - el.top }); };
  const up = () => { if (!box) return; const { R, sx, sy } = real(); const x = Math.min(box.x0, box.x1), y = Math.min(box.y0, box.y1);
    onSelect({ left: Math.round(R.left + x * sx), top: Math.round(R.top + y * sy), width: Math.round(Math.abs(box.x1 - box.x0) * sx), height: Math.round(Math.abs(box.y1 - box.y0) * sy) }); setBox(null); };
  let mbox = null;
  if (match?.found && img.current) { const { R, sx, sy } = real(); mbox = { left: (match.x - R.left) / sx, top: (match.y - R.top) / sy, width: match.w / sx, height: match.h / sy }; }
  return <div className="live" onMouseMove={moveM} onMouseUp={up}>
    {toolbar}
    {src ? <div className="imgwrap" style={{ cursor: selecting ? "crosshair" : "default" }} onMouseDown={down}>
      <img ref={img} src={src} draggable={false} />
      {box && <div className="selbox" style={{ left: Math.min(box.x0, box.x1), top: Math.min(box.y0, box.y1), width: Math.abs(box.x1 - box.x0), height: Math.abs(box.y1 - box.y0) }} />}
      {mbox && <div className="matchbox" style={mbox}><span>Target · {Math.round(match.confidence * 100)}%</span></div>}
    </div> : <div className="mute small">{err || "Connecting to screen…"}</div>}
    {selecting && <div className="hint">Drag a box around the element to save it as an asset</div>}
  </div>;
}
