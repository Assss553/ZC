/* ROX Store | rox_hud | All rights reserved. ESC menu + original San Andreas map (drawn from scratch, approximate). */
(() => {
const $ = (id) => document.getElementById(id);
const PREVIEW = !window.invokeNative;
const RES = window.GetParentResourceName ? GetParentResourceName() : 'rox_hud';
const post = (n, d = {}) => PREVIEW ? Promise.resolve(1) : fetch(`https://${RES}/${n}`, { method: 'POST', body: JSON.stringify(d) }).then(r => r.json()).catch(() => null);
// world -> map units (map is 900 x 1240)
const MX = (x) => (x + 4200) / 9000 * 900, MY = (y) => (8200 - y) / 12400 * 1240, WX = (u) => u / 900 * 9000 - 4200, WY = (v) => 8200 - v / 1240 * 12400;
const P = (pts) => pts.map(([x, y], i) => (i ? 'L' : 'M') + MX(x).toFixed(1) + ' ' + MY(y).toFixed(1)).join(' ') + 'Z';
const L = (pts) => pts.map(([x, y], i) => (i ? 'L' : 'M') + MX(x).toFixed(1) + ' ' + MY(y).toFixed(1)).join(' ');
// coastline (approximate, drawn by hand)
const COAST = [[-1900, -3500], [-1100, -3700], [-200, -3750], [700, -3550], [1300, -3100], [1700, -2500], [2100, -1700], [2600, -900], [2900, 0], [3300, 900], [3550, 1800], [3800, 2700], [4000, 3600], [3950, 4400], [3650, 5200], [3200, 5900], [2600, 6400], [1900, 6900], [1100, 7400], [400, 7600], [-200, 7150], [-700, 6650], [-1300, 6200], [-1900, 5700], [-2400, 5000], [-2900, 4100], [-3200, 3200], [-3300, 2300], [-3250, 1300], [-3050, 400], [-2700, -500], [-2400, -1300], [-2250, -2100], [-2150, -2900]];
const ISL = [[[-1900, -3500], [-2500, -3300], [-2300, -3050], [-1800, -3150]]];
const LAKE = [[650, 4250], [1100, 4600], [1800, 4700], [2600, 4500], [3000, 4100], [2700, 3800], [2000, 3650], [1300, 3700], [800, 3900]];
const MOUNT = [[[500, 5600], 900, '#3d3a32'], [[-1900, 3400], 800, '#34342c'], [[2600, 5600], 600, '#38352e'], [[-1000, 1600], 900, '#2f3a2c'], [[1500, 2500], 900, '#3a3628'], [[3300, 3800], 500, '#3a3529'], [[-200, 3000], 700, '#313a2b']];
const ROADS = [
  [[-800, -2500], [-500, -1800], [-300, -1000], [-200, -400], [-100, 500], [200, 1400], [800, 2300], [1500, 2900], [2000, 3300], [2700, 3600], [3200, 4300], [3000, 5000], [2400, 5700], [1700, 6300], [700, 6700], [-200, 6400]], // Senora / Route 13
  [[-2050, -500], [-2600, 1000], [-2900, 2400], [-2700, 3600], [-2200, 4600], [-1600, 5500], [-800, 6200], [-200, 6400]], // Great Ocean Hwy
  [[200, -2400], [600, -1600], [1200, -800], [1800, 200], [2500, 1200], [2700, 2400], [2400, 3400]], // east LS fwy
  [[-1600, -2900], [-800, -2500], [200, -2400], [1000, -2700]], // airport/port
  [[-2050, -500], [-1300, -600], [-300, -1000], [800, -1100], [1400, -1000]], // Del Perro fwy
  [[-1000, 1600], [0, 2500], [1100, 2700], [2000, 3300]], // Route 68 east
  [[-2600, 3000], [-1600, 2900], [-1000, 2700], [0, 2500]], // Route 68 west
];
const PLACES = [['LOS SANTOS', 0, -1100, 22], ['Vinewood', 300, 300, 12], ['LSIA', -1300, -2900, 11], ['Port of LS', 800, -3000, 11], ['Vespucci', -1300, -1300, 11], ['Del Perro', -1700, -400, 11],
  ['Sandy Shores', 1800, 3700, 13], ['Grapeseed', 2300, 4900, 12], ['Paleto Bay', -200, 6400, 13], ['Mount Chiliad', 500, 5600, 12], ['Fort Zancudo', -2300, 3100, 12], ['Harmony', 600, 2700, 11],
  ['Alamo Sea', 1700, 4200, 13], ['Chumash', -3100, 1100, 11], ['Tataviam Mts', 2400, 300, 11], ['Great Chaparral', -500, 2000, 11], ['Paleto Forest', -800, 5200, 11]];
let BLIPS = [['Pillbox Medical', 298, -584, '#ff4d6a', 'H'], ['Mission Row PD', 428, -984, '#5aa7ff', 'P'], ['Legion Square', 195, -933, '#2ee59d', 'L'], ['Sandy Shores PD', 1853, 3686, '#5aa7ff', 'P'], ['Paleto Bay PD', -448, 6012, '#5aa7ff', 'P'], ['Fleeca Bank', 149, -1040, '#ffc24a', '$'], ['Pacific Standard', 247, 222, '#ffc24a', '$']];

function mapSvg() {
  const city = []; for (let i = 0; i < 260; i++) { const x = -1900 + Math.random() * 3300, y = -2500 + Math.random() * 3000; if (Math.hypot((x - 0) / 1.6, (y + 1000)) < 1300) city.push(`<rect x="${MX(x).toFixed(1)}" y="${MY(y).toFixed(1)}" width="${(2 + Math.random() * 5).toFixed(1)}" height="${(2 + Math.random() * 5).toFixed(1)}"/>`); }
  return `<svg viewBox="0 0 900 1240" class="msvg"><defs>
    <radialGradient id="sea" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="#0e2130"/><stop offset="1" stop-color="#061019"/></radialGradient>
    <linearGradient id="land" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c3a2a"/><stop offset=".55" stop-color="#3a3a2c"/><stop offset="1" stop-color="#3a3430"/></linearGradient>
    ${MOUNT.map(([, , c], i) => `<radialGradient id="mt${i}"><stop offset="0" stop-color="${c}" stop-opacity="1"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>`).join('')}
    <pattern id="grid" width="45" height="45" patternUnits="userSpaceOnUse"><path d="M45 0H0V45" fill="none" stroke="rgba(120,180,220,.06)"/></pattern>
    <filter id="sh"><feDropShadow dx="0" dy="6" stdDeviation="8" flood-color="#000" flood-opacity=".6"/></filter><clipPath id="clip"><path d="${P(COAST)}"/></clipPath></defs>
    <rect width="900" height="1240" fill="url(#sea)"/><rect width="900" height="1240" fill="url(#grid)"/>
    ${[1, 2, 3].map(k => `<path d="${P(COAST)}" fill="none" stroke="rgba(90,170,220,${.12 / k})" stroke-width="${k * 14}"/>`).join('')}
    <path d="${P(COAST)}" fill="url(#land)" filter="url(#sh)"/>${ISL.map(p => `<path d="${P(p)}" fill="#3a3430"/>`).join('')}
    <g clip-path="url(#clip)">${MOUNT.map(([[x, y], r], i) => `<ellipse cx="${MX(x)}" cy="${MY(y)}" rx="${r / 10}" ry="${r / 10 * .8}" fill="url(#mt${i})"/>${[.7, .45, .25].map(f => `<ellipse cx="${MX(x)}" cy="${MY(y)}" rx="${r / 10 * f}" ry="${r / 10 * .8 * f}" fill="none" stroke="rgba(255,255,255,.05)"/>`).join('')}`).join('')}
      <ellipse cx="${MX(-100)}" cy="${MY(-1000)}" rx="110" ry="80" fill="rgba(70,70,80,.45)"/><g fill="rgba(255,200,140,.25)">${city.join('')}</g></g>
    <path d="${P(LAKE)}" fill="#0f2635" stroke="rgba(90,170,220,.35)" stroke-width="1.5"/>
    <path d="${L([[-2500, 2300], [-2100, 2600], [-1600, 2700], [-1000, 2800], [-300, 3200], [400, 3700], [800, 3950]])}" fill="none" stroke="#14303f" stroke-width="3"/>
    <g fill="none" stroke-linecap="round" stroke-linejoin="round">${ROADS.map(r => `<path d="${L(r)}" stroke="rgba(0,0,0,.5)" stroke-width="5"/><path d="${L(r)}" stroke="#d9a35a" stroke-width="2.2" opacity=".85"/>`).join('')}</g>
    <path d="${P(COAST)}" fill="none" stroke="rgba(180,220,240,.35)" stroke-width="1.2"/>
    <g class="lbls">${PLACES.map(([n, x, y, s]) => `<text x="${MX(x)}" y="${MY(y)}" font-size="${s}" ${s > 15 ? 'font-weight="800" letter-spacing="4"' : ''}>${n}</text>`).join('')}</g></svg>`;
}

/* ---------- styles ---------- */
document.head.insertAdjacentHTML('beforeend', `<style>
#pm2 { position: fixed; inset: 0; z-index: 50; display: none; font-family: 'Inter', sans-serif; color: #fff; background: radial-gradient(ellipse at 60% 50%, rgba(10,6,4,.55), rgba(0,0,0,.92)); backdrop-filter: blur(6px); }
#pm2.on { display: block; animation: pmIn .35s ease; } @keyframes pmIn { from { opacity: 0; } }
.pm-wrap { position: absolute; inset: 4vh 3vw; display: grid; grid-template-columns: 260px 1fr 320px; gap: 18px; animation: pmUp .5s cubic-bezier(.16,1,.3,1); } @keyframes pmUp { from { transform: translateY(30px) scale(.97); opacity: 0; } }
.pm-col { display: flex; flex-direction: column; gap: 12px; min-height: 0; }
.pm-brand { display: flex; align-items: center; gap: 12px; padding: 6px 4px 14px; } .pm-brand .lg { width: 48px; height: 48px; border-radius: 15px; display: grid; place-items: center; font: italic 900 17px 'Barlow Condensed', sans-serif; background: linear-gradient(145deg, #ff8a4c, #c43a0a); box-shadow: 0 10px 26px rgba(255,90,31,.5); }
.pm-brand b { display: block; font: italic 800 26px 'Barlow Condensed', sans-serif; letter-spacing: .5px; line-height: 1; } .pm-brand small { font-size: 11px; color: rgba(255,255,255,.5); }
.pm-nav { position: relative; display: flex; align-items: center; gap: 14px; padding: 14px 16px; border-radius: 16px; cursor: pointer; font-size: 14px; font-weight: 700; color: rgba(255,255,255,.6); background: rgba(255,255,255,.025); border: 1px solid transparent; transition: .2s cubic-bezier(.2,.8,.3,1); }
.pm-nav i { width: 36px; height: 36px; border-radius: 11px; display: grid; place-items: center; font-size: 15px; background: rgba(255,255,255,.05); transition: .2s; } .pm-nav kbd { margin-left: auto; font: 700 9.5px Inter; padding: 3px 6px; border-radius: 5px; background: rgba(255,255,255,.08); color: rgba(255,255,255,.5); }
.pm-nav:hover, .pm-nav.sel { color: #fff; background: rgba(255,255,255,.05); transform: translateX(6px); border-color: rgba(255,255,255,.07); } .pm-nav.sel i, .pm-nav:hover i { background: #ff5a1f; box-shadow: 0 6px 16px rgba(255,90,31,.45); }
.pm-nav.quit:hover i { background: #ff4d6a; box-shadow: 0 6px 16px rgba(255,77,106,.45); } .pm-sp { flex: 1; }
.pm-me { padding: 16px; border-radius: 18px; background: linear-gradient(145deg, rgba(255,90,31,.16), rgba(255,255,255,.02)); border: 1px solid rgba(255,90,31,.25); }
.pm-me .r { display: flex; align-items: center; gap: 12px; } .pm-me .av { width: 46px; height: 46px; border-radius: 14px; display: grid; place-items: center; font-weight: 800; background: linear-gradient(145deg, #ff8a4c, #c43a0a); }
.pm-me b { display: block; font-size: 15px; } .pm-me small { font-size: 11px; color: rgba(255,255,255,.55); } .pm-me .m2 { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-top: 12px; } .pm-me .m2 div { padding: 9px 10px; border-radius: 11px; background: rgba(0,0,0,.3); font-size: 9.5px; font-weight: 800; letter-spacing: 1px; color: rgba(255,255,255,.5); } .pm-me .m2 b { font-size: 14px; color: #fff; letter-spacing: 0; margin-top: 2px; }
/* map */
.pm-map { position: relative; border-radius: 26px; overflow: hidden; background: #061019; border: 1px solid rgba(255,255,255,.08); box-shadow: 0 30px 80px rgba(0,0,0,.6); }
.pm-mh { position: absolute; top: 14px; left: 14px; right: 14px; z-index: 5; display: flex; align-items: center; gap: 10px; pointer-events: none; } .pm-mh > * { pointer-events: auto; }
.pm-loc { display: flex; align-items: center; gap: 10px; padding: 10px 14px; border-radius: 14px; background: rgba(10,12,16,.82); backdrop-filter: blur(10px); font-size: 12.5px; font-weight: 700; } .pm-loc i { color: #ff5a1f; } .pm-loc small { display: block; font-size: 10px; color: rgba(255,255,255,.5); font-weight: 600; }
.pm-seg { margin-left: auto; display: flex; padding: 4px; border-radius: 12px; background: rgba(10,12,16,.82); } .pm-seg b { padding: 7px 14px; border-radius: 9px; font-size: 11.5px; cursor: pointer; color: rgba(255,255,255,.6); } .pm-seg b.on { background: #ff5a1f; color: #fff; }
.pm-zoom { position: absolute; right: 14px; bottom: 14px; z-index: 5; display: flex; flex-direction: column; gap: 6px; } .pm-zoom b { width: 38px; height: 38px; border-radius: 12px; display: grid; place-items: center; cursor: pointer; background: rgba(10,12,16,.85); font-size: 15px; } .pm-zoom b:hover { background: #ff5a1f; }
.pm-leg { position: absolute; left: 14px; bottom: 14px; z-index: 5; display: flex; gap: 6px; flex-wrap: wrap; max-width: 70%; } .pm-leg span { display: flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 10px; background: rgba(10,12,16,.82); font-size: 10.5px; font-weight: 700; cursor: pointer; } .pm-leg span i { width: 8px; height: 8px; border-radius: 50%; }
.pm-view { position: absolute; inset: 0; perspective: 1400px; overflow: hidden; cursor: grab; } .pm-view:active { cursor: grabbing; }
.pm-plane { position: absolute; left: 50%; top: 50%; width: 900px; height: 1240px; margin: -620px 0 0 -450px; transform-style: preserve-3d; transition: transform .7s cubic-bezier(.2,.8,.3,1); }
.pm-plane.drag { transition: none; } .msvg { width: 100%; height: 100%; display: block; } .lbls text { fill: rgba(255,255,255,.7); text-anchor: middle; font-family: Inter; font-weight: 700; paint-order: stroke; stroke: rgba(0,0,0,.6); stroke-width: 3px; }
.pm-3d .pm-plane::after { content: ''; position: absolute; left: 0; right: 0; bottom: -40px; height: 40px; background: linear-gradient(#2a2c24, #0b0c09); transform-origin: top; transform: rotateX(-90deg); }
.pin { position: absolute; transform-style: preserve-3d; transform: translate(-50%, -100%); pointer-events: auto; cursor: pointer; }
.pin .h { width: 24px; height: 24px; border-radius: 50% 50% 50% 0; transform: rotate(-45deg); background: var(--c); border: 2px solid #fff; display: grid; place-items: center; box-shadow: 0 4px 10px rgba(0,0,0,.6); }
.pin .h span { transform: rotate(45deg); font: 900 10px Inter; color: #111; } .pin .tt { position: absolute; left: 50%; bottom: 32px; transform: translateX(-50%); white-space: nowrap; padding: 4px 8px; border-radius: 7px; background: rgba(0,0,0,.85); font-size: 11px; font-weight: 700; opacity: 0; transition: .15s; pointer-events: none; } .pin:hover .tt { opacity: 1; }
.pm-3d .pin { transform: translate(-50%, -100%) rotateX(-58deg); transform-origin: bottom center; } .pm-3d .pin::after { content: ''; position: absolute; left: 50%; bottom: -14px; width: 2px; height: 14px; background: linear-gradient(#fff, transparent); }
.me-dot { position: absolute; width: 22px; height: 22px; margin: -11px; border-radius: 50%; background: #ff5a1f; border: 3px solid #fff; box-shadow: 0 0 0 10px rgba(255,90,31,.25), 0 0 24px #ff5a1f; transition: left .5s linear, top .5s linear; z-index: 3; }
.me-dot::before { content: ''; position: absolute; left: 50%; top: -22px; margin-left: -7px; border: 7px solid transparent; border-bottom: 14px solid #ff5a1f; transform-origin: 7px 33px; transform: rotate(var(--hd, 0deg)); }
.me-dot::after { content: ''; position: absolute; inset: -12px; border-radius: 50%; border: 2px solid #ff5a1f; animation: ping 1.8s infinite; } @keyframes ping { to { transform: scale(2.4); opacity: 0; } }
.pm-3d .me-dot { transform: rotateX(-58deg) translateY(-14px); }
.wp { position: absolute; width: 16px; height: 16px; margin: -8px; border-radius: 4px; transform: rotate(45deg); background: #ffd36b; border: 2px solid #fff; box-shadow: 0 0 16px #ffd36b; z-index: 3; display: none; } .wp.on { display: block; }
.pm-hint { position: absolute; left: 50%; top: 70px; transform: translateX(-50%); z-index: 5; padding: 7px 12px; border-radius: 10px; background: rgba(10,12,16,.8); font-size: 10.5px; color: rgba(255,255,255,.6); pointer-events: none; }
/* right column */
.pm-card { padding: 16px; border-radius: 20px; background: rgba(255,255,255,.035); border: 1px solid rgba(255,255,255,.07); } .pm-card h4 { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 800; letter-spacing: .5px; margin-bottom: 12px; } .pm-card h4 i { color: #ff5a1f; } .pm-card h4 span { margin-left: auto; font-size: 10px; color: #2ee59d; display: flex; align-items: center; gap: 5px; } .pm-card h4 span::before { content: ''; width: 7px; height: 7px; border-radius: 50%; background: #2ee59d; box-shadow: 0 0 8px #2ee59d; }
.pm-srv { display: flex; align-items: center; gap: 16px; } .pm-ring { position: relative; width: 92px; height: 92px; flex: none; } .pm-ring svg { width: 100%; height: 100%; transform: rotate(-90deg); } .pm-ring circle { fill: none; stroke-width: 9; } .pm-ring .fg { stroke: #ff5a1f; stroke-linecap: round; stroke-dasharray: 245; transition: stroke-dashoffset 1s; filter: drop-shadow(0 0 6px #ff5a1f); } .pm-ring .bg { stroke: rgba(255,255,255,.07); }
.pm-ring div { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; } .pm-ring b { font-size: 22px; } .pm-ring small { font-size: 9px; color: rgba(255,255,255,.5); font-weight: 700; }
.pm-kv { flex: 1; display: flex; flex-direction: column; gap: 6px; } .pm-kv div { display: flex; align-items: center; gap: 8px; padding: 8px 10px; border-radius: 11px; background: rgba(0,0,0,.25); font-size: 11.5px; font-weight: 700; } .pm-kv div b { margin-left: auto; font-size: 14px; } .pm-kv i { width: 14px; text-align: center; }
.pm-acts { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; } .pm-act { padding: 12px; border-radius: 14px; background: rgba(255,255,255,.03); border: 1px solid rgba(255,255,255,.06); font-size: 11.5px; font-weight: 700; color: rgba(255,255,255,.45); } .pm-act i { display: block; font-size: 18px; margin-bottom: 6px; }
.pm-act small { display: block; font-size: 9.5px; font-weight: 800; letter-spacing: .5px; margin-top: 3px; } .pm-act.on { color: #fff; border-color: rgba(46,229,157,.35); background: rgba(46,229,157,.07); } .pm-act.on i, .pm-act.on small { color: #2ee59d; }
.pm-time { text-align: center; } .pm-time b { display: block; font: 800 46px Inter; letter-spacing: -1.5px; line-height: 1; } .pm-time small { font-size: 11px; font-weight: 700; letter-spacing: 1.5px; color: rgba(255,255,255,.5); }
.pm-keys { display: flex; justify-content: center; gap: 12px; font-size: 10.5px; color: rgba(255,255,255,.5); font-weight: 700; } .pm-keys kbd { font: 800 9.5px Inter; padding: 3px 6px; border-radius: 5px; background: #fff; color: #111; margin-right: 4px; }
</style>`);

/* ---------- markup ---------- */
document.body.insertAdjacentHTML('beforeend', `<div id="pm2"><div class="pm-wrap">
  <div class="pm-col"><div class="pm-brand"><div class="lg" id="pmLogo">ROX</div><div><b id="pmSrv">ROX</b><small>Pause menu</small></div></div>
    ${[['resume', 'play', 'Resume', 'ESC'], ['map', 'map-location-dot', 'Map', 'M'], ['hud', 'sliders', 'HUD settings', ''], ['settings', 'gear', 'Game settings', ''], ['gta', 'earth-americas', 'GTA map', '']].map(([a, i, t, k], n) => `<div class="pm-nav ${n === 0 ? 'sel' : ''}" data-a="${a}"><i class="fa-solid fa-${i}"></i>${t}${k ? `<kbd>${k}</kbd>` : ''}</div>`).join('')}
    <div class="pm-sp"></div><div class="pm-me"><div class="r"><div class="av" id="pmAv">R</div><div><b id="pmN">—</b><small id="pmJ">—</small></div></div><div class="m2"><div>CASH<b id="pmC">$0</b></div><div>BANK<b id="pmB">$0</b></div><div>ID<b id="pmI">0</b></div><div>CITIZEN<b id="pqCid">—</b></div></div></div>
    <div class="pm-nav quit" data-a="quit"><i class="fa-solid fa-power-off"></i>Quit game</div></div>
  <div class="pm-map pm-3d" id="pmMap"><div class="pm-view" id="pmView"><div class="pm-plane" id="pmPlane">${mapSvg()}<div id="pmPins"></div><div class="wp" id="pmWp"></div><div class="me-dot" id="pmMe"></div></div></div>
    <div class="pm-mh"><div class="pm-loc"><i class="fa-solid fa-location-dot"></i><div id="pqLoc">—<small>Your location</small></div></div><div class="pm-seg" id="pmSeg"><b data-m="2d">2D</b><b data-m="3d" class="on">3D</b></div></div>
    <div class="pm-zoom"><b data-z="1"><i class="fa-solid fa-plus"></i></b><b data-z="-1"><i class="fa-solid fa-minus"></i></b><b data-z="0"><i class="fa-solid fa-location-crosshairs"></i></b></div>
    <div class="pm-leg" id="pmLeg"></div><div class="pm-hint">Drag to move · Wheel to zoom · Right click to rotate (3D) · Click to set GPS</div></div>
  <div class="pm-col"><div class="pm-card pm-time"><b id="pmT">00:00</b><small id="pmD">—</small></div>
    <div class="pm-card"><h4><i class="fa-solid fa-server"></i>SERVER<span>LIVE</span></h4><div class="pm-srv"><div class="pm-ring"><svg viewBox="0 0 92 92"><circle class="bg" cx="46" cy="46" r="39"/><circle class="fg" id="pqRing" cx="46" cy="46" r="39" style="stroke-dashoffset:245"/></svg><div><b id="pqOn">0</b><small id="pqMax">/ 0</small></div></div>
      <div class="pm-kv"><div><i class="fa-solid fa-shield-halved" style="color:#5aa7ff"></i>Police<b id="pqPol">0</b></div><div><i class="fa-solid fa-truck-medical" style="color:#ff4d6a"></i>EMS<b id="pqEms">0</b></div></div></div></div>
    <div class="pm-card" style="flex:1;min-height:0;overflow:auto"><h4><i class="fa-solid fa-bolt"></i>ACTIVITIES</h4><div class="pm-acts" id="pqActs"></div></div>
    <div class="pm-keys"><span><kbd>↑↓</kbd>Navigate</span><span><kbd>ENTER</kbd>Select</span><span><kbd>ESC</kbd>Resume</span></div></div>
</div></div>`);

/* ---------- map interaction ---------- */
const V = { mode: "3d", z: .75, rz: -15, px: 0, py: 0 }; let me = null, wp = null;
const plane = $('pmPlane');
function apply(fast) { plane.classList.toggle('drag', !!fast); const tilt = V.mode === '3d' ? 'rotateX(58deg)' : ''; const rot = V.mode === '3d' ? `rotateZ(${V.rz}deg)` : '';
  plane.style.transform = `translate(${V.px}px, ${V.py}px) ${tilt} scale(${V.z}) ${rot}`; $('pmMap').classList.toggle('pm-3d', V.mode === '3d'); }
function center() { if (!me) return; V.px = -(MX(me.x) - 450) * V.z; V.py = -(MY(me.y) - 620) * V.z * (V.mode === '3d' ? .55 : 1); }
function pins() { $('pmPins').innerHTML = BLIPS.map(([n, x, y, c, s], i) => `<div class="pin" style="left:${MX(x)}px;top:${MY(y)}px;--c:${c}" data-b="${i}"><div class="h"><span>${s}</span></div><div class="tt">${n}</div></div>`).join('');
  const seen = {}; $('pmLeg').innerHTML = BLIPS.filter(b => !seen[b[4]] && (seen[b[4]] = 1)).map(([n, , , c, s]) => `<span data-s="${s}"><i style="background:${c}"></i>${{ H: 'Hospital', P: 'Police', $: 'Banks', L: 'Landmarks' }[s] || n}</span>`).join(''); }
function setMe(c) { me = c; const d = $('pmMe'); d.style.left = MX(c.x) + 'px'; d.style.top = MY(c.y) + 'px'; d.style.setProperty('--hd', (-(c.h || 0)) + 'deg'); }
function setWp(x, y) { wp = { x, y }; const w = $('pmWp'); w.style.left = MX(x) + 'px'; w.style.top = MY(y) + 'px'; w.classList.add('on'); }
let drag = null;
$('pmView').addEventListener('mousedown', (e) => { drag = { x: e.clientX, y: e.clientY, px: V.px, py: V.py, rz: V.rz, btn: e.button, moved: false }; e.preventDefault(); });
document.addEventListener('mousemove', (e) => { if (!drag) return; const dx = e.clientX - drag.x, dy = e.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true;
  if (drag.btn === 2 && V.mode === '3d') V.rz = drag.rz + dx * .3; else { V.px = drag.px + dx; V.py = drag.py + dy; } apply(true); });
document.addEventListener('mouseup', (e) => { if (!drag) return; const d = drag; drag = null; apply(); if (d.moved || d.btn !== 0) return;
  const pin = e.target.closest('.pin'); let x, y;
  if (pin) { const b = BLIPS[pin.dataset.b]; x = b[1]; y = b[2]; } else if (V.mode === '2d') { const r = plane.getBoundingClientRect(); x = WX((e.clientX - r.left) / r.width * 900); y = WY((e.clientY - r.top) / r.height * 1240); } else return;
  setWp(x, y); post('waypoint', { x, y }); });
$('pmView').addEventListener('contextmenu', (e) => e.preventDefault());
$('pmView').addEventListener('wheel', (e) => { V.z = Math.max(.45, Math.min(3, V.z * (e.deltaY < 0 ? 1.12 : .89))); apply(); });
$('pmSeg').onclick = (e) => { const b = e.target.closest('[data-m]'); if (!b) return; V.mode = b.dataset.m; [...$('pmSeg').children].forEach(x => x.classList.toggle('on', x === b)); center(); apply(); };
document.querySelector('.pm-zoom').onclick = (e) => { const b = e.target.closest('[data-z]'); if (!b) return; const z = +b.dataset.z; if (!z) { V.z = 1.6; center(); } else V.z = Math.max(.45, Math.min(3, V.z * (z > 0 ? 1.25 : .8))); apply(); };

/* ---------- menu ---------- */
const NAV = () => [...document.querySelectorAll('#pm2 .pm-nav')]; let sel = 0;
const money = (n) => '$' + Math.floor(n || 0).toLocaleString('en-US');
function act(a) { if (a === 'map') { V.z = 1.6; center(); return apply(); } close(a === 'gta' ? 'map' : a); }
function close(a) { $('pm2').classList.remove('on'); document.body.classList.remove('paused'); post('pause', { action: a || 'resume' }); }
$('pm2').addEventListener('click', (e) => { const n = e.target.closest('.pm-nav'); if (n) act(n.dataset.a); });
document.addEventListener('keydown', (e) => { if (!$('pm2').classList.contains('on')) return; const n = NAV();
  if (e.key === 'Escape') close('resume'); else if (e.key === 'ArrowDown') sel = (sel + 1) % n.length; else if (e.key === 'ArrowUp') sel = (sel + n.length - 1) % n.length; else if (e.key === 'Enter') return act(n[sel].dataset.a); else if (e.key.toLowerCase() === 'm') return act('map'); else return;
  n.forEach((x, i) => x.classList.toggle('sel', i === sel)); });
setInterval(() => { if (!$('pm2').classList.contains('on')) return; const d = new Date(); $('pmD').textContent = d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }).toUpperCase(); }, 1000);
function open(d) { const i = d.info || {}; $('pmSrv').textContent = d.server || 'ROX'; $('pmLogo').textContent = (d.server || 'ROX').slice(0, 3).toUpperCase();
  $('pmJ').textContent = (i.job || 'Citizen') + (i.grade ? ' · ' + i.grade : ''); $('pmC').textContent = money(i.cash); $('pmB').textContent = money(i.bank); $('pmI').textContent = i.id ?? ''; $('pmT').textContent = i.time || '';
  $('pqActs').dataset.list = JSON.stringify(d.activities || []); acts(0); if (d.blips) BLIPS = d.blips.map(b => [b.label, b.x, b.y, b.color, b.icon]); pins();
  if (d.coords) setMe(d.coords); if (d.waypoint) setWp(d.waypoint.x, d.waypoint.y); else $('pmWp').classList.remove('on');
  $('pqLoc').innerHTML = `${d.location || '—'}<small>Your location</small>`; V.z = .75; V.rz = -15; center(); V.py -= 60; apply(); sel = 0; NAV().forEach((x, k) => x.classList.toggle('sel', k === 0));
  $('pm2').classList.add('on'); document.body.classList.add('paused'); }
function acts(police) { const list = JSON.parse($('pqActs').dataset.list || '[]');
  $('pqActs').innerHTML = list.map(a => `<div class="pm-act ${police >= a.police ? 'on' : ''}"><i class="fa-solid fa-${a.icon}"></i>${a.label}<small>${police >= a.police ? 'AVAILABLE' : a.police + ' POLICE NEEDED'}</small></div>`).join(''); }
window.addEventListener('message', (e) => { const d = e.data || {};
  if (d.action === 'pause') { if (d.open) open(d); else { $('pm2').classList.remove('on'); document.body.classList.remove('paused'); } }
  if (d.action === 'pauseData') { const p = d.data; $('pmN').textContent = p.name || ''; $('pmAv').textContent = (p.name || 'R').split(' ').map(w => w[0]).join('').slice(0, 2); $('pqCid').textContent = p.cid || '';
    $('pqOn').textContent = p.online; $('pqMax').textContent = '/ ' + p.max; $('pqPol').textContent = p.police; $('pqEms').textContent = p.ems; $('pqRing').style.strokeDashoffset = 245 * (1 - Math.min(1, p.online / Math.max(1, p.max))); acts(p.police); }
  if (d.action === 'pauseCoords' && $('pm2').classList.contains('on')) setMe(d.coords); });
if (PREVIEW && new URLSearchParams(location.search).get('pause2')) setTimeout(() => { window.postMessage({ action: 'pause', open: true, server: 'ROX', location: 'Mission Row · Atlee St', coords: { x: 410, y: -980, h: 40 }, waypoint: { x: 1850, y: 3690 },
  info: { id: 1, time: '16:37', job: 'LSPD', grade: 'Captain', cash: 12450, bank: 284500 }, activities: [{ label: 'Store Robbery', icon: 'store', police: 2 }, { label: 'House Robbery', icon: 'house', police: 1 }, { label: 'Fleeca Bank', icon: 'building-columns', police: 4 }, { label: 'Jewelry Store', icon: 'gem', police: 5 }] }, '*');
  window.postMessage({ action: 'pauseData', data: { online: 37, max: 64, police: 3, ems: 2, name: 'Jaber Dev', cid: 'IW731689' } }, '*'); }, 300);
})();
