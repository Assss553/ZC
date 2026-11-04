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
        ${App.prev ? `<div class="icon-btn" data-a="back" title="Back"><i class="fa-solid fa-arrow-left"></i></div>` : ''}
        <div class="ico"><i class="fa-solid fa-${icon}"></i></div>
        <div class="tt"><div class="eyebrow">${eyebrow}</div><div class="title">${title}</div></div>
        ${extra}
        <div class="officer"><span class="dot"></span><b>${esc(o.name || 'Officer')}</b>${o.grade ? ' · ' + esc(o.grade) : ''}</div>
        <div class="icon-btn x" data-a="close"><i class="fa-solid fa-xmark"></i></div>
    </div>`;
}

function openPanel(name, opts = {}, fromPanel) {
    App.prev = fromPanel || null;
    App.panel = name;
    if (name === 'jail') Jail.reset(opts);
    if (name === 'fine') Fine.reset(opts);
    if (name === 'mdt') MDT.reset(opts);
    render();
}
function render() {
    const P = { jail: Jail, fine: Fine, mdt: MDT }[App.panel];
    if (!P) return;
    root.innerHTML = P.html();
    H = P.handlers;
    P.after && P.after();
}
function closeAll(fromGame) {
    App.open = false; App.panel = null;
    root.innerHTML = ''; backdrop.classList.remove('show');
    clearInterval(App.tick);
    if (!fromGame) post('close');
}
function goBack() { const p = App.prev; App.prev = null; App.panel = p; if (p === 'mdt') { render(); MDT.load(); } else render(); }

root.addEventListener('click', (e) => {
    const a = e.target.closest('[data-a]');
    if (!a) { if (!e.target.closest('.dd') && !e.target.closest('[data-a="nearby"]')) document.querySelectorAll('.dd').forEach(d => d.remove()); return; }
    const k = a.dataset.a;
    if (k === 'close') return closeAll();
    if (k === 'back') return goBack();
    H[k] && H[k](a, e);
});
root.addEventListener('input', (e) => { const k = e.target.dataset.in; if (k && H['in:' + k]) H['in:' + k](e.target, e); });
root.addEventListener('keydown', (e) => { const k = e.target.dataset.enter; if (k && e.key === 'Enter' && !e.shiftKey && H[k]) { e.preventDefault(); H[k](e.target, e); } });
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && App.open) { if (document.querySelector('.dd')) return document.querySelectorAll('.dd').forEach(d => d.remove()); App.prev ? goBack() : closeAll(); }
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
        if (App.panel === 'mdt') render();
    },
    html() {
        const S = this.S, o = (App.init && App.init.officer) || {}, st = (S.dash && S.dash.stats) || (App.init && App.init.stats) || {};
        const nav = [
            ['dashboard', 'gauge-high', 'Dashboard'], ['citizens', 'id-card', 'Citizens'], ['vehicles', 'car', 'Vehicles'],
            ['warrants', 'user-ninja', 'Warrants', st.warrants], ['reports', 'file-lines', 'Reports'], ['bolo', 'binoculars', 'BOLO', st.bolos],
        ];
        const titles = { dashboard: ['Overview', 'Dashboard'], citizens: ['Records', 'Citizen Search'], vehicles: ['DMV', 'Vehicle Lookup'], warrants: ['Judicial', 'Warrants'], reports: ['Investigations', 'Incident Reports'], bolo: ['Dispatch', 'Be On The Look Out'] };
        const [eb, tt] = titles[S.page];
        return `<div class="panel mdt">
            <div class="side">
                <div class="brand"><div class="logo"><i class="fa-solid fa-shield-halved"></i></div><div><b>ZC MDT</b><span>MOBILE DATA TERMINAL</span></div></div>
                <div class="nav">
                    ${nav.map(([k, ic, l, c]) => `<div class="ni ${S.page === k ? 'on' : ''}" data-a="nav" data-p="${k}"><i class="fa-solid fa-${ic}"></i>${l}${c ? `<span class="count">${c}</span>` : ''}</div>`).join('')}
                    <div class="sep">QUICK ACTIONS</div>
                    <div class="ni" data-a="openJail"><i class="fa-solid fa-building-shield"></i>Prison Management</div>
                    <div class="ni" data-a="openFine"><i class="fa-solid fa-file-invoice-dollar"></i>Citations</div>
                </div>
                <div class="me"><div class="avatar">${initials(o.name)}</div><div class="who"><b>${esc(o.name || 'Officer')}</b><span>${esc(o.jobLabel || 'Police')}${o.grade ? ' · ' + esc(o.grade) : ''}</span></div><span class="badge ok">on duty</span></div>
            </div>
            <div class="main">
                <div class="topbar"><div class="tt"><div class="eyebrow">${eb}</div><div class="title">${tt}</div></div>
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
        return `<div class="search-bar" style="max-width:640px"><div class="input grow"><i class="fa-solid fa-car"></i><input placeholder="License plate..." value="${esc(S.vq)}" data-in="vq" data-enter="vsearch" style="text-transform:uppercase"></div>
                <button class="btn" data-a="vnearest"><i class="fa-solid fa-car-side"></i> Nearest</button><button class="btn primary" data-a="vsearch"><i class="fa-solid fa-magnifying-glass"></i> Search</button></div>
            <div class="list-rows">${S.vehicles.map((v, i) => `<div class="card" style="margin-bottom:0">
                <div style="display:flex;align-items:center;gap:14px">
                    <span class="plate">${esc(v.plate)}</span>
                    <div class="who"><b>${esc(v.model)}</b><span>Owner: ${esc(v.owner || 'Unknown')}</span></div>
                    ${v.unregistered ? '<span class="badge warn">not registered</span>' : '<span class="badge ok">registered</span>'}
                    ${v.stolen ? '<span class="badge bad"><i class="fa-solid fa-triangle-exclamation"></i> stolen</span>' : ''}
                    ${v.bolo ? '<span class="badge warn">bolo</span>' : ''}
                    ${v.fines ? `<span class="badge">${v.fines} citations</span>` : ''}
                    <span style="flex:1"></span>
                    ${v.cid ? `<button class="btn sm" data-a="vowner" data-cid="${esc(v.cid)}"><i class="fa-solid fa-id-card"></i> Owner</button>` : ''}
                </div>
                <div class="row" style="margin-top:12px">
                    <div class="toggle-row ${v.stolen ? 'on' : ''}" data-a="vstolen" data-i="${i}" style="width:220px"><div class="t"><b>Reported Stolen</b><span>Flag this plate</span></div><div class="switch"></div></div>
                    <div class="input grow"><i class="fa-solid fa-note-sticky"></i><input placeholder="Notes..." value="${esc(v.notes || '')}" data-in="vnotes" data-i="${i}"></div>
                    <button class="btn" data-a="vsave" data-i="${i}"><i class="fa-solid fa-floppy-disk"></i> Save</button>
                </div></div>`).join('') || `<div class="empty-state"><i class="fa-solid fa-car"></i>Search a plate to see the vehicle record</div>`}</div>`;
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
        clock(); App.tick = setInterval(clock, 1000);
    },
    handlers: {},
};
const dangerBadge = (d) => `<span class="badge ${d === 'high' ? 'bad' : d === 'low' ? 'info' : 'warn'}">${esc(d || 'medium')}</span>`;
const refocus = (sel) => { const i = root.querySelector(sel); if (i) { i.focus(); i.setSelectionRange && i.setSelectionRange(i.value.length, i.value.length); } };

Object.assign(MDT.handlers, {
    nav(el) { MDT.S.page = el.dataset.p; render(); MDT.load(); },
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
            officer: { name: 'Dev Hkmi', grade: 'Sergeant', jobLabel: 'LSPD', duty: true }, charges,
            jailTypes: [{ key: 'prison', label: 'Prison', icon: 'building-shield' }, { key: 'cell', label: 'Holding Cell', icon: 'door-closed' }],
            presets: [5, 10, 15, 30, 60], maxMinutes: 300, stats: {},
        };
        this.players = [
            { id: 824, name: 'Faisal Al-Harbi', cid: 'ZC48213', phone: '555-0182', dob: '1996-04-12', job: 'Mechanic', dist: 2.1 },
            { id: 512, name: 'Omar Nasser', cid: 'ZC11902', phone: '555-0341', dob: '1999-09-01', job: 'Unemployed', dist: 4.6 },
            { id: 77, name: 'Sara Khalid', cid: 'ZC77310', phone: '555-0777', dob: '2001-01-23', job: 'Taxi', dist: 5.8 },
        ];
        this.db = {
            seq: 20,
            prisoners: { ZC11902: { cid: 'ZC11902', name: 'Omar Nasser', type: 'prison', typeLabel: 'Prison', life: false, total: 1800, remaining: 1134, charges: ['Armed Robbery', 'Evading Police', 'Resisting Arrest'], bail: 12000, officer: 'Dev Hkmi', at: n - 700, online: true },
                         ZC90001: { cid: 'ZC90001', name: 'Majed Turki', type: 'prison', typeLabel: 'Prison', life: true, total: 0, remaining: 0, charges: ['Murder'], bail: 0, officer: 'Noura Saad', at: n - 86000, online: false } },
            fines: [
                { id: 11, cid: 'ZC48213', name: 'Faisal Al-Harbi', charges: ['Speeding', 'Running a Red Light'], amount: 850, paid: true, officer: 'Dev Hkmi', plate: '20HRX818', t: n - 3600 },
                { id: 14, cid: 'ZC77310', name: 'Sara Khalid', charges: ['Illegal Parking'], amount: 200, paid: false, officer: 'Noura Saad', t: n - 9000 },
            ],
            warrants: [{ id: 15, cid: 'ZC48213', name: 'Faisal Al-Harbi', reason: 'Wanted for questioning in the Fleeca bank robbery', danger: 'high', active: true, officer: 'Noura Saad', t: n - 5000 },
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
            people: { ZC48213: { flags: ['Armed'], notes: 'Known associate of the Vespucci crew.' } },
            vehicles: {},
        };
    },
    async call(a, d) {
        await new Promise(r => setTimeout(r, 120));
        const db = this.db, n = this.now(), P = this.players, byId = (id) => P.find(p => p.id === Number(id));
        const charge = (l) => App.init.charges.find(c => c.label === l);
        const log = (kind, text) => db.activity.unshift({ t: n, kind, text, officer: 'Dev Hkmi' });
        switch (a) {
            case 'nearby': return P.map(p => ({ id: p.id, name: p.name, dist: p.dist }));
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
                return { ...p, online: true, notes: pe.notes || '', flags: pe.flags || [], fines, jail: [{ id: 3, minutes: 20, charges: ['Assault'], officer: 'Noura Saad', t: n - 400000 }].filter(() => d.cid === 'ZC48213'),
                    warrants: db.warrants.filter(w => w.cid === d.cid), reports: db.reports.filter(r => r.involved.includes(p.name)).map(r => ({ id: r.id, title: r.title, t: r.t })),
                    owed: fines.filter(f => !f.paid).reduce((s, f) => s + f.amount, 0), prisoner: db.prisoners[d.cid] };
            }
            case 'saveCitizen': db.people[d.cid] = { notes: d.notes, flags: d.flags }; return { ok: true };
            case 'searchVehicle': { const v = db.vehicles[d.plate] || {}; return { rows: [{ plate: d.plate || '20HRX818', model: 'Karin Sultan RS', owner: 'Faisal Al-Harbi', cid: 'ZC48213', stolen: !!v.stolen, notes: v.notes || '', bolo: d.plate === '82KLM203', fines: db.fines.filter(f => f.plate === d.plate).length }] }; }
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
    window.postMessage({ action: 'open', panel: q.get('panel') || 'mdt', opts: q.get('id') ? { id: Number(q.get('id')) } : {} }, '*');
    if (q.get('hud')) setTimeout(() => window.postMessage({ action: 'jailHud', show: true, data: { label: 'Prison', remaining: 1134, total: 1800, bail: 12000, paybail: 'paybail' } }, '*'), 200);
}
