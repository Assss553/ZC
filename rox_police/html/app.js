/* ROX Store | rox_police | All rights reserved. */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const $ = (s, r = document) => r.querySelector(s);
const root = $('#root'), backdrop = $('#backdrop');

/* ---------- utils ---------- */
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '$' + Math.round(n || 0).toLocaleString('en-US');
const initials = (n) => String(n || '?').trim().split(/\s+/).slice(0, 2).map(w => w[0] || '').join('').toUpperCase() || '?';
const fmtDur = (sec) => {
    sec = Math.max(0, Math.round(sec));
    const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
    return h ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
};
const ago = (t) => {
    const d = Math.max(0, Date.now() / 1000 - t);
    if (d < 60) return 'just now';
    if (d < 3600) return Math.floor(d / 60) + 'm ago';
    if (d < 86400) return Math.floor(d / 3600) + 'h ago';
    return Math.floor(d / 86400) + 'd ago';
};
const fmtDate = (t) => new Date(t * 1000).toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });

/* ---------- server ---------- */
async function call(action, data = {}) {
    if (!RES) return Mock.call(action, data);
    try {
        const r = await fetch(`https://${RES}/req`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify({ action, data }) });
        return await r.json();
    } catch (e) { return { ok: false, msg: 'Request failed' }; }
}
function post(name, data = {}) {
    if (!RES) return;
    fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
}

/* ---------- toasts ---------- */
const TOAST = { success: ['circle-check', 'var(--ok)'], error: ['circle-xmark', 'var(--bad)'], warning: ['triangle-exclamation', 'var(--warn)'], info: ['circle-info', 'var(--info)'] };
function toast(msg, kind = 'info') {
    const [ic, c] = TOAST[kind] || TOAST.info;
    const el = document.createElement('div');
    el.className = 'toast'; el.style.setProperty('--tc', c);
    el.innerHTML = `<i class="fa-solid fa-${ic}"></i><div>${esc(msg)}</div>`;
    $('#toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 260); }, 4200);
}
const result = (r, okMsg) => { if (r && r.ok) toast(r.msg || okMsg || 'Done', 'success'); else toast((r && r.msg) || 'Failed', 'error'); return r && r.ok; };

/* ---------- app state ---------- */
const App = { open: false, panel: null, prev: null, init: null };
let H = {}; // current click/input handlers

function setColor(hex) {
    const m = /^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(hex || '');
    if (!m) return;
    document.documentElement.style.setProperty('--accent', '#' + m[1] + m[2] + m[3]);
    document.documentElement.style.setProperty('--accent-rgb', [m[1], m[2], m[3]].map(x => parseInt(x, 16)).join(','));
}

function header(eyebrow, title, icon, extra = '') {
    const o = App.init && App.init.officer || {};
    return `<div class="ph">
        ${App.prev ? `<div class="icon-btn" data-a="back" title="Back"><i class="fa-solid fa-arrow-left"></i></div>` : (App.tablet ? `<div class="icon-btn" data-a="home" title="Home"><i class="fa-solid fa-house"></i></div>` : '')}
        <div class="ico"><i class="fa-solid fa-${icon}"></i></div>
        <div class="tt"><div class="eyebrow">${eyebrow}</div><div class="title">${title}</div></div>
        ${extra}
        <div class="officer"><span class="dot"></span><b>${esc(o.name || 'Officer')}</b>${o.grade ? ' · ' + esc(o.grade) : ''}</div>
        <div class="icon-btn x" data-a="close"><i class="fa-solid fa-xmark"></i></div>
    </div>`;
}

const TABLET = new Set(['home', 'mdt', 'jail', 'fine', 'boss', 'settings']);
const PANELS = () => ({ home: Home, jail: Jail, fine: Fine, mdt: MDT, boss: Boss, impound: Impound, strip: Strip, settings: SettingsApp });

function openPanel(name, opts = {}, fromPanel) {
    if (name === 'boss' && App.init && !App.init.boss) { toast('Management only (Captain and above)', 'error'); return; }
    App.prev = fromPanel || null;
    App.panel = name;
    App.tablet = TABLET.has(name);
    const P = PANELS()[name];
    P && P.reset && P.reset(opts);
    render();
}
/* iPad settings (saved per player in NUI storage) */
const WALLPAPERS = ['img/wallpapers/street.jpg', 'img/wallpapers/forest.jpg', 'img/wallpapers/pond.jpg'];
const Settings = { wallpaper: null, scale: 1 };
try { Object.assign(Settings, JSON.parse(localStorage.getItem('rox_police_ipad') || '{}')); } catch (e) { /* storage unavailable */ }
const saveSettings = () => { try { localStorage.setItem('rox_police_ipad', JSON.stringify(Settings)); } catch (e) { /* storage unavailable */ } };
function applySettings() {
    const scr = $('#screen'), bz = $('.bezel');
    if (scr) scr.style.setProperty('--wall', `url("${(Settings.wallpaper || WALLPAPERS[0]).replace(/"/g, '')}")`);
    if (bz) bz.style.setProperty('--scale', Settings.scale || 1);
}
function tabletFrame() {
    return `<div class="tablet"><div class="bezel">
        <span class="screw s1"></span><span class="screw s2"></span><span class="screw s3"></span><span class="screw s4"></span>
        <span class="cam"></span>
        <span class="side-btn b1"></span><span class="side-btn b2"></span><span class="side-btn b3"></span><span class="side-btn b4"></span>
        <div class="screen" id="screen">
            <div class="app-layer"></div>
            <div class="statusbar"><span id="sbTime"></span><span class="sb-brand">ROX STORE</span>
                <span class="sb-icons"><i class="fa-solid fa-signal"></i><i class="fa-solid fa-wifi"></i><span class="battery"><i></i></span></span></div>
            <div class="app" id="app"></div>
            <div class="homebar" data-a="home"></div>
        </div>
    </div></div>`;
}
function render() {
    const P = PANELS()[App.panel];
    if (!P) return;
    if (App.tablet) {
        if (!root.querySelector('.tablet')) {
            root.innerHTML = tabletFrame();
            clearInterval(App.sbTick);
            const sb = () => { const e = $('#sbTime'); if (e) e.textContent = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }); };
            sb(); App.sbTick = setInterval(sb, 5000);
            applySettings();
        }
        $('#screen').classList.toggle('in-app', App.panel !== 'home');
        $('#app').innerHTML = P.html();
    } else {
        root.innerHTML = P.html();
    }
    backdrop.classList.toggle('show', App.tablet);
    H = P.handlers;
    P.after && P.after();
}
function closeAll(fromGame) {
    App.open = false; App.panel = null; App.tablet = false;
    root.innerHTML = ''; backdrop.classList.remove('show');
    clearInterval(App.tick); clearInterval(App.sbTick);
    if (!fromGame) post('close');
}
function goBack() { const p = App.prev; App.prev = null; App.panel = p; App.tablet = TABLET.has(p); render(); if (p === 'mdt') MDT.load(); if (p === 'boss') Boss.load(); }
function goHome() { App.prev = null; openPanel('home'); }

root.addEventListener('click', (e) => {
    const a = e.target.closest('[data-a]');
    if (!a) { if (!e.target.closest('.dd') && !e.target.closest('[data-a="nearby"]')) document.querySelectorAll('.dd').forEach(d => d.remove()); return; }
    const k = a.dataset.a;
    if (k === 'close') return closeAll();
    if (k === 'back') return goBack();
    if (k === 'home') return goHome();
    if (k === 'app') { const p = a.dataset.p, pg = a.dataset.page; if (p === 'mdt' && pg) { openPanel('mdt', { page: pg }); return; } return openPanel(p); }
    H[k] && H[k](a, e);
});
root.addEventListener('input', (e) => { const k = e.target.dataset.in; if (k && H['in:' + k]) H['in:' + k](e.target, e); });
root.addEventListener('keydown', (e) => { const k = e.target.dataset.enter; if (k && e.key === 'Enter' && !e.shiftKey && H[k]) { e.preventDefault(); H[k](e.target, e); } });
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && App.open) {
        if (document.querySelector('.dd')) return document.querySelectorAll('.dd').forEach(d => d.remove());
        if (document.querySelector('.modal-back')) return document.querySelector('.modal-back').remove();
        if (App.prev) return goBack();
        if (App.tablet && App.panel !== 'home') return goHome();
        closeAll();
    }
});

/* ---------- shared components ---------- */
function toggleRow(key, on, title, sub) {
    return `<div class="toggle-row ${on ? 'on' : ''}" data-a="${key}"><div class="t"><b>${title}</b><span>${sub}</span></div><div class="switch"></div></div>`;
}

// target player field with Nearby
function targetField(S, label = 'Server ID') {
    return `<div class="field">
        <div class="lbl"><span>${label}<span class="req">*</span></span></div>
        <div class="row" style="position:relative">
            <div class="input grow"><i class="fa-solid fa-user"></i><input type="number" placeholder="Player server ID" value="${esc(S.id)}" data-in="id"></div>
            <button class="btn" data-a="nearby"><i class="fa-solid fa-location-crosshairs"></i> NEARBY</button>
        </div>
        <div id="personSlot">${personCard(S.person)}</div>
        <div class="help">Enter the server ID of the player, or pick someone close to you.</div>
    </div>`;
}
function personCard(p) {
    if (!p) return '';
    if (!p.ok) return `<div class="person-card bad"><div class="avatar"><i class="fa-solid fa-user-slash"></i></div><div class="who"><b>Player not found</b><span>Check the server ID</span></div></div>`;
    return `<div class="person-card ${p.warrants ? 'bad' : ''}">
        <div class="avatar">${initials(p.name)}</div>
        <div class="who"><b>${esc(p.name)}</b><span>${esc(p.cid)}</span></div>
        ${p.warrants ? `<span class="badge bad"><i class="fa-solid fa-triangle-exclamation"></i>${p.warrants} warrant${p.warrants > 1 ? 's' : ''}</span>` : ''}
        ${p.jailed ? `<span class="badge accent">In prison</span>` : ''}
        ${(p.flags || []).map(f => `<span class="badge warn">${esc(f)}</span>`).join('')}
    </div>`;
}
let lookupTimer = null;
function bindTarget(S) {
    H['in:id'] = (el) => {
        S.id = el.value; S.person = null;
        $('#personSlot').innerHTML = '';
        clearTimeout(lookupTimer);
        if (!S.id) return;
        lookupTimer = setTimeout(async () => { S.person = await call('player', { id: Number(S.id) }); const slot = $('#personSlot'); if (slot) slot.innerHTML = personCard(S.person); }, 300);
    };
    H.nearby = async (btn) => {
        document.querySelectorAll('.dd').forEach(d => d.remove());
        const list = await call('nearby');
        const dd = document.createElement('div');
        dd.className = 'dd';
        dd.innerHTML = (list && list.length) ? list.map(p => `<div class="it" data-a="pick" data-id="${p.id}"><div class="avatar">${initials(p.name)}</div><div class="who"><b>${esc(p.name)}</b><span>ID ${p.id} · ${p.dist}m</span></div><span class="badge">${p.id}</span></div>`).join('')
            : `<div class="empty"><i class="fa-solid fa-user-slash"></i> Nobody nearby</div>`;
        btn.parentElement.appendChild(dd);
    };
    H.pick = (el) => {
        const inp = root.querySelector('[data-in="id"]');
        inp.value = el.dataset.id;
        document.querySelectorAll('.dd').forEach(d => d.remove());
        H['in:id'](inp);
    };
}

// charge picker
function pickerHtml(S, mode) {
    const charges = (App.init && App.init.charges) || [];
    const cats = ['All'].concat([...new Set(charges.map(c => c.cat))]);
    const q = S.q.toLowerCase();
    const list = charges.filter(c => (S.cat === 'All' || c.cat === S.cat) && (!q || c.label.toLowerCase().includes(q)));
    const sel = [...S.charges];
    return `<div class="picker">
        <div class="top">
            <div class="input"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Search ${mode === 'fine' ? 'violations' : 'charges'}..." value="${esc(S.q)}" data-in="cq"></div>
            <div class="cats">${cats.map(c => `<div class="c ${S.cat === c ? 'on' : ''}" data-a="cat" data-c="${esc(c)}">${esc(c)}</div>`).join('')}</div>
        </div>
        <div class="list" id="chList">${list.map(c => `<div class="ch ${S.charges.has(c.label) ? 'on' : ''}" data-a="ch" data-l="${esc(c.label)}">
            <div class="box"><i class="fa-solid fa-check"></i></div>
            <div class="n">${esc(c.label)}<small>${esc(c.cat)}</small></div>
            ${mode === 'jail' ? `<div class="tm">${c.time ? c.time + ' MIN' : '—'}</div>` : ''}
            <div class="m">${money(c.fine)}</div>
        </div>`).join('') || `<div class="empty-state" style="padding:20px">No results</div>`}</div>
        <div class="sel">${sel.length ? sel.map(l => `<span class="chip on" data-a="ch" data-l="${esc(l)}">${esc(l)} <i class="fa-solid fa-xmark x"></i></span>`).join('') : `<span class="none">Nothing selected</span>`}</div>
    </div>`;
}
function totals(S) {
    const charges = (App.init && App.init.charges) || [];
    let fine = 0, time = 0;
    for (const c of charges) if (S.charges.has(c.label)) { fine += c.fine || 0; time += c.time || 0; }
    return { fine, time, n: S.charges.size };
}
function bindPicker(S, mode, onChange) {
    const redraw = () => {
        const p = root.querySelector('.picker');
        const scroll = p && p.querySelector('.list').scrollTop;
        const focus = document.activeElement && document.activeElement.dataset.in === 'cq';
        p.outerHTML = pickerHtml(S, mode);
        const np = root.querySelector('.picker');
        np.querySelector('.list').scrollTop = scroll || 0;
        if (focus) { const i = np.querySelector('[data-in="cq"]'); i.focus(); i.setSelectionRange(i.value.length, i.value.length); }
        onChange && onChange();
    };
    H.cat = (el) => { S.cat = el.dataset.c; redraw(); };
    H.ch = (el) => { const l = el.dataset.l; S.charges.has(l) ? S.charges.delete(l) : S.charges.add(l); redraw(); };
    H['in:cq'] = (el) => { S.q = el.value; redraw(); };
}

/* =====================================================================
   PRISON MANAGEMENT
   ===================================================================== */
const Jail = {
    S: null,
    reset(o) {
        const types = (App.init && App.init.jailTypes) || [];
        this.S = { tab: o.tab || 'new', type: (types[0] || {}).key || 'prison', id: o.id ? String(o.id) : '', person: null, life: false, minutes: '', touched: false,
            charges: new Set(), q: '', cat: 'All', extra: '', bail: false, bailAmount: '', chargeFine: true, list: [], listQ: '' };
        if (o.id) call('player', { id: Number(o.id) }).then(p => { this.S.person = p; const s = $('#personSlot'); if (s) s.innerHTML = personCard(p); });
    },
    html() {
        const S = this.S, I = App.init || {};
        const tabs = `<div class="tabs">
            <div class="tab ${S.tab === 'new' ? 'on' : ''}" data-a="tab" data-t="new"><i class="fa-solid fa-user-plus"></i> New Prisoner</div>
            <div class="tab ${S.tab === 'list' ? 'on' : ''}" data-a="tab" data-t="list"><i class="fa-solid fa-users"></i> Prisoner List ${S.list.length ? `<span class="count">${S.list.length}</span>` : ''}</div>
        </div>`;
        let body, foot = '';
        if (S.tab === 'new') {
            const t = totals(S);
            body = `
                <div class="field"><div class="lbl"><span>Service Type<span class="req">*</span></span></div>
                    <div class="seg-pick">${(I.jailTypes || []).map(j => `<div class="opt ${S.type === j.key ? 'on' : ''}" data-a="type" data-k="${j.key}"><i class="fa-solid fa-${j.icon || 'building'}"></i>${esc(j.label)}</div>`).join('')}</div>
                </div>
                ${targetField(S)}
                <div class="field">${toggleRow('life', S.life, '<i class="fa-solid fa-infinity" style="color:var(--accent);margin-right:6px"></i>Life Sentence', 'Check this if the prisoner is receiving a life sentence')}</div>
                <div class="field" id="durField" style="${S.life ? 'display:none' : ''}">
                    <div class="lbl"><span>Sentence Duration<span class="req">*</span></span><span id="autoHint" class="dim" style="letter-spacing:0;text-transform:none;font-weight:600">${t.time && !S.touched ? 'auto from charges' : ''}</span></div>
                    <div class="input"><i class="fa-solid fa-clock"></i><input type="number" min="1" max="${I.maxMinutes || 300}" placeholder="Minutes" value="${esc(S.minutes || (S.touched ? '' : (t.time || '')))}" data-in="min"><span class="suffix">MIN</span></div>
                    <div class="stepper">${(I.presets || []).map(p => `<span class="chip" data-a="preset" data-v="${p}">${p} min</span>`).join('')}</div>
                    <div class="help">Specify the sentence duration in minutes (max ${I.maxMinutes || 300}).</div>
                </div>
                <div class="field"><div class="lbl"><span>Charges</span></div>${pickerHtml(S, 'jail')}
                    <div class="help">List the charges the player is being sentenced for.</div></div>
                <div class="field"><div class="lbl"><span>Extra Details</span></div>
                    <div class="input"><textarea placeholder="Evidence, items seized, notes..." data-in="extra">${esc(S.extra)}</textarea></div></div>
                <div class="field">${toggleRow('bail', S.bail, '<i class="fa-solid fa-scale-balanced" style="color:var(--accent);margin-right:6px"></i>Allow Bail', 'Prisoner can pay bail to be released early')}
                    <div class="input" id="bailInput" style="margin-top:8px;${S.bail && !S.life ? '' : 'display:none'}"><i class="fa-solid fa-dollar-sign"></i><input type="number" placeholder="Bail amount" value="${esc(S.bailAmount)}" data-in="bailAmount"></div></div>
                <div class="field" style="margin-bottom:0">${toggleRow('chargeFine', S.chargeFine, '<i class="fa-solid fa-money-bill-wave" style="color:var(--accent);margin-right:6px"></i>Charge Court Fine', 'Take the total fine of the charges from the player')}</div>`;
            foot = `<div class="pf"><div class="summary" id="sum">${this.sumHtml()}</div>
                <button class="btn primary block" data-a="send"><i class="fa-solid fa-lock"></i> Send to Prison</button></div>`;
        } else {
            const q = S.listQ.toLowerCase();
            const rows = S.list.filter(p => !q || p.name.toLowerCase().includes(q) || String(p.cid).toLowerCase().includes(q));
            body = `<div class="search-bar"><div class="input grow"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Search prisoners..." value="${esc(S.listQ)}" data-in="listQ"></div>
                <button class="btn" data-a="refresh"><i class="fa-solid fa-rotate"></i></button></div>
                <div class="list-rows">${rows.map(p => `<div class="rowcard">
                    <div class="avatar">${initials(p.name)}</div>
                    <div class="who"><b>${esc(p.name)}</b><span>${esc(p.cid)} · by ${esc(p.officer)} · ${ago(p.at)}</span>
                        <div class="meta"><span class="badge accent">${esc(p.typeLabel)}</span>${p.online ? '<span class="badge ok">online</span>' : '<span class="badge">offline</span>'}
                        ${(p.charges || []).slice(0, 2).map(c => `<span class="badge">${esc(c)}</span>`).join('')}${(p.charges || []).length > 2 ? `<span class="badge">+${p.charges.length - 2}</span>` : ''}
                        ${p.bail ? `<span class="badge ok">bail ${money(p.bail)}</span>` : ''}</div></div>
                    <div class="right">${p.life ? '<span class="big-num" style="color:var(--bad)">LIFE</span>' : `<span class="big-num" data-remain="${p.remaining}">${fmtDur(p.remaining)}</span><div class="progress"><i style="width:${Math.max(0, 100 - p.remaining / p.total * 100)}%"></i></div>`}
                        <button class="btn sm ok" data-a="release" data-cid="${esc(p.cid)}"><i class="fa-solid fa-lock-open"></i> Release</button></div>
                </div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-building-shield"></i>No prisoners right now</div>`}</div>`;
        }
        return `<div class="panel form">${header('Detention &amp; Corrections System', 'Prison Management', 'building-shield')}${tabs}<div class="pb">${body}</div>${foot}</div>`;
    },
    sumHtml() {
        const S = this.S, t = totals(S);
        const min = S.life ? 'LIFE' : (Number(S.minutes) || (!S.touched ? t.time : 0) || 0) + ' min';
        return `<div class="sum"><span>Sentence</span><b class="t">${min}</b></div>
            <div class="sum"><span>Court Fine</span><b class="m">${S.chargeFine ? money(t.fine) : '—'}</b></div>
            <div class="sum"><span>Charges</span><b class="a">${t.n}</b></div>`;
    },
    refreshSum() {
        const S = this.S, t = totals(S);
        const sum = $('#sum'); if (sum) sum.innerHTML = this.sumHtml();
        if (!S.touched) { const i = root.querySelector('[data-in="min"]'); if (i) i.value = t.time || ''; const h = $('#autoHint'); if (h) h.textContent = t.time ? 'auto from charges' : ''; }
    },
    async loadList() { this.S.list = await call('prisoners') || []; if (App.panel === 'jail') render(); },
    after() {
        const S = this.S;
        bindTarget(S);
        bindPicker(S, 'jail', () => this.refreshSum());
        clearInterval(App.tick);
        if (S.tab === 'list') {
            App.tick = setInterval(() => root.querySelectorAll('[data-remain]').forEach(el => { const v = Math.max(0, Number(el.dataset.remain) - 1); el.dataset.remain = v; el.textContent = fmtDur(v); }), 1000);
        }
    },
    handlers: {},
};
Object.assign(Jail.handlers, {
    tab(el) { Jail.S.tab = el.dataset.t; render(); if (Jail.S.tab === 'list') Jail.loadList(); },
    type(el) { Jail.S.type = el.dataset.k; root.querySelectorAll('.seg-pick .opt').forEach(o => o.classList.toggle('on', o === el)); },
    life(el) { const S = Jail.S; S.life = !S.life; el.classList.toggle('on', S.life); $('#durField').style.display = S.life ? 'none' : ''; $('#bailInput').style.display = S.bail && !S.life ? '' : 'none'; Jail.refreshSum(); },
    bail(el) { const S = Jail.S; S.bail = !S.bail; el.classList.toggle('on', S.bail); $('#bailInput').style.display = S.bail && !S.life ? '' : 'none'; },
    chargeFine(el) { const S = Jail.S; S.chargeFine = !S.chargeFine; el.classList.toggle('on', S.chargeFine); Jail.refreshSum(); },
    preset(el) { const S = Jail.S; S.minutes = el.dataset.v; S.touched = true; root.querySelector('[data-in="min"]').value = S.minutes; $('#autoHint').textContent = ''; Jail.refreshSum(); },
    'in:min'(el) { Jail.S.minutes = el.value; Jail.S.touched = el.value !== ''; $('#autoHint').textContent = ''; Jail.refreshSum(); },
    'in:extra'(el) { Jail.S.extra = el.value; },
    'in:bailAmount'(el) { Jail.S.bailAmount = el.value; },
    'in:listQ'(el) { Jail.S.listQ = el.value; render(); const i = root.querySelector('[data-in="listQ"]'); i.focus(); i.setSelectionRange(i.value.length, i.value.length); },
    refresh() { Jail.loadList(); },
    async release(el) { if (result(await call('release', { cid: el.dataset.cid }))) Jail.loadList(); },
    async send(btn) {
        const S = Jail.S, t = totals(S);
        const minutes = Number(S.minutes) || (!S.touched ? t.time : 0);
        if (!S.id) return toast('Enter the server ID', 'error');
        if (!S.life && !minutes) return toast('Enter the sentence duration', 'error');
        btn.classList.add('loading'); btn.disabled = true; btn.innerHTML = '<i class="fa-solid fa-circle-notch"></i> Sending...';
        const r = await call('jail', { id: Number(S.id), type: S.type, minutes, life: S.life, charges: [...S.charges], extra: S.extra, bail: S.bail, bailAmount: Number(S.bailAmount) || 0, chargeFine: S.chargeFine });
        if (result(r)) { Jail.reset({ tab: 'list' }); render(); Jail.loadList(); }
        else { btn.classList.remove('loading'); btn.disabled = false; btn.innerHTML = '<i class="fa-solid fa-lock"></i> Send to Prison'; }
    },
});

/* =====================================================================
   CITATIONS
   ===================================================================== */
const Fine = {
    S: null,
    reset(o) {
        this.S = { tab: o.tab || 'new', id: o.id ? String(o.id) : '', person: null, plate: o.plate || '', charges: new Set(), q: '', cat: 'All', notes: '', list: [], listQ: '' };
        if (o.id) call('player', { id: Number(o.id) }).then(p => { this.S.person = p; const s = $('#personSlot'); if (s) s.innerHTML = personCard(p); });
    },
    html() {
        const S = this.S;
        const tabs = `<div class="tabs">
            <div class="tab ${S.tab === 'new' ? 'on' : ''}" data-a="tab" data-t="new"><i class="fa-solid fa-file-pen"></i> New Citation</div>
            <div class="tab ${S.tab === 'list' ? 'on' : ''}" data-a="tab" data-t="list"><i class="fa-solid fa-clock-rotate-left"></i> History</div>
        </div>`;
        let body, foot = '';
        if (S.tab === 'new') {
            body = `${targetField(S)}
                <div class="field"><div class="lbl"><span>Vehicle Plate</span><span class="dim" style="letter-spacing:0;text-transform:none;font-weight:600">optional</span></div>
                    <div class="row"><div class="input grow"><i class="fa-solid fa-car"></i><input placeholder="e.g. 20HRX818" value="${esc(S.plate)}" data-in="plate" style="text-transform:uppercase"></div>
                    <button class="btn" data-a="nearestPlate"><i class="fa-solid fa-car-side"></i> NEAREST</button></div></div>
                <div class="field"><div class="lbl"><span>Violations<span class="req">*</span></span></div>${pickerHtml(S, 'fine')}</div>
                <div class="field" style="margin-bottom:0"><div class="lbl"><span>Notes</span></div>
                    <div class="input"><textarea placeholder="Location, speed, details..." data-in="notes">${esc(S.notes)}</textarea></div></div>`;
            foot = `<div class="pf"><div class="summary" id="sum">${this.sumHtml()}</div>
                <button class="btn primary block" data-a="issue"><i class="fa-solid fa-file-invoice-dollar"></i> Issue Citation</button></div>`;
        } else {
            body = `<div class="search-bar"><div class="input grow"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Search by name or citizen ID..." value="${esc(S.listQ)}" data-in="listQ" data-enter="search"></div>
                <button class="btn" data-a="search"><i class="fa-solid fa-magnifying-glass"></i></button></div>
                <div class="list-rows">${S.list.map(f => `<div class="rowcard">
                    <div class="avatar">${initials(f.name)}</div>
                    <div class="who"><b>${esc(f.name)}</b><span>#${f.id} · by ${esc(f.officer)} · ${ago(f.t)}${f.plate ? ' · ' + esc(f.plate) : ''}</span>
                        <div class="meta">${(f.charges || []).map(c => `<span class="badge">${esc(c)}</span>`).join('')}</div></div>
                    <div class="right"><span class="big-num" style="color:var(--ok)">${money(f.amount)}</span>
                        ${f.paid ? '<span class="badge ok"><i class="fa-solid fa-check"></i> paid</span>' : `<button class="btn sm" data-a="markPaid" data-id="${f.id}"><i class="fa-solid fa-check"></i> Mark paid</button>`}</div>
                </div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-file-invoice"></i>No citations yet</div>`}</div>`;
        }
        return `<div class="panel form">${header('Traffic &amp; Citation System', 'Citations', 'file-invoice-dollar')}${tabs}<div class="pb">${body}</div>${foot}</div>`;
    },
    sumHtml() { const t = totals(this.S); return `<div class="sum"><span>Violations</span><b class="a">${t.n}</b></div><div class="sum" style="flex:2"><span>Total Amount</span><b class="m">${money(t.fine)}</b></div>`; },
    async loadList() { this.S.list = await call('fines', { q: this.S.listQ }) || []; if (App.panel === 'fine') render(); },
    after() { bindTarget(this.S); bindPicker(this.S, 'fine', () => { const s = $('#sum'); if (s) s.innerHTML = this.sumHtml(); }); clearInterval(App.tick); },
    handlers: {},
};
Object.assign(Fine.handlers, {
    tab(el) { Fine.S.tab = el.dataset.t; render(); if (Fine.S.tab === 'list') Fine.loadList(); },
    'in:plate'(el) { Fine.S.plate = el.value.toUpperCase(); },
    'in:notes'(el) { Fine.S.notes = el.value; },
    'in:listQ'(el) { Fine.S.listQ = el.value; },
    search() { Fine.loadList(); },
    async nearestPlate() { const r = await call('closestPlate'); if (r && r.plate) { Fine.S.plate = r.plate; root.querySelector('[data-in="plate"]').value = r.plate; } else toast('No vehicle nearby', 'warning'); },
    async markPaid(el) { if ((await call('markPaid', { id: Number(el.dataset.id) })).ok) Fine.loadList(); },
    async issue(btn) {
        const S = Fine.S;
        if (!S.id) return toast('Enter the server ID', 'error');
        if (!S.charges.size) return toast('Select at least one violation', 'error');
        btn.disabled = true;
        const r = await call('fine', { id: Number(S.id), charges: [...S.charges], notes: S.notes, plate: S.plate });
        btn.disabled = false;
        if (result(r)) { Fine.reset({ tab: 'list' }); render(); Fine.loadList(); }
    },
});

/* =====================================================================
   MDT
   ===================================================================== */
const FLAGS = ['Armed', 'Dangerous', 'Gang', 'Escape Risk', 'Drugs', 'Mental Health'];
const MDT = {
    S: null,
    reset(o) {
        this.S = { page: o.page || 'dashboard', dash: null, cq: '', results: [], profile: null, ptab: 'fines', vq: '', vehicles: [],
            warrants: [], wForm: { name: '', cid: '', reason: '', danger: 'medium' }, wFilter: 'active',
            reports: [], rq: '', report: null, rForm: null, bolos: [], bForm: { title: '', plate: '', body: '' } };
        this.load();
    },
    async load() {
        const S = this.S;
        if (S.page === 'dashboard') S.dash = await call('dashboard');
        if (S.page === 'citizens' && !S.results.length) S.results = await call('searchCitizens', { q: S.cq }) || [];
        if (S.page === 'warrants') S.warrants = await call('warrants') || [];
        if (S.page === 'reports') S.reports = await call('reports', { q: S.rq }) || [];
        if (S.page === 'bolo') S.bolos = await call('bolos') || [];
        if (S.page === 'impound') S.holds = await call('holds') || [];
        if (S.page === 'vehicles' && !S.vehicles.length) S.vov = await call('vehicleOverview');
        if (App.panel === 'mdt') render();
    },
    html() {
        const S = this.S, o = (App.init && App.init.officer) || {}, st = (S.dash && S.dash.stats) || (App.init && App.init.stats) || {};
        const nav = [
            ['dashboard', 'gauge-high', 'Dashboard'], ['citizens', 'id-card', 'Citizens'], ['vehicles', 'car', 'Vehicles'],
            ['impound', 'truck-pickup', 'Impound'], ['warrants', 'user-ninja', 'Warrants', st.warrants], ['reports', 'file-lines', 'Reports'], ['bolo', 'binoculars', 'BOLO', st.bolos],
        ];
        const titles = { dashboard: ['Overview', 'Dashboard'], citizens: ['Records', 'Citizen Search'], vehicles: ['DMV', 'Vehicle Lookup'], impound: ['Vehicles', 'Police Hold / Depot'], warrants: ['Judicial', 'Warrants'], reports: ['Investigations', 'Incident Reports'], bolo: ['Dispatch', 'Be On The Look Out'] };
        const [eb, tt] = titles[S.page];
        return `<div class="panel mdt">
            <div class="side">
                <div class="brand"><div class="logo"><i class="fa-solid fa-shield-halved"></i></div><div><b>ROX MDT</b><span>MOBILE DATA TERMINAL</span></div></div>
                <div class="nav">
                    ${nav.map(([k, ic, l, c]) => `<div class="ni ${S.page === k ? 'on' : ''}" data-a="nav" data-p="${k}"><i class="fa-solid fa-${ic}"></i>${l}${c ? `<span class="count">${c}</span>` : ''}</div>`).join('')}
                    <div class="sep">QUICK ACTIONS</div>
                    <div class="ni" data-a="openJail"><i class="fa-solid fa-building-shield"></i>Prison Management</div>
                    <div class="ni" data-a="openFine"><i class="fa-solid fa-file-invoice-dollar"></i>Citations</div>
                    ${App.init && App.init.boss ? '<div class="ni" data-a="app" data-p="boss"><i class="fa-solid fa-briefcase"></i>Management</div>' : ''}
                </div>
                <div class="me"><div class="avatar">${initials(o.name)}</div><div class="who"><b>${esc(o.name || 'Officer')}</b><span>${esc(o.jobLabel || 'Police')}${o.grade ? ' · ' + esc(o.grade) : ''}</span></div><span class="badge ok">on duty</span></div>
            </div>
            <div class="main">
                <div class="topbar">${App.tablet ? '<div class="icon-btn" data-a="home" title="Home"><i class="fa-solid fa-house"></i></div>' : ''}<div class="tt"><div class="eyebrow">${eb}</div><div class="title">${tt}</div></div>
                    <div class="clock" id="clock"></div>
                    <div class="icon-btn" data-a="reload" title="Refresh"><i class="fa-solid fa-rotate"></i></div>
                    <div class="icon-btn x" data-a="close"><i class="fa-solid fa-xmark"></i></div></div>
                <div class="content">${this[S.page]()}</div>
            </div>
        </div>`;
    },
    dashboard() {
        const d = this.S.dash;
        if (!d) return `<div class="empty-state"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading...</div>`;
        const s = d.stats;
        const stat = (ic, v, l, c) => `<div class="stat" style="--c:${c}"><i class="fa-solid fa-${ic}"></i><b>${v}</b><span>${l}</span></div>`;
        const icons = { jail: 'building-shield', fine: 'file-invoice-dollar', warrant: 'user-ninja', report: 'file-lines', bolo: 'binoculars', release: 'lock-open', vehicle: 'car', citizen: 'id-card' };
        return `<div class="stats">
                ${stat('user-shield', s.officers, 'Officers On Duty', '77,163,255')}
                ${stat('building-shield', s.prisoners, 'In Prison', 'var(--accent-rgb)')}
                ${stat('user-ninja', s.warrants, 'Active Warrants', '255,77,94')}
                ${stat('binoculars', s.bolos, 'Active BOLO', '255,176,32')}
                ${stat('file-invoice-dollar', s.finesToday, 'Citations 24h', '52,209,122')}
                ${stat('hand-holding-dollar', s.unpaid, 'Unpaid Fines', '255,176,32')}
            </div>
            <div class="cols2">
                <div class="card"><h3><i class="fa-solid fa-wave-square"></i>Recent Activity</h3>
                    <div class="feed">${d.activity.map(a => `<div class="fi"><div class="ic"><i class="fa-solid fa-${icons[a.kind] || 'circle'}"></i></div><div class="tx">${esc(a.text)}<small>${esc(a.officer || 'System')} · ${ago(a.t)}</small></div></div>`).join('') || '<div class="dim">No activity yet</div>'}</div></div>
                <div>
                    <div class="card"><h3><i class="fa-solid fa-user-ninja"></i>Active Warrants<span class="sp"></span><span class="btn sm ghost" data-a="nav" data-p="warrants">View all</span></h3>
                        <div class="list-rows">${d.warrants.map(w => `<div class="rowcard"><div class="avatar">${initials(w.name)}</div><div class="who"><b>${esc(w.name)}</b><span>${esc(w.reason)}</span></div>${dangerBadge(w.danger)}</div>`).join('') || '<div class="dim">No active warrants</div>'}</div></div>
                    <div class="card"><h3><i class="fa-solid fa-binoculars"></i>BOLO<span class="sp"></span><span class="btn sm ghost" data-a="nav" data-p="bolo">View all</span></h3>
                        <div class="list-rows">${d.bolos.map(b => `<div class="rowcard"><div class="who"><b>${esc(b.title)}</b><span>${esc(b.body)}</span></div>${b.plate ? `<span class="plate">${esc(b.plate)}</span>` : ''}</div>`).join('') || '<div class="dim">No active BOLO</div>'}</div></div>
                </div>
            </div>`;
    },
    citizens() {
        const S = this.S, p = S.profile;
        const left = `<div class="search-bar"><div class="input grow"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Name, citizen ID or server ID..." value="${esc(S.cq)}" data-in="cq2" data-enter="csearch"></div>
            <button class="btn" data-a="csearch"><i class="fa-solid fa-magnifying-glass"></i></button></div>
            <div class="list-rows">${S.results.map(r => `<div class="rowcard click ${p && p.cid === r.cid ? 'sel' : ''}" data-a="cprofile" data-cid="${esc(r.cid)}">
                <div class="avatar">${initials(r.name)}</div><div class="who"><b>${esc(r.name)}</b><span>${esc(r.cid)}${r.id ? ' · ID ' + r.id : ''}</span></div>
                ${r.warrants ? '<span class="badge bad">wanted</span>' : ''}${r.jailed ? '<span class="badge accent">jailed</span>' : ''}${r.online ? '<span class="badge ok">online</span>' : ''}
            </div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-id-card"></i>Search for a citizen</div>`}</div>`;
        let right = `<div class="empty-state" style="padding-top:120px"><i class="fa-solid fa-user"></i>Select a citizen to view the record</div>`;
        if (p) {
            const tabs = [['fines', 'Citations', p.fines.length], ['jail', 'Prison', p.jail.length], ['warrants', 'Warrants', p.warrants.length], ['reports', 'Reports', p.reports.length]];
            let list = '';
            if (S.ptab === 'fines') list = p.fines.map(f => `<div class="rowcard"><div class="who"><b>${(f.charges || []).map(esc).join(', ')}</b><span>#${f.id} · ${esc(f.officer)} · ${fmtDate(f.t)}</span></div><span class="big-num" style="color:var(--ok)">${money(f.amount)}</span>${f.paid ? '<span class="badge ok">paid</span>' : '<span class="badge warn">unpaid</span>'}</div>`).join('');
            if (S.ptab === 'jail') list = p.jail.map(j => `<div class="rowcard"><div class="who"><b>${(j.charges || []).map(esc).join(', ') || 'No charges listed'}</b><span>${esc(j.officer)} · ${fmtDate(j.t)}${j.extra ? ' · ' + esc(j.extra) : ''}</span></div><span class="badge accent">${j.life ? 'LIFE' : j.minutes + ' min'}</span></div>`).join('');
            if (S.ptab === 'warrants') list = p.warrants.map(w => `<div class="rowcard"><div class="who"><b>${esc(w.reason)}</b><span>${esc(w.officer)} · ${fmtDate(w.t)}</span></div>${dangerBadge(w.danger)}${w.active ? '<span class="badge bad">active</span>' : '<span class="badge">closed</span>'}</div>`).join('');
            if (S.ptab === 'reports') list = p.reports.map(r => `<div class="rowcard click" data-a="openReport" data-id="${r.id}"><div class="who"><b>#${r.id} ${esc(r.title)}</b><span>${fmtDate(r.t)}</span></div><i class="fa-solid fa-chevron-right dim"></i></div>`).join('');
            right = `<div class="profile-head"><div class="avatar lg">${initials(p.name)}</div>
                    <div style="flex:1"><div class="nm">${esc(p.name)}</div><div class="dim mono">${esc(p.cid)}</div>
                        <div class="meta" style="display:flex;gap:6px;margin-top:8px;flex-wrap:wrap">
                            ${p.online ? '<span class="badge ok">online</span>' : '<span class="badge">offline</span>'}
                            ${p.warrants.some(w => w.active) ? '<span class="badge bad"><i class="fa-solid fa-triangle-exclamation"></i> wanted</span>' : ''}
                            ${p.prisoner ? '<span class="badge accent">in prison</span>' : ''}
                            ${p.owed ? `<span class="badge warn">owes ${money(p.owed)}</span>` : ''}
                        </div></div>
                    <div style="display:flex;gap:8px">
                        ${p.online ? `<button class="btn" data-a="jailP" data-id="${p.id}"><i class="fa-solid fa-lock"></i> Jail</button><button class="btn" data-a="fineP" data-id="${p.id}"><i class="fa-solid fa-file-invoice-dollar"></i> Cite</button>` : ''}
                        <button class="btn danger" data-a="warrantP"><i class="fa-solid fa-user-ninja"></i> Warrant</button>
                    </div></div>
                <div class="kv"><div><span>Server ID</span><b>${p.id || '—'}</b></div><div><span>Phone</span><b>${esc(p.phone || '—')}</b></div><div><span>Date of Birth</span><b>${esc(p.dob || '—')}</b></div><div><span>Job</span><b>${esc(p.job || '—')}</b></div></div>
                <div class="card" style="margin-bottom:14px"><h3><i class="fa-solid fa-flag"></i>Flags &amp; Notes<span class="sp"></span><button class="btn sm" data-a="saveCitizen"><i class="fa-solid fa-floppy-disk"></i> Save</button></h3>
                    <div class="chips" style="margin-bottom:10px">${FLAGS.map(f => `<span class="chip ${(p.flags || []).includes(f) ? 'on' : ''}" data-a="flag" data-f="${f}">${f}</span>`).join('')}</div>
                    <div class="input"><textarea placeholder="Officer notes about this citizen..." data-in="pnotes">${esc(p.notes || '')}</textarea></div></div>
                <div class="subtabs">${tabs.map(([k, l, c]) => `<div class="st ${S.ptab === k ? 'on' : ''}" data-a="ptab" data-t="${k}">${l}<span class="count">${c}</span></div>`).join('')}</div>
                <div class="list-rows">${list || '<div class="empty-state" style="padding:24px">Nothing here</div>'}</div>`;
        }
        return `<div class="split"><div>${left}</div><div>${right}</div></div>`;
    },
    vehicles() {
        const S = this.S;
        const search = `<div class="search-bar"><div class="input grow"><i class="fa-solid fa-car"></i><input placeholder="Search a license plate..." value="${esc(S.vq)}" data-in="vq" data-enter="vsearch" style="text-transform:uppercase"></div>
            <button class="btn" data-a="vnearest"><i class="fa-solid fa-car-side"></i> Nearest</button><button class="btn primary" data-a="vsearch"><i class="fa-solid fa-magnifying-glass"></i> Search</button>
            ${S.vehicles.length ? '<button class="btn ghost" data-a="vclear"><i class="fa-solid fa-xmark"></i></button>' : ''}</div>`;
        const modeBadge = (m) => m === 'depot' ? '<span class="badge accent"><i class="fa-solid fa-warehouse"></i> depot</span>' : '<span class="badge warn"><i class="fa-solid fa-truck-pickup"></i> impound</span>';
        if (!S.vehicles.length) {
            const o = S.vov;
            if (!o) return search + `<div class="empty-state"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading...</div>`;
            const stat = (ic, v, l, c) => `<div class="stat" style="--c:${c}"><i class="fa-solid fa-${ic}"></i><b>${v}</b><span>${l}</span></div>`;
            return `${search}
                <div class="stats" style="grid-template-columns:repeat(4,1fr)">
                    ${stat('truck-pickup', o.today, 'Impounded 24h', '255,176,32')}
                    ${stat('warehouse', o.holds.length, 'On police hold', 'var(--accent-rgb)')}
                    ${stat('triangle-exclamation', o.flagged.length, 'Flagged stolen', '255,77,94')}
                    ${stat('clipboard-list', o.total, 'Total impounds', '77,163,255')}
                </div>
                <div class="cols2">
                    <div class="card"><h3><i class="fa-solid fa-clock-rotate-left"></i>Recent Impounds<span class="sp"></span><span class="btn sm ghost" data-a="nav" data-p="impound">Police hold</span></h3>
                        ${o.recent.length ? `<table class="tbl"><tr><th>Plate</th><th>Vehicle</th><th>Type</th><th>Officer</th><th>When</th></tr>
                        ${o.recent.map(im => `<tr class="click" data-a="vopen" data-plate="${esc(im.plate)}"><td><span class="plate" style="font-size:12px;padding:1px 7px">${esc(im.plate)}</span></td>
                            <td><b>${esc(im.model || '—')}</b><div class="dim" style="font-size:10.5px">${esc(im.owner || im.reason || '')}</div></td><td>${modeBadge(im.mode)}${im.mode === 'depot' ? ` <span class="badge">${im.hours}h · ${money(im.price)}</span>` : ''}</td>
                            <td>${esc(im.officer)}</td><td class="dim">${ago(im.t)}</td></tr>`).join('')}</table>` : '<div class="empty-state" style="padding:26px"><i class="fa-solid fa-truck-pickup"></i>No impounds yet<br><span style="font-size:11px">Third eye on a vehicle → Impound / Depot</span></div>'}
                    </div>
                    <div>
                        <div class="card"><h3><i class="fa-solid fa-warehouse"></i>Police Hold</h3>
                            <div class="list-rows">${o.holds.slice(0, 4).map(h => `<div class="rowcard click" data-a="vopen" data-plate="${esc(h.plate)}"><span class="plate" style="font-size:12px;padding:1px 7px">${esc(h.plate)}</span><div class="who"><b>${esc(h.model || h.reason || 'Police hold')}</b><span>${esc(h.reason || '')}</span></div>
                                ${h.remaining > 0 ? `<span class="mono" style="color:var(--accent)" data-remain="${h.remaining}">${fmtDur(h.remaining)}</span>` : '<span class="badge ok">ready</span>'}</div>`).join('') || '<div class="dim">No vehicles on hold</div>'}</div></div>
                        <div class="card"><h3><i class="fa-solid fa-triangle-exclamation" style="color:var(--bad)"></i>Flagged Stolen</h3>
                            <div class="list-rows">${o.flagged.map(f => `<div class="rowcard click" data-a="vopen" data-plate="${esc(f.plate)}"><span class="plate" style="font-size:12px;padding:1px 7px">${esc(f.plate)}</span><div class="who"><b>${esc(f.model || 'Unknown model')}</b><span>${esc(f.notes || f.owner || '')}</span></div><span class="badge bad">stolen</span></div>`).join('') || '<div class="dim">No stolen vehicles</div>'}</div></div>
                    </div>
                </div>`;
        }
        return `${search}<div class="list-rows">${S.vehicles.map((v, i) => `<div class="card" style="margin-bottom:0">
                <div style="display:flex;align-items:center;gap:14px">
                    <span class="plate" style="font-size:18px">${esc(v.plate)}</span>
                    <div class="who"><b style="font-size:15px">${esc(v.model)}</b><span>Owner: ${esc(v.owner || 'Unknown')}</span></div>
                    ${v.unregistered ? '<span class="badge warn">not registered</span>' : '<span class="badge ok">registered</span>'}
                    ${v.stolen ? '<span class="badge bad"><i class="fa-solid fa-triangle-exclamation"></i> stolen</span>' : ''}
                    ${v.bolo ? '<span class="badge warn">bolo</span>' : ''}
                    ${v.fines ? `<span class="badge">${v.fines} citations</span>` : ''}
                    <span style="flex:1"></span>
                    ${v.cid ? `<button class="btn sm" data-a="vowner" data-cid="${esc(v.cid)}"><i class="fa-solid fa-id-card"></i> Owner</button>` : ''}
                </div>
                ${v.hold ? `<div class="person-card" style="margin-top:12px"><div class="avatar"><i class="fa-solid fa-warehouse"></i></div><div class="who"><b>On police hold · ${money(v.hold.price)}</b><span>${esc(v.hold.reason || '')} · by ${esc(v.hold.officer)} · ${ago(v.hold.t)}</span></div>
                    ${v.hold.remaining > 0 ? `<span class="big-num" style="color:var(--accent)" data-remain="${v.hold.remaining}">${fmtDur(v.hold.remaining)}</span>` : '<span class="badge ok">can be released</span>'}<button class="btn sm ok" data-a="hrelease" data-plate="${esc(v.plate)}"><i class="fa-solid fa-lock-open"></i> Release</button></div>` : ''}
                <div class="row" style="margin-top:12px">
                    <div class="toggle-row ${v.stolen ? 'on' : ''}" data-a="vstolen" data-i="${i}" style="width:220px"><div class="t"><b>Reported Stolen</b><span>Flag this plate</span></div><div class="switch"></div></div>
                    <div class="input grow"><i class="fa-solid fa-note-sticky"></i><input placeholder="Notes..." value="${esc(v.notes || '')}" data-in="vnotes" data-i="${i}"></div>
                    <button class="btn" data-a="vsave" data-i="${i}"><i class="fa-solid fa-floppy-disk"></i> Save</button>
                </div>
                ${(v.history || []).length ? `<div class="lbl" style="margin-top:14px"><span>Impound history</span></div><div class="feed">${v.history.map(im => `<div class="fi"><div class="ic"><i class="fa-solid fa-${im.mode === 'depot' ? 'warehouse' : 'truck-pickup'}"></i></div><div class="tx">${im.mode === 'depot' ? `Police hold ${im.hours}h · ${money(im.price)}` : 'Sent to impound'}${im.reason ? ' — ' + esc(im.reason) : ''}<small>${esc(im.officer)} · ${fmtDate(im.t)}</small></div></div>`).join('')}</div>` : ''}
                </div>`).join('')}</div>`;
    },
    warrants() {
        const S = this.S, F = S.wForm;
        const rows = S.warrants.filter(w => S.wFilter === 'all' || w.active);
        return `<div class="cols2">
            <div><div class="subtabs" style="max-width:260px"><div class="st ${S.wFilter === 'active' ? 'on' : ''}" data-a="wfilter" data-f="active">Active</div><div class="st ${S.wFilter === 'all' ? 'on' : ''}" data-a="wfilter" data-f="all">All</div></div>
                <div class="list-rows">${rows.map(w => `<div class="rowcard"><div class="avatar">${initials(w.name)}</div>
                    <div class="who"><b>${esc(w.name)}</b><span>${esc(w.reason)}</span><div class="meta"><span class="badge">#${w.id}</span><span class="badge">${esc(w.officer)}</span><span class="badge">${ago(w.t)}</span></div></div>
                    <div class="right">${dangerBadge(w.danger)}${w.active ? `<button class="btn sm ok" data-a="wclose" data-id="${w.id}"><i class="fa-solid fa-check"></i> Close</button>` : '<span class="badge">closed</span>'}</div></div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-user-ninja"></i>No warrants</div>`}</div></div>
            <div class="card"><h3><i class="fa-solid fa-gavel"></i>Issue Warrant</h3>
                <div class="field"><div class="lbl"><span>Suspect Name<span class="req">*</span></span></div><div class="input"><i class="fa-solid fa-user"></i><input value="${esc(F.name)}" data-in="wname" placeholder="Full name"></div></div>
                <div class="field"><div class="lbl"><span>Citizen ID</span></div><div class="input"><i class="fa-solid fa-fingerprint"></i><input value="${esc(F.cid)}" data-in="wcid" placeholder="optional"></div></div>
                <div class="field"><div class="lbl"><span>Reason<span class="req">*</span></span></div><div class="input"><textarea data-in="wreason" placeholder="Charges and reason...">${esc(F.reason)}</textarea></div></div>
                <div class="field"><div class="lbl"><span>Danger Level</span></div><div class="seg-pick">${[['low', 'shield', 'Low'], ['medium', 'shield-halved', 'Medium'], ['high', 'skull', 'High']].map(([k, ic, l]) => `<div class="opt ${F.danger === k ? 'on' : ''}" data-a="wdanger" data-k="${k}"><i class="fa-solid fa-${ic}"></i>${l}</div>`).join('')}</div></div>
                <button class="btn primary block" data-a="wcreate"><i class="fa-solid fa-gavel"></i> Issue Warrant</button></div>
        </div>`;
    },
    reports() {
        const S = this.S, R = S.report, F = S.rForm;
        const left = `<div class="search-bar"><div class="input grow"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Search reports..." value="${esc(S.rq)}" data-in="rq" data-enter="rsearch"></div>
                <button class="btn primary" data-a="rnew"><i class="fa-solid fa-plus"></i> New</button></div>
            <div class="list-rows">${S.reports.map(r => `<div class="rowcard click ${R && R.id === r.id ? 'sel' : ''}" data-a="ropen" data-id="${r.id}"><div class="who"><b>#${r.id} ${esc(r.title)}</b><span>${esc(r.kind)} · ${esc(r.officer)} · ${ago(r.t)}</span></div></div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-file-lines"></i>No reports yet</div>`}</div>`;
        let right = `<div class="empty-state" style="padding-top:120px"><i class="fa-solid fa-file-lines"></i>Select a report or create a new one</div>`;
        if (F) {
            right = `<div class="card"><h3><i class="fa-solid fa-file-pen"></i>New Incident Report</h3>
                <div class="grid2"><div class="field"><div class="lbl"><span>Title<span class="req">*</span></span></div><div class="input"><input value="${esc(F.title)}" data-in="rf" data-k="title" placeholder="e.g. Fleeca bank robbery"></div></div>
                <div class="field"><div class="lbl"><span>Type</span></div><div class="input"><select data-in="rf" data-k="kind">${['Incident', 'Arrest', 'Traffic', 'Robbery', 'Shooting', 'Investigation'].map(k => `<option ${F.kind === k ? 'selected' : ''}>${k}</option>`).join('')}</select></div></div></div>
                <div class="grid2"><div class="field"><div class="lbl"><span>Location</span></div><div class="input"><i class="fa-solid fa-location-dot"></i><input value="${esc(F.location)}" data-in="rf" data-k="location" placeholder="Street / area"></div></div>
                <div class="field"><div class="lbl"><span>Involved</span></div><div class="input"><i class="fa-solid fa-users"></i><input value="${esc(F.involved)}" data-in="rf" data-k="involved" placeholder="Names, comma separated"></div></div></div>
                <div class="field"><div class="lbl"><span>Report</span></div><div class="input"><textarea style="min-height:220px" data-in="rf" data-k="body" placeholder="What happened...">${esc(F.body)}</textarea></div></div>
                <div class="row"><button class="btn" data-a="rcancel">Cancel</button><button class="btn primary grow" data-a="rsave"><i class="fa-solid fa-floppy-disk"></i> Save Report</button></div></div>`;
        } else if (R) {
            right = `<div class="card"><h3><i class="fa-solid fa-file-lines"></i>Report #${R.id}<span class="sp"></span><span class="badge accent">${esc(R.kind)}</span></h3>
                <div class="title" style="font-size:20px;margin-bottom:12px">${esc(R.title)}</div>
                <div class="kv" style="grid-template-columns:repeat(3,1fr)"><div><span>Officer</span><b>${esc(R.officer)}</b></div><div><span>Location</span><b>${esc(R.location || '—')}</b></div><div><span>Date</span><b>${fmtDate(R.t)}</b></div></div>
                ${R.involved ? `<div class="lbl"><span>Involved</span></div><div class="chips" style="margin-bottom:16px">${R.involved.split(',').map(n => `<span class="chip">${esc(n.trim())}</span>`).join('')}</div>` : ''}
                <div class="lbl"><span>Report</span></div><div class="report-body">${esc(R.body || '—')}</div></div>`;
        }
        return `<div class="split"><div>${left}</div><div>${right}</div></div>`;
    },
    impound() {
        const S = this.S;
        return `<div class="list-rows">${(S.holds || []).map(h => `<div class="rowcard"><span class="plate">${esc(h.plate)}</span>
            <div class="who"><b>${esc(h.reason || 'Police hold')}</b><span>${esc(h.officer)} · ${ago(h.t)}</span><div class="meta"><span class="badge ok">${money(h.price)}</span><span class="badge">${h.hours}h hold</span></div></div>
            <div class="right">${h.remaining > 0 ? `<span class="big-num" data-remain="${h.remaining}">${fmtDur(h.remaining)}</span><div class="progress"><i style="width:${Math.max(0, 100 - h.remaining / Math.max(1, h.hours * 3600) * 100)}%"></i></div>` : '<span class="badge ok">can be released</span>'}
                <button class="btn sm ok" data-a="hrelease" data-plate="${esc(h.plate)}"><i class="fa-solid fa-lock-open"></i> Release</button></div></div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-warehouse"></i>No vehicles on police hold<br><span style="font-size:11px">Use the third eye on a vehicle → Impound / Depot</span></div>`}</div>`;
    },
    bolo() {
        const S = this.S, F = S.bForm;
        return `<div class="cols2">
            <div class="list-rows">${S.bolos.map(b => `<div class="rowcard"><div class="avatar"><i class="fa-solid fa-binoculars"></i></div>
                <div class="who"><b>${esc(b.title)}</b><span>${esc(b.body)}</span><div class="meta"><span class="badge">${esc(b.officer)}</span><span class="badge">${ago(b.t)}</span></div></div>
                <div class="right">${b.plate ? `<span class="plate">${esc(b.plate)}</span>` : ''}${b.active ? `<button class="btn sm ok" data-a="bclose" data-id="${b.id}"><i class="fa-solid fa-check"></i> Close</button>` : '<span class="badge">closed</span>'}</div></div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-binoculars"></i>No BOLO</div>`}</div>
            <div class="card"><h3><i class="fa-solid fa-bullhorn"></i>New BOLO</h3>
                <div class="field"><div class="lbl"><span>Title<span class="req">*</span></span></div><div class="input"><input value="${esc(F.title)}" data-in="bf" data-k="title" placeholder="e.g. Black Sultan fleeing north"></div></div>
                <div class="field"><div class="lbl"><span>Plate</span></div><div class="input"><i class="fa-solid fa-car"></i><input value="${esc(F.plate)}" data-in="bf" data-k="plate" placeholder="optional" style="text-transform:uppercase"></div></div>
                <div class="field"><div class="lbl"><span>Description</span></div><div class="input"><textarea data-in="bf" data-k="body" placeholder="Suspect / vehicle description...">${esc(F.body)}</textarea></div></div>
                <button class="btn primary block" data-a="bcreate"><i class="fa-solid fa-bullhorn"></i> Broadcast BOLO</button></div>
        </div>`;
    },
    after() {
        clearInterval(App.tick);
        const clock = () => { const c = $('#clock'); if (c) c.textContent = new Date().toLocaleTimeString('en-GB'); };
        clock(); App.tick = setInterval(() => { clock(); root.querySelectorAll('[data-remain]').forEach(el => { const v = Math.max(0, Number(el.dataset.remain) - 1); el.dataset.remain = v; el.textContent = fmtDur(v); }); }, 1000);
    },
    handlers: {},
};
const dangerBadge = (d) => `<span class="badge ${d === 'high' ? 'bad' : d === 'low' ? 'info' : 'warn'}">${esc(d || 'medium')}</span>`;
const refocus = (sel) => { const i = root.querySelector(sel); if (i) { i.focus(); i.setSelectionRange && i.setSelectionRange(i.value.length, i.value.length); } };

Object.assign(MDT.handlers, {
    nav(el) { MDT.S.page = el.dataset.p; render(); MDT.load(); },
    async hrelease(el) { if (result(await call('releaseHold', { plate: el.dataset.plate }))) { if (MDT.S.page === 'vehicles' && MDT.S.vehicles.length) MDT.handlers.vsearch(); else MDT.load(); } },
    reload() { MDT.S.results = []; MDT.load(); },
    openJail() { openPanel('jail', {}, 'mdt'); },
    openFine() { openPanel('fine', {}, 'mdt'); },
    // citizens
    'in:cq2'(el) { MDT.S.cq = el.value; },
    async csearch() { MDT.S.results = await call('searchCitizens', { q: MDT.S.cq }) || []; render(); refocus('[data-in="cq2"]'); },
    async cprofile(el) { MDT.S.profile = await call('citizen', { cid: el.dataset.cid }); MDT.S.ptab = 'fines'; render(); },
    ptab(el) { MDT.S.ptab = el.dataset.t; render(); },
    flag(el) { const p = MDT.S.profile, f = el.dataset.f; p.flags = p.flags || []; p.flags = p.flags.includes(f) ? p.flags.filter(x => x !== f) : p.flags.concat([f]); el.classList.toggle('on'); },
    'in:pnotes'(el) { MDT.S.profile.notes = el.value; },
    async saveCitizen() { const p = MDT.S.profile; result(await call('saveCitizen', { cid: p.cid, name: p.name, notes: p.notes, flags: p.flags }), 'Profile saved'); },
    jailP(el) { openPanel('jail', { id: Number(el.dataset.id) }, 'mdt'); },
    fineP(el) { openPanel('fine', { id: Number(el.dataset.id) }, 'mdt'); },
    warrantP() { const p = MDT.S.profile; MDT.S.wForm = { name: p.name, cid: p.cid, reason: '', danger: 'medium' }; MDT.S.page = 'warrants'; render(); MDT.load(); },
    async openReport(el) { MDT.S.page = 'reports'; MDT.S.rForm = null; await MDT.load(); MDT.S.report = MDT.S.reports.find(r => r.id === Number(el.dataset.id)) || null; render(); },
    // vehicles
    'in:vq'(el) { MDT.S.vq = el.value.toUpperCase(); },
    async vsearch() { const r = await call('searchVehicle', { plate: MDT.S.vq }); MDT.S.vehicles = (r && r.rows) || []; render(); },
    vopen(el) { MDT.S.page = 'vehicles'; MDT.S.vq = el.dataset.plate; MDT.handlers.vsearch(); },
    vclear() { MDT.S.vehicles = []; MDT.S.vq = ''; render(); MDT.load(); },
    async vnearest() { const r = await call('closestPlate'); if (r && r.plate) { MDT.S.vq = r.plate; MDT.handlers.vsearch(); } else toast('No vehicle nearby', 'warning'); },
    vstolen(el) { const v = MDT.S.vehicles[el.dataset.i]; v.stolen = !v.stolen; el.classList.toggle('on', v.stolen); },
    'in:vnotes'(el) { MDT.S.vehicles[el.dataset.i].notes = el.value; },
    async vsave(el) { const v = MDT.S.vehicles[el.dataset.i]; if (result(await call('flagVehicle', v), 'Vehicle saved')) MDT.handlers.vsearch(); },
    async vowner(el) { MDT.S.page = 'citizens'; MDT.S.profile = await call('citizen', { cid: el.dataset.cid }); render(); },
    // warrants
    wfilter(el) { MDT.S.wFilter = el.dataset.f; render(); },
    'in:wname'(el) { MDT.S.wForm.name = el.value; }, 'in:wcid'(el) { MDT.S.wForm.cid = el.value; }, 'in:wreason'(el) { MDT.S.wForm.reason = el.value; },
    wdanger(el) { MDT.S.wForm.danger = el.dataset.k; root.querySelectorAll('[data-a="wdanger"]').forEach(o => o.classList.toggle('on', o === el)); },
    async wcreate() { const F = MDT.S.wForm; if (result(await call('createWarrant', { ...F, cid: F.cid || null }))) { MDT.S.wForm = { name: '', cid: '', reason: '', danger: 'medium' }; MDT.load(); } },
    async wclose(el) { if ((await call('closeWarrant', { id: Number(el.dataset.id) })).ok) { toast('Warrant closed', 'success'); MDT.load(); } },
    // reports
    'in:rq'(el) { MDT.S.rq = el.value; },
    rsearch() { MDT.load().then(() => refocus('[data-in="rq"]')); },
    rnew() { MDT.S.report = null; MDT.S.rForm = { title: '', kind: 'Incident', location: '', involved: '', body: '' }; render(); refocus('[data-k="title"]'); },
    rcancel() { MDT.S.rForm = null; render(); },
    'in:rf'(el) { MDT.S.rForm[el.dataset.k] = el.value; },
    ropen(el) { MDT.S.rForm = null; MDT.S.report = MDT.S.reports.find(r => r.id === Number(el.dataset.id)); render(); },
    async rsave() { const r = await call('createReport', MDT.S.rForm); if (result(r)) { MDT.S.rForm = null; await MDT.load(); MDT.S.report = MDT.S.reports.find(x => x.id === r.id) || null; render(); } },
    // bolo
    'in:bf'(el) { MDT.S.bForm[el.dataset.k] = el.value; },
    async bcreate() { if (result(await call('createBolo', MDT.S.bForm))) { MDT.S.bForm = { title: '', plate: '', body: '' }; MDT.load(); } },
    async bclose(el) { if ((await call('closeBolo', { id: Number(el.dataset.id) })).ok) MDT.load(); },
});
// "in:rf" select uses change too
root.addEventListener('change', (e) => { const k = e.target.dataset.in; if (k && e.target.tagName === 'SELECT' && H['in:' + k]) H['in:' + k](e.target, e); });

/* =====================================================================
   HOME SCREEN (iPad)
   ===================================================================== */
const Home = {
    S: { dash: null },
    reset() { call('dashboard').then(d => { this.S.dash = d; if (App.panel === 'home') render(); }); },
    html() {
        const o = (App.init && App.init.officer) || {}, d = this.S.dash || {}, st = d.stats || {};
        const now = new Date();
        const app = (k, ic, nm, c, n, dark) => {
            const [p, pg] = k.split(':');
            return `<div class="dock-app" data-a="app" data-p="${p}" ${pg ? `data-page="${pg}"` : ''} style="--c:${c}"><span class="aicon ${dark ? 'dark' : ''}"><i class="fa-solid fa-${ic}"></i></span>${n ? `<span class="badge-n">${n}</span>` : ''}<span class="dock-tip">${nm}</span></div>`;
        };
        const w = (k, ic, v, l, c) => { const [p, pg] = k.split(':'); return `<div class="hw glass" data-a="app" data-p="${p}" ${pg ? `data-page="${pg}"` : ''} style="--c:${c}"><div class="wi"><i class="fa-solid fa-${ic}"></i></div><div><b>${v ?? '—'}</b><span>${l}</span></div></div>`; };
        const icons = { jail: 'building-shield', fine: 'file-invoice-dollar', warrant: 'user-ninja', report: 'file-lines', bolo: 'binoculars', release: 'lock-open', vehicle: 'car', citizen: 'id-card' };
        return `<div class="home2">
            <div class="home-clock"><b id="homeClock">${now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })}</b><span>${now.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })}</span></div>
            <div class="home-me glass"><div class="avatar">${initials(o.name)}</div><div>${esc(o.name || 'Officer')}<small>${esc(o.jobLabel || 'Police')}${o.grade ? ' · ' + esc(o.grade) : ''}</small></div><span class="dot"></span></div>
            <div class="home-widgets">
                ${w('mdt:dashboard', 'user-shield', st.officers, 'Officers on duty', '77,163,255')}
                ${w('jail', 'building-shield', st.prisoners, 'In prison', '255,90,31')}
                ${w('mdt:warrants', 'user-ninja', st.warrants, 'Active warrants', '255,77,94')}
                ${w('mdt:bolo', 'binoculars', st.bolos, 'Active BOLO', '255,176,32')}
            </div>
            ${d.activity && d.activity.length ? `<div class="home-feed glass"><h4><i class="fa-solid fa-wave-square"></i>Live Activity</h4>${d.activity.slice(0, 5).map(a => `<div class="fi"><i class="fa-solid fa-${icons[a.kind] || 'circle'}"></i><div>${esc(a.text)}<small>${esc(a.officer || 'System')} · ${ago(a.t)}</small></div></div>`).join('')}</div>` : ''}
            <div class="home-brand">ROX POLICE OS</div>
            <div class="dock">
                ${app('mdt', 'shield-halved', 'MDT', '255,90,31')}
                ${app('mdt:citizens', 'id-card', 'Citizens', '77,141,255')}
                ${app('mdt:vehicles', 'car', 'Vehicles', '40,180,200')}
                ${app('mdt:impound', 'truck-pickup', 'Impound', '255,176,32')}
                ${app('jail', 'building-shield', 'Prison', '255,110,50')}
                ${app('fine', 'file-invoice-dollar', 'Citations', '52,180,110')}
                ${app('mdt:warrants', 'user-ninja', 'Warrants', '255,77,94', st.warrants, true)}
                ${app('mdt:reports', 'file-lines', 'Reports', '200,200,215', 0, true)}
                ${app('mdt:bolo', 'binoculars', 'BOLO', '255,150,40', st.bolos, true)}
                <span class="sep"></span>
                ${App.init && App.init.boss ? app('boss', 'briefcase', 'Management', '130,100,255') : ''}
                <div class="dock-app" data-a="app" data-p="settings"><img class="aicon" src="img/icons/settings.jpg" alt=""><span class="dock-tip">Settings</span></div>
            </div>
        </div>`;
    },
    after() { clearInterval(App.tick); App.tick = setInterval(() => { const c = $('#homeClock'); if (c) c.textContent = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }); }, 5000); },
    handlers: {},
};

/* =====================================================================
   SETTINGS (iPad)
   ===================================================================== */
const SettingsApp = {
    reset() {},
    html() {
        const cur = Settings.wallpaper || WALLPAPERS[0];
        const custom = Settings.wallpaper && !WALLPAPERS.includes(Settings.wallpaper) ? Settings.wallpaper : '';
        const pct = Math.round((Settings.scale || 1) * 100);
        const o = (App.init && App.init.officer) || {};
        return `<div class="panel form">${header('iPad', 'Settings', 'gear')}
            <div class="pb"><div class="settings">
                <div class="set-card"><div class="set-head"><span class="si"><i class="fa-solid fa-image"></i></span><div><b>Wallpaper</b><small>Pick the home screen background</small></div></div>
                    <div class="walls">${WALLPAPERS.map(w => `<div class="wall ${cur === w ? 'on' : ''}" style="background-image:url('${w}')" data-a="setwall" data-src="${w}">${cur === w ? '<i class="fa-solid fa-check"></i>' : ''}</div>`).join('')}</div>
                    <div class="set-row"><div class="input grow"><i class="fa-solid fa-link"></i><input id="customWall" placeholder="Or paste an image URL https://..." value="${esc(custom)}"></div><button class="btn" data-a="setwallurl">Save</button></div></div>
                <div class="set-card"><div class="set-head"><span class="si"><i class="fa-solid fa-up-right-and-down-left-from-center"></i></span><div><b>iPad size</b><small>Make the iPad bigger or smaller on screen</small></div><span class="set-val" id="scaleVal">${pct}%</span></div>
                    <div class="set-row"><span class="muted">Small</span><input type="range" class="set-range" min="70" max="115" step="1" value="${pct}" data-in="scale"><span class="muted">Large</span><button class="btn" data-a="resetscale">Default</button></div></div>
                <div class="set-card"><div class="set-head"><span class="si"><i class="fa-solid fa-circle-info"></i></span><div><b>About</b><small>ROX Police OS · rox_police · ${esc(o.name || '')}${o.grade ? ' · ' + esc(o.grade) : ''}</small></div><span class="badge accent">ROX STORE</span></div></div>
            </div></div></div>`;
    },
    handlers: {},
};
Object.assign(SettingsApp.handlers, {
    setwall(el) { Settings.wallpaper = el.dataset.src; saveSettings(); applySettings(); render(); },
    setwallurl() { const v = ($('#customWall').value || '').trim(); if (v && !/^https:\/\//.test(v)) return toast('Use an https:// link', 'error'); Settings.wallpaper = v || null; saveSettings(); applySettings(); render(); },
    resetscale() { Settings.scale = 1; saveSettings(); applySettings(); render(); },
    'in:scale'(el) { Settings.scale = Number(el.value) / 100; saveSettings(); applySettings(); const v = $('#scaleVal'); if (v) v.textContent = el.value + '%'; },
});

/* =====================================================================
   MANAGEMENT (boss menu)
   ===================================================================== */
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const fmtHours = (min) => min >= 60 ? (min / 60).toFixed(1) + 'h' : (min || 0) + 'm';
const Boss = {
    S: null,
    reset(o) { this.S = { page: o.page || 'dashboard', dash: null, emp: null, grades: [], q: '', prof: null, ptab: 'info', modal: null, log: [], hireList: [], rec: { kind: 'reward', reason: '' } }; this.load(); },
    async load() {
        const S = this.S;
        if (S.page === 'dashboard') { S.dash = await call('bossDash'); S.grades = (S.dash && S.dash.grades) || S.grades; }
        if (S.page === 'employees' || S.page === 'certs') { const r = await call('employees'); S.emp = (r && r.list) || []; S.grades = (r && r.grades) || S.grades; }
        if (S.page === 'finance' && !S.dash) S.dash = await call('bossDash');
        if (S.page === 'log') S.log = await call('bossLog') || [];
        if (App.panel === 'boss') render();
    },
    html() {
        const S = this.S, o = (App.init && App.init.officer) || {};
        const nav = [['dashboard', 'table-cells-large', 'Dashboard'], ['employees', 'users', 'Employee List', S.dash && S.dash.online], ['certs', 'certificate', 'Certifications'], ['finance', 'building-columns', 'Finance'], ['log', 'wave-square', 'Activity Log']];
        const titles = { dashboard: ['Management', 'Dashboard'], employees: ['Database', 'Employee List'], profile: ['Employee', 'Profile'], certs: ['Database', 'Certifications'], finance: ['Department', 'Finance'], log: ['Database', 'Activity Log'] };
        const [eb, tt] = titles[S.page];
        return `<div class="panel mdt boss">
            <div class="side">
                <div class="brand"><div class="logo"><i class="fa-solid fa-briefcase"></i></div><div><b>Management</b><span>${esc((o.jobLabel || 'POLICE').toUpperCase())}</span></div></div>
                <div class="nav"><div class="sep">DATABASE</div>
                    ${nav.map(([k, ic, l, c]) => `<div class="ni ${S.page === k || (k === 'employees' && S.page === 'profile') ? 'on' : ''}" data-a="bnav" data-p="${k}"><i class="fa-solid fa-${ic}"></i>${l}${c ? `<span class="count">${c}</span>` : ''}</div>`).join('')}
                    <div class="sep">APPS</div>
                    <div class="ni" data-a="app" data-p="mdt"><i class="fa-solid fa-shield-halved"></i>MDT</div>
                </div>
                <div class="me"><div class="avatar">${initials(o.name)}</div><div class="who"><b>${esc(o.name || '')}</b><span>${esc(o.grade || '')}</span></div></div>
            </div>
            <div class="main">
                <div class="topbar">
                    <div class="icon-btn" data-a="home" title="Home"><i class="fa-solid fa-house"></i></div>
                    ${S.page === 'profile' ? `<div class="icon-btn" data-a="bnav" data-p="employees"><i class="fa-solid fa-arrow-left"></i></div>` : ''}
                    <div class="tt"><div class="eyebrow">${eb}</div><div class="title">${tt}</div></div>
                    <div class="clock" id="clock"></div>
                    <div class="icon-btn" data-a="breload"><i class="fa-solid fa-rotate"></i></div>
                    <div class="icon-btn x" data-a="close"><i class="fa-solid fa-xmark"></i></div>
                </div>
                <div class="content">${this[S.page]()}</div>
            </div>
            ${S.modal ? this.modalHtml() : ''}
        </div>`;
    },
    gradeName(l) { const g = this.S.grades.find(x => x.level === l); return g ? g.name : l; },
    dashboard() {
        const d = this.S.dash, o = (App.init && App.init.officer) || {};
        if (!d) return `<div class="empty-state"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading...</div>`;
        const bars = (n) => `<div class="mini-bars">${[5, 9, 6, 12, 8, 14, 10, 18].map((h, i) => `<i style="height:${Math.max(3, h * (n ? 1 : .3))}px"></i>`).join('')}</div>`;
        const st = (ic, l, v, f, n) => `<div class="bstat"><div class="h"><span><i class="fa-solid fa-${ic}"></i>${l}</span></div><div class="v"><b>${v}</b>${bars(n)}</div><div class="f">${f}</div></div>`;
        return `<div class="welcome"><div class="avatar">${initials(o.name)}</div><div><b>Welcome back, ${esc((o.name || '').split(' ')[0].toUpperCase())}!</b><span>Manage your department and employees</span></div>
                <span style="flex:1"></span><button class="btn primary" data-a="hireOpen"><i class="fa-solid fa-user-plus"></i> Hire</button></div>
            <div class="grid3" style="grid-template-columns:repeat(4,1fr);margin-bottom:18px">
                ${st('users', 'Total employees', d.total, `<b>${d.total}</b> in the department`, d.total)}
                ${st('signal', 'Online employees', d.online, `<b>${d.online}</b> online now`, d.online)}
                ${st('clock', 'On duty', d.duty, `<b>${d.duty}</b> on duty`, d.duty)}
                ${st('building-columns', 'Society', d.balance == null ? '—' : money(d.balance), d.balance == null ? 'account not linked' : 'department account', 1)}
            </div>
            <div class="cols2">
                <div class="card"><h3><i class="fa-solid fa-users"></i>Online Employees<span class="sp"></span></h3>
                    ${d.onlineList.length ? `<table class="tbl"><tr><th>Name</th><th>Status</th><th>Rank</th><th>Callsign</th><th>Duty</th></tr>
                    ${d.onlineList.map(e => `<tr class="click" data-a="bprof" data-cid="${esc(e.cid)}"><td><div class="cell-who"><div class="avatar">${initials(e.name)}</div><div><b>${esc(e.name)}</b><div class="dim" style="font-size:10.5px">${esc(e.cid)}</div></div></div></td>
                        <td><span class="badge ok">● active</span></td><td>${esc(e.grade)}</td><td class="mono">${esc(e.callsign || '—')}</td>
                        <td>${e.duty ? '<span class="badge ok"><i class="fa-solid fa-calendar-check"></i> on duty</span>' : '<span class="badge">off duty</span>'}</td></tr>`).join('')}</table>` : '<div class="dim">Nobody online</div>'}
                </div>
                <div class="card"><h3><i class="fa-solid fa-bell"></i>Notification Center</h3>
                    <div class="feed">${d.log.map(l => `<div class="fi"><div class="ic"><i class="fa-solid fa-briefcase"></i></div><div class="tx">${esc(l.text)}<small>${esc(l.by)} · ${ago(l.t)}</small></div></div>`).join('') || '<div class="dim" style="text-align:center;padding:30px 0">No management activity recorded</div>'}</div></div>
            </div>`;
    },
    employees() {
        const S = this.S;
        if (!S.emp) return `<div class="empty-state"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading...</div>`;
        const q = S.q.toLowerCase();
        const rows = S.emp.filter(e => !q || e.name.toLowerCase().includes(q) || String(e.cid).toLowerCase().includes(q) || (e.callsign || '').toLowerCase().includes(q));
        return `<div class="search-bar"><div class="input grow"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Search employees..." value="${esc(S.q)}" data-in="bq"></div>
                <button class="btn primary" data-a="hireOpen"><i class="fa-solid fa-user-plus"></i> Hire</button></div>
            <table class="tbl"><tr><th>Name</th><th>Rank</th><th>Callsign</th><th>Status</th><th>Duty time</th><th>Rewards</th><th>Strikes</th><th></th></tr>
            ${rows.map(e => `<tr class="click" data-a="bprof" data-cid="${esc(e.cid)}">
                <td><div class="cell-who"><div class="avatar">${initials(e.name)}</div><div><b>${esc(e.name)}</b><div class="dim" style="font-size:10.5px">${esc(e.cid)}</div></div></div></td>
                <td><span class="badge accent">${esc(e.grade)}</span></td><td class="mono">${esc(e.callsign || '—')}</td>
                <td>${e.online ? (e.duty ? '<span class="badge ok">on duty</span>' : '<span class="badge info">online</span>') : '<span class="badge">offline</span>'}</td>
                <td class="mono">${fmtHours(e.dutyTotal)}</td><td style="color:var(--ok)" class="mono">+${e.rewards || 0}</td><td style="color:var(--bad)" class="mono">-${e.strikes || 0}</td>
                <td><i class="fa-solid fa-chevron-right dim"></i></td></tr>`).join('')}</table>`;
    },
    profile() {
        const S = this.S, p = S.prof;
        if (!p) return `<div class="empty-state"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading...</div>`;
        const tabs = [['info', 'circle-info', 'Information'], ['certs', 'certificate', 'Certifications'], ['rank', 'ranking-star', 'Rank & Actions']];
        let body = '';
        if (S.ptab === 'info') {
            const max = Math.max(1, ...Object.values(p.duty || {}));
            const lvl = (v) => !v ? '' : v / max > .75 ? 'l4' : v / max > .5 ? 'l3' : v / max > .25 ? 'l2' : 'l1';
            const peak = p.peak ? `${DAYS[Number(p.peak.split('_')[0])]} ${p.peak.split('_')[1]}:00` : '—';
            const rec = S.rec;
            body = `<div class="cols2" style="grid-template-columns:1fr 1.4fr">
                <div class="card"><h3><i class="fa-solid fa-award"></i>Reward &amp; Strike</h3>
                    <div class="rs-tot"><div><span><i class="fa-solid fa-trophy"></i> Total Reward</span><b style="color:var(--ok)">+${p.rewards.length}</b></div><div><span><i class="fa-solid fa-triangle-exclamation"></i> Total Strike</span><b style="color:var(--bad)">-${p.strikes.length}</b></div></div>
                    <div class="subtabs"><div class="st ${rec.kind === 'reward' ? 'on' : ''}" data-a="recKind" data-k="reward" style="${rec.kind === 'reward' ? 'color:var(--ok)' : ''}"><i class="fa-solid fa-trophy"></i> Reward</div><div class="st ${rec.kind === 'strike' ? 'on' : ''}" data-a="recKind" data-k="strike" style="${rec.kind === 'strike' ? 'color:var(--bad)' : ''}"><i class="fa-solid fa-triangle-exclamation"></i> Strike</div></div>
                    <div class="row"><div class="input grow"><input placeholder="Reason..." value="${esc(rec.reason)}" data-in="recReason" data-enter="recAdd"></div><button class="btn ${rec.kind === 'strike' ? 'danger' : 'ok'}" data-a="recAdd"><i class="fa-solid fa-plus"></i></button></div>
                    <div class="feed" style="margin-top:10px;max-height:150px;overflow:auto">${p.rewards.map(r => ({ ...r, k: 'r' })).concat(p.strikes.map(r => ({ ...r, k: 's' }))).sort((a, b) => b.t - a.t).map(r => `<div class="fi"><div class="ic" style="color:${r.k === 'r' ? 'var(--ok)' : 'var(--bad)'}"><i class="fa-solid fa-${r.k === 'r' ? 'trophy' : 'triangle-exclamation'}"></i></div><div class="tx">${esc(r.reason)}<small>${esc(r.by)} · ${ago(r.t)}</small></div></div>`).join('') || '<div class="dim" style="text-align:center;padding:14px">No records</div>'}</div>
                </div>
                <div class="card"><h3><i class="fa-solid fa-chart-simple"></i>Activity Overview</h3>
                    <div class="grid3" style="grid-template-columns:repeat(4,1fr);margin-bottom:14px">
                        <div class="sum"><span>Total duty</span><b>${fmtHours(p.dutyTotal)}</b></div><div class="sum"><span>Peak hour</span><b style="font-size:16px">${peak}</b></div>
                        <div class="sum"><span>Status</span><b style="font-size:16px;color:${p.online ? 'var(--ok)' : 'var(--dim)'}">${p.online ? (p.duty ? 'On duty' : 'Online') : 'Offline'}</b></div><div class="sum"><span>Last duty</span><b style="font-size:16px">${p.lastDuty ? ago(p.lastDuty) : '—'}</b></div>
                    </div>
                    <div class="heat"><span></span>${Array.from({ length: 24 }, (_, h) => `<span class="hl">${h % 2 ? '' : String(h).padStart(2, '0')}</span>`).join('')}
                        ${[1, 2, 3, 4, 5, 6, 0].map(d => `<span>${DAYS[d]}</span>${Array.from({ length: 24 }, (_, h) => { const v = (p.duty || {})[d + '_' + h] || 0; return `<i class="c ${lvl(v)}" title="${DAYS[d]} ${h}:00 · ${v} min"></i>`; }).join('')}`).join('')}</div>
                    <div class="legend">Less <i class="c" style="background:#1c1c21"></i><i class="c heat l1" style="background:rgba(var(--accent-rgb),.25)"></i><i class="c" style="background:rgba(var(--accent-rgb),.5)"></i><i class="c" style="background:rgba(var(--accent-rgb),.75)"></i><i class="c" style="background:var(--accent)"></i> More</div>
                </div></div>
                <div class="card"><h3><i class="fa-solid fa-note-sticky"></i>Notes<span class="sp"></span><button class="btn sm" data-a="saveStaff"><i class="fa-solid fa-floppy-disk"></i> Save</button></h3>
                    <div class="input"><textarea data-in="snotes" placeholder="Supervisor notes...">${esc(p.notes || '')}</textarea></div></div>`;
        } else if (S.ptab === 'certs') {
            body = `<div class="cert-grid">${(App.init.certifications || []).map(c => { const on = p.certs && p.certs[c.key]; return `<div class="cert ${on ? 'on' : ''}" data-a="cert" data-k="${c.key}"><div class="ci"><i class="fa-solid fa-${c.icon}"></i></div><b>${esc(c.label)}</b><span>${on ? 'Granted by ' + esc(on.by) + ' · ' + ago(on.t) : 'Not certified'}</span></div>`; }).join('')}</div>`;
        } else {
            body = `<div class="cols2" style="grid-template-columns:1.4fr 1fr"><div class="card"><h3><i class="fa-solid fa-ranking-star"></i>Rank</h3>
                    <div class="list-rows">${(p.grades || S.grades).slice().reverse().map(g => `<div class="rowcard click ${g.level === p.gradeLevel ? 'sel' : ''}" data-a="setGrade" data-l="${g.level}"><div class="avatar" style="width:28px;height:28px;font-size:11px">${g.level}</div><div class="who"><b>${esc(g.name)}</b><span>${g.payment != null ? money(g.payment) + ' / paycheck' : ''}</span></div>${g.level === p.gradeLevel ? '<span class="badge accent">current</span>' : '<span class="btn sm">Set</span>'}</div>`).join('')}</div></div>
                <div class="card"><h3><i class="fa-solid fa-user-xmark" style="color:var(--bad)"></i>Danger Zone</h3><p class="muted" style="margin-bottom:14px;line-height:1.5">Firing removes ${esc(p.name)} from the police department. This can't be undone from here.</p>
                    <button class="btn danger" style="width:100%" data-a="fire"><i class="fa-solid fa-user-xmark"></i> Fire Employee</button></div></div>`;
        }
        return `<div class="banner"></div>
            <div class="prof"><div class="avatar lg">${initials(p.name)}<span class="on-dot ${p.online ? 'on' : ''}"></span></div>
                <div style="flex:1;padding-bottom:6px"><div class="nm">${esc(p.name)}</div><div class="dim">${esc(p.grade)} · ${esc(p.cid)}</div></div>
                <div class="row" style="padding-bottom:6px"><div class="input" style="width:130px"><i class="fa-solid fa-hashtag"></i><input value="${esc(p.callsign || '')}" placeholder="Callsign" data-in="callsign" data-enter="saveStaff"></div><button class="btn" data-a="saveStaff"><i class="fa-solid fa-pen"></i> Edit Profile</button></div></div>
            <div class="kv" style="grid-template-columns:repeat(6,1fr)">
                <div><span>Department</span><b>${esc((App.init.officer || {}).jobLabel || 'Police')}</b></div><div><span>Rank</span><b>${esc(p.grade)}</b></div>
                <div><span>Phone number</span><b>${esc(p.phone || '—')}</b></div><div><span>Callsign</span><b class="mono">${esc(p.callsign || '—')}</b></div>
                <div><span>Last duty</span><b>${p.online ? 'Online' : (p.lastDuty ? ago(p.lastDuty) : '—')}</b></div><div><span>Officer ID</span><b class="mono">${esc(p.cid)}</b></div></div>
            <div class="tabs" style="padding:0;margin-bottom:16px">${tabs.map(([k, ic, l]) => `<div class="tab ${S.ptab === k ? 'on' : ''}" data-a="bptab" data-t="${k}" style="flex:none;padding:10px 16px"><i class="fa-solid fa-${ic}"></i> ${l}</div>`).join('')}</div>
            ${body}`;
    },
    certs() {
        const S = this.S, certs = (App.init && App.init.certifications) || [];
        if (!S.emp) return `<div class="empty-state"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading...</div>`;
        return `<div class="card"><h3><i class="fa-solid fa-certificate"></i>Certification Matrix<span class="sp"></span><span class="dim" style="text-transform:none;letter-spacing:0;font-weight:600">open a profile to grant</span></h3>
            <table class="tbl matrix"><tr><th>Employee</th>${certs.map(c => `<th style="text-align:center"><i class="fa-solid fa-${c.icon}"></i><br>${esc(c.label)}</th>`).join('')}</tr>
            ${S.emp.map(e => `<tr class="click" data-a="bprof" data-cid="${esc(e.cid)}"><td><div class="cell-who"><div class="avatar">${initials(e.name)}</div><b>${esc(e.name)}</b></div></td>${certs.map(c => `<td class="cc ${(e.certs || {})[c.key] ? 'on' : ''}"><i class="fa-solid fa-circle-check"></i></td>`).join('')}</tr>`).join('')}</table></div>`;
    },
    finance() {
        const d = this.S.dash || {};
        return `<div class="cols2"><div class="card" style="padding:26px"><h3><i class="fa-solid fa-building-columns"></i>Department Account</h3>
                <div class="balance">${d.balance == null ? '—' : money(d.balance)}</div><div class="dim" style="margin-top:8px">${d.balance == null ? 'No society account found (qb-banking / qb-management / Renewed-Banking / esx_society)' : 'Society: ' + esc((App.init.officer || {}).jobLabel || 'police')}</div></div>
            <div class="card"><h3><i class="fa-solid fa-money-bill-transfer"></i>Transfer</h3>
                <div class="field"><div class="lbl"><span>Amount</span></div><div class="input"><i class="fa-solid fa-dollar-sign"></i><input type="number" placeholder="0" data-in="famount"></div></div>
                <div class="grid2"><button class="btn ok" data-a="fmove" data-k="deposit"><i class="fa-solid fa-arrow-down"></i> Deposit</button><button class="btn primary" data-a="fmove" data-k="withdraw"><i class="fa-solid fa-arrow-up"></i> Withdraw</button></div></div></div>`;
    },
    log() {
        return `<div class="card"><div class="feed">${this.S.log.map(l => `<div class="fi"><div class="ic"><i class="fa-solid fa-briefcase"></i></div><div class="tx">${esc(l.text)}<small>${esc(l.by)} · ${fmtDate(l.t)}</small></div></div>`).join('') || '<div class="empty-state"><i class="fa-solid fa-wave-square"></i>No management activity recorded</div>'}</div></div>`;
    },
    modalHtml() {
        const S = this.S;
        return `<div class="modal-back"><div class="modal"><h3><i class="fa-solid fa-user-plus"></i>Hire Employee<span style="flex:1"></span><span class="icon-btn" data-a="modalClose" style="width:28px;height:28px"><i class="fa-solid fa-xmark"></i></span></h3>
            <div class="lbl"><span>Nearby players</span></div>
            <div class="list-rows" style="margin-bottom:14px">${S.hireList.map(p => `<div class="rowcard click ${S.modal.id === p.id ? 'sel' : ''}" data-a="hirePick" data-id="${p.id}"><div class="avatar">${initials(p.name)}</div><div class="who"><b>${esc(p.name)}</b><span>ID ${p.id} · ${p.dist}m</span></div></div>`).join('') || '<div class="dim" style="padding:10px">Nobody nearby</div>'}</div>
            <div class="lbl"><span>Rank</span></div>
            <div class="input" style="margin-bottom:16px"><select data-in="hireGrade">${S.grades.filter(g => g.level < ((App.init.officer || {}).gradeLevel ?? 99)).map(g => `<option value="${g.level}" ${Number(S.modal.grade) === g.level ? 'selected' : ''}>${esc(g.name)}</option>`).join('')}</select></div>
            <button class="btn primary block" data-a="hireGo"><i class="fa-solid fa-user-plus"></i> Hire</button></div></div>`;
    },
    after() { MDT.after(); },
    handlers: {},
};
Object.assign(Boss.handlers, {
    bnav(el) { Boss.S.page = el.dataset.p; Boss.S.prof = null; render(); Boss.load(); },
    breload() { Boss.load(); if (Boss.S.page === 'profile') Boss.handlers.bprof({ dataset: { cid: Boss.S.prof.cid } }); },
    'in:bq'(el) { Boss.S.q = el.value; render(); refocus('[data-in="bq"]'); },
    async bprof(el) { Boss.S.page = 'profile'; Boss.S.ptab = Boss.S.ptab || 'info'; Boss.S.prof = null; render(); Boss.S.prof = await call('employee', { cid: el.dataset.cid }); if (Boss.S.prof && Boss.S.prof.grades) Boss.S.grades = Boss.S.prof.grades; render(); },
    bptab(el) { Boss.S.ptab = el.dataset.t; render(); },
    recKind(el) { Boss.S.rec.kind = el.dataset.k; render(); },
    'in:recReason'(el) { Boss.S.rec.reason = el.value; },
    async recAdd() { const p = Boss.S.prof; if (result(await call('addRecord', { cid: p.cid, kind: Boss.S.rec.kind, reason: Boss.S.rec.reason }))) { Boss.S.rec.reason = ''; Boss.handlers.bprof({ dataset: { cid: p.cid } }); } },
    'in:snotes'(el) { Boss.S.prof.notes = el.value; },
    'in:callsign'(el) { Boss.S.prof.callsign = el.value.toUpperCase(); },
    async saveStaff() { const p = Boss.S.prof; if (result(await call('saveStaff', { cid: p.cid, callsign: p.callsign, notes: p.notes }), 'Saved')) render(); },
    async cert(el) { const p = Boss.S.prof, k = el.dataset.k, on = !(p.certs && p.certs[k]); if ((await call('setCert', { cid: p.cid, key: k, on })).ok) { toast(on ? 'Certification granted' : 'Certification removed', 'success'); Boss.handlers.bprof({ dataset: { cid: p.cid } }); } },
    async setGrade(el) { const p = Boss.S.prof, l = Number(el.dataset.l); if (l === p.gradeLevel) return; if (result(await call('setGrade', { cid: p.cid, grade: l }))) Boss.handlers.bprof({ dataset: { cid: p.cid } }); },
    async fire() { const p = Boss.S.prof; if (result(await call('fire', { cid: p.cid }))) { Boss.S.page = 'employees'; Boss.S.prof = null; Boss.load(); } },
    async hireOpen() { Boss.S.modal = { id: null, grade: 0 }; Boss.S.hireList = []; render(); Boss.S.hireList = await call('nearby') || []; if (Boss.S.modal) render(); },
    modalClose() { Boss.S.modal = null; render(); },
    hirePick(el) { Boss.S.modal.id = Number(el.dataset.id); render(); },
    'in:hireGrade'(el) { Boss.S.modal.grade = Number(el.value); },
    async hireGo() { const m = Boss.S.modal; if (!m.id) return toast('Pick a player', 'error'); if (result(await call('hire', { id: m.id, grade: m.grade || 0 }))) { Boss.S.modal = null; Boss.load(); } },
    'in:famount'(el) { Boss.S.famount = el.value; },
    async fmove(el) { const r = await call('society', { action: el.dataset.k, amount: Number(Boss.S.famount) }); if (result(r)) { Boss.S.dash.balance = r.balance; render(); } },
});

/* =====================================================================
   IMPOUND / DEPOT (side panel)
   ===================================================================== */
const Impound = {
    S: null,
    reset(o) { this.S = { step: 'choose', mode: 'impound', v: o.vehicle || {}, price: 0, hours: 0, reason: '', busy: false }; },
    html() {
        const S = this.S, v = S.v, I = (App.init && App.init.impound) || { price: 500, maxPrice: 50000, maxHours: 72 };
        const head = (t, sub) => `<div class="sp-head"><div style="width:28px"></div><div class="sp-title"><small>${sub}</small>${t}</div><div class="sp-x" data-a="close"><i class="fa-solid fa-xmark"></i></div></div>`;
        const card = `<div class="veh-card"><div class="top"><span class="plate">${esc(v.plate || '—')}</span><div><div class="model">${esc(v.model || 'Vehicle')}</div><div class="owner"><i class="fa-solid fa-user"></i> ${esc(v.owner || (v.registered === false ? 'Not registered' : 'Unknown owner'))}</div></div></div>
            <div class="chips">${v.registered ? '<span class="badge ok">registered</span>' : '<span class="badge warn">unregistered</span>'}${v.stolen ? '<span class="badge bad">stolen</span>' : ''}${v.hold ? '<span class="badge accent">already on hold</span>' : ''}</div></div>`;
        let body;
        if (S.step === 'choose') {
            body = `${card}
                <div class="opt-card ${S.mode === 'impound' ? 'on' : ''}" data-a="imode" data-m="impound"><div class="oi"><i class="fa-solid fa-truck-pickup"></i></div><div><b>Impound</b><span>Sends the vehicle to the regular impound, the player can retrieve it quickly for ${money(I.price)}.</span></div></div>
                <div class="opt-card ${S.mode === 'depot' ? 'on' : ''}" data-a="imode" data-m="depot"><div class="oi"><i class="fa-solid fa-warehouse"></i></div><div><b>Depot</b><span>Police hold, the vehicle is held for a set time or fine.</span></div></div>
                <div class="sp-actions" style="margin-top:6px"><button class="sp-btn" data-a="close">Cancel</button><button class="sp-btn go" data-a="inext">Continue</button></div>`;
            return `<div class="side-wrap"><div class="spn">${head('Impound/Depot<br>Vehicle', 'Police · Vehicle')}<div class="sp-body">${body}</div><div class="sp-foot">ROX STORE</div></div></div>`;
        }
        const pct = (x, m) => (m ? x / m * 100 : 0) + '%';
        body = `${card}<div class="sp-form">
            ${S.mode === 'depot' ? `
            <div class="field"><div class="lbl"><span>Depot price<span class="req">*</span></span></div><div class="input"><i class="fa-solid fa-dollar-sign"></i><input type="number" min="0" max="${I.maxPrice}" value="${S.price}" data-in="iprice"></div></div>
            <div class="field"><div class="lbl"><span>Release in (hours)<span class="req">*</span></span><b class="mono" id="hrsV" style="color:var(--accent);font-size:14px;letter-spacing:0">${S.hours}h</b></div>
                <input type="range" class="range" min="0" max="${I.maxHours}" value="${S.hours}" style="--p:${pct(S.hours, I.maxHours)}" data-in="ihours"><div class="range-v"><span>0</span><span>${I.maxHours}h</span></div></div>`
            : `<div class="summary" style="margin-bottom:14px"><div class="sum"><span>Impound fee</span><b class="m">${money(I.price)}</b></div><div class="sum"><span>Hold</span><b class="t">None</b></div></div>`}
            <div class="field" style="margin-bottom:0"><div class="lbl"><span>Reason</span></div><div class="input"><i class="fa-solid fa-pen"></i><input placeholder="Illegally parked, evidence..." value="${esc(S.reason)}" data-in="ireason"></div></div>
        </div>
        ${S.busy ? `<div class="sp-progress"><i></i></div><div class="dim" style="text-align:center;font-size:11px;letter-spacing:2px">PROCESSING...</div>` : `<div class="sp-actions"><button class="sp-btn" data-a="iback">Cancel</button><button class="sp-btn go" data-a="iconfirm">Confirm</button></div>`}`;
        return `<div class="side-wrap"><div class="spn">${head(S.mode === 'depot' ? 'Depot<br>Vehicle' : 'Impound<br>Vehicle', 'Police · Vehicle')}<div class="sp-body">${body}</div><div class="sp-foot">ROX STORE</div></div></div>`;
    },
    handlers: {},
};
Object.assign(Impound.handlers, {
    imode(el) { Impound.S.mode = el.dataset.m; render(); },
    inext() { Impound.S.step = 'form'; render(); },
    iback() { Impound.S.step = 'choose'; render(); },
    'in:iprice'(el) { Impound.S.price = Number(el.value) || 0; },
    'in:ihours'(el) { const I = App.init.impound || { maxHours: 72 }; Impound.S.hours = Number(el.value); el.style.setProperty('--p', (Impound.S.hours / I.maxHours * 100) + '%'); $('#hrsV').textContent = Impound.S.hours + 'h'; },
    'in:ireason'(el) { Impound.S.reason = el.value; },
    async iconfirm() {
        const S = Impound.S;
        S.busy = true; render();
        const r = await call('impound', { plate: S.v.plate, mode: S.mode, price: S.price, hours: S.hours, reason: S.reason, model: S.v.model, owner: S.v.owner });
        S.busy = false;
        if (result(r)) { if (!RES) closeAll(); } else render();
    },
});

/* =====================================================================
   REMOVE MASK / HAT / GLASSES (side panel)
   ===================================================================== */
const Strip = {
    S: null,
    reset(o) {
        this.S = { list: null, sel: o.target || null, items: {} };
        call('nearby').then(l => { this.S.list = l || []; if (!this.S.sel && this.S.list[0]) this.S.sel = this.S.list[0].id; this.preselect(); if (App.panel === 'strip') render(); });
    },
    preselect() { const p = (this.S.list || []).find(x => x.id === this.S.sel); this.S.items = {}; if (p) (App.init.accessories || []).forEach(a => { if (p[a.key]) this.S.items[a.key] = true; }); },
    html() {
        const S = this.S, acc = (App.init && App.init.accessories) || [];
        const p = (S.list || []).find(x => x.id === S.sel);
        const list = S.list === null ? `<div class="dim" style="text-align:center"><i class="fa-solid fa-circle-notch fa-spin"></i></div>`
            : S.list.length ? S.list.map(x => `<div class="person-opt ${x.id === S.sel ? 'on' : ''}" data-a="spick" data-id="${x.id}"><div class="avatar">${initials(x.name)}</div><div class="who"><b>${esc(x.name)}</b><span>ID ${x.id} · ${x.dist}m</span></div>
                <div class="wear">${acc.map(a => `<i class="fa-solid fa-${a.icon} ${x[a.key] ? 'on' : ''}" title="${a.label}"></i>`).join('')}</div></div>`).join('')
            : `<div class="veh-card" style="text-align:center;color:var(--muted)"><i class="fa-solid fa-user-slash" style="font-size:22px"></i>Nobody close to you</div>`;
        return `<div class="side-wrap"><div class="spn">
            <div class="sp-head"><div style="width:28px"></div><div class="sp-title"><small>Police · Suspect</small>Remove<br>Accessories</div><div class="sp-x" data-a="close"><i class="fa-solid fa-xmark"></i></div></div>
            <div class="sp-body">${list}
                ${p ? `<div class="sp-form"><div class="lbl"><span>What to remove</span></div><div class="acc-grid">${acc.map(a => `<div class="acc ${S.items[a.key] ? 'on' : ''} ${p[a.key] ? '' : 'off'}" data-a="sacc" data-k="${a.key}"><i class="fa-solid fa-${a.icon}"></i>${esc(a.label)}<small>${p[a.key] ? 'WEARING' : 'NONE'}</small></div>`).join('')}</div></div>
                <div class="sp-actions"><button class="sp-btn" data-a="close">Cancel</button><button class="sp-btn go" data-a="sgo">Remove</button></div>` : ''}
            </div><div class="sp-foot">ROX STORE</div></div></div>`;
    },
    handlers: {},
};
Object.assign(Strip.handlers, {
    spick(el) { Strip.S.sel = Number(el.dataset.id); Strip.preselect(); render(); },
    sacc(el) { const k = el.dataset.k; Strip.S.items[k] = !Strip.S.items[k]; el.classList.toggle('on'); },
    async sgo() {
        const S = Strip.S;
        const r = await call('strip', { id: S.sel, items: S.items });
        if (result(r)) { const p = S.list.find(x => x.id === S.sel); Object.keys(S.items).forEach(k => { if (S.items[k]) p[k] = false; }); S.items = {}; render(); }
    },
});

/* ---------- jail hud ---------- */
const Hud = { el: $('#jailHud'), t: null, data: null };
function jailHud(show, data) {
    clearInterval(Hud.t);
    if (!show) { Hud.el.classList.remove('show'); Hud.el.innerHTML = ''; return; }
    Hud.data = data;
    const draw = () => {
        const d = Hud.data;
        Hud.el.innerHTML = `<div class="box"><div class="ic"><i class="fa-solid fa-building-shield"></i></div>
            <div><div class="lb">${esc(d.label)} · ${d.life ? 'life sentence' : 'time remaining'}</div><div class="time">${d.life ? '∞' : fmtDur(d.remaining)}</div>
            ${d.life ? '' : `<div class="progress"><i style="width:${Math.max(0, 100 - d.remaining / Math.max(1, d.total) * 100)}%"></i></div>`}</div>
            ${d.bail ? `<div class="bail">Bail <b>${money(d.bail)}</b><br>/${esc(d.paybail || 'paybail')}</div>` : ''}</div>`;
    };
    draw();
    Hud.el.classList.add('show');
    Hud.t = setInterval(() => { if (!Hud.data.life && Hud.data.remaining > 0) Hud.data.remaining--; draw(); }, 1000);
}

/* ---------- messages ---------- */
window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
        if (d.color) setColor(d.color);
        if (d.init) App.init = d.init;
        App.open = true;
        backdrop.classList.add('show');
        openPanel(d.panel || 'mdt', d.opts || {});
    } else if (d.action === 'close') closeAll(true);
    else if (d.action === 'toast') toast(d.msg, d.kind);
    else if (d.action === 'jailHud') jailHud(d.show, d.data);
});

/* =====================================================================
   BROWSER PREVIEW (mock server)
   ===================================================================== */
const Mock = {
    now: () => Math.floor(Date.now() / 1000),
    db: null,
    seed() {
        const n = this.now();
        const charges = [
            ['Traffic', 'Speeding', 500, 0], ['Traffic', 'Reckless Driving', 1500, 0], ['Traffic', 'Running a Red Light', 350, 0], ['Traffic', 'Illegal Parking', 200, 0],
            ['Traffic', 'Driving Without License', 800, 0], ['Traffic', 'Hit and Run', 2500, 10], ['Traffic', 'Evading Police', 3000, 15],
            ['Criminal', 'Assault', 2000, 10], ['Criminal', 'Robbery', 5000, 25], ['Criminal', 'Armed Robbery', 8000, 35], ['Criminal', 'Bank Robbery', 15000, 60],
            ['Criminal', 'Murder', 30000, 120], ['Criminal', 'Grand Theft Auto', 4000, 15], ['Criminal', 'Drug Trafficking', 8000, 30], ['Criminal', 'Illegal Weapon', 5000, 20],
            ['Public', 'Disturbing the Peace', 400, 0], ['Public', 'Resisting Arrest', 1500, 10], ['Public', 'Obstruction of Justice', 2000, 10],
        ].map(([cat, label, fine, time]) => ({ cat, label, fine, time }));
        App.init = {
            officer: { name: 'Dev Hkmi', grade: 'Captain', jobLabel: 'LSPD', duty: true, gradeLevel: 4, cid: 'RX10001' }, charges, boss: true,
            certifications: [['firearms', 'Firearms', 'gun'], ['pursuit', 'Pursuit Driving', 'car-burst'], ['k9', 'K9 Unit', 'dog'], ['air', 'Air Unit', 'helicopter'], ['swat', 'SWAT', 'user-ninja'], ['detective', 'Detective', 'user-secret'], ['traffic', 'Traffic Unit', 'motorcycle'], ['fto', 'Field Training', 'chalkboard-user']].map(([key, label, icon]) => ({ key, label, icon })),
            accessories: [['mask', 'Mask', 'masks-theater'], ['hat', 'Hat', 'hat-cowboy'], ['glasses', 'Glasses', 'glasses'], ['bag', 'Bag', 'bag-shopping']].map(([key, label, icon]) => ({ key, label, icon })),
            impound: { price: 500, maxPrice: 50000, maxHours: 72 },
            jailTypes: [{ key: 'prison', label: 'Prison', icon: 'building-shield' }, { key: 'cell', label: 'Holding Cell', icon: 'door-closed' }],
            presets: [5, 10, 15, 30, 60], maxMinutes: 300, stats: {},
        };
        this.players = [
            { id: 824, name: 'Faisal Al-Harbi', cid: 'RX48213', phone: '555-0182', dob: '1996-04-12', job: 'Mechanic', dist: 2.1, mask: true, hat: true, glasses: false, bag: true },
            { id: 512, name: 'Omar Nasser', cid: 'RX11902', phone: '555-0341', dob: '1999-09-01', job: 'Unemployed', dist: 4.6, mask: false, hat: false, glasses: true, bag: false },
            { id: 77, name: 'Sara Khalid', cid: 'RX77310', phone: '555-0777', dob: '2001-01-23', job: 'Taxi', dist: 5.8, mask: false, hat: true, glasses: true, bag: false },
        ];
        this.db = {
            seq: 20,
            prisoners: { RX11902: { cid: 'RX11902', name: 'Omar Nasser', type: 'prison', typeLabel: 'Prison', life: false, total: 1800, remaining: 1134, charges: ['Armed Robbery', 'Evading Police', 'Resisting Arrest'], bail: 12000, officer: 'Dev Hkmi', at: n - 700, online: true },
                         RX90001: { cid: 'RX90001', name: 'Majed Turki', type: 'prison', typeLabel: 'Prison', life: true, total: 0, remaining: 0, charges: ['Murder'], bail: 0, officer: 'Noura Saad', at: n - 86000, online: false } },
            fines: [
                { id: 11, cid: 'RX48213', name: 'Faisal Al-Harbi', charges: ['Speeding', 'Running a Red Light'], amount: 850, paid: true, officer: 'Dev Hkmi', plate: '20HRX818', t: n - 3600 },
                { id: 14, cid: 'RX77310', name: 'Sara Khalid', charges: ['Illegal Parking'], amount: 200, paid: false, officer: 'Noura Saad', t: n - 9000 },
            ],
            warrants: [{ id: 15, cid: 'RX48213', name: 'Faisal Al-Harbi', reason: 'Wanted for questioning in the Fleeca bank robbery', danger: 'high', active: true, officer: 'Noura Saad', t: n - 5000 },
                       { id: 9, name: 'Unknown male, red hoodie', reason: 'Shots fired at Grove St', danger: 'medium', active: true, officer: 'Dev Hkmi', t: n - 20000 }],
            reports: [{ id: 12, title: 'Fleeca bank robbery — Vespucci Blvd', kind: 'Robbery', location: 'Vespucci Blvd', involved: 'Faisal Al-Harbi, Omar Nasser', body: 'Two suspects entered the bank at 14:20 armed with pistols.\nOne suspect was arrested after a short pursuit, the second fled north in a black Sultan.', officer: 'Dev Hkmi', t: n - 4000 }],
            bolos: [{ id: 16, title: 'Black Sultan fleeing north', plate: '82KLM203', body: 'Second robbery suspect, armed. Last seen on Route 68.', active: true, officer: 'Dev Hkmi', t: n - 3900 }],
            activity: [
                { t: n - 700, kind: 'jail', text: 'Omar Nasser sent to Prison for 30 min', officer: 'Dev Hkmi' },
                { t: n - 3600, kind: 'fine', text: 'Faisal Al-Harbi fined $850 (paid)', officer: 'Dev Hkmi' },
                { t: n - 3900, kind: 'bolo', text: 'BOLO: Black Sultan fleeing north', officer: 'Dev Hkmi' },
                { t: n - 4000, kind: 'report', text: 'Report #12: Fleeca bank robbery — Vespucci Blvd', officer: 'Dev Hkmi' },
                { t: n - 5000, kind: 'warrant', text: 'Warrant issued for Faisal Al-Harbi', officer: 'Noura Saad' },
            ],
            people: { RX48213: { flags: ['Armed'], notes: 'Known associate of the Vespucci crew.' } },
            holds: { '82KLM203': { plate: '82KLM203', model: 'Karin Sultan', owner: 'Omar Nasser', price: 7500, hours: 24, releaseAt: n + 72000, reason: 'Used in Fleeca robbery — evidence', officer: 'Dev Hkmi', t: n - 14400 } },
            impounds: [
                { plate: '44XYZ019', mode: 'impound', price: 500, hours: 0, reason: 'Illegally parked', model: 'Declasse Vigero', owner: 'Sara Khalid', officer: 'Noura Saad', t: n - 50000 },
                { plate: '82KLM203', mode: 'depot', price: 7500, hours: 24, reason: 'Used in Fleeca robbery — evidence', model: 'Karin Sultan', owner: 'Omar Nasser', officer: 'Dev Hkmi', t: n - 14400 },
                { plate: '20HRX818', mode: 'impound', price: 500, hours: 0, reason: 'Abandoned on the highway', model: 'Karin Sultan RS', owner: 'Faisal Al-Harbi', officer: 'Khalid Al-Otaibi', t: n - 3000 },
            ],
            balance: 284500,
            bossLog: [{ t: n - 1800, text: 'Noura Saad rank set to Sergeant', by: 'Dev Hkmi' }, { t: n - 7200, text: 'Reward for Khalid Al-Otaibi: Excellent pursuit on Route 68', by: 'Dev Hkmi' }, { t: n - 90000, text: 'Yazeed Fahad hired as Recruit', by: 'Dev Hkmi' }],
            staff: (() => {
                const heat = (seed) => { const o = {}; for (let d = 0; d < 7; d++) for (let h = 0; h < 24; h++) { const v = Math.floor(Math.max(0, Math.sin((h + seed) / 3.2) * 60 + (d % 3) * 8 - 18)); if (v > 0 && (h > 14 || h < 2)) o[d + '_' + h] = v; } return o; };
                return [
                    { cid: 'RX10001', name: 'Dev Hkmi', gradeLevel: 4, grade: 'Captain', callsign: '1-ADAM', online: true, duty: true, phone: '1130376829', dutyTotal: 5230, rewards: [{ t: n - 400000, reason: 'Leadership during bank heist', by: 'Chief' }], strikes: [], certs: { firearms: { t: n - 900000, by: 'Chief' }, swat: { t: n - 800000, by: 'Chief' }, air: { t: n - 500000, by: 'Chief' } }, duty: heat(0), lastDuty: n },
                    { cid: 'RX20442', name: 'Noura Saad', gradeLevel: 2, grade: 'Sergeant', callsign: '2-LINCOLN', online: true, duty: true, phone: '1130344120', dutyTotal: 3110, rewards: [], strikes: [], certs: { firearms: { t: n - 600000, by: 'Dev Hkmi' }, detective: { t: n - 300000, by: 'Dev Hkmi' } }, duty: heat(4), lastDuty: n },
                    { cid: 'RX31877', name: 'Khalid Al-Otaibi', gradeLevel: 1, grade: 'Officer', callsign: '3-MARY', online: true, duty: false, phone: '1130311092', dutyTotal: 1880, rewards: [{ t: n - 7200, reason: 'Excellent pursuit on Route 68', by: 'Dev Hkmi' }], strikes: [{ t: n - 200000, reason: 'Late to briefing', by: 'Noura Saad' }], certs: { pursuit: { t: n - 100000, by: 'Dev Hkmi' } }, duty: heat(8), lastDuty: n - 3600 },
                    { cid: 'RX40210', name: 'Yazeed Fahad', gradeLevel: 0, grade: 'Recruit', callsign: '', online: false, duty: false, phone: '1130399001', dutyTotal: 240, rewards: [], strikes: [], certs: {}, duty: heat(12), lastDuty: n - 90000 },
                ];
            })(),
            grades: [{ level: 0, name: 'Recruit', payment: 50 }, { level: 1, name: 'Officer', payment: 75 }, { level: 2, name: 'Sergeant', payment: 100 }, { level: 3, name: 'Lieutenant', payment: 125 }, { level: 4, name: 'Captain', payment: 150 }, { level: 5, name: 'Chief', payment: 200 }],
            vehicles: { '71BRV552': { stolen: true, model: 'Bravado Buffalo', owner: 'Mohammed Ali', notes: 'Stolen from Legion Square parking' } },
        };
    },
    async call(a, d) {
        await new Promise(r => setTimeout(r, 120));
        const db = this.db, n = this.now(), P = this.players, byId = (id) => P.find(p => p.id === Number(id));
        const charge = (l) => App.init.charges.find(c => c.label === l);
        const log = (kind, text) => db.activity.unshift({ t: n, kind, text, officer: 'Dev Hkmi' });
        switch (a) {
            case 'nearby': return P.map(p => ({ id: p.id, name: p.name, dist: p.dist, mask: p.mask, hat: p.hat, glasses: p.glasses, bag: p.bag }));
            case 'strip': { const p = byId(d.id); Object.keys(d.items).forEach(k => { if (d.items[k]) p[k] = false; }); return { ok: true, msg: `Removed ${Object.keys(d.items).filter(k => d.items[k]).join(', ')} from ${p.name}` }; }
            case 'impound': db.impounds.push({ plate: d.plate, mode: d.mode, price: d.price, hours: d.hours, reason: d.reason, model: d.model, owner: d.owner, officer: 'Dev Hkmi', t: n }); if (d.mode === 'depot') db.holds[d.plate] = { plate: d.plate, price: d.price, hours: d.hours, releaseAt: n + d.hours * 3600, reason: d.reason, officer: 'Dev Hkmi', t: n }; return { ok: true, msg: d.mode === 'depot' ? `Vehicle ${d.plate} held for ${d.hours}h` : `Vehicle ${d.plate} impounded` };
            case 'vehicleOverview': return { today: 2, total: db.impounds.length, recent: db.impounds.slice().reverse(), holds: Object.values(db.holds).map(h => ({ ...h, remaining: Math.max(0, h.releaseAt - n) })), flagged: Object.entries(db.vehicles).filter(([, v]) => v.stolen).map(([plate, v]) => ({ plate, ...v })) };
            case 'holds': return Object.values(db.holds).map(h => ({ ...h, remaining: Math.max(0, h.releaseAt - n) }));
            case 'releaseHold': delete db.holds[d.plate]; return { ok: true, msg: d.plate + ' released' };
            case 'bossDash': { const on = db.staff.filter(e => e.online); return { total: db.staff.length, online: on.length, duty: on.filter(e => e.duty).length, balance: db.balance, onlineList: on, log: db.bossLog.slice(0, 8), grades: db.grades }; }
            case 'employees': return { list: db.staff.map(e => ({ ...e, rewards: e.rewards.length, strikes: e.strikes.length })), grades: db.grades };
            case 'employee': { const e = db.staff.find(x => x.cid === d.cid); let peak = null, pv = 0; Object.entries(e.duty).forEach(([k, v]) => { if (v > pv) { pv = v; peak = k; } }); return { ok: true, ...e, peak, grades: db.grades }; }
            case 'setGrade': { const e = db.staff.find(x => x.cid === d.cid); if (d.grade >= 4) return { ok: false, msg: 'You can only set ranks below yours' }; e.gradeLevel = d.grade; e.grade = db.grades[d.grade].name; db.bossLog.unshift({ t: n, text: `${e.name} rank set to ${e.grade}`, by: 'Dev Hkmi' }); return { ok: true, msg: 'Rank updated' }; }
            case 'fire': db.staff = db.staff.filter(x => x.cid !== d.cid); return { ok: true, msg: 'Employee fired' };
            case 'hire': { const p = byId(d.id); db.staff.push({ cid: p.cid, name: p.name, gradeLevel: d.grade, grade: db.grades[d.grade].name, callsign: '', online: true, duty: false, phone: p.phone, dutyTotal: 0, rewards: [], strikes: [], certs: {}, duty: {} }); return { ok: true, msg: p.name + ' hired' }; }
            case 'addRecord': { if (!d.reason) return { ok: false, msg: 'Write a reason' }; const e = db.staff.find(x => x.cid === d.cid); e[d.kind === 'strike' ? 'strikes' : 'rewards'].push({ t: n, reason: d.reason, by: 'Dev Hkmi' }); return { ok: true, msg: d.kind === 'strike' ? 'Strike added' : 'Reward added' }; }
            case 'setCert': { const e = db.staff.find(x => x.cid === d.cid); if (d.on) e.certs[d.key] = { t: n, by: 'Dev Hkmi' }; else delete e.certs[d.key]; return { ok: true }; }
            case 'saveStaff': { const e = db.staff.find(x => x.cid === d.cid); e.callsign = d.callsign; e.notes = d.notes; return { ok: true, msg: 'Saved' }; }
            case 'society': { const a = Number(d.amount) || 0; if (a <= 0) return { ok: false, msg: 'Invalid amount' }; db.balance += d.action === 'deposit' ? a : -a; return { ok: true, msg: 'Done', balance: db.balance }; }
            case 'bossLog': return db.bossLog;
            case 'closestPlate': return { plate: '20HRX818', model: 'Sultan' };
            case 'player': { const p = byId(d.id); if (!p) return { ok: false }; return { ok: true, name: p.name, cid: p.cid, jailed: !!db.prisoners[p.cid], warrants: db.warrants.filter(w => w.active && w.cid === p.cid).length, flags: (db.people[p.cid] || {}).flags || [] }; }
            case 'jail': {
                const p = byId(d.id); if (!p) return { ok: false, msg: 'Player not found' };
                if (db.prisoners[p.cid]) return { ok: false, msg: p.name + ' is already in prison' };
                const tl = App.init.jailTypes.find(t => t.key === d.type).label;
                db.prisoners[p.cid] = { cid: p.cid, name: p.name, type: d.type, typeLabel: tl, life: d.life, total: d.minutes * 60, remaining: d.minutes * 60, charges: d.charges, bail: d.bail ? d.bailAmount : 0, officer: 'Dev Hkmi', at: n, online: true };
                log('jail', `${p.name} sent to ${tl} for ${d.life ? 'life' : d.minutes + ' min'}`);
                return { ok: true, msg: `${p.name} was sent to ${tl}` };
            }
            case 'prisoners': return Object.values(db.prisoners).sort((a, b) => b.at - a.at);
            case 'release': delete db.prisoners[d.cid]; return { ok: true, msg: 'Prisoner released' };
            case 'fine': {
                const p = byId(d.id); if (!p) return { ok: false, msg: 'Player not found' };
                const amount = d.charges.reduce((s, l) => s + (charge(l) || {}).fine, 0);
                db.fines.push({ id: ++db.seq, cid: p.cid, name: p.name, charges: d.charges, amount, paid: true, notes: d.notes, plate: d.plate, officer: 'Dev Hkmi', t: n });
                log('fine', `${p.name} fined ${money(amount)} (paid)`);
                return { ok: true, msg: `Citation issued to ${p.name} — ${money(amount)} paid` };
            }
            case 'fines': return db.fines.slice().reverse().filter(f => !d.q || f.name.toLowerCase().includes(d.q.toLowerCase()));
            case 'markPaid': db.fines.find(f => f.id === d.id).paid = true; return { ok: true };
            case 'dashboard': return { stats: { officers: 6, prisoners: Object.keys(db.prisoners).length, warrants: db.warrants.filter(w => w.active).length, bolos: db.bolos.filter(b => b.active).length, finesToday: db.fines.length, unpaid: db.fines.filter(f => !f.paid).length }, activity: db.activity.slice(0, 12), warrants: db.warrants.filter(w => w.active), bolos: db.bolos.filter(b => b.active) };
            case 'searchCitizens': { const q = (d.q || '').toLowerCase(); return P.filter(p => !q || p.name.toLowerCase().includes(q) || p.cid.toLowerCase().includes(q)).map(p => ({ cid: p.cid, name: p.name, id: p.id, online: true, warrants: db.warrants.filter(w => w.active && w.cid === p.cid).length, jailed: !!db.prisoners[p.cid] })); }
            case 'citizen': {
                const p = P.find(x => x.cid === d.cid) || { cid: d.cid, name: '?' }, pe = db.people[d.cid] || {};
                const fines = db.fines.filter(f => f.cid === d.cid).reverse();
                return { ...p, online: true, notes: pe.notes || '', flags: pe.flags || [], fines, jail: [{ id: 3, minutes: 20, charges: ['Assault'], officer: 'Noura Saad', t: n - 400000 }].filter(() => d.cid === 'RX48213'),
                    warrants: db.warrants.filter(w => w.cid === d.cid), reports: db.reports.filter(r => r.involved.includes(p.name)).map(r => ({ id: r.id, title: r.title, t: r.t })),
                    owed: fines.filter(f => !f.paid).reduce((s, f) => s + f.amount, 0), prisoner: db.prisoners[d.cid] };
            }
            case 'saveCitizen': db.people[d.cid] = { notes: d.notes, flags: d.flags }; return { ok: true };
            case 'searchVehicle': { const pl = d.plate || '20HRX818', v = db.vehicles[pl] || {}, h = db.holds[pl], im = db.impounds.filter(x => x.plate === pl).reverse()[0]; return { rows: [{ plate: pl, model: v.model || (im && im.model) || 'Karin Sultan RS', owner: v.owner || (im && im.owner) || 'Faisal Al-Harbi', cid: 'RX48213', stolen: !!v.stolen, notes: v.notes || '', bolo: pl === '82KLM203', fines: db.fines.filter(f => f.plate === pl).length, hold: h ? { ...h, remaining: Math.max(0, h.releaseAt - n) } : null, history: db.impounds.filter(x => x.plate === pl).reverse() }] }; }
            case 'flagVehicle': db.vehicles[d.plate] = { stolen: d.stolen, notes: d.notes }; return { ok: true };
            case 'warrants': return db.warrants.slice().sort((a, b) => b.t - a.t);
            case 'createWarrant': if (!d.name || !d.reason) return { ok: false, msg: 'Name and reason are required' }; db.warrants.push({ id: ++db.seq, ...d, active: true, officer: 'Dev Hkmi', t: n }); log('warrant', 'Warrant issued for ' + d.name); return { ok: true, msg: 'Warrant issued' };
            case 'closeWarrant': db.warrants.find(w => w.id === d.id).active = false; return { ok: true };
            case 'reports': return db.reports.slice().reverse();
            case 'createReport': if (!d.title) return { ok: false, msg: 'Title is required' }; { const r = { id: ++db.seq, ...d, officer: 'Dev Hkmi', t: n }; db.reports.push(r); log('report', `Report #${r.id}: ${r.title}`); return { ok: true, msg: `Report #${r.id} saved`, id: r.id }; }
            case 'bolos': return db.bolos.slice().reverse();
            case 'createBolo': if (!d.title) return { ok: false, msg: 'Title is required' }; db.bolos.push({ id: ++db.seq, ...d, active: true, officer: 'Dev Hkmi', t: n }); return { ok: true, msg: 'BOLO created' };
            case 'closeBolo': db.bolos.find(b => b.id === d.id).active = false; return { ok: true };
        }
        return { ok: false, msg: 'Unknown action ' + a };
    },
};

if (!RES) {
    document.body.classList.add('preview');
    Mock.seed();
    const q = new URLSearchParams(location.search);
    const opts = q.get('id') ? { id: Number(q.get('id')) } : {};
    if (q.get('page')) opts.page = q.get('page');
    if (q.get('panel') === 'impound') opts.vehicle = { plate: '20HRX818', model: 'Karin Sultan RS', owner: 'Faisal Al-Harbi', registered: true, stolen: false };
    window.postMessage({ action: 'open', panel: q.get('panel') || 'home', opts }, '*');
    if (q.get('hud')) setTimeout(() => window.postMessage({ action: 'jailHud', show: true, data: { label: 'Prison', remaining: 1134, total: 1800, bail: 12000, paybail: 'paybail' } }, '*'), 200);
}
