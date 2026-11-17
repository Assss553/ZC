/* ROX Store | rox_radialmenu V2 | All rights reserved. */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
let post = (name, data = {}) => RES ? fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {}) : Promise.resolve();
const $ = (id) => document.getElementById(id);
const menu = $('menu'), ring = $('ring'), title = $('title'), coreBtn = $('coreBtn');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const S = { open: false, title: 'QUICK MENU', stack: [], sound: true, keepInput: true };

let actx = null;
function beep(f, d, v, slide = 0.6) {
    if (!S.sound) return;
    try { actx = actx || new AudioContext(); const o = actx.createOscillator(), g = actx.createGain(), t = actx.currentTime;
        o.type = 'sine'; o.frequency.setValueAtTime(f, t); o.frequency.exponentialRampToValueAtTime(f * slide, t + d);
        g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.0001, t + d); o.connect(g).connect(actx.destination); o.start(t); o.stop(t + d); } catch (e) {}
}

const cur = () => S.stack[S.stack.length - 1];
const isNum = (l) => /^\d+(\.\d+)?$/.test(String(l).trim());

function render() {
    const lvl = cur(), n = lvl.items.length;
    const r = Math.max(118, Math.min(210, 52 + n * 15));           // ring grows with the number of tiles
    ring.innerHTML = lvl.items.map((it, i) => {
        const a = (i / n) * Math.PI * 2 - Math.PI / 2;
        const x = Math.cos(a) * r, y = Math.sin(a) * r * .92;
        const big = isNum(it.label);
        return `<div class="tile" data-i="${i}" style="--x:${x.toFixed(1)}px;--y:${y.toFixed(1)}px;--d:${(i * 18)}ms">
            <div class="box">${i < 9 ? `<span class="key">${i + 1}</span>` : ''}${big ? `<span class="num">${esc(it.label)}</span>` : `<i class="fa-solid fa-${esc(it.icon || 'circle')}"></i>`}${it.items ? '<span class="sub"></span>' : ''}</div>
            <div class="lbl">${esc(big && it.sub ? it.sub : it.label)}</div></div>`;
    }).join('');
    S.r = r; const tO = $('trackO'), tI = $('trackI');
    tO.style.width = tO.style.height = (r * 2 + 40) + 'px'; tI.style.width = tI.style.height = (r * 2 - 70) + 'px';
    $('beam').classList.remove('show');
    setTitle(S.stack.length > 1 ? lvl.title : S.title);
    coreBtn.innerHTML = S.stack.length > 1 ? '<i class="fa-solid fa-rotate-left"></i>' : '<i class="fa-solid fa-xmark"></i>';
    requestAnimationFrame(() => ring.querySelectorAll('.tile').forEach(t => t.classList.add('in')));
}
function setTitle(t) { title.textContent = t; title.classList.remove('pop'); void title.offsetWidth; title.classList.add('pop'); }

ring.addEventListener('mouseover', (e) => {
    const t = e.target.closest('.tile'); if (!t || t.dataset.hov) return;
    ring.querySelectorAll('.tile').forEach(x => delete x.dataset.hov); t.dataset.hov = 1;
    setTitle(cur().items[t.dataset.i].label); beep(1800, .03, .02);
    const n = cur().items.length, a = (t.dataset.i / n) * Math.PI * 2 - Math.PI / 2, bm = $('beam');
    bm.style.width = (S.r - 48) + 'px'; bm.style.transform = `translate(0,-1px) rotate(${Math.atan2(Math.sin(a) * .92, Math.cos(a))}rad) translateX(30px)`; bm.classList.add('show');
});
ring.addEventListener('mouseleave', () => { $('beam').classList.remove('show'); ring.querySelectorAll('.tile').forEach(x => delete x.dataset.hov); setTitle(S.stack.length > 1 ? cur().title : S.title); });
ring.addEventListener('click', (e) => {
    const t = e.target.closest('.tile'); if (!t) return;
    const it = cur().items[t.dataset.i];
    if (it.items && it.items.length) { beep(700, .1, .04, 1.4); S.stack.push({ title: it.label, items: it.items }); render(); return; }
    beep(900, .12, .05, 1.3);
    post('select', { id: it.id });
});
coreBtn.addEventListener('click', back);
document.addEventListener('mousemove', (e) => {
    if (!S.open) return;
    const dx = (e.clientX / innerWidth - .5), dy = (e.clientY / innerHeight - .5);
    $('stage').style.setProperty('--ry', (dx * 10).toFixed(2) + 'deg'); $('stage').style.setProperty('--rx', (14 - dy * 10).toFixed(2) + 'deg');
});
document.addEventListener('contextmenu', (e) => { e.preventDefault(); if (S.open) back(); });
document.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'Backspace') back();
    else if (/^[1-9]$/.test(e.key)) { const t = ring.querySelector(`.tile[data-i="${Number(e.key) - 1}"]`); if (t) t.click(); }
    else if (e.key === 'F1' && !S.keepInput) close();
});

function back() { if (S.stack.length > 1) { S.stack.pop(); beep(600, .1, .04); render(); } else close(); }
function setColor(hex) {
    const m = /^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(hex || ''); if (!m) return;
    document.documentElement.style.setProperty('--accent', '#' + m[1] + m[2] + m[3]);
    document.documentElement.style.setProperty('--accent-rgb', [m[1], m[2], m[3]].map(x => parseInt(x, 16)).join(','));
}
function open(d) {
    setColor(d.color); S.title = (d.title || 'QUICK MENU'); S.sound = d.sound !== false; S.keepInput = !!d.keepInput;
    S.stack = [{ title: S.title, items: d.items || [] }]; S.open = true;
    menu.classList.add('open'); render(); beep(420, .18, .04, 2);
}
function close(fromGame) {
    if (!S.open) return; S.open = false; menu.classList.remove('open');
    if (!fromGame) post('close');
}
window.addEventListener('message', (e) => { const d = e.data || {}; if (d.action === 'open') open(d); else if (d.action === 'close') close(true); });

/* browser preview */
if (!RES) {
    document.body.classList.add('preview');
    let u = 0; const I = (label, icon, items, sub) => ({ id: 'x' + (u++), label, icon, items, sub });
    const radio = I('Radio', 'wifi', [I('ON/OFF', 'power-off'), I('0.1', '', 0, 'CH 0.1'), I('0.2', '', 0, 'CH 0.2'), I('0.3', '', 0, 'CH 0.3'), I('0.4', '', 0, 'CH 0.4'), I('0.5', '', 0, 'CH 0.5'), I('5', '', 0, 'CH 5')]);
    const items = [I('Citizen', 'circle-user', [I('Show ID', 'id-card'), I('Carry', 'people-carry-box')]), I('Emote Menu', 'list'), I('Job Menu', 'bars', [I('MDT', 'shield-halved'), I('Management', 'briefcase')]), I('Blips', 'map-location-dot'), I('Police Actions', 'shield-halved', [I('Prison', 'building-shield'), I('Citations', 'file-invoice-dollar'), I('Impound', 'truck-pickup')]), radio];
    const q = new URLSearchParams(location.search);
    setTimeout(() => { open({ title: 'QUICK MENU', items, keepInput: false }); if (q.get('sub')) setTimeout(() => ring.querySelector(`.tile[data-i="${items.length - 1}"]`).click(), 300); }, 100);
    const _c = close; close = (g) => { _c(g); setTimeout(() => open({ title: 'QUICK MENU', items }), 600); };
}
