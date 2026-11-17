/* ROX Store | rox_phone | All rights reserved. Original Los Santos style wallpapers drawn as SVG (no game screenshots). */
const RoxWalls = (() => {
  const W = 400, H = 860;
  const url = (svg) => `url('data:image/svg+xml,${encodeURIComponent(svg).replace(/'/g, '%27')}') center/cover`;
  const svg = (body, defs = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid slice"><defs>${defs}</defs>${body}</svg>`;
  let seed = 7; const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
  const palm = (x, y, s, c) => { let f = ''; for (let i = 0; i < 7; i++) { const a = -160 + i * 26; f += `<path d="M0 0 q ${30 * Math.cos(a * Math.PI / 180) * s} ${-20 * s} ${70 * Math.cos(a * Math.PI / 180) * s} ${40 * Math.sin(a * Math.PI / 180) * s + 18 * s}" stroke="${c}" stroke-width="${7 * s}" fill="none" stroke-linecap="round"/>`; }
    return `<g transform="translate(${x} ${y})"><path d="M0 0 C ${6 * s} ${120 * s} ${-4 * s} ${240 * s} ${8 * s} ${380 * s}" stroke="${c}" stroke-width="${7 * s}" fill="none"/>${f}</g>`; };
  const city = (base, h, c, win) => { let b = '', x = -10; seed = 11; while (x < W + 10) { const w = 18 + rnd() * 34, hh = h * (.35 + rnd() * .65); b += `<rect x="${x}" y="${base - hh}" width="${w}" height="${hh + 400}" fill="${c}"/>`;
      if (win) for (let yy = base - hh + 8; yy < base - 6; yy += 9) for (let xx = x + 4; xx < x + w - 4; xx += 7) if (rnd() < .33) b += `<rect x="${xx}" y="${yy}" width="3" height="4" fill="${win}" opacity="${.5 + rnd() * .5}"/>`; x += w + 2; } return b; };
  const stars = (n) => { let t = ''; seed = 3; for (let i = 0; i < n; i++) t += `<circle cx="${rnd() * W}" cy="${rnd() * H * .5}" r="${rnd() * 1.3 + .2}" fill="#fff" opacity="${rnd() * .8 + .2}"/>`; return t; };
  const L = [];
  // 1 Vespucci sunset palms
  L.push(['Sunset Palms', svg(`<rect width="${W}" height="${H}" fill="url(#g)"/><circle cx="200" cy="430" r="92" fill="url(#s)"/>${[0, 1, 2, 3, 4, 5].map(i => `<rect x="90" y="${440 + i * 14}" width="220" height="${4 + i}" fill="url(#g)" opacity=".9"/>`).join('')}
    ${city(560, 120, '#2a1030')}<rect y="560" width="${W}" height="${H}" fill="#1a0b1f"/>${palm(40, 300, 1.1, '#140814')}${palm(350, 360, .9, '#140814')}${palm(300, 470, .6, '#1d0c1e')}<rect y="${H - 260}" width="${W}" height="260" fill="url(#f)"/>`,
    `<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2b1055"/><stop offset=".35" stop-color="#d62f6b"/><stop offset=".58" stop-color="#ff8a3d"/><stop offset=".66" stop-color="#ffc06b"/></linearGradient>
     <linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff1a8"/><stop offset="1" stop-color="#ff6a3d"/></linearGradient><linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".8"/></linearGradient>`)]);
  // 2 Downtown night
  L.push(['Downtown Night', svg(`<rect width="${W}" height="${H}" fill="url(#n)"/>${stars(90)}<circle cx="300" cy="150" r="34" fill="#fff6dd" opacity=".9"/><circle cx="312" cy="142" r="34" fill="#0c1230"/>
    ${city(620, 330, '#0b0f24', '#ffcf7a')}<rect y="620" width="${W}" height="${H}" fill="#070918"/><rect y="620" width="${W}" height="${H}" fill="url(#r)"/><path d="M0 700 L400 650 L400 680 L0 760z" fill="#ff5a1f" opacity=".18"/>`,
    `<linearGradient id="n" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05061a"/><stop offset=".6" stop-color="#1b1446"/><stop offset=".75" stop-color="#5a1f4f"/></linearGradient><linearGradient id="r" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff5a1f" stop-opacity=".25"/><stop offset=".4" stop-color="#000" stop-opacity="0"/></linearGradient>`)]);
  // 3 Mount Chiliad
  L.push(['Chiliad Dawn', svg(`<rect width="${W}" height="${H}" fill="url(#c)"/><circle cx="110" cy="300" r="50" fill="#fff3cf" opacity=".95"/>
    <path d="M-20 520 L120 330 L190 400 L260 300 L420 500 V900 H-20z" fill="#7a5a8c" opacity=".7"/><path d="M220 340 l40-40 30 34 -18 -6 -14 14 -12 -10z" fill="#fff" opacity=".8"/>
    <path d="M-20 600 L80 470 L170 560 L300 440 L420 580 V900 H-20z" fill="#4b3463"/><path d="M-20 680 L110 590 L230 670 L330 600 L420 650 V900 H-20z" fill="#2c1d3d"/><path d="M-20 760 Q200 700 420 770 V900 H-20z" fill="#170f22"/>`,
    `<linearGradient id="c" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffb37a"/><stop offset=".45" stop-color="#ff7e7e"/><stop offset=".7" stop-color="#9d6bb0"/></linearGradient>`)]);
  // 4 Del Perro pier
  L.push(['Pier Dusk', svg(`<rect width="${W}" height="${H}" fill="url(#p)"/><circle cx="200" cy="470" r="60" fill="#ffd18a"/><rect y="500" width="${W}" height="${H}" fill="url(#o)"/>
    ${[0, 1, 2, 3, 4, 5, 6].map(i => `<rect x="${170 - i * 6}" y="${510 + i * 22}" width="${60 + i * 12}" height="2" fill="#ffd18a" opacity="${.7 - i * .08}"/>`).join('')}
    <g fill="#120a18"><rect x="230" y="440" width="170" height="10"/>${[0, 1, 2, 3, 4, 5].map(i => `<rect x="${240 + i * 30}" y="450" width="5" height="70"/>`).join('')}<circle cx="330" cy="360" r="72" fill="none" stroke="#120a18" stroke-width="6"/>${[0, 1, 2, 3, 4, 5, 6, 7].map(i => `<line x1="330" y1="360" x2="${330 + 72 * Math.cos(i * Math.PI / 4)}" y2="${360 + 72 * Math.sin(i * Math.PI / 4)}" stroke="#120a18" stroke-width="2"/>`).join('')}<rect x="326" y="360" width="8" height="82"/></g>
    ${palm(30, 360, .9, '#120a18')}`,
    `<linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1f2a6b"/><stop offset=".4" stop-color="#b54b8a"/><stop offset=".58" stop-color="#ffa86b"/></linearGradient><linearGradient id="o" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5a3a7a"/><stop offset="1" stop-color="#0a0a1c"/></linearGradient>`)]);
  // 5 Neon grid
  L.push(['Neon Drive', svg(`<rect width="${W}" height="${H}" fill="url(#ng)"/>${stars(60)}<circle cx="200" cy="380" r="110" fill="url(#ns)"/>${[0, 1, 2, 3, 4].map(i => `<rect x="80" y="${400 + i * 18}" width="240" height="${5 + i * 2}" fill="#14002a"/>`).join('')}
    <rect y="480" width="${W}" height="${H}" fill="#14002a"/>${Array.from({ length: 14 }, (_, i) => `<line x1="${200 + (i - 7) * 14}" y1="480" x2="${200 + (i - 7) * 120}" y2="${H}" stroke="#ff2d95" stroke-width="1.5" opacity=".7"/>`).join('')}
    ${Array.from({ length: 12 }, (_, i) => { const y = 480 + Math.pow(i, 1.9) * 3.4; return `<line x1="0" y1="${y}" x2="${W}" y2="${y}" stroke="#ff2d95" stroke-width="1.5" opacity=".7"/>`; }).join('')}`,
    `<linearGradient id="ng" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0a0018"/><stop offset=".55" stop-color="#3a0a5a"/></linearGradient><linearGradient id="ns" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe066"/><stop offset=".6" stop-color="#ff2d95"/></linearGradient>`)]);
  // 6 Vinewood hills
  L.push(['Vinewood Hills', svg(`<rect width="${W}" height="${H}" fill="url(#v)"/>${stars(50)}<path d="M-20 520 Q100 380 220 450 T420 420 V900 H-20z" fill="#1d2440"/>
    <text x="70" y="470" font-family="Arial Black,Arial" font-weight="900" font-size="34" fill="#e9e3d0" opacity=".85" transform="rotate(-8 200 460)" letter-spacing="2">LOS SANTOS</text>
    <path d="M-20 600 Q150 520 420 600 V900 H-20z" fill="#121731"/>${city(700, 90, '#0a0d1e', '#ffcf7a')}<rect y="700" width="${W}" height="${H}" fill="#070915"/>`,
    `<linearGradient id="v" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0b1030"/><stop offset=".6" stop-color="#3b3a7a"/><stop offset=".72" stop-color="#e07a5f"/></linearGradient>`)]);
  // 7 ROX dark
  L.push(['ROX Dark', svg(`<rect width="${W}" height="${H}" fill="#0b0b0d"/><circle cx="330" cy="120" r="260" fill="url(#rx)"/><circle cx="40" cy="760" r="200" fill="url(#rx)" opacity=".6"/>
    ${Array.from({ length: 40 }, (_, i) => `<line x1="${-400 + i * 30}" y1="0" x2="${i * 30 + 460}" y2="${H}" stroke="#fff" stroke-opacity=".025"/>`).join('')}<text x="200" y="470" text-anchor="middle" font-family="Arial Black,Arial" font-weight="900" font-size="120" fill="#fff" opacity=".04">ROX</text>`,
    `<radialGradient id="rx"><stop offset="0" stop-color="#ff5a1f" stop-opacity=".55"/><stop offset="1" stop-color="#ff5a1f" stop-opacity="0"/></radialGradient>`)]);
  // 8 Sandy desert
  L.push(['Sandy Shores', svg(`<rect width="${W}" height="${H}" fill="url(#d)"/><circle cx="260" cy="360" r="70" fill="#fff0c2"/><path d="M-20 520 L60 440 L130 500 L220 420 L320 480 L420 430 V900 H-20z" fill="#b5654a"/>
    <path d="M-20 620 Q200 560 420 640 V900 H-20z" fill="#7a3b2e"/><path d="M-20 720 Q200 680 420 730 V900 H-20z" fill="#3a1c1a"/><g fill="#2a1414"><rect x="70" y="600" width="6" height="60"/><rect x="58" y="615" width="5" height="20" rx="2"/><rect x="82" y="608" width="5" height="22" rx="2"/></g>`,
    `<linearGradient id="d" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3d6bd6"/><stop offset=".5" stop-color="#f2a35e"/><stop offset=".62" stop-color="#ffd59a"/></linearGradient>`)]);
  return { list: L.map(x => url(x[1])), names: L.map(x => x[0]) };
})();
