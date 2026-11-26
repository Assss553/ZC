import { useEffect, useRef, useState } from "react";
import { api } from "../api";
import { LiveRun } from "./LiveRun";
import { Zap, X, CornerDownLeft } from "lucide-react";

const SUGGEST = ["افحص جهازي وقل لي ليش بطيء", "وش البرامج اللي تشتغل مع بدء التشغيل؟", "افتح VS Code", "كم المساحة الفاضية في الأقراص؟", "افحص الإنترنت", "سكّر كل نوافذ المتصفح"];

export function CommandBar({ go }: { go: (p: any) => void }) {
  const [open, setOpen] = useState(false); const [text, setText] = useState(""); const [task, setTask] = useState<number | null>(null); const [err, setErr] = useState("");
  const inp = useRef<HTMLInputElement>(null);
  useEffect(() => {
    const k = (e: KeyboardEvent) => { if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setOpen((o) => !o); } if (e.key === "Escape") setOpen(false); };
    addEventListener("keydown", k); const off = (window as any).rox?.onCommand?.(() => setOpen(true));
    return () => { removeEventListener("keydown", k); off?.(); };
  }, []);
  useEffect(() => { if (open) setTimeout(() => inp.current?.focus(), 30); }, [open]);
  const run = async (t = text) => {
    if (!t.trim()) return; setErr("");
    try { const r = await api<any>("/api/instant", { body: { text: t } }); setTask(r.task_id); setText(""); } catch (e: any) { setErr(e.message); }
  };
  if (!open) return null;
  return <div className="cmd-overlay" onMouseDown={(e) => e.target === e.currentTarget && setOpen(false)}>
    <div className="cmd">
      <div className="cmd-in"><Zap size={18} color="var(--orange)" />
        <input ref={inp} value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === "Enter" && run()} placeholder="اطلب أي شيء ويتنفذ فوراً على جهازك…" />
        <kbd><CornerDownLeft size={12} /></kbd><button className="ti" onClick={() => setOpen(false)}><X size={15} /></button></div>
      {err && <div className="banner small" style={{ margin: 10 }}>{err}</div>}
      {task ? <div style={{ padding: 10 }}><LiveRun taskId={task} compact />
        <div className="row" style={{ marginTop: 8 }}><button className="btn small" onClick={() => { setOpen(false); go("chat"); }}>فتح في المحادثة</button><button className="btn small" onClick={() => setTask(null)}>أمر جديد</button></div></div>
        : <div className="cmd-sug">{SUGGEST.map((s) => <button key={s} onClick={() => run(s)}>{s}</button>)}</div>}
      <div className="cmd-foot mute small">Ctrl+K داخل التطبيق · Ctrl+Shift+Space من أي مكان في Windows · الإجراءات الخطرة تطلب موافقتك</div>
    </div>
  </div>;
}
