/* ROX Store | rox_radialmenu V3 | All rights reserved. */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
let post = (name, data = {}) => RES ? fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {}) : Promise.resolve();
const $ = (id) => document.getElementById(id);
const menu = $('menu'), svg = $('svg'), icons = $('icons'), title = $('title'), crumb = $('crumb'), hint = $('hint'), coreBtn = $('coreBtn');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const S = { open: false, title: 'QUICK MENU', stack: [], sound: true, keepInput: true, hov: -1 };
const R_OUT = 292, R_IN = 122, R_MID = 208, GAP = 2.2;        // svg units (viewBox 600)

let actx = null;
function beep(f, d, v, slide = 0.6) {
    if (!S.sound) return;
    try { actx = actx || new AudioContext(); const o = actx.createOscillator(), g = actx.createGain(), t = actx.currentTime;
        o.type = 'sine'; o.frequency.setValueAtTime(f, t); o.frequency.exponentialRampToValueAtTime(f * slide, t + d);
        g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.0001, t + d); o.connect(g).connect(actx.destination); o.start(t); o.stop(t + d); } catch (e) {}
}
const cur = () => S.stack[S.stack.length - 1];
const isNum = (l) => /^\d+(\.\d+)?$/.test(String(l).trim());
const pt = (r, a) => [Math.cos(a) * r, Math.sin(a) * r];

function slicePath(a0, a1, ro, ri) {
    const go = GAP / ro, gi = GAP / ri;                        // constant-width gap between slices
    const [x0, y0] = pt(ro, a0 + go), [x1, y1] = pt(ro, a1 - go), [x2, y2] = pt(ri, a1 - gi), [x3, y3] = pt(ri, a0 + gi);
    const lg = a1 - a0 > Math.PI ? 1 : 0;
    return `M${x0},${y0} A${ro},${ro} 0 ${lg} 1 ${x1},${y1} L${x2},${y2} A${ri},${ri} 0 ${lg} 0 ${x3},${y3} Z`;
}
function edgePath(a0, a1, r) {
    const g = (GAP + 6) / r, [x0, y0] = pt(r, a0 + g), [x1, y1] = pt(r, a1 - g);
    return `M${x0},${y0} A${r},${r} 0 ${a1 - a0 > Math.PI ? 1 : 0} 1 ${x1},${y1}`;
}

const PRO = ['aaa', 'orbit', 'hex'];
function renderPro() {
    const lvl = cur(), n = Math.max(1, lvl.items.length), step = Math.PI * 2 / n, T = S.theme;
    const R = T === 'aaa' ? 214 : T === 'orbit' ? 222 : 212;
    let s = `<circle class="p-ring" r="${R}"/><circle class="p-ring2" r="${R + 62}"/>`, h = '';
    if (T === 'aaa') for (let i = 0; i < n; i++) {                     // thin arc per option
        const a0 = -Math.PI / 2 - step / 2 + i * step, a1 = a0 + step;
        s += `<g class="seg" data-i="${i}"><path class="arc" d="${edgePath(a0, a1, 286)}"/><path class="arc2" d="${edgePath(a0, a1, 276)}"/></g>`;
    }
    s += `<line id="link" class="p-link" x1="0" y1="0" x2="0" y2="0"/>`;
    lvl.items.forEach((it, i) => {
        const a = -Math.PI / 2 + i * step, [x, y] = pt(R, a), big = isNum(it.label), d = `${i * 25}ms`;
        h += `<div class="ic p-${T}" data-i="${i}" style="left:${50 + x / 6}%;top:${50 + y / 6}%;--d:${d}">
            <div class="card">${i < 10 ? `<span class="k">${(i + 1) % 10}</span>` : ''}
            ${big ? `<span class="num">${esc(it.label)}</span>` : `<i class="fa-solid fa-${esc(it.icon || 'circle')}"></i>`}
            ${it.items ? '<span class="dot"></span>' : ''}</div>
            <span class="lb">${esc(big && it.sub ? it.sub : it.label)}</span></div>`;
    });
    svg.innerHTML = s; icons.innerHTML = h; S.hov = -1;
    const deep = S.stack.length > 1;
    crumb.textContent = deep ? S.stack.slice(0, -1).map(l => l.title).join(' › ') : 'ROX';
    setTitle(deep ? lvl.title : S.title); hint.textContent = `${lvl.items.length} options`;
    $('bigic').innerHTML = '';
    coreBtn.innerHTML = deep ? '<i class="fa-solid fa-arrow-left"></i>' : '<i class="fa-solid fa-xmark"></i>';
    requestAnimationFrame(() => document.querySelectorAll('.seg,.ic').forEach(t => t.classList.add('in')));
}
function render() {
    if (PRO.includes(S.theme)) return renderPro();
    const lvl = cur(), n = Math.max(1, lvl.items.length), step = Math.PI * 2 / n, start = -Math.PI / 2 - step / 2;
    let s = `<defs><pattern id="carbon" width="8" height="8" patternUnits="userSpaceOnUse"><rect width="8" height="8" fill="#15161a"/><path d="M0 0h4v4H0zM4 4h4v4H4z" fill="#1d1f24"/></pattern>
      <linearGradient id="topGrad" x1="0" y1="-1" x2="0" y2="1" gradientUnits="objectBoundingBox"><stop offset="0" stop-color="#2a2e37"/><stop offset="1" stop-color="#15171c"/></linearGradient><linearGradient id="accGrad" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff9a5c"/><stop offset="1" style="stop-color:var(--accent)"/></linearGradient><linearGradient id="goldGrad" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe3a1"/><stop offset=".5" stop-color="#e7b14b"/><stop offset="1" stop-color="#9c6a1c"/></linearGradient></defs>
      <ellipse class="shadow3d" cx="0" cy="40" rx="${R_OUT + 10}" ry="${R_OUT - 10}"/><circle class="ring-outer" r="${R_OUT + 8}"/><circle class="rim" r="${R_OUT + 3}"/><circle class="ring-glow" r="${R_IN - 6}"/><g class="ticks">`, h = '';
    for (let t = 0; t < 72; t++) { const a = t / 72 * Math.PI * 2, big = t % 6 === 0, [x0, y0] = pt(R_OUT + 14, a), [x1, y1] = pt(R_OUT + (big ? 26 : 20), a); s += `<line class="${big ? 'big' : ''}" x1="${x0}" y1="${y0}" x2="${x1}" y2="${y1}"/>`; }
    s += `</g><path id="pointer" class="pointer" d="M0,${-(R_IN - 14)} l-9,16 h18z"/>`;
    lvl.items.forEach((it, i) => {
        const a0 = start + i * step, a1 = a0 + step, am = (a0 + a1) / 2, d = `${i * 22}ms`;
        const sp = slicePath(a0, a1, R_OUT, R_IN), d3 = document.body.classList.contains('t-d3');
        let dp = ''; if (d3) for (let k = 7; k >= 1; k--) dp += `<path class="depth ${k < 3 ? 'lit' : ''}" transform="translate(0 ${k * 2.2})" d="${sp}"/>`;
        s += `<g class="seg" data-i="${i}" style="--d:${d}">${dp}<path class="bg" d="${sp}"/><path class="edge" d="${edgePath(a0, a1, R_OUT - 3)}"/></g>`;
        const [x, y] = pt(R_MID, am), big = isNum(it.label);
        h += `<div class="ic" data-i="${i}" style="left:${50 + x / 6}%;top:${50 + y / 6}%;--d:${d}">
            ${i < 10 ? `<span class="k">${(i + 1) % 10}</span>` : ''}
            ${big ? `<span class="num">${esc(it.label)}</span>` : `<span class="badge"><i class="fa-solid fa-${esc(it.icon || 'circle')}"></i></span>`}
            <span class="lb">${esc(big && it.sub ? it.sub : it.label)}</span>${it.items ? '<span class="more"><i class="fa-solid fa-chevron-down" style="font-size:9px"></i></span>' : ''}</div>`;
    });
    svg.innerHTML = s; icons.innerHTML = h; S.hov = -1;
    const deep = S.stack.length > 1;
    crumb.textContent = deep ? S.stack.slice(0, -1).map(l => l.title).join(' › ') : 'ROX';
    setTitle(deep ? lvl.title : S.title); hint.textContent = `${lvl.items.length} options`;
    coreBtn.innerHTML = deep ? '<i class="fa-solid fa-arrow-left"></i>' : '<i class="fa-solid fa-xmark"></i>';
    requestAnimationFrame(() => document.querySelectorAll('.seg,.ic').forEach(t => t.classList.add('in')));
}
function setTitle(t) { title.textContent = t; title.classList.remove('pop'); void title.offsetWidth; title.classList.add('pop'); }

function hover(i) {
    if (i === S.hov) return; S.hov = i;
    document.querySelectorAll('.seg,.ic').forEach(e => e.classList.toggle('on', +e.dataset.i === i));
    const sg = document.querySelector(`.seg[data-i="${i}"]`); if (sg) sg.parentNode.appendChild(sg);
    if (PRO.includes(S.theme)) {
        const ln = $('link'), bi = $('bigic');
        if (i >= 0 && ln) { const n = cur().items.length, [x, y] = pt(S.theme === 'orbit' ? 222 : 212, -Math.PI / 2 + i * Math.PI * 2 / n); const L = Math.hypot(x, y), ux = x / L, uy = y / L; ln.setAttribute('x1', ux * 108); ln.setAttribute('y1', uy * 108); ln.setAttribute('x2', ux * (L - 52)); ln.setAttribute('y2', uy * (L - 52)); ln.classList.add('show'); }
        else if (ln) ln.classList.remove('show');
        if (bi) { const it = i >= 0 ? cur().items[i] : null; bi.innerHTML = it ? (isNum(it.label) ? `<span class="bnum">${esc(it.label)}</span>` : `<i class="fa-solid fa-${esc(it.icon || 'circle')}"></i>`) : ''; bi.classList.toggle('show', !!it); }
    }
    const pn = $('pointer'); if (pn) { if (i < 0) pn.classList.remove('show'); else { pn.style.transform = `rotate(${i * 360 / cur().items.length}deg)`; pn.classList.add('show'); } }
    const lvl = cur();
    if (i < 0) { setTitle(S.stack.length > 1 ? lvl.title : S.title); hint.textContent = `${lvl.items.length} options`; return; }
    const it = lvl.items[i]; setTitle(it.sub && isNum(it.label) ? it.sub : it.label);
    hint.textContent = it.items ? `${it.items.length} options ›` : 'Click to select'; beep(1800, .03, .02);
}
function select(i) {
    const it = cur().items[i]; if (!it) return;
    if (it.items && it.items.length) { beep(700, .1, .04, 1.4); S.stack.push({ title: it.label, items: it.items }); render(); return; }
    beep(900, .12, .05, 1.3); post('select', { id: it.id });
}
// pick slice by mouse angle (works anywhere on the ring, even between icon & edge)
function indexAt(e) {
    const r = svg.getBoundingClientRect(), x = (e.clientX - r.left) / r.width * 600 - 300, y = (e.clientY - r.top) / r.height * 600 - 300;
    const dist = Math.hypot(x, y); if (dist < R_IN - 10 || dist > R_OUT + 40) return -1;
    const n = cur().items.length, step = Math.PI * 2 / n;
    let a = Math.atan2(y, x) + Math.PI / 2 + step / 2; a = (a % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2);
    return Math.floor(a / step) % n;
}
document.addEventListener('mousemove', (e) => { if (!S.open) return; hover(indexAt(e));
    const w = $('wheel'); w.style.setProperty('--ry', ((e.clientX / innerWidth - .5) * 12).toFixed(2) + 'deg'); w.style.setProperty('--rx', ((.5 - e.clientY / innerHeight) * 8).toFixed(2) + 'deg'); });
document.addEventListener('click', (e) => { if (!S.open || e.target.closest('.core-btn') || e.target.closest('.themes')) return; const i = indexAt(e); if (i >= 0) select(i); });
coreBtn.addEventListener('click', back);
document.addEventListener('contextmenu', (e) => { e.preventDefault(); if (S.open) back(); });
document.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'Backspace') back();
    else if (/^[0-9]$/.test(e.key)) { const i = e.key === '0' ? 9 : Number(e.key) - 1; hover(i); select(i); }
    else if (e.key === 'F1' && !S.keepInput) close();
});

function setTheme(t) { S.theme = t || ''; document.body.classList.remove('t-neon', 't-gold', 't-white', 't-d3', 't-aaa', 't-orbit', 't-hex'); if (t) document.body.classList.add('t-' + t); document.querySelectorAll('.themes button').forEach(b => b.classList.toggle('on', b.dataset.t === (t || ''))); if (S.open) render(); }
function open(d) {
    setColor(d.color); setTheme(d.theme); S.title = (d.title || 'QUICK MENU'); S.sound = d.sound !== false; S.keepInput = !!d.keepInput;
    S.stack = [{ title: S.title, items: d.items || [] }]; S.open = true;
    menu.classList.add('open'); render(); beep(420, .18, .04, 2);
}
function close(fromGame) {
    if (!S.open) return; S.open = false; menu.classList.remove('open');
    if (!fromGame) post('close');
}
function back() { if (S.stack.length > 1) { S.stack.pop(); beep(600, .1, .04); render(); } else close(); }
function setColor(hex) {
    const m = /^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(hex || ''); if (!m) return;
    document.documentElement.style.setProperty('--accent', '#' + m[1] + m[2] + m[3]);
    document.documentElement.style.setProperty('--accent-rgb', [m[1], m[2], m[3]].map(x => parseInt(x, 16)).join(','));
}
window.addEventListener('message', (e) => { const d = e.data || {}; if (d.action === 'open') open(d); else if (d.action === 'close') close(true); });

/* browser preview */
if (!RES) {
    document.body.classList.add('preview');
    let u = 0; const I = (label, icon, items, sub) => ({ id: 'x' + (u++), label, icon, items, sub });
    const radio = I('Radio', 'walkie-talkie', [...Array.from({ length: 10 }, (_, k) => I(String(k + 1), '', 0, 'CH ' + (k + 1))), I('ON/OFF', 'power-off')]);
    const citizen = I('Citizen', 'user', [I('Drag', 'people-pulling'), I('Carry', 'person-falling-burst'), I('Put In Vehicle', 'right-to-bracket'),
        I('Take Out', 'right-from-bracket'), I('Stop', 'hand'), I('Give Number', 'address-book'), I('Rob', 'mask')]);
    const items = [citizen, radio, I('Emotes', 'person-walking', [I('Emote Menu', 'face-smile'), I('Hands Up', 'hand')]), I('Clothing', 'shirt', [I('Hat', 'hat-cowboy')]),
        I('Police', 'shield-halved', [I('MDT', 'shield-halved'), I('Prison', 'building-shield')]), I('GPS', 'map-location-dot'), I('Phone', 'mobile-screen'), I('Settings', 'gear')];
    const q = new URLSearchParams(location.search);
    let TH = q.get('theme') ?? 'aaa';
    document.querySelectorAll('.themes button').forEach(b => b.onclick = (e) => { e.stopPropagation(); TH = b.dataset.t; setTheme(TH); });
    setTimeout(() => { open({ title: 'QUICK MENU', items, keepInput: false, theme: TH });
        const sub = q.get('sub'); if (sub) setTimeout(() => select(+sub), 300); const hv = q.get('hover'); if (hv) setTimeout(() => hover(+hv), 700); }, 100);
    const _c = close; close = (g) => { _c(g); setTimeout(() => open({ title: 'QUICK MENU', items, theme: TH }), 600); };
}
