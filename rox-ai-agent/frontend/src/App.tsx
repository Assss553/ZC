import { useEffect, useState } from "react";
import { api } from "./api";
import { Key, Lang, LangCtx, useT } from "./i18n";
import { Approvals, usePoll } from "./components/common";
import Dashboard from "./pages/Dashboard"; import Chat from "./pages/Chat"; import Game from "./pages/Game"; import Computer from "./pages/Computer";
import Coding from "./pages/Coding"; import Tasks from "./pages/Tasks"; import Settings from "./pages/Settings"; import Audit from "./pages/Audit";

const PAGES: [Key, string, () => JSX.Element][] = [["dashboard", "◧", Dashboard], ["chat", "💬", Chat], ["game", "🎮", Game], ["computer", "🖱", Computer],
  ["coding", "⌨", Coding], ["tasks", "⏱", Tasks], ["settings", "⚙", Settings], ["audit", "🛡", Audit]];

function Shell() {
  const t = useT(); const [page, setPage] = useState<Key>("dashboard");
  const { data: s } = usePoll<any>("/api/status", 1500);
  const P = PAGES.find((p) => p[0] === page)![2];
  const estop = () => s?.emergency_stop ? api("/api/emergency-stop/reset", { body: {} }) : api("/api/emergency-stop", { body: {} });
  useEffect(() => { const k = (e: KeyboardEvent) => { if (e.ctrlKey && e.shiftKey && e.key.toLowerCase() === "x") api("/api/emergency-stop", { body: {} }); };
    window.addEventListener("keydown", k); return () => window.removeEventListener("keydown", k); }, []);
  return <div className="app">
    <aside className="side">
      <div className="brand"><i>R</i><b>ROX AI AGENT</b></div>
      {PAGES.map(([k, ic]) => <button key={k} className={`nav ${page === k ? "on" : ""}`} onClick={() => setPage(k)}>{ic} <span>{t(k)}</span></button>)}
      <div className="grow" />
      <button className={`estop ${s?.emergency_stop ? "armed" : ""}`} onClick={estop} title="Ctrl+Shift+X (global: Ctrl+Alt+Pause)">{s?.emergency_stop ? t("estopActive") : "⛔ " + t("estop")}</button>
    </aside>
    <main key={page}><P /></main><Approvals />
  </div>;
}

export default function App() {
  const [lang, setLangS] = useState<Lang>((localStorage.getItem("lang") as Lang) || "ar");
  const setLang = (l: Lang) => { setLangS(l); localStorage.setItem("lang", l); };
  useEffect(() => { document.documentElement.dir = lang === "ar" ? "rtl" : "ltr"; document.documentElement.lang = lang; }, [lang]);
  return <LangCtx.Provider value={{ lang, setLang }}><Shell /></LangCtx.Provider>;
}
