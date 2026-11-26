import { useEffect, useMemo, useRef, useState } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { python } from "@codemirror/lang-python";
import { html } from "@codemirror/lang-html";
import { css } from "@codemirror/lang-css";
import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";
import { api, onEvent } from "../api";
import { useT } from "../i18n";
import { PlanView, TaskControls, usePoll } from "../components/common";
import { Stethoscope, ScanSearch, Wand2, CheckCircle2, XCircle, Loader2, FileWarning, Terminal, Eye, MessageSquareText, Bug, MonitorX, Sparkles, FilePen, FolderOpen } from "lucide-react";

type Issue = { file: string; line: number; message: string; source: string };
type Check = { name: string; state: "running" | "done"; issues: number; output: string };
const key = (i: Issue) => `${i.source}|${i.file}|${i.message}`;
const langFor = (p: string) => p.endsWith(".py") ? [python()] : p.endsWith(".lua") ? [StreamLanguage.define(lua)] : p.match(/\.html?$/) ? [html()]
  : p.endsWith(".css") ? [css()] : p.match(/\.(m?[jt]sx?)$/) ? [javascript({ jsx: true, typescript: /tsx?$/.test(p) })] : [];

export default function Doctor({ go }: { go: (p: any) => void }) {
  const t = useT();
  const [tab, setTab] = useState<"project" | "windows">("project");
  const { data: settings } = usePoll<any>("/api/settings", 30000);
  const [root, setRoot] = useState(""); const [ask, setAsk] = useState(""); const [review, setReview] = useState(false);
  const [taskId, setTaskId] = useState<number | null>(null); const [busy, setBusy] = useState(false);
  const [checks, setChecks] = useState<Record<string, Check>>({});
  const [first, setFirst] = useState<Issue[] | null>(null); const [current, setCurrent] = useState<Issue[]>([]);
  const [kinds, setKinds] = useState<string[]>([]);
  const [feed, setFeed] = useState<{ ts: number; kind: string; text: string }[]>([]);
  const [term, setTerm] = useState<string[]>([]);
  const [live, setLive] = useState<{ path: string; content: string; diff: string } | null>(null);
  const { data: td } = usePoll<any>(taskId ? `/api/tasks/${taskId}` : "/api/status", 1200, [taskId]);
  const task = taskId ? td?.task : null;
  const tid = useRef<number | null>(null); const pending = useRef(false); tid.current = pending.current ? -1 : taskId;

  useEffect(() => { if (!root && settings?.allowed_folders?.[0]) setRoot(settings.allowed_folders[0]); }, [settings]);
  useEffect(() => onEvent((e) => {
    const mine = e.data?.task_id == null || e.data.task_id === tid.current || (tid.current === -1 && e.type.startsWith("doctor"));
    if (!mine) return;
    if (e.type === "doctor") {
      setChecks((c) => ({ ...c, [e.data.check]: { name: e.data.check, state: e.data.state, issues: e.data.issues, output: e.data.output } }));
      if (e.data.state === "done" && e.data.output) setTerm((l) => [...l, `$ ${e.data.check}\n${e.data.output}`].slice(-60));
    }
    if (e.type === "doctor_report") { setCurrent(e.data.issues); setKinds(e.data.kinds); setFirst((f) => f ?? e.data.issues); }
    if (e.type === "agent_say") setFeed((f) => [...f, { ts: e.ts, kind: "say", text: e.data.text }]);
    if (e.type === "decision") {
      const i = e.data.input ?? {};
      setFeed((f) => [...f, { ts: e.ts, kind: e.data.action, text: i.path ?? i.command ?? i.query ?? "" }]);
      if (e.data.action === "run_command") setTerm((l) => [...l, `$ ${i.command}`]);
    }
    if (e.type === "file_change") {
      api<any>(`/api/files/read?path=${encodeURIComponent(e.data.path)}`).then((f) => setLive({ path: e.data.path, content: f.content, diff: e.data.diff })).catch(() => {});
    }
  }), []);

  const reset = () => { setChecks({}); setFirst(null); setCurrent([]); setFeed([]); setTerm([]); setLive(null); };
  const scan = async () => {
    reset(); setTaskId(null); setBusy(true);
    try { const r = await api<any>("/api/doctor/scan", { body: { root } }); setFirst(r.issues); setCurrent(r.issues); setKinds(r.kinds); }
    catch (e: any) { alert(e.message); }
    setBusy(false);
  };
  const fix = async () => {
    reset(); pending.current = true; tid.current = -1;
    const r = await api<any>("/api/tasks", { body: { kind: "doctor", title: `Doctor: ${root.split(/[\\/]/).pop()}`, prompt: ask, state: { root, review } } }).catch((e) => alert(e.message));
    pending.current = false; if (r) { tid.current = r.id; setTaskId(r.id); }
  };

  const curKeys = useMemo(() => new Set(current.map(key)), [current]);
  const resolved = (first ?? []).filter((i) => !curKeys.has(key(i))).length;
  const total = first?.length ?? 0;
  const ext = useMemo(() => langFor(live?.path ?? ""), [live?.path]);
  const changedLines = useMemo(() => {
    if (!live) return [] as number[]; const out: number[] = []; let n = 0;
    for (const l of live.diff.split("\n")) { const h = l.match(/^@@ -\d+(?:,\d+)? \+(\d+)/); if (h) { n = +h[1]; continue; } if (l.startsWith("+") && !l.startsWith("+++")) out.push(n++); else if (!l.startsWith("-")) n++; }
    return out;
  }, [live]);

  return <>
    <div className="row" style={{ justifyContent: "space-between", marginBottom: 14 }}>
      <h1 className="row" style={{ margin: 0 }}><Stethoscope color="var(--orange)" /> {t("doctor")}</h1>
      <div className="seg big">
        <button className={tab === "project" ? "on" : ""} onClick={() => setTab("project")}><Bug size={14} /> Projects & code</button>
        <button className={tab === "windows" ? "on" : ""} onClick={() => setTab("windows")}><MonitorX size={14} /> Windows app crashes</button>
      </div>
    </div>
    {tab === "windows" ? <WinCrashes go={go} /> : <>
      <div className="card doc-bar">
        <FolderOpen size={18} className="mute" />
        <select value={root} onChange={(e) => setRoot(e.target.value)} style={{ maxWidth: 360 }}>{(settings?.allowed_folders ?? []).map((f: string) => <option key={f}>{f}</option>)}</select>
        <input value={ask} onChange={(e) => setAsk(e.target.value)} placeholder="اختياري: صف المشكلة — مثال: الزر لا يعمل والسكربت يعطي خطأ عند التشغيل" />
        <label className="row small" style={{ margin: 0, whiteSpace: "nowrap" }}><input type="checkbox" style={{ width: "auto" }} checked={review} onChange={(e) => setReview(e.target.checked)} /> {t("review")}</label>
        <button className="btn" onClick={scan} aria-disabled={!root || busy}>{busy ? <Loader2 size={15} className="spin" /> : <ScanSearch size={15} />} Scan</button>
        <button className="btn pri" onClick={fix} aria-disabled={!root || !!(task && task.status === "running")}><Wand2 size={15} /> Fix with AI</button>
        <TaskControls task={task} />
      </div>
      {!settings?.allowed_folders?.length && <div className="banner">Add a project folder in Settings → Allowed folders first.</div>}

      <div className="doc-grid">
        {/* left: checks + issues */}
        <div className="card doc-col">
          <h2>Health</h2>
          <div className="health">
            <div className="ring" style={{ ["--p" as any]: total ? resolved / total : (first ? 1 : 0) }}><b>{first ? (total ? `${resolved}/${total}` : "✓") : "—"}</b><small>{first ? (total ? "fixed" : "clean") : "not scanned"}</small></div>
            <div className="small mute">{kinds.length ? kinds.join(" · ") : "Detects Python, Node/TypeScript, Lua/FiveM, HTML, JSON"}</div>
          </div>
          <h2 style={{ marginTop: 14 }}>Checks</h2>
          {Object.values(checks).map((c) => <div key={c.name} className="chk">{c.state === "running" ? <Loader2 size={15} className="spin" color="var(--orange)" /> : c.issues ? <XCircle size={15} color="var(--bad)" /> : <CheckCircle2 size={15} color="var(--ok)" />}
            <span>{c.name}</span>{c.state === "done" && c.issues > 0 && <span className="pill bad">{c.issues}</span>}</div>)}
          {!Object.keys(checks).length && <div className="mute small">—</div>}
          <h2 style={{ marginTop: 14 }}>Issues</h2>
          <div className="issues">{(first ?? []).map((i, n) => { const done = !curKeys.has(key(i)); return <div key={n} className={`iss ${done ? "ok" : ""}`}>
            {done ? <CheckCircle2 size={14} color="var(--ok)" /> : <FileWarning size={14} color="var(--warn)" />}
            <div><div className="mono">{i.file}{i.line ? `:${i.line}` : ""} <span className="pill">{i.source}</span></div><div className="small">{i.message}</div></div></div>; })}
            {current.filter((i) => !(first ?? []).some((f) => key(f) === key(i))).map((i, n) => <div key={"n" + n} className="iss"><FileWarning size={14} color="var(--bad)" /><div><div className="mono">{i.file}:{i.line} <span className="pill bad">new</span></div><div className="small">{i.message}</div></div></div>)}
            {first && !first.length && <div className="row small" style={{ color: "var(--ok)" }}><Sparkles size={14} /> No issues found</div>}</div>
        </div>

        {/* center: live repair view */}
        <div className="card doc-live">
          <div className="row" style={{ justifyContent: "space-between" }}>
            <h2 className="row" style={{ margin: 0 }}><Eye size={15} /> Live repair {task?.status === "running" && <span className="live-dot" />}</h2>
            <span className="mono small mute row livepath" dir="ltr"><FilePen size={13} /> {live ? live.path : "waiting for the first edit…"}</span>
          </div>
          {live ? <>
            <div className="editor-wrap" dir="ltr"><CodeMirror value={live.content} height="100%" theme="dark" editable={false} extensions={ext}
              onCreateEditor={(v) => { const l = changedLines[0]; if (l) setTimeout(() => { try { v.dispatch({ selection: { anchor: v.state.doc.line(Math.min(l, v.state.doc.lines)).from }, scrollIntoView: true }); } catch { /* ignore */ } }, 50); }} key={live.path + live.diff.length} /></div>
            <div className="difbox mono" dir="ltr">{live.diff.split("\n").slice(2).map((l, j) => <div key={j} className={l.startsWith("+") ? "diff-add" : l.startsWith("-") ? "diff-del" : l.startsWith("@@") ? "mute" : ""}>{l || " "}</div>)}</div>
          </> : <div className="empty"><Wand2 size={36} color="#333" /><div className="mute">Press <b>Fix with AI</b> — you will see each file open here and every change highlighted as Claude makes it.</div></div>}
        </div>

        {/* right: narration + plan + terminal */}
        <div className="doc-col2">
          <div className="card"><h2>Plan</h2><PlanView steps={task?.plan ? JSON.parse(task.plan) : []} />
            {task && <><label>Progress</label><div className="bar"><div style={{ width: `${(task.progress ?? 0) * 100}%` }} /></div></>}</div>
          <div className="card feed"><h2 className="row"><MessageSquareText size={14} /> What Claude is doing</h2>
            {feed.slice().reverse().map((f, i) => <div key={i} className={`fi ${f.kind}`}><span className="mute">{new Date(f.ts * 1000).toLocaleTimeString()}</span> {f.kind === "say" ? f.text : <><b>{f.kind}</b> <span className="mono">{f.text}</span></>}</div>)}
            {!feed.length && <div className="mute small">—</div>}</div>
          <div className="card term"><h2 className="row"><Terminal size={14} /> Terminal</h2><pre className="mono" dir="ltr">{term.join("\n\n") || "—"}</pre></div>
        </div>
      </div>
    </>}
  </>;
}

function WinCrashes({ go }: { go: (p: any) => void }) {
  const { data } = usePoll<any>("/api/doctor/windows-errors?days=7", 60000);
  const [ans, setAns] = useState<Record<number, string>>({}); const [busy, setBusy] = useState<number | null>(null);
  const analyze = async (i: number, e: any) => {
    setBusy(i);
    const r = await api<any>("/api/chat", { body: { text: `حلل هذا الخطأ من سجل أحداث Windows واشرح السبب المحتمل وخطوات إصلاح آمنة (بدون تعديل إعدادات الأمان):\n\n${e.message}` } }).catch((x) => ({ reply: "⚠️ " + x.message }));
    setAns((a) => ({ ...a, [i]: r.reply })); setBusy(null);
  };
  if (!data) return <div className="mute">…</div>;
  if (!data.available) return <div className="banner">Reading the Windows Application event log is available on Windows only.</div>;
  return <div className="card">
    <p className="small mute">Read-only: application crashes and hangs from the last 7 days (Event IDs 1000/1001/1002). ROX does not change system settings; Claude explains the cause and suggests safe fixes.</p>
    {!data.events.length && <div className="row" style={{ color: "var(--ok)" }}><Sparkles size={16} /> No application crashes recorded.</div>}
    {data.events.map((e: any, i: number) => <div key={i} className="crash">
      <div className="row" style={{ justifyContent: "space-between" }}><div className="row"><MonitorX size={16} color="var(--bad)" /><b>{e.app || e.provider}</b><span className="pill">ID {e.id}</span><span className="small mute">{e.time}</span></div>
        <button className="btn" onClick={() => analyze(i, e)} aria-disabled={busy === i}>{busy === i ? <Loader2 size={14} className="spin" /> : <Wand2 size={14} />} Diagnose</button></div>
      <details><summary className="small mute">Details</summary><pre className="mono">{e.message}</pre></details>
      {ans[i] && <div className="msg assistant" style={{ maxWidth: "100%", marginTop: 8 }}>{ans[i]}</div>}
    </div>)}
  </div>;
}
