import { useEffect, useRef, useState } from "react";
import { api, onEvent } from "../api";
import { PlanView, usePoll } from "./common";
import { Loader2, CheckCircle2, XCircle, Square, Pause, Play, Cpu, MemoryStick, HardDrive, Wifi, AppWindow, Rocket, Globe, Terminal, Search, FileText, Clipboard,
  ListTree, Skull, PackageSearch, Power, Wrench, MousePointerClick, Keyboard, Camera, ZoomIn, Timer, Hand, SendHorizontal, Activity, ChevronDown } from "lucide-react";

const TOOL: Record<string, [any, string]> = {
  system_info: [Cpu, "معلومات النظام"], list_processes: [Activity, "العمليات الجارية"], disk_usage: [HardDrive, "مساحة الأقراص"], network_info: [Wifi, "الشبكة"],
  installed_apps: [PackageSearch, "البرامج المثبتة"], startup_apps: [Power, "برامج بدء التشغيل"], services: [ListTree, "الخدمات"], recent_app_crashes: [Wrench, "أعطال البرامج"],
  list_windows: [AppWindow, "النوافذ المفتوحة"], find_files: [Search, "بحث عن ملفات"], read_text_file: [FileText, "قراءة ملف"], clipboard_get: [Clipboard, "الحافظة"],
  launch_app: [Rocket, "تشغيل برنامج"], open_url: [Globe, "فتح رابط"], window_action: [AppWindow, "التحكم بنافذة"], kill_process: [Skull, "إنهاء عملية"],
  clipboard_set: [Clipboard, "نسخ للحافظة"], powershell: [Terminal, "PowerShell"], screenshot: [Camera, "لقطة شاشة"], zoom: [ZoomIn, "تكبير"],
  left_click: [MousePointerClick, "نقر"], double_click: [MousePointerClick, "نقر مزدوج"], right_click: [MousePointerClick, "نقر يمين"], type: [Keyboard, "كتابة"],
  key: [Keyboard, "مفتاح"], scroll: [MousePointerClick, "تمرير"], mouse_move: [MousePointerClick, "تحريك الماوس"], wait: [Timer, "انتظار"], ask_user: [Hand, "سؤال لك"],
};
type Step = { id: number; kind: "say" | "tool"; text?: string; tool?: string; input?: any; result?: string; ts: number };
const brief = (i: any) => !i ? "" : i.name ?? i.title ?? i.command ?? i.url ?? i.pattern ?? i.path ?? i.text ?? (i.coordinate ? i.coordinate.join(",") : "") ?? "";

export function LiveRun({ taskId, compact = false }: { taskId: number; compact?: boolean }) {
  const [steps, setSteps] = useState<Step[]>([]); const [frame, setFrame] = useState(""); const [msg, setMsg] = useState("");
  const n = useRef(0); const { data } = usePoll<any>(`/api/tasks/${taskId}`, 1500, [taskId]);
  const task = data?.task; const running = task && ["running", "paused", "queued"].includes(task.status);
  useEffect(() => onEvent((e) => {
    if (e.data?.task_id !== taskId && e.type !== "agent_frame") return;
    if (e.type === "agent_frame") { if (running !== false) setFrame(e.data.b64); return; }
    if (e.type === "agent_say") setSteps((s) => [...s, { id: n.current++, kind: "say", text: e.data.text, ts: e.ts }]);
    if (e.type === "decision") setSteps((s) => [...s, { id: n.current++, kind: "tool", tool: e.data.action, input: e.data.input, ts: e.ts }]);
    if (e.type === "tool_result") setSteps((s) => { const c = [...s]; for (let i = c.length - 1; i >= 0; i--) if (c[i].kind === "tool" && c[i].tool === e.data.action && !c[i].result) { c[i] = { ...c[i], result: e.data.result }; break; } return c; });
  }), [taskId, running]);
  // history (after reload): rebuild from the persisted task log
  const hist: Step[] = !steps.length && data?.events ? data.events.slice().reverse().filter((e: any) => e.level === "info" || e.level === "tool")
    .map((e: any, i: number) => e.level === "tool" ? { id: i, kind: "tool", tool: e.message.split(" ")[0], ts: e.ts } : { id: i, kind: "say", text: e.message, ts: e.ts }) : [];
  const list = steps.length ? steps : hist;
  const op = (o: string, body: any = {}) => api(`/api/tasks/${taskId}/${o}`, { body }).catch((e) => alert(e.message));
  const plan = task?.plan ? JSON.parse(task.plan) : [];
  const status = task?.status ?? "queued";
  return <div className={`liverun ${compact ? "compact" : ""}`}>
    <div className="lr-head">
      {running ? <Loader2 size={15} className="spin" color="var(--orange)" /> : status === "completed" ? <CheckCircle2 size={15} color="var(--ok)" /> : <XCircle size={15} color="var(--bad)" />}
      <b>{running ? (status === "paused" ? "متوقف مؤقتاً" : "ينفّذ الآن…") : status === "completed" ? "تم" : status}</b>
      <span className="mute small">#{taskId}</span>
      {running && <div className="lr-ctl">
        {status === "paused" ? <button className="btn ib" onClick={() => op("resume")}><Play size={13} /></button> : <button className="btn ib" onClick={() => op("pause")}><Pause size={13} /></button>}
        <button className="btn ib danger" onClick={() => op("stop")}><Square size={13} /></button></div>}
    </div>
    {plan.length > 0 && <div className="lr-plan"><PlanView steps={plan} /></div>}
    <div className="lr-body">
      <div className="lr-steps">{list.map((s) => s.kind === "say" ? <div key={s.id} className="lr-say">{s.text}</div> : (() => {
        const [I, label] = TOOL[s.tool!] ?? [Wrench, s.tool]; const done = !!s.result || !running;
        return <details key={s.id} className="lr-tool"><summary>{done ? <CheckCircle2 size={13} color="var(--ok)" /> : <Loader2 size={13} className="spin" />}<I size={14} color="var(--orange2)" />
          <span>{label}</span><span className="mono mute lr-arg">{String(brief(s.input)).slice(0, 70)}</span>{s.result && <ChevronDown size={12} className="mute" />}</summary>
          {s.result && <pre className="mono" dir="ltr">{s.result}</pre>}</details>; })())}
        {running && !list.length && <div className="mute small">يبدأ…</div>}</div>
      {frame && !compact && running && <img className="lr-frame" src={`data:image/jpeg;base64,${frame}`} />}
    </div>
    {running && <div className="lr-inject"><input value={msg} onChange={(e) => setMsg(e.target.value)} placeholder="أضف تعليمات أثناء التنفيذ…" onKeyDown={(e) => { if (e.key === "Enter" && msg) { op("message", { text: msg }); setMsg(""); } }} />
      <button className="btn ib" onClick={() => { if (msg) { op("message", { text: msg }); setMsg(""); } }}><SendHorizontal size={14} /></button></div>}
  </div>;
}
