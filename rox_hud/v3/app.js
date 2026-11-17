/* ROX Store | rox_hud V3 | All rights reserved. */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const post = (n, d = {}) => RES ? fetch(`https://${RES}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(d) }).catch(() => {}) : Promise.resolve();
const $ = (id) => document.getElementById(id);
const rgb = (h) => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)).join(',');
const root = document.documentElement;
let S = { compass: true, info: true, mapOnFoot: false, vignette: true, unit: 'kmh', color: '#ff5a1f', hidden: false }, MAX = 300;

/* ---------- rings ---------- */
const RINGS = [['hunger', 'burger', '#ffb020'], ['thirst', 'droplet', '#4da3ff'], ['stress', 'brain', '#ff5c8a'], ['stamina', 'person-running', '#3ddc84'], ['oxygen', 'lungs', '#7fe3ff'], ['voice', 'microphone', '#ffffff']];
$('rings').innerHTML = RINGS.map(([k, ic, c]) => `<div class="ring ${k}" id="r-${k}" style="--c:${c}"><svg viewBox="0 0 40 40"><circle class="bg" cx="20" cy="20" r="16"/><circle class="fg" cx="20" cy="20" r="16"/></svg><i class="fa-solid fa-${ic}"></i></div>`).join('');
function ring(k, v, show = true, lowAt) {
    const r = $('r-' + k); r.classList.toggle('hide', !show); if (!show) return;
    v = Math.max(0, Math.min(100, v)); r.querySelector('.fg').style.strokeDashoffset = 100.5 * (1 - v / 100);
    r.classList.toggle('low', lowAt != null && v <= lowAt);
}

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

/* ---------- speedometer ---------- */
const C = 100, A0 = 135, A1 = 405;
const pol = (r, a) => { a = a * Math.PI / 180; return [C + r * Math.cos(a), C + r * Math.sin(a)]; };
const arcD = (r, a0, a1) => { const [x0, y0] = pol(r, a0), [x1, y1] = pol(r, a1); return `M${x0.toFixed(2)} ${y0.toFixed(2)} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`; };
$('arcBg').setAttribute('d', arcD(92, A0, A1)); $('arcFill').setAttribute('d', arcD(92, A0, A1));
$('rpmBg').setAttribute('d', arcD(57, A0 + 25, A1 - 25)); $('rpmFill').setAttribute('d', arcD(57, A0 + 25, A1 - 25));
const ARC = $('arcFill').getTotalLength(), RPM = $('rpmFill').getTotalLength();
$('arcFill').style.strokeDasharray = ARC; $('arcFill').style.strokeDashoffset = ARC;
let TICKS = [];
function buildTicks() {
    const n = 30, g = $('ticks'); let h = '';
    for (let i = 0; i <= n; i++) {
        const a = A0 + (A1 - A0) * i / n, mj = i % 5 === 0;
        const [x0, y0] = pol(mj ? 78 : 81, a), [x1, y1] = pol(86, a);
        h += `<line x1="${x0.toFixed(2)}" y1="${y0.toFixed(2)}" x2="${x1.toFixed(2)}" y2="${y1.toFixed(2)}" class="${mj ? 'mj' : ''}"/>`;
        if (mj) { const [tx, ty] = pol(70, a); h += `<text x="${tx.toFixed(1)}" y="${ty.toFixed(1)}">${Math.round(MAX * i / n)}</text>`; }
    }
    g.innerHTML = h; TICKS = [...g.querySelectorAll('line')];
}
buildTicks();

/* ---------- settings ---------- */
const TOGGLES = [['compass', 'compass', 'Compass'], ['info', 'id-card', 'Player info (ID, job, money)'], ['mapOnFoot', 'map', 'Minimap on foot'], ['vignette', 'heart-pulse', 'Low health effect'], ['hidden', 'eye-slash', 'Hide HUD (cinematic)']];
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
    if (d.action === 'init') { if (d.settings) S = Object.assign(S, d.settings); if (d.maxSpeed && d.maxSpeed !== MAX) { MAX = d.maxSpeed; buildTicks(); } setMap(d.map); apply(); return; }
    if (d.action === 'map') return setMap(d.map);
    if (d.action === 'settings') { if (d.settings) S = Object.assign(S, d.settings); renderSettings(); $('settings').classList.add('on'); return; }
    if (d.action !== 'tick') return;

    $('hud').classList.toggle('hidden', !!d.hidden);
    $('vignette').classList.toggle('on', S.vignette && !d.hidden && d.health > 0 && d.health < 30);
    $('mapFrame').classList.toggle('off', !d.radar); $('col').classList.toggle('left', !d.radar);

    // location
    compass(d.heading); text('deg', Math.round(d.heading) + '°'); text('dir', d.dir);
    text('street', d.street + (d.cross ? ' / ' + d.cross : '')); text('zone', d.zone || '');

    // health / armor
    $('hpFill').style.width = d.health + '%'; text('hpVal', String(Math.round(d.health)));
    document.querySelector('.bar.hp').classList.toggle('low', d.health < 25);
    $('arRow').classList.toggle('off', !d.armor); $('arFill').style.width = d.armor + '%'; text('arVal', String(d.armor));

    // rings
    ring('hunger', d.hunger, true, 15); ring('thirst', d.thirst, true, 15);
    ring('stress', d.stress, d.stress > 5); ring('stamina', d.stamina, d.stamina < 98, 10);
    ring('oxygen', d.oxygen ?? 100, d.oxygen != null, 25);
    ring('voice', (d.voice || 2) / 3 * 100);
    const v = $('r-voice'); v.classList.toggle('talk', !!d.talking && !d.radio); v.classList.toggle('radio', !!d.radio);

    // player info
    if (d.info) {
        text('pid', String(d.info.id)); text('ptime', d.info.time);
        $('pjob').style.display = d.info.job ? '' : 'none'; text('pjobTxt', (d.info.job || '') + (d.info.grade ? ' · ' + d.info.grade : ''));
        $('pduty').classList.toggle('off', d.info.duty === false);
        if (d.info.cash != null && text('pcash', money(d.info.cash))) { $('pcash').classList.remove('bump'); void $('pcash').offsetWidth; $('pcash').classList.add('bump'); }
        if (d.info.bank != null && text('pbank', money(d.info.bank))) { $('pbank').classList.remove('bump'); void $('pbank').offsetWidth; $('pbank').classList.add('bump'); }
        document.querySelector('.i-money').style.display = d.info.cash == null && d.info.bank == null ? 'none' : '';
    }

    // vehicle
    const car = d.veh; $('speedo').classList.toggle('on', !!car); if (!car) return;
    const sp = Math.max(0, car.speed), s = String(Math.min(999, sp)).padStart(3, '0'), lead = s.match(/^0{0,2}/)[0];
    $('spd').innerHTML = `<span class="dim">${lead}</span>${s.slice(lead.length)}`;
    const f = Math.min(1, sp / MAX); $('arcFill').style.strokeDashoffset = ARC * (1 - f);
    const lit = Math.round(f * (TICKS.length - 1)); TICKS.forEach((t, i) => t.classList.toggle('on', i <= lit && sp > 0));
    const rp = Math.max(0, Math.min(1, (car.rpm - .2) / .8)), rf = $('rpmFill');
    rf.style.strokeDasharray = `${(RPM * rp).toFixed(1)} ${RPM}`; rf.style.strokeDashoffset = 0;
    rf.setAttribute('class', 'rpm-fill' + (rp > .9 ? ' red' : rp > .7 ? ' hi' : ''));
    const g = $('gear'); g.textContent = car.gear === 0 ? 'R' : (sp < 1 && car.gear <= 1 ? 'N' : car.gear); g.classList.toggle('r', car.gear === 0);
    $('fuelFill').style.width = car.fuel + '%'; $('fuelBox').classList.toggle('low', car.fuel < 15);
    const ind = (id, on, warn, ok) => { const el = $(id); el.classList.toggle('on', !!on); el.classList.toggle('warn', !!warn); el.classList.toggle('ok', !!ok); };
    ind('iBelt', car.belt, !car.belt && sp > 20); ind('iEng', false, car.engine < 40 || car.running === false && car.engine < 40, car.engine >= 40 && car.running !== false);
    ind('iLgt', car.lights); ind('iLock', car.locked);
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
