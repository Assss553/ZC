/* ROX Store | rox_hud V2 | All rights reserved. */
const $ = (id) => document.getElementById(id);
const rgb = (h) => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)).join(',');
const segs = (el, n) => { el.innerHTML = '<i></i>'.repeat(n); return [...el.children]; };
const HP = segs($('hpSegs'), 25), RPM = segs($('rpm'), 24), FUEL = segs($('fuel'), 20);
const DIAS = [['hunger', 'burger', '#ffb020'], ['thirst', 'droplet', '#4da3ff'], ['stress', 'brain', '#ff4d5e'], ['stamina', 'person-running', '#3ddc84'], ['oxygen', 'lungs', '#9be7ff']];
$('dias').innerHTML = DIAS.map(([k, ic, c]) => `<div class="dia" id="d-${k}" style="--c:${c};--cr:${rgb(c)}"><div class="sh"><b></b></div><i class="fa-solid fa-${ic}"></i><span class="v"></span></div>`).join('');

const strip = $('strip'), LBL = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };
for (let d = -180; d <= 540; d += 15) { const a = ((d % 360) + 360) % 360, el = document.createElement('span'); el.dataset.d = d;
    if (LBL[a] !== undefined) { el.textContent = LBL[a]; } else if (a % 30 === 0) { el.textContent = a; el.className = 'n'; } else el.className = 't'; strip.appendChild(el); }
const compass = (h) => strip.querySelectorAll('span').forEach(s => { s.style.left = (220 + (s.dataset.d - h) * 3.2) + 'px'; });

function dia(k, v, show, lowAt) {
    const d = $('d-' + k); d.style.display = show ? '' : 'none'; if (!show) return;
    v = Math.max(0, Math.min(100, Math.round(v))); d.querySelector('b').style.height = (v * 1.6) + '%'; d.querySelector('.v').textContent = v;
    d.classList.toggle('low', lowAt != null && v <= lowAt);
}
const fill = (arr, frac, cls) => arr.forEach((s, i) => { const on = i < Math.round(frac * arr.length); s.className = on ? 'on' + (cls ? cls(i / arr.length) : '') : ''; });
const VOICE = { 1: 'Whisper', 2: 'Normal', 3: 'Shouting' };

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'init') { if (d.color) { document.documentElement.style.setProperty('--accent', d.color); document.documentElement.style.setProperty('--accent-rgb', rgb(d.color)); }
        $('unit').textContent = d.unit === 'mph' ? 'MPH' : 'KM/H'; if (d.compass === false) $('compass').style.display = 'none'; return; }
    if (d.action === 'belt') { $('cBelt').classList.toggle('on', d.on); return; }
    if (d.action !== 'tick') return;
    $('hud').classList.toggle('hidden', !!d.hidden);
    fill(HP, d.health / 100); $('hpVal').textContent = Math.round(d.health); $('heart').classList.toggle('low', d.health < 25);
    $('arLine').style.width = d.armor + '%';
    dia('hunger', d.hunger, true, 15); dia('thirst', d.thirst, true, 15); dia('stress', d.stress, d.stress > 5); dia('stamina', d.stamina, d.stamina < 98); dia('oxygen', d.oxygen ?? 100, d.oxygen != null, 25);
    $('voice').classList.toggle('talk', !!d.talking); $('vTxt').textContent = VOICE[d.voice] || 'Normal';
    compass(d.heading); $('dir').textContent = d.dir; $('street').textContent = d.street + (d.cross ? ' / ' + d.cross : ''); $('zone').textContent = d.zone || '';
    const v = d.veh; $('veh').classList.toggle('on', !!v); if (!v) return;
    const s = String(Math.min(999, v.speed)).padStart(3, '0'), lead = s.match(/^0*/)[0].slice(0, 2);
    $('spd').innerHTML = `<span class="dim">${lead}</span>${s.slice(lead.length)}`;
    fill(RPM, Math.min(1, v.rpm), (p) => p > .85 ? ' red' : p > .65 ? ' hi' : '');
    const g = $('gear'); g.textContent = v.speed < 1 && v.gear <= 1 ? 'N' : (v.gear === 0 ? 'R' : v.gear); g.classList.toggle('r', v.gear === 0);
    fill(FUEL, v.fuel / 100); $('fuelTxt').textContent = Math.round(v.fuel) + '%'; document.querySelector('.fuel-row').classList.toggle('low', v.fuel < 15);
    $('cBelt').classList.toggle('on', !!v.belt); $('cBelt').classList.toggle('warn', !v.belt && v.speed > 20);
    $('cEng').classList.toggle('ok', v.engine >= 40); $('cEng').classList.toggle('warn', v.engine < 40);
    $('cLgt').classList.toggle('on', !!v.lights); $('cLock').classList.toggle('on', !!v.locked);
});

if (typeof GetParentResourceName !== 'function') {
    document.body.classList.add('preview'); let h = 40, t = 0;
    window.postMessage({ action: 'init', color: '#ff5a1f', unit: 'kmh' }, '*');
    setInterval(() => { t++; h = (h + .5) % 360; const sp = Math.max(0, Math.round(70 + Math.sin(t / 18) * 70));
        window.postMessage({ action: 'tick', health: 82, armor: 60, hunger: 62, thirst: 12, stress: 34, stamina: 60, talking: t % 40 < 14, voice: 2, heading: h,
            dir: ['N','NE','E','SE','S','SW','W','NW'][Math.floor((h + 22.5) / 45) % 8], street: 'Vespucci Blvd', cross: 'Alta St', zone: 'Pillbox Hill',
            veh: new URLSearchParams(location.search).get('foot') ? null : { speed: sp, rpm: .2 + (sp % 45) / 50, gear: 3, fuel: 68, engine: 90, belt: false, lights: true, locked: true } }, '*'); }, 80);
}
