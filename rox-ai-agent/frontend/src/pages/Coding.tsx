import { useEffect, useMemo, useState } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { python } from "@codemirror/lang-python";
import { html } from "@codemirror/lang-html";
import { css } from "@codemirror/lang-css";
import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";
import { api } from "../api";
import { useT } from "../i18n";
import { PlanView, TaskControls, TaskLog, usePoll } from "../components/common";
import { Folder, FileCode2, FilePlus2, FilePen, Undo2, Save } from "lucide-react";

const langFor = (p: string) => p.endsWith(".py") ? [python()] : p.endsWith(".lua") ? [StreamLanguage.define(lua)] : p.match(/\.html?$/) ? [html()]
  : p.endsWith(".css") ? [css()] : p.match(/\.(m?[jt]sx?)$/) ? [javascript({ jsx: true, typescript: /tsx?$/.test(p) })] : [];

export default function Coding() {
  const t = useT();
  const { data: settings } = usePoll<any>("/api/settings", 30000);
  const [root, setRoot] = useState(""); const [prompt, setPrompt] = useState(""); const [review, setReview] = useState(false);
  const [engine, setEngine] = useState("api"); const [taskId, setTaskId] = useState<number | null>(null);
  const [tree, setTree] = useState<any[]>([]); const [file, setFile] = useState<{ path: string; content: string } | null>(null); const [dirty, setDirty] = useState(false);
  const { data: td } = usePoll<any>(taskId ? `/api/tasks/${taskId}` : "/api/status", 2000, [taskId]);
  const task = taskId ? td?.task : null;
  useEffect(() => { if (!root && settings?.allowed_folders?.[0]) setRoot(settings.allowed_folders[0]); }, [settings]);
  const loadTree = () => root && api<any[]>(`/api/files/tree?root=${encodeURIComponent(root)}`).then(setTree).catch(() => setTree([]));
  useEffect(() => { loadTree(); }, [root, td?.changes?.length]);
  const open = (p: string) => api<any>(`/api/files/read?path=${encodeURIComponent(p)}`).then((f) => { setFile(f); setDirty(false); });
  const save = () => file && api("/api/files/write", { body: file }).then(() => setDirty(false)).catch((e) => alert(e.message));
  const run = async () => { const r = await api<any>("/api/tasks", { body: { kind: "coding", title: prompt.slice(0, 60), prompt, state: { root, review, engine } } }).catch((e) => alert(e.message)); if (r) setTaskId(r.id); };
  const ext = useMemo(() => langFor(file?.path ?? ""), [file?.path]);
  return <>
    <h1>{t("coding")}</h1>
    <div className="grid" style={{ gridTemplateColumns: "1fr 1.6fr" }}>
      <div className="grid">
        <div className="card">
          <label>{t("projectFolder")}</label>
          <select value={root} onChange={(e) => setRoot(e.target.value)}>{(settings?.allowed_folders ?? []).map((f: string) => <option key={f}>{f}</option>)}</select>
          {!settings?.allowed_folders?.length && <div className="small mute">Add an allowed folder in Settings first.</div>}
          <label>{t("request")}</label><textarea rows={4} value={prompt} onChange={(e) => setPrompt(e.target.value)} placeholder="أنشئ سكربت FiveM بلغة Lua لنظام وظائف مع fxmanifest.lua" />
          <label className="row"><input type="checkbox" style={{ width: "auto" }} checked={review} onChange={(e) => setReview(e.target.checked)} /> {t("review")}</label>
          <label>Engine</label><select value={engine} onChange={(e) => setEngine(e.target.value)}>
            <option value="api">Claude API (key)</option><option value="claude_code">Claude Code CLI (account login)</option></select>
          <div className="row" style={{ marginTop: 10 }}><button className="btn pri" onClick={run} aria-disabled={!prompt || !root}>{t("run")}</button><TaskControls task={task} /></div>
          {task && <><label>{t("plan")}</label><PlanView steps={task.plan ? JSON.parse(task.plan) : []} /></>}
        </div>
        <div className="card"><h2>{t("files")}</h2><div className="tree mono">{tree.map((n) =>
          <div key={n.path} onClick={() => !n.dir && open(n.path)} style={{ paddingInlineStart: 8 * (n.rel.split(/[\\/]/).length - 1) }}>{n.dir ? <Folder size={13} color="var(--orange)" /> : <FileCode2 size={13} />} {n.rel.split(/[\\/]/).pop()}</div>)}</div></div>
      </div>
      <div className="grid">
        <div className="card">
          <div className="row" style={{ justifyContent: "space-between" }}><span className="mono small">{file?.path ?? "—"}</span>
            <button className="btn pri" onClick={save} aria-disabled={!dirty}><Save size={13} /> {t("save")}</button></div>
          {file && <div dir="ltr"><CodeMirror value={file.content} height="420px" theme="dark" extensions={ext} onChange={(v) => { setFile({ ...file, content: v }); setDirty(true); }} /></div>}
        </div>
        <div className="card"><div className="row" style={{ justifyContent: "space-between" }}><h2>{t("changes")}</h2>
          {taskId && <button className="btn danger" onClick={() => confirm("Undo?") && api(`/api/tasks/${taskId}/revert`, { body: {} }).then(() => { loadTree(); })}><Undo2 size={13} /> {t("undo")}</button>}</div>
          <div className="log">{(td?.changes ?? []).slice().reverse().map((c: any, i: number) => <details key={i}><summary className="mono">{c.created ? <FilePlus2 size={13} color="var(--ok)" /> : <FilePen size={13} color="var(--orange)" />} {c.path}</summary>
            <pre className="mono">{c.diff.split("\n").map((l: string, j: number) => <div key={j} className={l.startsWith("+") ? "diff-add" : l.startsWith("-") ? "diff-del" : ""}>{l}</div>)}</pre></details>)}</div>
        </div>
        <div className="card"><h2>Log</h2><TaskLog taskId={taskId} /></div>
      </div>
    </div>
  </>;
}
