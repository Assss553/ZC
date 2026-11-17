/* ROX Store | rox_hud | All rights reserved. */
const $ = (id) => document.getElementById(id);
const TILES = [['hunger', 'burger', '#ffb020'], ['thirst', 'droplet', '#4da3ff'], ['stress', 'brain', '#ff4d5e'], ['stamina', 'person-running', '#3ddc84'], ['oxygen', 'lungs', '#9be7ff'], ['voice', 'microphone', '#ffffff']];
const rgb = (h) => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)).join(',');
$('tiles').innerHTML = TILES.map(([k, ic, c]) => `<div class="tile" id="t-${k}" style="--c:${c};--cr:${rgb(c)}"><div class="lvl"></div><i class="fa-solid fa-${ic}"></i><span class="num"></span></div>`).join('');

// compass strip
const strip = $('strip'); const LBL = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };
for (let d = -180; d <= 540; d += 15) { const a = ((d % 360) + 360) % 360; const el = document.createElement('span'); el.dataset.d = d;
    if (LBL[a] !== undefined) { el.textContent = LBL[a]; el.className = 'c'; } else if (a % 45 === 0 || a % 15 === 0) { el.className = 't'; } strip.appendChild(el); }
function compass(h) { const W = 420, px = 4; strip.querySelectorAll('span').forEach(s => { s.style.left = (W / 2 + (s.dataset.d - h) * px) + 'px'; }); }

function tile(k, v, show = true, low = 15) {
    const t = $('t-' + k); t.style.display = show ? '' : 'none'; if (!show) return;
    v = Math.max(0, Math.min(100, Math.round(v))); t.querySelector('.lvl').style.height = v + '%'; t.querySelector('.num').textContent = v;
    t.classList.toggle('low', k !== 'stress' && k !== 'stamina' && v <= low);
}
const VOICE = { 1: 'Whisper', 2: 'Normal', 3: 'Shout' };
let unit = 'kmh';
window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'init') { if (d.color) { document.documentElement.style.setProperty('--accent', d.color); document.documentElement.style.setProperty('--accent-rgb', rgb(d.color)); }
        unit = d.unit; $('unit').textContent = unit === 'mph' ? 'MPH' : 'KM/H'; if (d.compass === false) $('compass').style.display = 'none'; return; }
    if (d.action === 'belt') { $('belt').classList.toggle('on', d.on); return; }
    if (d.action !== 'tick') return;
    $('hud').classList.toggle('hidden', !!d.hidden);
    $('hpFill').style.width = d.health + '%'; $('hpVal').textContent = Math.round(d.health);
    $('arBar').classList.toggle('hide', !d.armor); $('arFill').style.width = d.armor + '%'; $('arVal').textContent = d.armor;
    tile('hunger', d.hunger); tile('thirst', d.thirst); tile('stress', d.stress, d.stress > 5); tile('stamina', d.stamina, d.stamina < 98);
    tile('oxygen', d.oxygen ?? 100, d.oxygen != null, 25);
    const vt = $('t-voice'); vt.classList.toggle('talk', !!d.talking); vt.querySelector('.lvl').style.height = (d.voice || 2) / 3 * 100 + '%'; vt.querySelector('.num').textContent = ['','LOW','MID','HIGH'][d.voice] || 'MID';
    compass(d.heading); $('dir').textContent = d.dir; $('street').textContent = d.street + (d.cross ? ' / ' + d.cross : ''); $('zone').textContent = d.zone || '';
    const v = d.veh; $('speedo').classList.toggle('on', !!v);
    if (v) { $('spd').textContent = v.speed; $('rpmArc').style.strokeDashoffset = 410 - 410 * Math.min(1, v.rpm);
        $('gear').textContent = v.speed === 0 && v.gear <= 1 ? 'N' : (v.gear === 0 ? 'R' : v.gear);
        $('belt').classList.toggle('warn', !v.belt && v.speed > 20); $('belt').classList.toggle('on', !!v.belt);
        $('eng').classList.toggle('warn', v.engine < 40); $('lgt').classList.add('lgt'); $('lgt').classList.toggle('on', !!v.lights);
        $('fuelFill').style.width = v.fuel + '%'; document.querySelector('.fuel').classList.toggle('low', v.fuel < 15); }
});

if (typeof GetParentResourceName !== 'function') {   // browser preview
    document.body.classList.add('preview'); let h = 40, s = 0, t = 0;
    window.postMessage({ action: 'init', color: '#ff5a1f', unit: 'kmh' }, '*');
    setInterval(() => { t++; h = (h + 0.6) % 360; s = Math.round(80 + Math.sin(t / 15) * 40);
        window.postMessage({ action: 'tick', health: 86, armor: 54, hunger: 62, thirst: 12, stress: 34, stamina: 60, oxygen: null, talking: t % 40 < 15, voice: 2, heading: h,
            dir: ['N','NE','E','SE','S','SW','W','NW'][Math.floor((h + 22.5) / 45) % 8], street: 'Vespucci Blvd', cross: 'Alta St', zone: 'Pillbox Hill',
            veh: new URLSearchParams(location.search).get('foot') ? null : { speed: s, rpm: .3 + (s % 40) / 60, gear: 3, fuel: 64, engine: 90, belt: false, lights: true } }, '*'); }, 80);
}
