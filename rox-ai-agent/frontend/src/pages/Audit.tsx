import { usePoll } from "../components/common";
import { useT } from "../i18n";
export default function Audit() {
  const t = useT(); const { data } = usePoll<any[]>("/api/audit", 4000);
  const cls = (d: string) => d === "blocked" || d === "denied" ? "bad" : d === "approved" ? "ok" : "";
  return <><h1>{t("audit")}</h1><div className="card"><table className="tbl mono"><tbody>{(data ?? []).map((a) =>
    <tr key={a.id}><td className="mute">{new Date(a.ts * 1000).toLocaleString()}</td><td>{a.actor}</td><td>{a.action}</td><td><span className={`pill ${cls(a.decision)}`}>{a.decision}</span></td><td className="small mute">{a.detail}</td></tr>)}</tbody></table></div></>;
}
