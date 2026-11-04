/* ROX Store | rox_radialmenu | All rights reserved. */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
let post = (name, data = {}) => {
    if (!RES) { console.log('[post]', name, data); return Promise.resolve(); }
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
};

/* ---------- geometry (1000 box) ---------- */
const C = 500, BOX = 1000, CORE_R = 112, DEPTH = 2;
const LV = [
    { r1: 128, r2: 218, icon: 168, z: 0,  slot: null, gap: 1.4, fs: 23 },
    { r1: 230, r2: 306, icon: 268, z: 20, slot: 27,   gap: 1.1, fs: 19 },
    { r1: 318, r2: 388, icon: 353, z: 40, slot: 21,   gap: 0.9, fs: 17 },
];
const SVGNS = 'http://www.w3.org/2000/svg';
const $ = (id) => document.getElementById(id);
const stage = $('stage'), wheel = $('wheel'), ringsEl = $('rings');
const labelEl = $('label'), crumbEl = $('crumb'), hintEl = $('hint'), closeBtn = $('closeBtn'), markEl = $('mark');
const needleLayer = $('needleLayer'), chipsEl = $('chips');
const arcs = [$('activeArc'), $('activeArcGlow')];
const activeArc = {
    setAttribute: (k, v) => arcs.forEach(a => a.setAttribute(k, v)),
    classList: { add: (c) => arcs.forEach(a => a.classList.add(c)), remove: (c) => arcs.forEach(a => a.classList.remove(c)) },
};

const state = {
    open: false, keepInput: true, sound: true, title: 'ROX MENU',
    rings: [], path: [],
    t: 0, tTarget: 0, rx: 10, ry: 0, trx: 10, try: 0, scale: 1,
};

/* per-level gradients */
(() => {
    const defs = $('defs');
    LV.forEach((L, i) => {
        const o = (L.r1 / L.r2 * 100).toFixed(1);
        defs.insertAdjacentHTML('beforeend', `
            <radialGradient id="gTop${i}" cx="${C}" cy="${C}" r="${L.r2}" gradientUnits="userSpaceOnUse">
                <stop offset="${o}%" stop-color="#1b1c22"/><stop offset="100%" stop-color="#0d0e12"/>
            </radialGradient>
            <radialGradient id="gHot${i}" cx="${C}" cy="${C}" r="${L.r2}" gradientUnits="userSpaceOnUse">
                <stop offset="${o}%" stop-color="var(--accent)" stop-opacity="0.12"/><stop offset="100%" stop-color="var(--accent)" stop-opacity="0.9"/>
            </radialGradient>
            <radialGradient id="gTrail${i}" cx="${C}" cy="${C}" r="${L.r2}" gradientUnits="userSpaceOnUse">
                <stop offset="${o}%" stop-color="var(--accent)" stop-opacity="0.04"/><stop offset="100%" stop-color="var(--accent)" stop-opacity="0.3"/>
            </radialGradient>`);
    });
    const css = LV.map((_, i) => `
        .ring-${i} .top .face { fill: url(#gTop${i}); }
        .ring-${i} .seg.trail .top .face { fill: url(#gTrail${i}); }
        .ring-${i} .seg.hover .top .face { fill: url(#gHot${i}); }`).join('');
    document.head.insertAdjacentHTML('beforeend', `<style>${css}</style>`);
})();

/* ---------- helpers ---------- */
const polar = (r, deg) => {
    const a = (deg - 90) * Math.PI / 180;
    return [C + r * Math.cos(a), C + r * Math.sin(a)];
};
const arcD = (r, a0, a1) => {
    const [x0, y0] = polar(r, a0), [x1, y1] = polar(r, a1);
    return `M${x0} ${y0} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1} ${y1}`;
};
const sliceD = (r1, r2, a0, a1) => {
    const large = a1 - a0 > 180 ? 1 : 0;
    const [x0, y0] = polar(r2, a0), [x1, y1] = polar(r2, a1);
    const [x2, y2] = polar(r1, a1), [x3, y3] = polar(r1, a0);
    return `M${x0} ${y0} A${r2} ${r2} 0 ${large} 1 ${x1} ${y1} L${x2} ${y2} A${r1} ${r1} 0 ${large} 0 ${x3} ${y3}Z`;
};
const chevD = (r, deg) => {
    const [a, b] = polar(r + 6, deg), [c, d] = polar(r - 2, deg - 2.2), [e, f] = polar(r - 2, deg + 2.2);
    return `M${a} ${b} L${c} ${d} L${e} ${f}Z`;
};
const angDiff = (a, b) => { let d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d; };
const norm = (a) => ((a % 360) + 360) % 360;
// bounding box of a ring slice, so every svg is only as big as its shape
const sliceBox = (r1, r2, a0, a1, pad = 10) => {
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (let a = a0; a <= a1 + 0.001; a += Math.max(1, (a1 - a0) / 24)) {
        for (const r of [r1, r2]) {
            const [x, y] = polar(r, Math.min(a, a1));
            x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
        }
    }
    return { x: Math.floor(x0 - pad), y: Math.floor(y0 - pad), w: Math.ceil(x1 - x0 + pad * 2), h: Math.ceil(y1 - y0 + pad * 2) };
};
const svgWith = (cls, inner, z, box) => {
    const s = document.createElementNS(SVGNS, 'svg');
    box = box || { x: 0, y: 0, w: BOX, h: BOX };
    s.setAttribute('viewBox', `${box.x} ${box.y} ${box.w} ${box.h}`);
    s.setAttribute('width', box.w); s.setAttribute('height', box.h);
    s.setAttribute('class', cls);
    s.style.left = box.x + 'px'; s.style.top = box.y + 'px';
    if (z) s.style.transform = `translateZ(${z}px)`;
    s.innerHTML = inner;
    return s;
};

/* ---------- sound ---------- */
let actx = null;
function beep(freq, dur, vol, type = 'triangle', slide = 0.5) {
    if (!state.sound) return;
    try {
        actx = actx || new (window.AudioContext || window.webkitAudioContext)();
        const o = actx.createOscillator(), g = actx.createGain(), now = actx.currentTime;
        o.type = type;
        o.frequency.setValueAtTime(freq, now);
        o.frequency.exponentialRampToValueAtTime(freq * slide, now + dur);
        g.gain.setValueAtTime(vol, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
        o.connect(g).connect(actx.destination);
        o.start(now); o.stop(now + dur);
    } catch (e) {}
}
const sfx = {
    tick: () => beep(2200, 0.035, 0.03),
    expand: () => beep(900, 0.08, 0.025, 'sine', 1.4),
    select: () => { beep(660, 0.12, 0.05, 'sine', 1.5); setTimeout(() => beep(990, 0.14, 0.04, 'sine', 1.3), 60); },
    open: () => beep(320, 0.22, 0.05, 'sine', 2.4),
};

/* ---------- rings ---------- */
function buildRing(level, items, parentMid) {
    const L = LV[level], n = items.length;
    const slot = level === 0 ? 360 / n : Math.min(L.slot, 360 / n);
    const start = level === 0 ? 0 : parentMid - slot * (n - 1) / 2;
    const mids = items.map((_, i) => norm(start + i * slot));
    const full = level === 0 || slot * n >= 359;

    const el = document.createElement('div');
    el.className = `layer ring ring-${level}` + (level ? ' in' : '');
    el.style.setProperty('--z', L.z + 'px');
    el.style.setProperty('--rf', level ? '0deg' : '0deg');
    const segs = [], icons = [];

    items.forEach((it, i) => {
        const mid = start + i * slot;
        const a0 = mid - slot / 2 + (n > 1 || !full ? L.gap : 0), a1 = mid + slot / 2 - (n > 1 || !full ? L.gap : 0.01);
        const rad = (mid - 90) * Math.PI / 180;
        const push = 8 + level * 2;
        const ox = Math.cos(rad) * push + 'px', oy = Math.sin(rad) * push + 'px';

        const seg = document.createElement('div');
        seg.className = 'seg';
        seg.style.setProperty('--ox', ox); seg.style.setProperty('--oy', oy);
        const face = sliceD(L.r1, L.r2, a0, a1);
        const box = sliceBox(L.r1, L.r2, a0, a1);
        for (let k = DEPTH; k >= 1; k--) seg.appendChild(svgWith(`side s${k}`, `<path d="${face}"/>`, -k * 5, box));
        seg.appendChild(svgWith('top',
            `<path class="under" d="${face}"/><path class="face" d="${face}"/>` +
            `<path class="edge" d="${arcD(L.r2 - 3, a0 + .8, a1 - .8)}"/>` +
            (it.items && level < LV.length - 1 ? `<path class="chev" d="${chevD(L.r2 - 12, mid)}"/>` : ''), 0, box));
        el.appendChild(seg); segs.push(seg);

        const [x, y] = polar(L.icon, mid);
        const d = document.createElement('div');
        d.className = 'icon';
        d.style.left = x + 'px'; d.style.top = y + 'px';
        d.style.setProperty('--ox', ox); d.style.setProperty('--oy', oy);
        d.style.setProperty('--fs', L.fs + 'px');
        d.innerHTML = `<i class="fa-solid fa-${it.icon || 'circle'}"></i><span class="lbl">${escapeHtml(it.label)}</span>`;
        el.appendChild(d); icons.push(d);
    });

    ringsEl.appendChild(el);
    return { level, items, mids, slot, el, segs, icons };
}
const escapeHtml = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function dropRings(fromLevel) {
    while (state.rings.length > fromLevel) state.rings.pop().el.remove();
}

function itemAt(path, level) { return state.rings[level] && state.rings[level].items[path[level]]; }

function setLabel(text) {
    if (labelEl.textContent === text) return;
    labelEl.textContent = text;
    labelEl.classList.remove('pop'); void labelEl.offsetWidth; labelEl.classList.add('pop');
}

function setPath(np, silent) {
    const op = state.path;
    let d = 0;
    while (d < Math.max(op.length, np.length) && op[d] === np[d]) d++;
    if (d === op.length && d === np.length) return;

    // rebuild outer rings that belong to a changed branch
    dropRings(d + 1);
    state.path = np;
    for (let l = d; l < np.length; l++) {
        const it = itemAt(np, l);
        if (it && it.items && it.items.length && l + 1 < LV.length && !state.rings[l + 1]) {
            state.rings[l + 1] = buildRing(l + 1, it.items, state.rings[l].mids[np[l]]);
            if (!silent) sfx.expand();
        }
    }
    // the deepest hovered item might have opened a ring right now
    const last = np.length - 1;
    if (last >= 0) {
        const it = itemAt(np, last);
        if (it && it.items && it.items.length && last + 1 < LV.length && !state.rings[last + 1]) {
            state.rings[last + 1] = buildRing(last + 1, it.items, state.rings[last].mids[np[last]]);
        }
    }
    if (np.length === 0) dropRings(1);

    // classes
    state.rings.forEach((r, l) => {
        r.segs.forEach((s, i) => {
            const on = np[l] === i;
            s.classList.toggle('hover', on && l === last);
            s.classList.toggle('trail', on && l < last);
            r.icons[i].classList.toggle('hover', on && l === last);
            r.icons[i].classList.toggle('trail', on && l < last);
        });
    });

    const crumbs = np.slice(0, -1).map((idx, l) => state.rings[l].items[idx].label);
    crumbEl.textContent = crumbs.length ? crumbs.join(' › ') : state.title;

    if (last < 0) {
        needleLayer.classList.remove('show');
        activeArc.classList.remove('show');
        setLabel(state.title);
        hintEl.textContent = `${state.rings[0].items.length} sections`;
        markEl.className = 'mark fa-solid fa-' + (state.logo || 'bolt');
        return;
    }
    if (!silent) sfx.tick();
    const r = state.rings[last], it = r.items[np[last]], mid = r.mids[np[last]], L = LV[last];
    needleLayer.style.setProperty('--na', mid + 'deg');
    needleLayer.classList.add('show');
    activeArc.setAttribute('d', arcD(L.r2 + 9, mid - r.slot / 2 + 2.5, mid + r.slot / 2 - 2.5));
    activeArc.classList.add('show');
    setLabel(it.label);
    hintEl.textContent = it.items ? `◆ ${it.items.length} options` : 'click to use';
    markEl.className = 'mark fa-solid fa-' + (it.icon || 'circle');
    burst(mid, L.r2, 8);
}

/* ---------- input ---------- */
function pointer(e) {
    const rect = stage.getBoundingClientRect();
    const k = BOX / rect.width;
    const dx = (e.clientX - (rect.left + rect.width / 2)) * k, dy = (e.clientY - (rect.top + rect.height / 2)) * k;
    return { deg: norm(Math.atan2(dy, dx) * 180 / Math.PI + 90), dist: Math.hypot(dx, dy), dx, dy };
}

function hitRing(r, deg) {
    if (r.level === 0) return Math.round(deg / r.slot) % r.items.length;
    for (let i = 0; i < r.mids.length; i++) if (angDiff(deg, r.mids[i]) <= r.slot / 2) return i;
    return -1;
}

let switchTimer = null;
function cancelSwitch() { if (switchTimer) { clearTimeout(switchTimer); switchTimer = null; } }
function delaySwitch(path) {
    switchTimer = setTimeout(() => { switchTimer = null; if (state.open) setPath(path); }, 110);
}

document.addEventListener('mousemove', (e) => {
    if (!state.open) return;
    const { deg, dist, dx, dy } = pointer(e);
    const clamp = (v) => Math.max(-1, Math.min(1, v));
    state.try = clamp(dx / 450) * 12;
    state.trx = 7 - clamp(dy / 450) * 12;

    cancelSwitch();
    if (dist < CORE_R) return setPath([]);
    let level = 0;
    while (level < LV.length - 1 && dist > LV[level].r2 + 6) level++;
    level = Math.min(level, state.rings.length - 1);

    const idx = hitRing(state.rings[level], deg);
    if (level === 0) {
        if (state.path[0] === idx) return setPath(state.path.slice(0, 1));
        // a sub ring is open: switch section after a short delay, so a diagonal
        // move toward the outer ring does not jump to the neighbour section
        if (state.rings.length > 1) return delaySwitch([idx]);
        return setPath([idx]);
    }
    if (idx < 0) {
        // outside the fan: fall back to the parent ring
        const parent = state.rings[level - 1];
        const pIdx = hitRing(parent, deg);
        if (level - 1 === 0 && pIdx !== state.path[0] && angDiff(deg, parent.mids[state.path[0]]) > parent.slot) return delaySwitch([pIdx]);
        return setPath(state.path.slice(0, level));
    }
    const np = state.path.slice(0, level).concat([idx]);
    // a deeper ring is open from this level: switch with a short delay (diagonal moves)
    if (state.rings.length > level + 1 && state.path[level] !== idx && state.path.length > level) return delaySwitch(np);
    setPath(np);
});

document.addEventListener('wheel', (e) => {
    if (!state.open) return;
    const last = Math.max(0, state.path.length - 1), r = state.rings[last], n = r.items.length;
    const cur = state.path.length ? state.path[last] : 0;
    setPath(state.path.slice(0, last).concat([(cur + (e.deltaY > 0 ? 1 : -1) + n) % n]));
});

function select() {
    const last = state.path.length - 1;
    if (last < 0) return;
    const r = state.rings[last], it = r.items[state.path[last]];
    if (!it) return;
    if (it.items && it.items.length) { sfx.expand(); return; }
    sfx.select();
    burst(r.mids[state.path[last]], LV[last].r2, 30, true);
    const seg = r.segs[state.path[last]];
    seg.animate([{ filter: 'brightness(2.2)' }, { filter: 'brightness(1)' }], { duration: 300 });
    post('select', { id: it.id });
}

document.addEventListener('mousedown', (e) => {
    if (!state.open) return;
    if (e.button === 2) return close();
    if (e.button !== 0) return;
    if (e.target.closest('#closeBtn')) return close();
    select();
});
document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener('keydown', (e) => {
    if (!state.open) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'Backspace') setPath(state.path.slice(0, -1));
    else if (e.key === 'Enter') select();
    else if (e.key === 'F1' && !state.keepInput) close();
});

/* ---------- particles ---------- */
const fx = $('fx'), ctx = fx.getContext('2d');
const FX = 1200, FC = FX / 2, DPR = 1;
fx.width = FX * DPR; fx.height = FX * DPR; ctx.scale(DPR, DPR);
let parts = [], accent = [255, 90, 31];

function spawn(deg, r, fast) {
    const a = (deg - 90) * Math.PI / 180 + (Math.random() - .5) * 0.2;
    const rr = r + Math.random() * 10;
    const sp = fast ? 2.5 + Math.random() * 4 : 0.3 + Math.random() * 1.2;
    parts.push({ x: FC + Math.cos(a) * rr, y: FC + Math.sin(a) * rr, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
        life: 1, decay: 0.012 + Math.random() * 0.02, size: 0.8 + Math.random() * 2.2 });
}
function burst(deg, r, count, fast) { for (let i = 0; i < count; i++) spawn(deg, r, fast); }

function drawFx() {
    ctx.clearRect(0, 0, FX, FX);
    if (state.open && parts.length < 160 && Math.random() < 0.45) spawn(Math.random() * 360, LV[0].r2);
    const last = state.path.length - 1;
    if (state.open && last >= 0 && Math.random() < 0.7) spawn(state.rings[last].mids[state.path[last]], LV[last].r2);
    ctx.globalCompositeOperation = 'lighter';
    parts = parts.filter(p => {
        p.x += p.vx; p.y += p.vy; p.vx *= 0.985; p.vy *= 0.985; p.life -= p.decay;
        if (p.life <= 0) return false;
        const a = p.life * state.t;
        ctx.fillStyle = `rgba(${accent[0]},${accent[1]},${accent[2]},${a * 0.25})`;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.size * 3, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = `rgba(255,${180 + (accent[1] >> 2)},150,${a})`;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.size * 0.7, 0, Math.PI * 2); ctx.fill();
        return true;
    });
}

/* ---------- loop ---------- */
let running = false;
const ease = (x) => 1 - Math.pow(1 - x, 3);
function fit() { state.scale = Math.min(1.25, window.innerHeight / 1000, window.innerWidth / 1000); }
window.addEventListener('resize', fit); fit();

function frame() {
    state.t += (state.tTarget - state.t) * 0.16;
    state.rx += (state.trx - state.rx) * 0.1;
    state.ry += (state.try - state.ry) * 0.1;
    const e = ease(Math.max(0, Math.min(1, state.t)));
    wheel.style.setProperty('--d', (0.15 + 0.85 * e).toFixed(3));
    wheel.style.transform = `rotateX(${state.rx.toFixed(2)}deg) rotateY(${state.ry.toFixed(2)}deg) rotateZ(${(-50 * (1 - e)).toFixed(2)}deg) scale(${(0.55 + 0.45 * e).toFixed(3)})`;
    stage.style.transform = `scale(${state.scale})`;
    stage.style.opacity = Math.min(1, state.t * 1.4).toFixed(3);
    drawFx();
    if (!state.open && state.t < 0.01 && parts.length === 0) { running = false; stage.style.opacity = 0; return; }
    requestAnimationFrame(frame);
}
function startLoop() { if (!running) { running = true; requestAnimationFrame(frame); } }

/* ---------- open / close ---------- */
function setColor(hex) {
    const m = /^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(hex || '');
    if (!m) return;
    accent = [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)];
    document.documentElement.style.setProperty('--accent', '#' + m[1] + m[2] + m[3]);
    document.documentElement.style.setProperty('--accent-rgb', accent.join(','));
}

function renderChips(c) {
    c = c || {};
    const chips = [];
    if (c.job && c.job !== 'unemployed' && c.job !== 'none') {
        chips.push(`<div class="chip"><i class="fa-solid fa-briefcase"></i>${escapeHtml(c.jobLabel || c.job)}<span class="dot ${c.duty === false ? 'off' : ''}"></span></div>`);
    }
    chips.push(c.vehicle
        ? `<div class="chip"><i class="fa-solid fa-car"></i>${escapeHtml(c.vehicleLabel || 'Vehicle')}</div>`
        : `<div class="chip"><i class="fa-solid fa-person-walking"></i>On Foot</div>`);
    chipsEl.innerHTML = chips.join('');
}

function open(data) {
    setColor(data.color);
    state.title = data.title || 'ROX MENU';
    state.keepInput = !!data.keepInput;
    state.sound = data.sound !== false;
    dropRings(0);
    state.path = [];
    state.rings = [buildRing(0, data.items || [])];
    state.rx = state.trx = 7; state.ry = state.try = 0;
    renderChips(data.context);
    state.path = [-1];
    setPath([], true);
    state.open = true; state.tTarget = 1;
    stage.classList.add('open');
    sfx.open();
    startLoop();
}

function close(fromGame) {
    if (!state.open) return;
    state.open = false; state.tTarget = 0;
    stage.classList.remove('open');
    if (!fromGame) post('close');
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') open(d);
    else if (d.action === 'close') close(true);
});

/* ---------- browser preview (outside FiveM) ---------- */
if (!RES) {
    document.body.classList.add('preview');
    let uid = 0;
    const I = (label, icon, items) => ({ id: 'x' + (uid++), label, icon, items });
    const vehicle = I('Vehicle', 'car', [
        I('Engine', 'power-off'),
        I('Doors', 'door-open', [I('Front Left', 'door-open'), I('Front Right', 'door-open'), I('Rear Left', 'door-open'), I('Rear Right', 'door-open'), I('Hood', 'car-side'), I('Trunk', 'box-open'), I('All Doors', 'car')]),
        I('Windows', 'wind', [I('Front Left', 'wind'), I('Front Right', 'wind'), I('Rear Left', 'wind'), I('Rear Right', 'wind'), I('All', 'wind')]),
        I('Seats', 'chair', [I('Driver', 'gauge-high'), I('Passenger', 'user'), I('Rear Left', 'user'), I('Rear Right', 'user')]),
        I('Lights', 'lightbulb'), I('Lock', 'lock'), I('Give Keys', 'key'),
    ]);
    const police = I('Police', 'shield-halved', [
        I('Citizen', 'person', [I('Cuff', 'handcuffs'), I('Escort', 'people-arrows'), I('Search', 'magnifying-glass'), I('Put In Vehicle', 'right-to-bracket'), I('Take Out', 'right-from-bracket'), I('Fine', 'file-invoice-dollar'), I('Jail', 'building-shield')]),
        I('Objects', 'road-barrier', [I('Cone', 'traffic-light'), I('Barrier', 'road-barrier'), I('Spikes', 'road-spikes'), I('Remove', 'trash')]),
        I('Vehicle', 'car-side', [I('Impound', 'truck-pickup'), I('Plate Check', 'rectangle-list'), I('Radar', 'satellite-dish')]),
        I('MDT', 'tablet-screen-button'), I('Backup', 'tower-broadcast'), I('Duty', 'user-shield'),
    ]);
    const common = [
        I('Citizen', 'user', [I('Show ID', 'id-card'), I('Give Number', 'address-book'), I('Carry', 'people-carry-box'), I('Rob', 'mask')]),
        I('Emotes', 'person-walking', [I('Emote Menu', 'face-smile'), I('Hands Up', 'hand'), I('Sit', 'chair'), I('Cancel', 'ban')]),
        I('Clothing', 'shirt', [I('Hat', 'hat-cowboy'), I('Mask', 'masks-theater'), I('Glasses', 'glasses'), I('Shirt', 'shirt'), I('Pants', 'socks'), I('Shoes', 'shoe-prints')]),
        I('GPS', 'map-location-dot'), I('Phone', 'mobile-screen'), I('Settings', 'gear'),
    ];
    const q = new URLSearchParams(location.search);
    const job = q.get('job') ?? 'police', inVeh = q.get('veh') !== '0';
    const items = [].concat(inVeh ? [vehicle] : [], job === 'police' ? [police] : [], common, inVeh ? [] : [I('Flip Vehicle', 'rotate')]);
    const demoOpen = () => open({ title: 'ROX MENU', items, keepInput: false, sound: true,
        context: { job, jobLabel: job === 'police' ? 'LSPD' : job, duty: true, vehicle: inVeh, vehicleLabel: 'Police Cruiser' } });
    setTimeout(demoOpen, 100);
    const _close = close;
    close = (g) => { _close(g); setTimeout(demoOpen, 700); };
}
