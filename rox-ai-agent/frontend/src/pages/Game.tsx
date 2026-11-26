import { useState } from "react";
import { api } from "../api";
import { useT } from "../i18n";
import { ScreenView, TaskControls, TaskLog, useEvents, usePoll, PlanView } from "../components/common";

export default function Game() {
  const t = useT();
  const { data: adapters } = usePoll<any[]>("/api/games/adapters", 60000);
  const [refresh, setRefresh] = useState(0);
  const { data: wins } = usePoll<any[]>("/api/windows", 30000, [refresh]);
  const [adapter, setAdapter] = useState("generic"); const [win, setWin] = useState(""); const [mission, setMission] = useState("");
  const [mins, setMins] = useState(30); const [taskId, setTaskId] = useState<number | null>(null);
  const { data: td } = usePoll<any>(taskId ? `/api/tasks/${taskId}` : "/api/status", 1500, [taskId]);
  const task = taskId ? td?.task : null;
  const decisions = useEvents((e) => (e.type === "decision" || e.type === "agent_say") && e.data.task_id === taskId);
  const a = adapters?.find((x) => x.id === adapter);
  const start = async () => {
    const r = await api<any>("/api/tasks", { body: { kind: "game", title: `${a?.name}: ${mission.slice(0, 40)}`, prompt: mission, duration_minutes: mins, state: { adapter, window: win } } }).catch((e) => alert(e.message));
    if (r) setTaskId(r.id);
  };
  return <>
    <h1>{t("game")}</h1>
    <div className="banner small">Adapters only — single-player games or modes that allow automation. Screenshots + OS input only: no code injection, memory reading or anti-cheat bypass. Fast real-time action games are not a good fit for screenshot-based control.</div>
    <div className="grid g2">
      <ScreenView title={t("liveGame")} window={win} fps={10} />
      <div className="card">
        <label>{t("selectGame")}</label>
        <select value={adapter} onChange={(e) => setAdapter(e.target.value)}>{adapters?.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}</select>
        <div className="small mute" style={{ marginTop: 4 }}>{a?.description} {a?.allowed_keys && <>· keys: {a.allowed_keys.join(", ") || "mouse only"}</>}</div>
        <label>{t("selectWindow")} <button className="btn small" onClick={() => setRefresh(refresh + 1)}>{t("refresh")}</button></label>
        <select value={win} onChange={(e) => setWin(e.target.value)}><option value="">—</option>
          {(wins ?? []).filter((w) => !a?.window_hint || w.title.toLowerCase().includes(a.window_hint.toLowerCase()) || adapter === "generic").map((w) => <option key={w.title}>{w.title}</option>)}</select>
        <label>{t("mission")}</label><textarea rows={3} value={mission} onChange={(e) => setMission(e.target.value)} placeholder="مثال: العب 2048 وحاول الوصول إلى 512" />
        <label>{t("duration")}</label><input type="number" min={1} value={mins} onChange={(e) => setMins(+e.target.value)} />
        <div className="row" style={{ marginTop: 12 }}>
          <button className="btn pri" onClick={start} aria-disabled={!win || !mission}>{t("startPlaying")}</button>
          <TaskControls task={task} />
        </div>
        {task && <><label>{t("progress")}</label><div className="bar"><div style={{ width: `${task.progress * 100}%` }} /></div>
          <label>{t("plan")}</label><PlanView steps={task.plan ? JSON.parse(task.plan) : []} /></>}
      </div>
    </div>
    <div className="grid g2" style={{ marginTop: 14 }}>
      <div className="card"><h2>{t("decisions")} / {t("moves")}</h2><div className="log">{decisions.map((d, i) =>
        <div key={i}>{d.type === "decision" ? <><b>{d.data.action}</b> <span className="mute">{JSON.stringify(d.data.input)}</span></> : <span>💬 {d.data.text}</span>}</div>)}</div></div>
      <div className="card"><h2>{t("errors")} / log</h2><TaskLog taskId={taskId} /></div>
    </div>
  </>;
}
