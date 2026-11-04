const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const post = (name, data = {}) => {
    if (!RES) { console.log('[post]', name, data); return Promise.resolve(); }
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
};

const C = 230, R_OUT = 208, R_IN = 124, ICON_R = 166, R_ARC = 214;
const $ = (id) => document.getElementById(id);
const wheel = $('wheel'), segG = $('segments'), iconsEl = $('icons');
const labelEl = $('label'), crumbEl = $('crumb'), closeBtn = $('closeBtn');
const needle = $('needle'), activeArc = $('activeArc');

let state = { open: false, title: 'ZC MENU', keepInput: true, stack: [], hovered: -1 };

const polar = (r, deg) => {
    const a = (deg - 90) * Math.PI / 180;
    return [C + r * Math.cos(a), C + r * Math.sin(a)];
};
const arc = (r, a0, a1) => {
    const [x0, y0] = polar(r, a0), [x1, y1] = polar(r, a1);
    return `M${x0} ${y0} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1} ${y1}`;
};
const slice = (r1, r2, a0, a1) => {
    const large = a1 - a0 > 180 ? 1 : 0;
    const [x0, y0] = polar(r2, a0), [x1, y1] = polar(r2, a1);
    const [x2, y2] = polar(r1, a1), [x3, y3] = polar(r1, a0);
    return `M${x0} ${y0} A${r2} ${r2} 0 ${large} 1 ${x1} ${y1} L${x2} ${y2} A${r1} ${r1} 0 ${large} 0 ${x3} ${y3}Z`;
};

const current = () => state.stack[state.stack.length - 1];
const step = () => 360 / Math.max(current().items.length, 1);

function setLabel(text) {
    if (labelEl.textContent === text) return;
    labelEl.textContent = text;
    labelEl.classList.remove('pop'); void labelEl.offsetWidth; labelEl.classList.add('pop');
}

function render(animate) {
    const level = current();
    const items = level.items, n = items.length, s = step();
    segG.innerHTML = ''; iconsEl.innerHTML = '';
    items.forEach((it, i) => {
        const mid = i * s, a0 = mid - s / 2, a1 = mid + s / 2 - (n === 1 ? 0.01 : 0);
        const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        p.setAttribute('d', slice(R_IN, R_OUT, a0, a1));
        p.setAttribute('class', 'seg');
        segG.appendChild(p);

        const [x, y] = polar(ICON_R, mid);
        const d = document.createElement('div');
        d.className = 'icon';
        d.style.left = x + 'px'; d.style.top = y + 'px';
        d.innerHTML = `<i class="fa-solid fa-${it.icon || 'circle'}"></i>${it.items ? '<span class="sub"></span>' : ''}`;
        iconsEl.appendChild(d);
    });
    crumbEl.textContent = state.stack.map(l => l.title).join(' › ');
    closeBtn.innerHTML = state.stack.length > 1
        ? '<i class="fa-solid fa-arrow-left"></i>'
        : '<i class="fa-solid fa-xmark"></i>';
    state.hovered = -1;
    hover(-1);
    if (animate) { wheel.classList.remove('swap'); void wheel.offsetWidth; wheel.classList.add('swap'); }
}

function hover(i) {
    state.hovered = i;
    const segs = segG.children, icons = iconsEl.children;
    for (let k = 0; k < segs.length; k++) {
        segs[k].classList.toggle('hover', k === i);
        icons[k].classList.toggle('hover', k === i);
    }
    if (i < 0) {
        needle.classList.remove('show');
        activeArc.classList.remove('show');
        setLabel(current().title);
        return;
    }
    const s = step(), mid = i * s;
    needle.style.transform = `rotate(${mid}deg)`;
    needle.classList.add('show');
    activeArc.setAttribute('d', arc(R_ARC, mid - s / 2 + 3, mid + s / 2 - 3));
    activeArc.classList.add('show');
    setLabel(current().items[i].label);
}

function angleFromEvent(e) {
    const r = wheel.getBoundingClientRect();
    const dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
    const dist = Math.hypot(dx, dy) * (460 / r.width);
    let deg = Math.atan2(dy, dx) * 180 / Math.PI + 90;
    if (deg < 0) deg += 360;
    return { deg, dist };
}

document.addEventListener('mousemove', (e) => {
    if (!state.open) return;
    const { deg, dist } = angleFromEvent(e);
    if (dist < R_IN - 14) { if (state.hovered !== -1) hover(-1); return; }
    const s = step(), n = current().items.length;
    const i = Math.round(deg / s) % n;
    if (i !== state.hovered) hover(i);
});

function back() {
    if (state.stack.length > 1) { state.stack.pop(); render(true); }
    else close();
}

function select() {
    const it = current().items[state.hovered];
    if (!it) return;
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
    else if (e.key === 'F1' && !state.keepInput) close();
});

function open(data) {
    if (data.color) document.documentElement.style.setProperty('--accent', data.color);
    state.title = data.title || 'ZC MENU';
    state.keepInput = !!data.keepInput;
    state.stack = [{ title: state.title, items: data.items || [] }];
    state.open = true;
    render(false);
    wheel.classList.add('open');
}

function close(fromGame) {
    state.open = false;
    wheel.classList.remove('open');
    if (!fromGame) post('close');
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') open(d);
    else if (d.action === 'close') close(true);
});

/* Browser preview (outside FiveM) */
if (!RES) {
    document.body.classList.add('preview');
    const demo = [
        { id: 'p', label: 'Police', icon: 'shield-halved', items: [
            { id: 'p1', label: 'Police Radar', icon: 'satellite-dish' },
            { id: 'p2', label: 'Cuff', icon: 'handcuffs' },
            { id: 'p3', label: 'Escort', icon: 'people-arrows' },
            { id: 'p4', label: 'Search', icon: 'magnifying-glass' },
            { id: 'p5', label: 'MDT', icon: 'tablet-screen-button' },
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
    setTimeout(() => open({ title: 'ZC MENU', items: demo, keepInput: false }), 100);
    window.__reopen = () => setTimeout(() => open({ title: 'ZC MENU', items: demo }), 50);
    const _close = close;
    close = (g) => { _close(g); window.__reopen(); };
}
