/** ROX mark: orange rounded tile, a stylised aperture "eye" (the agent watching) with an R-cut. */
export function Logo({ size = 30 }: { size?: number }) {
  return <svg width={size} height={size} viewBox="0 0 64 64" aria-label="ROX">
    <defs>
      <linearGradient id="rg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#ff9a4d" /><stop offset="1" stopColor="#d9560b" /></linearGradient>
    </defs>
    <rect x="2" y="2" width="60" height="60" rx="16" fill="url(#rg)" />
    <rect x="2.5" y="2.5" width="59" height="59" rx="15.5" fill="none" stroke="#fff" strokeOpacity=".25" />
    <path d="M20 46V18h14.5a9 9 0 0 1 2.6 17.6L45 46h-7.6l-7-10H27v10z M27 24v6.4h7.2a3.2 3.2 0 0 0 0-6.4z" fill="#141414" fillRule="evenodd" />
    <circle cx="46" cy="18" r="4" fill="#141414" /><circle cx="46" cy="18" r="1.6" fill="#ff9a4d" />
  </svg>;
}
