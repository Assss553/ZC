import { useState } from "react";
import { api } from "../api";
import { useT } from "../i18n";
import { TaskLog, usePoll } from "../components/common";

export default function Tasks() {
  const t = useT();
  const { data: tasks } = usePoll<any[]>("/api/tasks", 3000);
  const { data: adapters } = usePoll<any[]>("/api/games/adapters", 60000);
  const { data: wins } = usePoll<any[]>("/api/windows", 30000);
  const [f, setF] = useState({ kind: "game", title: "", prompt: "", start: "00:00", end: "06:00", adapter: "generic", window: "", root: "" });
  const [sel, setSel] = useState<number | null>(null);
  const create = () => api("/api/tasks", { body: { kind: f.kind, title: f.title || f.prompt.slice(0, 50), prompt: f.prompt, start_at_local: f.start || null, end_at_local: f.end || null,
    state: f.kind === "game" ? { adapter: f.adapter, window: f.window } : f.kind === "coding" ? { root: f.root } : {} } }).catch((e) => alert(e.message));
  const op = (id: number, o: string) => api(`/api/tasks/${id}/${o}`, { body: {} }).catch((e) => alert(e.message));
  const cls = (s: string) => ({ running: "ok", completed: "ok", failed: "bad", stopped: "", paused: "warn", interrupted: "warn", scheduled: "or" } as any)[s] ?? "";
  return <>
    <h1>{t("tasks")}</h1>
    <div className="banner small">Tasks run only while the PC is on and ROX is open. During a task ROX keeps Windows awake (no sleep); it cannot work while the PC is off or asleep.</div>
    <div className="grid g2">
      <div className="card"><table className="tbl"><thead><tr><th>#</th><th>{t("kind")}</th><th>Title</th><th>{t("status")}</th><th>{t("progress")}</th><th>Window</th><th /></tr></thead>
        <tbody>{(tasks ?? []).map((x) => <tr key={x.id} onClick={() => setSel(x.id)} style={{ cursor: "pointer", background: sel === x.id ? "#1c1712" : "" }}>
          <td>{x.id}</td><td>{x.kind}</td><td>{x.title}</td><td><span className={`pill ${cls(x.status)}`}>{x.status}</span>{x.error_count > 0 && <span className="pill bad">{x.error_count} err</span>}</td>
          <td>{Math.round(x.progress * 100)}%</td>
          <td className="small mute">{x.start_at ? new Date(x.start_at * 1000).toLocaleString() : "now"} → {x.end_at ? new Date(x.end_at * 1000).toLocaleString() : "∞"}</td>
          <td className="row"><button className="btn small" onClick={() => op(x.id, "resume")}>▶</button><button className="btn small" onClick={() => op(x.id, "pause")}>⏸</button><button className="btn small danger" onClick={() => op(x.id, "stop")}>■</button></td></tr>)}</tbody></table></div>
      <div className="card"><h2>{t("schedule")}</h2>
        <label>{t("kind")}</label><select value={f.kind} onChange={(e) => setF({ ...f, kind: e.target.value })}><option value="game">game</option><option value="computer">computer</option><option value="coding">coding</option></select>
        {f.kind === "game" && <><label>{t("selectGame")}</label><select value={f.adapter} onChange={(e) => setF({ ...f, adapter: e.target.value })}>{adapters?.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
          <label>{t("selectWindow")}</label><select value={f.window} onChange={(e) => setF({ ...f, window: e.target.value })}><option value="">—</option>{(wins ?? []).map((w) => <option key={w.title}>{w.title}</option>)}</select></>}
        {f.kind === "coding" && <><label>{t("projectFolder")}</label><input value={f.root} onChange={(e) => setF({ ...f, root: e.target.value })} /></>}
        <label>{t("request")}</label><textarea rows={3} value={f.prompt} onChange={(e) => setF({ ...f, prompt: e.target.value })} placeholder="ابدأ تشغيل اللعبة وأكمل المهمة المحددة" />
        <div className="row"><div style={{ flex: 1 }}><label>{t("startAt")}</label><input type="time" value={f.start} onChange={(e) => setF({ ...f, start: e.target.value })} /></div>
          <div style={{ flex: 1 }}><label>{t("endAt")}</label><input type="time" value={f.end} onChange={(e) => setF({ ...f, end: e.target.value })} /></div></div>
        <button className="btn pri" style={{ marginTop: 12 }} onClick={create} aria-disabled={!f.prompt}>{t("schedule")}</button>
      </div>
    </div>
    {sel && <div className="card" style={{ marginTop: 14 }}><h2>Timeline #{sel}</h2><TaskLog taskId={sel} /></div>}
  </>;
}
