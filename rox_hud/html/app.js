/* ROX Store | rox_hud V3 | All rights reserved. */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const post = (n, d = {}) => RES ? fetch(`https://${RES}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(d) }).catch(() => {}) : Promise.resolve();
const $ = (id) => document.getElementById(id);
const rgb = (h) => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)).join(',');
const root = document.documentElement;
let S = { alwaysStatus: false, compass: true, info: true, mapOnFoot: false, vignette: true, unit: 'kmh', color: '#ff5a1f', hidden: false }, MAX = 300;

/* ---------- triangle status (auto show / hide) ---------- */
const HEX = [['hunger', 'burger'], ['thirst', 'droplet'], ['stress', 'brain'], ['stamina', 'person-running'], ['oxygen', 'lungs'], ['voice', 'microphone']];
const TRI_UP = 'M24 3 L45 40 L3 40 Z', TRI_DN = 'M3 4 L45 4 L24 41 Z';
$('hexRow').innerHTML = HEX.map(([k, ic], i) => { const up = i % 2 === 0;
    return `<div class="st ${up ? 'up' : 'dn'}" id="r-${k}"><svg viewBox="0 0 48 44"><path class="tb" d="${up ? TRI_UP : TRI_DN}"/><path class="tf" d="${up ? TRI_UP : TRI_DN}" pathLength="100"/></svg><i class="fa-solid fa-${ic}"></i></div>`; }).join('');
// show when it matters, hide when full (setting "always" keeps them visible)
function ring(k, v, show = true, lowAt, hideAbove = 90) {
    const r = $('r-' + k); v = Math.max(0, Math.min(100, v));
    const low = lowAt != null && v <= lowAt;
    const visible = show && (S.alwaysStatus || low || v < hideAbove || k === 'voice');
    r.classList.toggle('hide', !visible);
    r.querySelector('.tf').style.strokeDashoffset = 100 - v;
    r.classList.toggle('low', low);
}
const segs = (el, n, curve) => { el.innerHTML = Array.from({ length: n }, (_, i) => `<i style="--h:${curve ? 40 + 60 * Math.sin(i / (n - 1) * Math.PI / 2) : 100}%"></i>`).join(''); return [...el.children]; };
const HP = segs($('hpSegs'), 26), RPMS = segs($('rpm'), 22, true), FUELS = segs($('fuel'), 20);
const fill = (arr, frac, cls) => arr.forEach((s, i) => { s.className = i < Math.round(frac * arr.length) ? 'on' + (cls ? cls(i / arr.length) : '') : ''; });
const VOICE = { 1: 'Whisper', 2: 'Normal', 3: 'Shouting' };

/* ---------- compass ---------- */
const strip = $('strip'), LBL = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };
for (let d = -180; d <= 540; d += 15) {
    const a = ((d % 360) + 360) % 360, el = document.createElement('span'); el.dataset.d = d;
    if (LBL[a] !== undefined) { el.textContent = LBL[a]; el.className = 'l' + (a % 90 === 0 ? ' main' : ''); }
    else if (a % 30 === 0) { el.textContent = a; el.className = 'n'; } else el.className = 't';
    strip.appendChild(el);
}
const STRIP = [...strip.children];
const compass = (h) => STRIP.forEach(s => { s.style.left = (230 + (s.dataset.d - h) * 3.4) + 'px'; });

let MAXS = 300; function buildTicks() {}

/* ---------- settings ---------- */
const TOGGLES = [['compass', 'compass', 'Compass'], ['info', 'id-card', 'Player info (ID, job, money)'], ['mapOnFoot', 'map', 'Minimap on foot'], ['vignette', 'heart-pulse', 'Low health effect'], ['alwaysStatus', 'eye', 'Always show status'], ['hidden', 'eye-slash', 'Hide HUD (cinematic)']];
const COLORS = ['#ff5a1f', '#ff2a3a', '#ffb020', '#3ddc84', '#1fc9b8', '#4da3ff', '#8a6cff', '#ff5ec4'];
function renderSettings() {
    $('sList').innerHTML = TOGGLES.map(([k, ic, l]) => `<div class="s-row ${S[k] ? 'on' : ''}" data-k="${k}"><i class="fa-solid fa-${ic}"></i><span>${l}</span><div class="sw"></div></div>`).join('');
    $('swatches').innerHTML = COLORS.map(c => `<button style="--s:${c}" class="${S.color === c ? 'on' : ''}" data-c="${c}"></button>`).join('');
    document.querySelectorAll('#unitSeg button').forEach(b => b.classList.toggle('on', b.dataset.u === S.unit));
}
function apply() {
    root.style.setProperty('--accent', S.color); root.style.setProperty('--accent-rgb', rgb(S.color));
    $('unit').textContent = S.unit === 'mph' ? 'MPH' : 'KM/H';
    $('compass').classList.toggle('off', !S.compass); $('info').classList.toggle('off', !S.info);
}
const save = () => { apply(); renderSettings(); post('saveSettings', S); };
$('settings').addEventListener('click', (e) => {
    const r = e.target.closest('.s-row'), c = e.target.closest('[data-c]'), u = e.target.closest('[data-u]'), a = e.target.closest('[data-a]');
    if (r) { S[r.dataset.k] = !S[r.dataset.k]; save(); }
    else if (c) { S.color = c.dataset.c; save(); }
    else if (u) { S.unit = u.dataset.u; save(); }
    else if (a) closeSettings();
});
function closeSettings() { $('settings').classList.remove('on'); post('closeSettings'); }
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && $('settings').classList.contains('on')) closeSettings(); });

/* ---------- helpers ---------- */
const money = (n) => '$' + Math.round(n || 0).toLocaleString('en-US');
function setMap(m) { if (!m) return; root.style.setProperty('--mx', m.x * 100 + 'vw'); root.style.setProperty('--my', m.y * 100 + 'vh'); root.style.setProperty('--mw', m.w * 100 + 'vw'); root.style.setProperty('--mh', m.h * 100 + 'vh'); }
let last = {};
function text(id, v) { if (last[id] === v) return false; last[id] = v; $(id).textContent = v; return true; }

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'init') { if (d.settings) S = Object.assign(S, d.settings);  setMap(d.map); apply(); return; }
    if (d.action === 'map') return setMap(d.map);
    if (d.action === 'settings') { if (d.settings) S = Object.assign(S, d.settings); renderSettings(); $('settings').classList.add('on'); return; }
    if (d.action !== 'tick') return;

    $('hud').classList.toggle('hidden', !!d.hidden);
    $('vignette').classList.toggle('on', S.vignette && !d.hidden && d.health > 0 && d.health < 30);
    $('mapFrame').classList.toggle('off', !d.radar); $('mapHead').classList.toggle('foot', !d.radar); $('hexRow').classList.toggle('foot', !d.radar);
    compass(d.heading); text('deg', Math.round(d.heading) + '°'); text('dir', d.dir);
    text('street', d.street + (d.cross ? ' / ' + d.cross : '')); text('zone', d.zone || '');

    fill(HP, d.health / 100); text('hpVal', String(Math.round(d.health))); $('heart').classList.toggle('low', d.health < 25);
    $('arLine').style.width = d.armor + '%'; $('arTxt').style.display = d.armor ? '' : 'none'; text('arVal', String(d.armor));
    $('voice').classList.toggle('talk', !!d.talking && !d.radio); $('voice').classList.toggle('radio', !!d.radio); text('vTxt', d.radio ? 'Radio' : (VOICE[d.voice] || 'Normal'));

    ring('hunger', d.hunger, true, 20); ring('thirst', d.thirst, true, 20); ring('stress', d.stress, d.stress > 5, null, 101); ring('stamina', 100 - d.stamina, d.stamina > 3, 15, 97);
    ring('oxygen', d.oxygen ?? 100, d.oxygen != null, 25, 101); ring('voice', (d.voice || 2) / 3 * 100, true, null, 101);
    $('r-voice').classList.toggle('talk', !!d.talking && !d.radio); $('r-voice').classList.toggle('radio', !!d.radio);

    if (d.info) {
        text('pid', String(d.info.id)); text('ptime', d.info.time);
        $('pjob').style.display = d.info.job ? '' : 'none'; text('pjobTxt', (d.info.job || '') + (d.info.grade ? ' · ' + d.info.grade : ''));
        $('pduty').classList.toggle('off', d.info.duty === false);
        if (d.info.cash != null && text('pcash', money(d.info.cash))) { $('pcash').classList.remove('bump'); void $('pcash').offsetWidth; $('pcash').classList.add('bump'); }
        if (d.info.bank != null && text('pbank', money(d.info.bank))) { $('pbank').classList.remove('bump'); void $('pbank').offsetWidth; $('pbank').classList.add('bump'); }
        document.querySelector('.i-money').style.display = d.info.cash == null && d.info.bank == null ? 'none' : '';
    }

    const car = d.veh; $('veh').classList.toggle('on', !!car); if (!car) return;
    const sp = Math.max(0, car.speed), s = String(Math.min(999, sp)).padStart(3, '0'), lead = s.match(/^0{0,2}/)[0];
    $('spd').innerHTML = `<span class="dim">${lead}</span>${s.slice(lead.length)}`;
    fill(RPMS, Math.max(0, Math.min(1, (car.rpm - .15) / .85)), (p) => p > .85 ? ' red' : p > .62 ? ' hi' : '');
    const g = $('gear'); g.querySelector('b').textContent = car.gear === 0 ? 'R' : (sp < 1 && car.gear <= 1 ? 'N' : car.gear); g.classList.toggle('r', car.gear === 0);
    fill(FUELS, car.fuel / 100); text('fuelTxt', Math.round(car.fuel) + '%'); document.querySelector('.fuel-row').classList.toggle('low', car.fuel < 15);
    $('hFuel').classList.toggle('warn', car.fuel < 15); $('hEng').classList.toggle('warn', car.engine < 40);
    const chip = (id, on, warn, ok) => { const el = $(id); el.classList.toggle('on', !!on); el.classList.toggle('warn', !!warn); el.classList.toggle('ok', !!ok); };
    chip('cBelt', car.belt, !car.belt && sp > 20); chip('cEng', false, car.engine < 40, car.engine >= 40 && car.running !== false);
    chip('cLgt', car.lights); chip('cLock', car.locked);
});

/* ---------- browser preview ---------- */
if (!RES) {
    document.body.classList.add('preview');
    const q = new URLSearchParams(location.search), foot = !!q.get('foot');
    window.postMessage({ action: 'init', settings: S, maxSpeed: 300, map: { x: .015, y: .775, w: .155, h: .185 } }, '*');
    let h = 40, t = 0;
    setInterval(() => { t++; h = (h + .4) % 360; const sp = Math.max(0, Math.round(118 + Math.sin(t / 25) * 30));
        window.postMessage({ action: 'tick', radar: !foot, health: q.get('low') ? 18 : 86, armor: 62, hunger: 64, thirst: 13, stress: 38, stamina: 55, talking: t % 50 < 18, radio: false, voice: 2,
            heading: h, dir: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][Math.floor((h + 22.5) / 45) % 8], street: 'Vespucci Blvd', cross: 'Alta St', zone: 'Pillbox Hill',
            info: { id: 12, time: '21:43', job: 'LSPD', grade: 'Captain', duty: true, cash: 12450, bank: 284500 },
            veh: foot ? null : { speed: sp, rpm: .35 + (sp % 40) / 70, gear: 4, fuel: 64, engine: 92, belt: false, lights: true, locked: true, running: true } }, '*'); }, 80);
    if (q.get('settings')) setTimeout(() => window.postMessage({ action: 'settings', settings: S }, '*'), 300);
}
