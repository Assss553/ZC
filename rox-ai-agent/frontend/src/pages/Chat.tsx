import { useEffect, useRef, useState } from "react";
import { api } from "../api";
import { useT } from "../i18n";
import { usePoll } from "../components/common";

type Msg = { role: string; text: string; proposal?: any; images?: number };

export default function Chat() {
  const t = useT();
  const { data: convs, setData: setConvs } = usePoll<any[]>("/api/conversations", 10000);
  const [cid, setCid] = useState<number | null>(null);
  const [msgs, setMsgs] = useState<Msg[]>([]); const [text, setText] = useState(""); const [busy, setBusy] = useState(false);
  const [shot, setShot] = useState(false); const [imgs, setImgs] = useState<{ media_type: string; data: string }[]>([]);
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => { end.current?.scrollIntoView({ behavior: "smooth" }); }, [msgs]);
  useEffect(() => {
    if (!cid) { setMsgs([]); return; }
    api<any[]>(`/api/conversations/${cid}`).then((h) => setMsgs(h.map((m) => ({ role: m.role, ...JSON.parse(m.content) }))));
  }, [cid]);

  const send = async () => {
    if (!text.trim() || busy) return;
    const mine: Msg = { role: "user", text, images: imgs.length + (shot ? 1 : 0) };
    setMsgs((m) => [...m, mine]); setText(""); setBusy(true);
    try {
      const r = await api<any>("/api/chat", { body: { conversation_id: cid, text: mine.text, images: imgs, attach_screenshot: shot } });
      if (!cid) { setCid(r.conversation_id); api<any[]>("/api/conversations").then(setConvs); }
      setMsgs((m) => [...m, { role: "assistant", text: r.reply, proposal: r.proposal }]);
    } catch (e: any) { setMsgs((m) => [...m, { role: "assistant", text: "⚠️ " + e.message }]); }
    setBusy(false); setImgs([]); setShot(false);
  };
  const addImage = (f: File) => { const rd = new FileReader(); rd.onload = () => setImgs((l) => [...l, { media_type: f.type, data: String(rd.result).split(",")[1] }]); rd.readAsDataURL(f); };

  return <div className="grid" style={{ gridTemplateColumns: "220px 1fr" }}>
    <div className="card" style={{ height: "calc(100vh - 60px)", overflow: "auto" }}>
      <button className="btn pri" style={{ width: "100%", textAlign: "center", marginBottom: 10 }} onClick={() => setCid(null)}>{t("newChat")}</button>
      {(convs ?? []).map((c) => <div key={c.id} className={`nav ${c.id === cid ? "on" : ""}`} style={{ display: "block" }} onClick={() => setCid(c.id)}>{c.title}</div>)}
    </div>
    <div className="card chat">
      <div className="msgs">
        {msgs.map((m, i) => <div key={i} className={`msg ${m.role}`}>
          {m.text}{m.images ? <div className="small mute">📎 {m.images}</div> : null}
          {m.proposal && <Proposal p={m.proposal} />}
        </div>)}
        {busy && <div className="msg assistant mute">…</div>}<div ref={end} />
      </div>
      <div className="row" style={{ marginTop: 8 }}>
        <label className="row small" style={{ margin: 0 }}><input type="checkbox" style={{ width: "auto" }} checked={shot} onChange={(e) => setShot(e.target.checked)} /> {t("attachShot")}</label>
        <label className="btn small" style={{ margin: 0 }}>{t("attachImg")} ({imgs.length})<input type="file" accept="image/png,image/jpeg,image/webp" hidden onChange={(e) => e.target.files?.[0] && addImage(e.target.files[0])} /></label>
      </div>
      <div className="row" style={{ marginTop: 8, flexWrap: "nowrap" }}>
        <textarea rows={2} value={text} placeholder={t("typeHere")} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } }} />
        <button className="btn pri" onClick={send} aria-disabled={busy}>{t("send")}</button>
      </div>
    </div>
  </div>;
}

function Proposal({ p }: { p: any }) {
  const t = useT(); const [state, setState] = useState<any>({}); const [done, setDone] = useState<string>("");
  const needsRoot = p.kind === "coding"; const needsWin = p.kind === "game";
  const { data: wins } = usePoll<any[]>(needsWin ? "/api/windows" : "/api/status", 15000);
  const run = async () => {
    try {
      const r = await api<any>("/api/tasks", { body: { kind: p.kind, title: p.title, prompt: p.prompt, start_at_local: p.start_at_local, end_at_local: p.end_at_local, state: { adapter: "generic", ...state } } });
      setDone(`#${r.id} ${r.status}`);
    } catch (e: any) { setDone("⚠️ " + e.message); }
  };
  return <div className="card" style={{ marginTop: 10, background: "#141416" }}>
    <div className="row"><span className="pill or">{p.kind}</span><b>{p.title}</b>{p.start_at_local && <span className="pill">{p.start_at_local} → {p.end_at_local ?? "…"}</span>}</div>
    <ol className="small">{p.plan.map((s: string, i: number) => <li key={i}>{s}</li>)}</ol>
    {needsRoot && <><label>{t("projectFolder")}</label><input placeholder={"C:\\Users\\you\\Desktop\\my-project"} onChange={(e) => setState({ ...state, root: e.target.value })} /></>}
    {needsWin && <><label>{t("selectWindow")}</label><select onChange={(e) => setState({ ...state, window: e.target.value })}><option value="">—</option>{(Array.isArray(wins) ? wins : []).map((w: any) => <option key={w.title}>{w.title}</option>)}</select></>}
    <div className="row" style={{ marginTop: 8 }}>{done ? <span className="pill ok">{done}</span> : <button className="btn pri" onClick={run}>{t("approveRun")}</button>}</div>
  </div>;
}
