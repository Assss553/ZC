import { useEffect, useState } from "react";
import { api } from "./api";
import { Key, Lang, LangCtx, useT } from "./i18n";
import { Approvals, usePoll } from "./components/common";
import { Logo } from "./components/Logo";
import { LayoutPanelTop, LayoutDashboard, MessagesSquare, Gamepad2, MousePointer2, Code2, Stethoscope, CalendarClock, Settings as Cog, ShieldCheck, OctagonX, RotateCcw, Zap, type LucideIcon } from "lucide-react";
import Doctor from "./pages/Doctor";
import { CommandBar } from "./components/CommandBar";
import Dashboard from "./pages/Dashboard"; import Chat from "./pages/Chat"; import Game from "./pages/Game"; import Computer from "./pages/Computer";
import Coding from "./pages/Coding"; import Studio from "./pages/Studio"; import Tasks from "./pages/Tasks"; import Settings from "./pages/Settings"; import Audit from "./pages/Audit";

const PAGES: [Key, LucideIcon, (p: any) => JSX.Element][] = [["studio", LayoutPanelTop, Studio], ["dashboard", LayoutDashboard, Dashboard], ["chat", MessagesSquare, Chat],
  ["doctor", Stethoscope, Doctor], ["game", Gamepad2, Game], ["computer", MousePointer2, Computer], ["coding", Code2, Coding], ["tasks", CalendarClock, Tasks],
  ["settings", Cog, Settings], ["audit", ShieldCheck, Audit]];

function Shell() {
  const t = useT(); const [page, setPage] = useState<Key>("studio");
  const { data: s } = usePoll<any>("/api/status", 1500);
  const P = PAGES.find((p) => p[0] === page)![2];
  const estop = () => s?.emergency_stop ? api("/api/emergency-stop/reset", { body: {} }) : api("/api/emergency-stop", { body: {} });
  useEffect(() => { const k = (e: KeyboardEvent) => { if (e.ctrlKey && e.shiftKey && e.key.toLowerCase() === "x") api("/api/emergency-stop", { body: {} }); };
    window.addEventListener("keydown", k); return () => window.removeEventListener("keydown", k); }, []);
  return <div className={`app ${page === "studio" ? "slim" : ""}`}>
    <aside className="side">
      <div className="brand"><Logo /><b>ROX AI AGENT</b></div>
      {PAGES.map(([k, I]) => <button key={k} title={t(k)} className={`nav ${page === k ? "on" : ""}`} onClick={() => setPage(k)}><I size={18} strokeWidth={1.8} /> <span>{t(k)}</span></button>)}
      <button className="nav cmdk" title="Ctrl+K" onClick={() => dispatchEvent(new KeyboardEvent("keydown", { key: "k", ctrlKey: true }))}><Zap size={18} /> <span>أمر فوري <kbd>Ctrl K</kbd></span></button>
      <div className="grow" />
      <button className={`estop ${s?.emergency_stop ? "armed" : ""}`} onClick={estop} title="Ctrl+Shift+X (global: Ctrl+Alt+Pause)">{s?.emergency_stop ? <RotateCcw size={18} /> : <OctagonX size={18} />}<span>{s?.emergency_stop ? t("estopActive") : t("estop")}</span></button>
    </aside>
    <main key={page} className={page === "studio" ? "full" : ""}><P go={setPage} /></main><Approvals /><CommandBar go={setPage} />
  </div>;
}

export default function App() {
  const [lang, setLangS] = useState<Lang>((localStorage.getItem("lang") as Lang) || "ar");
  const setLang = (l: Lang) => { setLangS(l); localStorage.setItem("lang", l); };
  useEffect(() => { document.documentElement.dir = lang === "ar" ? "rtl" : "ltr"; document.documentElement.lang = lang; }, [lang]);
  return <LangCtx.Provider value={{ lang, setLang }}><Shell /></LangCtx.Provider>;
}
