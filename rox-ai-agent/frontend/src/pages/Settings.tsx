import { useEffect, useState } from "react";
import { api } from "../api";
import { useT, LangCtx } from "../i18n";
import { useContext } from "react";

export default function Settings() {
  const t = useT(); const { lang, setLang } = useContext(LangCtx);
  const [s, setS] = useState<any>(null); const [key, setKey] = useState(""); const [test, setTest] = useState<any>(null); const [folder, setFolder] = useState("");
  const load = () => api("/api/settings").then(setS);
  useEffect(() => { load(); }, []);
  const save = (patch: any) => api("/api/settings", { body: patch }).then(setS).catch((e) => alert(e.message));
  if (!s) return <div className="mute">…</div>;
  return <>
    <h1>{t("settings")}</h1>
    <div className="grid g2">
      <div className="grid">
        <div className="card"><h2>AI provider</h2>
          <div className="row">{[["api", "B · Claude API (API key, Console billing)"], ["claude_code", "A · Claude account via Claude Code"], ["local", "C · Local model (planned)"]].map(([id, l]) =>
            <button key={id} className={`btn ${s.provider === id ? "pri" : ""}`} aria-disabled={id === "local"} onClick={() => save({ provider: id })}>{l}</button>)}</div>
          <p className="small mute">Billing is separate: a Claude.ai Pro/Max subscription does <b>not</b> include API usage. The API key path bills your Anthropic Console account per token. The Claude Code path uses Claude Code's own official login; ROX never reads its tokens or cookies.</p>
        </div>
        <div className="card"><h2>B · Claude API</h2>
          <div className="small">Saved key: <span className="mono">{s.api_key_masked ?? "—"}</span> <span className="mute">(stored in Windows Credential Manager, not in files)</span></div>
          <label>API key</label><div className="row" style={{ flexWrap: "nowrap" }}><input type="password" autoComplete="off" value={key} onChange={(e) => setKey(e.target.value)} placeholder="sk-ant-…" />
            <button className="btn pri" onClick={() => api("/api/claude/key", { body: { api_key: key } }).then(() => { setKey(""); load(); }).catch((e) => alert(e.message))}>{t("save")}</button>
            <button className="btn danger" onClick={() => api("/api/claude/key", { method: "DELETE" }).then(load)}>✕</button></div>
          <div className="row" style={{ marginTop: 10 }}><button className="btn" onClick={() => { setTest({ loading: true }); api("/api/claude/test", { body: {} }).then(setTest); }}>{t("test")}</button>
            {test?.ok === true && <span className="pill ok">OK · {test.models.length} models{test.selected_available ? "" : " · selected model not listed!"}</span>}
            {test?.ok === false && <span className="pill bad">{test.error}</span>}</div>
          <label>Model</label><select value={s.model} onChange={(e) => save({ model: e.target.value })}>
            {Array.from(new Set([s.model, "claude-opus-5-5", ...(test?.models ?? [])])).map((m: string) => <option key={m}>{m}</option>)}</select>
          <label>Effort</label><select value={s.effort} onChange={(e) => save({ effort: e.target.value })}>{["low", "medium", "high", "xhigh", "max"].map((x) => <option key={x}>{x}</option>)}</select>
          <label className="row"><input type="checkbox" style={{ width: "auto" }} checked={s.use_fallbacks} onChange={(e) => save({ use_fallbacks: e.target.checked })} /> Server-side refusal fallback (recommended)</label>
        </div>
        <div className="card"><h2>A · Claude account (Claude Code)</h2>
          {s.claude_code.installed ? <span className="pill ok">Claude Code {s.claude_code.version}</span> : <span className="pill warn">not installed</span>}
          <p className="small mute">{s.claude_code.hint ?? "Log in once in a terminal with `claude` then `/login`. ROX runs `claude -p` headless for coding tasks. Computer/Game control requires the API path (computer-use tool)."}</p>
        </div>
      </div>
      <div className="grid">
        <div className="card"><h2>Allowed folders</h2>
          {s.allowed_folders.map((f: string) => <div key={f} className="row mono small" style={{ justifyContent: "space-between" }}>{f}
            <button className="btn small danger" onClick={() => save({ allowed_folders: s.allowed_folders.filter((x: string) => x !== f) })}>✕</button></div>)}
          <div className="row" style={{ marginTop: 8, flexWrap: "nowrap" }}><input value={folder} onChange={(e) => setFolder(e.target.value)} placeholder={"C:\\Users\\you\\Desktop\\ROX-Projects"} />
            <button className="btn" onClick={async () => { const p = (window as any).rox?.pickFolder ? await (window as any).rox.pickFolder() : null; if (p) setFolder(p); }}>…</button>
            <button className="btn pri" onClick={() => { save({ allowed_folders: [...s.allowed_folders, folder] }); setFolder(""); }}>+</button></div>
        </div>
        <div className="card"><h2>Limits & autonomy</h2>
          <label>Max total output tokens (0 = unlimited)</label><input type="number" defaultValue={s.max_output_tokens_total} onBlur={(e) => save({ max_output_tokens_total: +e.target.value })} />
          <label>Periodic report every (minutes)</label><input type="number" defaultValue={s.report_minutes} onBlur={(e) => save({ report_minutes: +e.target.value })} />
          <label className="row"><input type="checkbox" style={{ width: "auto" }} checked={s.auto_resume} onChange={(e) => save({ auto_resume: e.target.checked })} /> Auto-resume interrupted tasks after a crash/restart</label>
          <label className="row"><input type="checkbox" style={{ width: "auto" }} checked={s.run_at_login} onChange={(e) => save({ run_at_login: e.target.checked })} /> Start ROX when I sign in to Windows</label>
        </div>
        <div className="card"><h2>{t("language")}</h2><div className="row">
          <button className={`btn ${lang === "ar" ? "pri" : ""}`} onClick={() => { setLang("ar"); save({ language: "ar" }); }}>العربية</button>
          <button className={`btn ${lang === "en" ? "pri" : ""}`} onClick={() => { setLang("en"); save({ language: "en" }); }}>English</button></div></div>
      </div>
    </div>
  </>;
}
