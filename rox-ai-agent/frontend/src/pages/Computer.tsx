import { useState } from "react";
import { api } from "../api";
import { useT } from "../i18n";
import { PlanView, ScreenView, TaskControls, TaskLog, useEvents, usePoll } from "../components/common";

export default function Computer() {
  const t = useT();
  const [prompt, setPrompt] = useState(""); const [taskId, setTaskId] = useState<number | null>(null); const [msg, setMsg] = useState("");
  const { data: td } = usePoll<any>(taskId ? `/api/tasks/${taskId}` : "/api/status", 1500, [taskId]);
  const task = taskId ? td?.task : null;
  const frames = useEvents((e) => e.type === "decision" && e.data.task_id === taskId, 80);
  const run = async () => { const r = await api<any>("/api/tasks", { body: { kind: "computer", title: prompt.slice(0, 60), prompt } }).catch((e) => alert(e.message)); if (r) setTaskId(r.id); };
  const [tx, setTx] = useState({ x: 200, y: 200, text: "" });
  const test = (action: string) => api("/api/input/test", { body: { action, ...tx } }).then((r: any) => r.cursor && alert(r.cursor)).catch((e) => alert(e.message));
  return <>
    <h1>{t("computer")}</h1>
    <div className="grid g2">
      <ScreenView title={t("liveDesktop")} />
      <div className="grid">
        <div className="card">
          <label>{t("request")}</label>
          <textarea rows={4} value={prompt} onChange={(e) => setPrompt(e.target.value)} placeholder="افتح VS Code وأنشئ مشروع FiveM جديداً في مجلد المشاريع" />
          <div className="row" style={{ marginTop: 10 }}><button className="btn pri" onClick={run} aria-disabled={!prompt}>{t("run")}</button><TaskControls task={task} /></div>
          {task && <><label>{t("plan")}</label><PlanView steps={task.plan ? JSON.parse(task.plan) : []} />
            <label>{t("message")}</label><div className="row" style={{ flexWrap: "nowrap" }}><input value={msg} onChange={(e) => setMsg(e.target.value)} />
              <button className="btn" onClick={() => api(`/api/tasks/${taskId}/message`, { body: { text: msg } }).then(() => setMsg("")).catch((e) => alert(e.message))}>{t("send")}</button></div></>}
        </div>
        <div className="card"><h2>Input test (manual)</h2>
          <div className="row"><input style={{ width: 80 }} type="number" value={tx.x} onChange={(e) => setTx({ ...tx, x: +e.target.value })} />
            <input style={{ width: 80 }} type="number" value={tx.y} onChange={(e) => setTx({ ...tx, y: +e.target.value })} />
            <button className="btn" onClick={() => test("move")}>move</button><button className="btn" onClick={() => test("click")}>click</button>
            <button className="btn" onClick={() => test("cursor")}>cursor</button></div>
          <div className="row" style={{ marginTop: 6, flexWrap: "nowrap" }}><input placeholder="text or key combo e.g. ctrl+s" value={tx.text} onChange={(e) => setTx({ ...tx, text: e.target.value })} />
            <button className="btn" onClick={() => test("type")}>type</button><button className="btn" onClick={() => test("key")}>key</button></div>
          <div className="small mute" style={{ marginTop: 6 }}>Failsafe: slam the mouse into any screen corner to abort pyautogui instantly.</div>
        </div>
      </div>
    </div>
    <div className="grid g2" style={{ marginTop: 14 }}>
      <div className="card"><h2>Commands</h2><div className="log">{frames.map((d, i) => <div key={i}><b>{d.data.action}</b> <span className="mute">{JSON.stringify(d.data.input)}</span></div>)}</div></div>
      <div className="card"><h2>Log</h2><TaskLog taskId={taskId} /></div>
    </div>
  </>;
}
