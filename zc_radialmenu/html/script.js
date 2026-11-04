const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const post = (name, data = {}) => {
    if (!RES) { console.log('[post]', name, data); return Promise.resolve(); }
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
};

/* geometry (520 box) */
const C = 260, R_IN = 128, R_OUT = 228, ICON_R = 178, R_ARC = 240, GAP = 1.6, DEPTH = 4;
const SVGNS = 'http://www.w3.org/2000/svg';
const $ = (id) => document.getElementById(id);
const stage = $('stage'), wheel = $('wheel'), segsEl = $('segs'), iconsEl = $('icons');
const labelEl = $('label'), crumbEl = $('crumb'), hintEl = $('hint'), closeBtn = $('closeBtn');
const needleLayer = $('needleLayer'), activeArc = $('activeArc');

const state = {
    open: false, keepInput: true, sound: true, title: 'ZC MENU',
    stack: [], hovered: -1,
    t: 0, tTarget: 0,            // open progress
    rx: 0, ry: 0, trx: 0, try: 0, // tilt
    spin: 0,                     // swap spin
    mouse: { x: 0, y: 0 },
};

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
const svgWith = (cls, inner, z) => {
    const s = document.createElementNS(SVGNS, 'svg');
    s.setAttribute('viewBox', '0 0 520 520');
    s.setAttribute('width', '520'); s.setAttribute('height', '520');
    s.setAttribute('class', cls);
    if (z) s.style.transform = `translateZ(${z}px)`;
    s.innerHTML = inner;
    return s;
};

const current = () => state.stack[state.stack.length - 1];
const step = () => 360 / Math.max(current().items.length, 1);

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
    select: () => { beep(660, 0.12, 0.05, 'sine', 1.5); setTimeout(() => beep(990, 0.14, 0.04, 'sine', 1.3), 60); },
    open: () => beep(320, 0.22, 0.05, 'sine', 2.4),
    back: () => beep(700, 0.12, 0.04, 'sine', 0.6),
};

/* ---------- render ---------- */
function setLabel(text) {
    if (labelEl.textContent === text) return;
    labelEl.textContent = text;
    labelEl.classList.remove('pop'); void labelEl.offsetWidth; labelEl.classList.add('pop');
}

function render(animate) {
    const items = current().items, n = items.length, s = step();
    segsEl.innerHTML = ''; iconsEl.innerHTML = '';
    items.forEach((it, i) => {
        const mid = i * s;
        const a0 = mid - s / 2 + (n > 1 ? GAP : 0), a1 = mid + s / 2 - (n > 1 ? GAP : 0.01);
        const rad = (mid - 90) * Math.PI / 180;
        const ox = Math.cos(rad) * 10 + 'px', oy = Math.sin(rad) * 10 + 'px';

        const seg = document.createElement('div');
        seg.className = 'seg';
        seg.style.setProperty('--ox', ox); seg.style.setProperty('--oy', oy);
        const face = sliceD(R_IN, R_OUT, a0, a1);
        for (let k = DEPTH; k >= 1; k--) seg.appendChild(svgWith(`side s${k}`, `<path d="${face}"/>`, -k * 3));
        seg.appendChild(svgWith('top', `<path class="under" d="${face}"/><path class="face" d="${face}"/><path class="edge" d="${arcD(R_OUT - 3, a0 + 1, a1 - 1)}"/>`));
        segsEl.appendChild(seg);

        const [x, y] = polar(ICON_R, mid);
        const d = document.createElement('div');
        d.className = 'icon';
        d.style.left = x + 'px'; d.style.top = y + 'px';
        d.style.setProperty('--ox', ox); d.style.setProperty('--oy', oy);
        d.innerHTML = `<i class="fa-solid fa-${it.icon || 'circle'}"></i>${it.items ? '<span class="sub"></span>' : ''}`;
        iconsEl.appendChild(d);
    });
    crumbEl.textContent = state.stack.map(l => l.title).join(' › ');
    closeBtn.innerHTML = state.stack.length > 1
        ? '<i class="fa-solid fa-arrow-left"></i>'
        : '<i class="fa-solid fa-xmark"></i>';
    state.hovered = -2;
    hover(-1, true);
    if (animate) state.spin = -40;
}

function hover(i, silent) {
    if (i === state.hovered) return;
    state.hovered = i;
    const segs = segsEl.children, icons = iconsEl.children;
    for (let k = 0; k < segs.length; k++) {
        segs[k].classList.toggle('hover', k === i);
        icons[k].classList.toggle('hover', k === i);
    }
    if (i < 0) {
        needleLayer.classList.remove('show');
        activeArc.classList.remove('show');
        setLabel(current().title);
        hintEl.textContent = `${current().items.length} options`;
        return;
    }
    if (!silent) sfx.tick();
    const s = step(), mid = i * s, it = current().items[i];
    needleLayer.style.setProperty('--na', mid + 'deg');
    needleLayer.classList.add('show');
    activeArc.setAttribute('d', arcD(R_ARC, mid - s / 2 + 3, mid + s / 2 - 3));
    activeArc.classList.add('show');
    setLabel(it.label);
    hintEl.textContent = it.items ? `◆ ${it.items.length} options` : 'click to select';
    burst(mid, 8);
}

/* ---------- input ---------- */
function polarFromEvent(e) {
    const r = stage.getBoundingClientRect();
    const dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
    let deg = Math.atan2(dy, dx) * 180 / Math.PI + 90;
    if (deg < 0) deg += 360;
    return { deg, dist: Math.hypot(dx, dy), dx, dy };
}

document.addEventListener('mousemove', (e) => {
    if (!state.open) return;
    const { deg, dist, dx, dy } = polarFromEvent(e);
    const clamp = (v) => Math.max(-1, Math.min(1, v));
    state.try = clamp(dx / 320) * 16;
    state.trx = 10 - clamp(dy / 320) * 16;
    if (dist < R_IN - 18) return hover(-1);
    const n = current().items.length;
    hover(Math.round(deg / step()) % n);
});

document.addEventListener('wheel', (e) => {
    if (!state.open) return;
    const n = current().items.length;
    const cur = state.hovered < 0 ? 0 : state.hovered;
    hover((cur + (e.deltaY > 0 ? 1 : -1) + n) % n);
});

function back() {
    if (state.stack.length > 1) { sfx.back(); state.stack.pop(); render(true); }
    else close();
}

function select() {
    const it = current().items[state.hovered];
    if (!it) return;
    sfx.select();
    burst(state.hovered * step(), 24, true);
    if (it.items && it.items.length) {
        state.stack.push({ title: it.label, items: it.items });
        render(true);
    } else {
        post('select', { id: it.id });
    }
}

document.addEventListener('mousedown', (e) => {
    if (!state.open) return;
    if (e.button === 2) return back();
    if (e.button !== 0) return;
    if (e.target.closest('#closeBtn')) return back();
    if (state.hovered >= 0) select();
});
document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener('keydown', (e) => {
    if (!state.open) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'Backspace') back();
    else if (e.key === 'Enter') select();
    else if (e.key === 'F1' && !state.keepInput) close();
});

/* ---------- particles ---------- */
const fx = $('fx'), ctx = fx.getContext('2d');
const FX = 840, FC = FX / 2, DPR = Math.min(window.devicePixelRatio || 1, 2);
fx.width = FX * DPR; fx.height = FX * DPR; ctx.scale(DPR, DPR);
let parts = [];
let accent = [255, 90, 31];

function spawn(deg, fast) {
    const a = (deg - 90) * Math.PI / 180 + (Math.random() - .5) * 0.25;
    const r = R_OUT + Math.random() * 12;
    const sp = fast ? 2.5 + Math.random() * 4 : 0.3 + Math.random() * 1.2;
    parts.push({ x: FC + Math.cos(a) * r, y: FC + Math.sin(a) * r, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
        life: 1, decay: 0.012 + Math.random() * 0.02, size: 0.8 + Math.random() * 2.2 });
}
function burst(deg, count, fast) { for (let i = 0; i < count; i++) spawn(deg, fast); }

function drawFx() {
    ctx.clearRect(0, 0, FX, FX);
    if (state.open && parts.length < 140 && Math.random() < 0.5) spawn(Math.random() * 360);
    if (state.open && state.hovered >= 0 && Math.random() < 0.7) spawn(state.hovered * step());
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

/* ---------- animation loop ---------- */
let running = false;
const ease = (x) => 1 - Math.pow(1 - x, 3);
function frame() {
    state.t += (state.tTarget - state.t) * 0.16;
    state.rx += (state.trx - state.rx) * 0.1;
    state.ry += (state.try - state.ry) * 0.1;
    state.spin += (0 - state.spin) * 0.14;
    const e = ease(Math.max(0, Math.min(1, state.t)));
    const scale = 0.55 + 0.45 * e;
    const rotZ = -50 * (1 - e) + state.spin;
    wheel.style.setProperty('--d', (0.15 + 0.85 * e).toFixed(3));
    wheel.style.transform = `rotateX(${state.rx.toFixed(2)}deg) rotateY(${state.ry.toFixed(2)}deg) rotateZ(${rotZ.toFixed(2)}deg) scale(${scale.toFixed(3)})`;
    stage.style.opacity = Math.min(1, state.t * 1.4).toFixed(3);
    drawFx();
    if (!state.open && state.t < 0.01 && parts.length === 0) {
        running = false; stage.style.opacity = 0; return;
    }
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

function open(data) {
    setColor(data.color);
    state.title = data.title || 'ZC MENU';
    state.keepInput = !!data.keepInput;
    state.sound = data.sound !== false;
    state.stack = [{ title: state.title, items: data.items || [] }];
    state.open = true; state.tTarget = 1;
    state.rx = state.trx = 10; state.ry = state.try = 0;
    render(false);
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
    const demo = [
        { id: 'p', label: 'Police', icon: 'shield-halved', items: [
            { id: 'p1', label: 'Police Radar', icon: 'satellite-dish' },
            { id: 'p2', label: 'Cuff', icon: 'handcuffs' },
            { id: 'p3', label: 'Escort', icon: 'people-arrows' },
            { id: 'p4', label: 'Search', icon: 'magnifying-glass' },
            { id: 'p5', label: 'MDT', icon: 'tablet-screen-button' },
            { id: 'p6', label: 'Spike Strip', icon: 'road-spikes' },
        ] },
        { id: 'a', label: 'Citizen', icon: 'user', items: [{ id: 'a1', label: 'Show ID', icon: 'id-card' }] },
        { id: 'b', label: 'Emotes', icon: 'person-walking' },
        { id: 'c', label: 'Clothing', icon: 'shirt' },
        { id: 'd', label: 'Vehicle', icon: 'car', items: [{ id: 'd1', label: 'Engine', icon: 'power-off' }] },
        { id: 'e', label: 'GPS', icon: 'map-location-dot' },
        { id: 'f', label: 'Phone', icon: 'mobile-screen' },
        { id: 'g', label: 'Music', icon: 'music' },
        { id: 'h', label: 'Keys', icon: 'key' },
        { id: 'i', label: 'Settings', icon: 'bars' },
    ];
    const demoOpen = () => open({ title: 'ZC MENU', items: demo, keepInput: false, sound: true });
    setTimeout(demoOpen, 100);
    const _close = close;
    close = (g) => { _close(g); setTimeout(demoOpen, 700); };
}
