import { ScreenView, usePoll, PlanView, fmtDur } from "../components/common";
import { useT } from "../i18n";

export default function Dashboard() {
  const t = useT();
  const { data: s, err } = usePoll<any>("/api/status", 1500);
  const task = s?.current_task; const plan = task?.plan ? JSON.parse(task.plan) : [];
  return <>
    <h1>{t("dashboard")}</h1>
    {err && <div className="banner">Backend: {err}</div>}
    {s && !s.capture_available && <div className="banner">Screen capture unavailable on this machine (needs an interactive Windows desktop).</div>}
    {s?.is_admin && <div className="banner">⚠️ Running as Administrator. ROX is designed to run as a normal user.</div>}
    <div className="grid g4" style={{ marginBottom: 14 }}>
      <Stat l={t("aiStatus")} v={s?.emergency_stop ? "STOP" : s?.active_tasks?.length ? t("working") : t("idle")} />
      <Stat l={t("connection")} v={s ? (s.provider === "api" ? (s.api_key_set ? t("connected") : t("notConnected")) : s.provider) : "…"} sub={s?.model} />
      <Stat l={`${t("cpu")} / ${t("ram")}`} v={s ? `${s.cpu.toFixed(0)}% / ${s.ram.toFixed(0)}%` : "…"} sub={s ? `${s.ram_used_gb} GB` : ""} />
      <Stat l={t("session")} v={s ? fmtDur(s.uptime_s) : "…"} sub={s?.usage?.requests ? `${s.usage.requests} req · ${s.usage.output_tokens} out tok` : ""} />
    </div>
    <div className="grid g2">
      <ScreenView title={t("liveDesktop")} />
      <div className="grid">
        <div className="card"><h2>{t("currentTask")}</h2>
          {task ? <><div style={{ fontWeight: 600 }}>{task.title}</div><div className="mute small">{task.kind} · {task.status}</div>
            <label>{t("progress")}</label><div className="bar"><div style={{ width: `${(task.progress ?? 0) * 100}%` }} /></div>
            <label>{t("plan")}</label><PlanView steps={plan} /></> : <div className="mute">{t("none")}</div>}
        </div>
        <div className="card"><h2>{t("recent")}</h2>
          <div className="log">{(s?.recent_actions ?? []).slice().reverse().map((a: any, i: number) =>
            <div key={i}><span className="mute">{new Date(a.ts * 1000).toLocaleTimeString()}</span> <b>{a.data.action}</b> <span className="mute">{a.data.actor}</span></div>)}
            {!s?.recent_actions?.length && <span className="mute">—</span>}</div>
        </div>
        <div className="card small mute">FPS of games is not measured: Windows has no reliable, non-invasive API for another app's FPS. The badge on the stream shows the stream rate.</div>
      </div>
    </div>
  </>;
}
const Stat = ({ l, v, sub }: { l: string; v: string; sub?: string }) =>
  <div className="card stat"><div className="l">{l}</div><div className="v">{v}</div><div className="small mute">{sub}</div></div>;
