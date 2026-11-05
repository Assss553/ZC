/*
 * ROX Real Estate  ·  © ROX Store – All rights reserved.
 * Made for ROX Store. Do not resell or redistribute without permission.
 */
/* ROX Real Estate – iPad UI */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rox_realestate';
const IS_GAME = typeof GetParentResourceName === 'function';
const $ = (s, r = document) => r.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* ------------------------------------------------------------------ icons */
const IC = {
    home: '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    homekey: '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><circle cx="10" cy="14" r="2.2"/><path d="M12.2 14H17v2"/>',
    building: '<rect x="4" y="3" width="11" height="18" rx="1"/><path d="M15 9h4a1 1 0 0 1 1 1v11H15M8 7h3M8 11h3M8 15h3M18 3v4M16 5h4"/>',
    tag: '<path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9z"/><circle cx="8" cy="8" r="1.6"/>',
    key: '<circle cx="7.5" cy="15.5" r="4.5"/><path d="m10.7 12.3 9.3-9.3M17 6l3 3M14 9l2 2"/>',
    map: '<path d="m9 4-6 2v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/>',
    sofa: '<path d="M4 11V8a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v3"/><path d="M2 13a2 2 0 0 1 4 0v2h12v-2a2 2 0 0 1 4 0v5H2z"/><path d="M5 18v2M19 18v2"/>',
    file: '<path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
    back: '<path d="m15 18-6-6 6-6"/>',
    close: '<path d="M18 6 6 18M6 6l12 12"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
    pin: '<path d="M12 21s-7-6.2-7-12a7 7 0 0 1 14 0c0 5.8-7 12-7 12z"/><circle cx="12" cy="9" r="2.5"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    unlock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 7.8-1.2"/>',
    cart: '<circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M2 3h3l2.6 12.4a1 1 0 0 0 1 .8h9.7a1 1 0 0 0 1-.8L21 7H6"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    cash: '<rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 12h.01M18 12h.01"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    trash: '<path d="M3 6h18M8 6V4h8v2M6 6l1 15h10l1-15"/>',
    edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
    crosshair: '<circle cx="12" cy="12" r="9"/><path d="M12 3v4M12 17v4M3 12h4M17 12h4"/><circle cx="12" cy="12" r="1.5"/>',
    door: '<path d="M5 21V4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v17M3 21h18"/><circle cx="15" cy="12" r="1"/>',
    pen: '<path d="M3 21c3-1 5-3 6-6l8-8 3 3-8 8c-3 1-5 3-6 6"/><path d="m15 5 3 3"/>',
    send: '<path d="M22 2 11 13M22 2l-7 20-4-9-9-4z"/>',
    bath: '<path d="M4 12h16v3a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zM6 12V5a2 2 0 0 1 4 0M6 20l-1 2M18 20l1 2"/>',
    bed: '<path d="M2 18V6M2 14h20v4M22 18v-5a3 3 0 0 0-3-3H10v4"/><circle cx="6" cy="11" r="2"/>',
    chair: '<path d="M5 11V8a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v3"/><path d="M3 12a2 2 0 0 1 4 0v2h10v-2a2 2 0 0 1 4 0v5H3zM6 17v2M18 17v2"/>',
    chair_old: '<path d="M6 21v-7h12v7M6 14V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v9M4 14h16"/>',
    table: '<path d="M3 8h18M5 8v12M19 8v12M3 8l2-4h14l2 4"/>',
    plant: '<path d="M7 15h10l-1.5 6h-7zM12 15V9M12 9c0-3 2-5 5-5 0 3-2 5-5 5zM12 11c0-2.5-1.7-4-4-4 0 2.5 1.7 4 4 4z"/>',
    tv: '<rect x="2" y="5" width="20" height="13" rx="2"/><path d="M8 21h8M12 18v3"/>',
    kitchen: '<rect x="6" y="2" width="12" height="20" rx="2"/><path d="M6 9h12M9 5v2M9 12v4"/>',
    kitchen_old: '<rect x="4" y="2" width="16" height="20" rx="2"/><path d="M4 10h16M8 6h.01M8 14v3"/>',
    light: '<path d="M8 3h8l3 7H5zM12 10v9M8 21h8"/>',
    light_old: '<path d="M9 18h6M10 22h4M12 2a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 2z"/>',
    box: '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
    move: '<path d="M5 9l-3 3 3 3M9 5l3-3 3 3M15 19l-3 3-3-3M19 9l3 3-3 3M2 12h20M12 2v20"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    alert: '<path d="M12 3 2 20h20z"/><path d="M12 10v4M12 17h.01"/>',
    door_open: '<path d="M13 4h5a1 1 0 0 1 1 1v16M3 21h18M13 4v17L5 19V6z"/><circle cx="10" cy="12" r=".8"/>',
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18M11 13v2h2v-2"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
    image: '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-5-5L5 21"/>',
    resize: '<path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/>',
    eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
};
const icon = (n) => `<svg viewBox="0 0 24 24">${IC[n] || IC.info}</svg>`;

/* ------------------------------------------------------------------ state */
const S = {
    open: false, data: null, st: null, view: 'home', params: {}, history: [],
    cart: [], shopCat: 'all', shopSearch: '', shopProp: null, shopCount: 0,
    listSearch: '', manageFilter: 'all', manageSearch: '',
    create: null, pickTarget: null,
    map: { z: 1, x: 0, y: 0, ready: false, hasImg: true },
    overlay: null, fp: null,
    settings: { wallpaper: null, scale: 1, lang: null },
    interiorFilter: 'all',
};

/* ------------------------------------------------------------------ settings (saved per player in the NUI storage) */
const WALLPAPERS = ['img/wallpapers/street.jpg', 'img/wallpapers/pond.jpg', 'img/wallpapers/forest.jpg'];
function loadSettings() {
    try { Object.assign(S.settings, JSON.parse(localStorage.getItem('rox_re_settings') || '{}')); } catch (e) { /* storage unavailable */ }
}
function saveSettings() {
    try { localStorage.setItem('rox_re_settings', JSON.stringify(S.settings)); } catch (e) { /* storage unavailable */ }
}
function applySettings() {
    const wall = S.settings.wallpaper || (S.st && S.st.wallpaper) || WALLPAPERS[0];
    $('#screen').style.setProperty('--wall', `url('${String(wall).replace(/'/g, '%27')}')`);
    $('#tablet').style.setProperty('--scale', S.settings.scale || 1);
    LANG = S.settings.lang || (S.st && (S.st.defaultLocale || S.st.locale)) || 'en';
    document.documentElement.lang = LANG;
    document.documentElement.dir = LANG === 'ar' ? 'rtl' : 'ltr';
}
loadSettings();
if (S.settings.lang && IS_GAME) post('setLang', { lang: S.settings.lang });

const resetCreate = () => {
    S.create = { step: 1, interior: null, label: '', ptype: 'sale', price: '', rentPrice: '', rentDays: (S.st && S.st.rentDays) || 7, buyerId: '', image: '', door: null, street: '', inside: null };
};

/* ------------------------------------------------------------------ helpers */
function post(name, data = {}) {
    if (!IS_GAME) return Mock.post(name, data);
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) })
        .then((r) => r.json()).catch(() => ({}));
}
async function call(name, ...args) {
    const r = await post('call', { name, args, argc: args.length });
    if (r && !r.ok && typeof r.data === 'string') toast(r.data, 'error');
    return r || {};
}
function money(n) {
    const v = Math.floor(Number(n) || 0).toLocaleString('en-US');
    return `<em>${esc((S.st && S.st.currency) || '$')}</em>${v}`;
}
const moneyText = (n) => `${(S.st && S.st.currency) || '$'}${Math.floor(Number(n) || 0).toLocaleString('en-US')}`;
const props = () => (S.data && S.data.properties) || [];
const findProp = (id) => props().find((p) => p.id === Number(id));
const interiorOf = (key) => ((S.st && S.st.interiors) || []).find((i) => i.key === key);
const interiorName = (i) => (i ? (LANG === 'ar' && i.labelAr ? i.labelAr : i.label) : '');
const catName = (c) => (LANG === 'ar' && c.labelAr ? c.labelAr : c.label);
const fmtDate = (ts) => (ts ? new Date(ts * 1000).toLocaleDateString(LANG === 'ar' ? 'ar' : 'en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : t('unknown'));

function bgImage(src, tier, cls = '', style = '') {
    const layers = [], sizes = [];
    if (src) { layers.push(`url('${String(src).replace(/'/g, '%27')}')`); sizes.push('cover'); }
    sizes.push('38% auto', 'cover');
    layers.push(`url('data:image/svg+xml,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.16)" stroke-width="1.2"><path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>')}')`);
    layers.push('linear-gradient(145deg, var(--t1, #2a2a30), var(--t2, #141416))');
    return `class="ph tier-${tier || 'mid'} ${cls}" style="background-image:${layers.join(',')};background-size:${sizes.join(',')};background-position:center;background-repeat:no-repeat;${style}"`;
}
function propImg(p, cls, style) { const i = interiorOf(p.interior); return bgImage(p.image || (i && i.image), i && i.tier, cls, style); }

// picture chain: html/img/furniture/<model>.* (detected) -> Config.Furniture.ImageUrl -> category icon
function furnImg(model) {
    const local = S.st && S.st.furnitureImages && S.st.furnitureImages[model];
    const tpl = S.st && S.st.furnitureImage;
    const remote = tpl ? tpl.replace('%s', model) : '';
    const first = local || remote;
    if (!first) return '';
    return `<img src="${esc(first)}" data-fb="${local && remote ? esc(remote) : ''}" onerror="imgFallback(this)" onload="this.parentNode.classList.add('has-img')">`;
}
window.imgFallback = (img) => {
    const fb = img.dataset.fb;
    if (fb) { img.dataset.fb = ''; img.src = fb; } else img.remove();
};
const CAT_COLORS = {
    all: ['#ff8a4c', '#ff4a12'], bathroom: ['#4fc3e8', '#1f7fb0'], bed: ['#a08bff', '#5a3fd6'], chair: ['#e8925a', '#b65a22'],
    table: ['#d3aa6c', '#8d6a35'], decorations: ['#6bd889', '#2b9a4c'], electronic: ['#5aa9ff', '#2f5bff'], kitchen: ['#f5bf4f', '#c9831a'],
    light: ['#ffe07a', '#e3a313'], storage: ['#a7a7b3', '#5e5e6a'],
};
const catColor = (cat) => CAT_COLORS[cat] || CAT_COLORS.storage;
function catIconTile(cat, ic) {
    const [a, b] = catColor(cat);
    return `<span class="ci" style="background:linear-gradient(160deg,${a},${b})">${icon(ic)}</span>`;
}
function furnIcon(cat) {
    const c = ((S.st && S.st.categories) || []).find((x) => x.key === cat);
    const [a] = catColor(cat);
    return `<span class="ph-ic" style="--c:${a}">${icon((c && c.icon) || 'box')}</span>`;
}

function statusChip(p) {
    if (p.salePrice && p.status === 'owned') return `<span class="chip">${t('st_sale')}</span>`;
    const map = { available: 'orange', pending: 'blue', owned: 'green', rented: 'green' };
    return `<span class="chip ${map[p.status] || ''}">${t('st_' + p.status)}</span>`;
}
function contractChip(c) {
    const map = { pending: 'orange', signed: 'green', declined: 'red', expired: 'red', cancelled: 'red' };
    return `<span class="chip ${map[c.status] || ''}">${t('st_' + c.status)}</span>`;
}
function priceLine(p) {
    if (p.ptype === 'rent') return `<span class="price">${money(p.rentPrice)} <small>${t('per_days', p.rentDays)}</small></span>`;
    return `<span class="price">${money(p.salePrice || p.price)}</span>`;
}

function toast(msg, kind = 'info') {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.innerHTML = `<span class="ti">${icon(kind === 'success' ? 'check' : kind === 'error' ? 'alert' : 'info')}</span><span>${esc(msg)}</span>`;
    $('#toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 320); }, 4200);
}

/* ------------------------------------------------------------------ navigation */
function go(view, params = {}) {
    S.history.push({ view: S.view, params: S.params });
    S.view = view; S.params = params;
    render();
}
function back() {
    const h = S.history.pop();
    if (!h) return home();
    S.view = h.view; S.params = h.params;
    render();
}
function home() { S.history = []; S.view = 'home'; S.params = {}; render(); }

async function refresh() {
    const r = await post('call', { name: 'bootstrap', args: [], argc: 0 });
    if (r && r.data) { S.data = r.data; render(); }
}

function appbar(title, sub, right = '') {
    return `<div class="appbar"><button class="icon-btn flip" data-act="back">${icon('back')}</button>
        <div><h1>${title}</h1>${sub ? `<div class="sub">${sub}</div>` : ''}</div><div class="grow"></div>${right}</div>`;
}

/* ------------------------------------------------------------------ views */
const Views = {};

Views.home = () => {
    const d = S.data;
    const now = new Date();
    const pending = (d.contracts || []).filter((c) => c.status === 'pending' && c.isMine).length;
    const overdue = props().filter((p) => p.isOwner && p.overdue > 0).length;
    const img = (f) => `<img class="aicon" src="img/icons/${f}.jpg" alt="">`;
    const css = (cls, ic) => `<span class="aicon ${cls}">${icon(ic)}</span>`;
    const app = (view, label, art, badge) => `<button class="dock-app" data-act="go" data-view="${view}">${art}
        ${badge ? `<i class="badge">${badge}</i>` : ''}<span class="dock-tip">${label}</span></button>`;
    return `<div class="home2">
        <div class="home-clock"><b>${now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })}</b>
            <span>${now.toLocaleDateString(LANG === 'ar' ? 'ar' : 'en-GB', { weekday: 'long', day: 'numeric', month: 'long' })}</span></div>
        <div class="home-wallet">${icon('cash')}<span>${moneyText(d.money)}</span></div>
        <div class="dock">
            ${app('shop', t('app_furniture'), img('furniture'))}
            ${d.apps && d.apps.create ? app('create', t('app_create'), css('ai-blue', 'briefcase')) : ''}
            ${app('contracts', t('app_contracts'), css('ai-dark', 'file'), pending)}
            ${app('dashboard', t('app_estate'), img('realestate'), overdue)}
            ${app('settings', t('app_settings'), img('settings'))}
            ${d.apps && d.apps.manage ? app('manage', t('app_manage'), css('ai-orange', 'building')) : ''}
        </div>
    </div>`;
};

Views.settings = () => {
    const cur = S.settings.wallpaper || S.st.wallpaper || WALLPAPERS[0];
    const custom = S.settings.wallpaper && !WALLPAPERS.includes(S.settings.wallpaper) ? S.settings.wallpaper : '';
    const pct = Math.round((S.settings.scale || 1) * 100);
    return `<div class="page">${appbar(t('app_settings'), t('set_sub'))}
        <div class="scroll settings">
            <section class="set-card">
                <div class="set-head">${icon('image')}<div><b>${t('set_wallpaper')}</b><small>${t('set_wallpaper_sub')}</small></div></div>
                <div class="walls">${WALLPAPERS.map((w) => `<button class="wall ${w === cur ? 'on' : ''}" data-act="setwall" data-src="${w}" style="background-image:url('${w}')">${w === cur ? `<i>${icon('check')}</i>` : ''}</button>`).join('')}</div>
                <div class="set-row"><input class="input" id="customWall" placeholder="${t('set_custom_ph')}" value="${esc(custom)}"><button class="btn ghost" data-act="setwallurl">${t('save')}</button></div>
            </section>
            <section class="set-card">
                <div class="set-head">${icon('resize')}<div><b>${t('set_size')}</b><small>${t('set_size_sub')}</small></div><span class="set-val" id="scaleVal">${pct}%</span></div>
                <div class="set-row"><span class="muted">${t('set_small')}</span><input type="range" class="range" id="scaleRange" min="70" max="115" step="1" value="${pct}"><span class="muted">${t('set_large')}</span>
                <button class="btn ghost" data-act="resetscale">${t('set_reset')}</button></div>
            </section>
            <section class="set-card">
                <div class="set-head">${icon('globe')}<div><b>${t('set_lang')}</b><small>${t('set_lang_sub')}</small></div></div>
                <div class="seg" style="max-width:360px"><button class="${LANG === 'en' ? 'on' : ''}" data-act="setlang" data-v="en">English</button><button class="${LANG === 'ar' ? 'on' : ''}" data-act="setlang" data-v="ar">العربية</button></div>
            </section>
            <section class="set-card">
                <div class="set-head">${icon('info')}<div><b>${t('set_about')}</b><small>ROX Realty OS · v1.2 · © ROX Store · ${esc(S.data.name)} · ID ${S.data.serverId}</small></div>
                ${S.data.isRealtor ? `<span class="chip orange">${t('realtor_badge', S.data.grade)}</span>` : ''}</div>
            </section>
        </div></div>`;
};

Views.dashboard = () => {
    const list = props();
    const mine = list.filter((p) => p.hasKey);
    const overdue = mine.filter((p) => p.overdue > 0).length;
    const avail = list.filter((p) => p.status === 'available');
    const market = list.filter((p) => p.salePrice && !p.isOwner);
    const minPrice = avail.length ? Math.min(...avail.map((p) => (p.ptype === 'rent' ? p.rentPrice : p.price))) : 0;
    const big = (kind, title, sub, chip, ic, ghost) => `<div class="card big" data-act="go" data-view="list" data-kind="${kind}">
        <h3>${title}</h3><p>${sub}</p>${chip}<div class="big-ic">${icon(ic)}</div><div class="ghost-ic">${icon(ghost)}</div></div>`;
    return `<div class="page">
        ${appbar(t('app_estate'), '')}
        <div class="dash">
            <div class="card map-card">${mapHtml()}</div>
            <div class="dash-side">
                ${big('mine', t('mine_title'), t('mine_sub'), overdue ? `<span class="chip red">${t('n_overdue', overdue)}</span>` : `<span class="chip ${mine.length ? 'green' : ''}">${t('n_owned', mine.length)}</span>`, 'homekey', 'key')}
                ${big('available', t('avail_title'), t('avail_sub'), `<span class="chip">${avail.length ? t('from_price', moneyText(minPrice)) : t('none')}</span>`, 'building', 'building')}
                ${S.st.marketplace ? big('market', t('market_title'), t('market_sub'), `<span class="chip">${t('n_listed', market.length)}</span>`, 'tag', 'cart') : ''}
            </div>
        </div>
    </div>`;
};

/* map ---------------------------------------------------------------- */
function mapHtml() {
    const m = S.st.map;
    const W = m.maxX - m.minX, H = m.maxY - m.minY;
    const pins = props().map((p) => {
        const x = ((p.door.x - m.minX) / W) * 100;
        const y = ((m.maxY - p.door.y) / H) * 100;
        let cls = 'taken';
        if (p.hasKey) cls = 'mine';
        else if (p.status === 'available') cls = 'avail';
        else if (p.salePrice) cls = 'sale';
        return `<div class="pin ${cls}" style="left:${x}%;top:${y}%" data-id="${p.id}"><i data-act="pin" data-id="${p.id}"></i></div>`;
    }).join('');
    return `<div class="map ${S.map.hasImg ? '' : 'nomap'}" id="map"><div class="map-inner" id="mapInner">
            ${S.map.hasImg ? `<img src="${esc(m.image)}" onerror="mapMissing()">` : ''}${pins}</div></div>
        <div class="map-head"><h2>${t('map_title')}</h2><p>${t('map_sub')}</p></div>
        ${S.map.hasImg ? '' : `<div class="map-hint">${t('map_missing')}</div>`}
        <div class="legend"><span><i style="background:var(--accent)"></i>${t('lg_available')}</span><span><i style="background:var(--green)"></i>${t('lg_yours')}</span><span><i style="background:#fff"></i>${t('lg_sale')}</span><span><i style="background:#77777f"></i>${t('lg_taken')}</span></div>
        <div class="map-zoom"><button data-act="zoom" data-d="1">+</button><button data-act="zoom" data-d="-1">−</button></div>
        <div class="map-tip hidden" id="mapTip"></div>`;
}
window.mapMissing = () => { S.map.hasImg = false; if (S.view === 'dashboard') render(); };

function setupMap() {
    const map = $('#map'), inner = $('#mapInner');
    if (!map || !inner) return;
    const m = S.st.map;
    const rect = map.getBoundingClientRect();
    const aspect = (m.maxX - m.minX) / (m.maxY - m.minY);
    const baseW = rect.width, baseH = baseW / aspect;
    inner.style.width = baseW + 'px'; inner.style.height = baseH + 'px';
    if (!S.map.ready) {
        // focus Los Santos city
        S.map.z = 2.6;
        const cx = ((-200 - m.minX) / (m.maxX - m.minX)) * baseW, cy = ((m.maxY - (-700)) / (m.maxY - m.minY)) * baseH;
        S.map.x = rect.width / 2 - cx * S.map.z; S.map.y = rect.height / 2 - cy * S.map.z;
        S.map.ready = true;
    }
    const apply = () => {
        inner.style.transform = `translate(${S.map.x}px, ${S.map.y}px) scale(${S.map.z})`;
        inner.style.setProperty('--ps', (1 / S.map.z).toFixed(3));
    };
    apply();
    S.map.apply = apply; S.map.rect = () => map.getBoundingClientRect();
    map.onwheel = (e) => { e.preventDefault(); zoomAt(e.deltaY < 0 ? 1.15 : 1 / 1.15, e.clientX, e.clientY); };
    let drag = null;
    map.onmousedown = (e) => { if (e.target.dataset.act === 'pin') return; drag = { x: e.clientX, y: e.clientY, ox: S.map.x, oy: S.map.y }; map.classList.add('dragging'); };
    window.onmousemove = (e) => { if (!drag) return; S.map.x = drag.ox + e.clientX - drag.x; S.map.y = drag.oy + e.clientY - drag.y; apply(); };
    window.onmouseup = () => { drag = null; map.classList.remove('dragging'); };
    const tip = $('#mapTip');
    map.onmouseover = (e) => {
        const id = e.target.dataset && e.target.dataset.id;
        if (!id || e.target.dataset.act !== 'pin') return;
        const p = findProp(id); if (!p) return;
        const r = e.target.getBoundingClientRect(), card = map.parentElement.getBoundingClientRect();
        tip.innerHTML = `<b>${esc(p.label)}</b><span class="muted">${esc(p.street || interiorName(interiorOf(p.interior)))}</span><div>${priceLine(p)}</div>${statusChip(p)}`;
        tip.style.left = r.left + r.width / 2 - card.left + 'px'; tip.style.top = r.top + r.height - card.top + 'px';
        tip.classList.remove('hidden');
    };
    map.onmouseout = (e) => { if (e.target.dataset && e.target.dataset.act === 'pin') tip.classList.add('hidden'); };
}
function zoomAt(f, cx, cy) {
    const r = S.map.rect();
    const nz = Math.min(12, Math.max(0.8, S.map.z * f));
    const px = (cx ?? r.left + r.width / 2) - r.left, py = (cy ?? r.top + r.height / 2) - r.top;
    S.map.x = px - ((px - S.map.x) * nz) / S.map.z; S.map.y = py - ((py - S.map.y) * nz) / S.map.z; S.map.z = nz;
    S.map.apply();
}

/* lists -------------------------------------------------------------- */
function propCard(p) {
    const i = interiorOf(p.interior);
    return `<div class="card pcard" data-act="go" data-view="detail" data-id="${p.id}">
        <div ${propImg(p)}>${statusChip(p)}<span class="pid">#${p.id}</span></div>
        <div class="pb"><b>${esc(p.label)}</b><small>${esc(p.street || '')}</small>
            <div class="pf">${priceLine(p)}<span class="meta"><span>${icon('door')}${t('rooms', p.rooms)}</span></span></div>
            <small>${esc(interiorName(i))}</small></div></div>`;
}

Views.list = () => {
    const kind = S.params.kind || 'mine';
    const titles = { mine: ['mine_title', 'mine_sub'], available: ['avail_title', 'avail_sub'], market: ['market_title', 'market_sub'] };
    let list = props();
    if (kind === 'mine') list = list.filter((p) => p.hasKey);
    if (kind === 'available') list = list.filter((p) => p.status === 'available');
    if (kind === 'market') list = list.filter((p) => p.salePrice && !p.isOwner);
    const q = S.listSearch.toLowerCase();
    if (q) list = list.filter((p) => (p.label + ' ' + (p.street || '')).toLowerCase().includes(q));
    const body = list.length ? `<div class="pgrid">${list.map(propCard).join('')}</div>`
        : `<div class="empty">${icon(kind === 'mine' ? 'key' : 'building')}<b>${t(kind === 'mine' ? 'empty_mine' : 'empty_list')}</b>${kind === 'mine' ? t('empty_hint') : ''}</div>`;
    return `<div class="page">${appbar(t(titles[kind][0]), t(titles[kind][1]),
        `<div class="toolbar"><div class="search">${icon('search')}<input class="input" data-bind="listSearch" data-rerender="1" placeholder="${t('search')}" value="${esc(S.listSearch)}"></div></div>`)}
        <div class="scroll" style="flex:1">${body}</div></div>`;
};

Views.detail = () => {
    const p = findProp(S.params.id);
    if (!p) return `<div class="page">${appbar('#', '')}<div class="empty">${icon('alert')}<b>${t('empty_list')}</b></div></div>`;
    const i = interiorOf(p.interior);
    const stats = [];
    stats.push([t('type'), t(p.ptype === 'rent' ? 't_rent' : 't_sale')]);
    if (p.ptype === 'rent') stats.push([t('rent'), `${money(p.rentPrice)} <small class="muted">${t('per_days', p.rentDays)}</small>`, true]);
    else stats.push([t('price'), money(p.price), true]);
    if (p.salePrice) stats.push([t('sale_price'), money(p.salePrice), true]);
    stats.push([t('interior'), esc(interiorName(i))]);
    stats.push([t('owner'), esc(p.ownerName || t('unknown'))]);
    stats.push([t('realtor'), esc(p.realtorName || t('unknown'))]);
    if (p.isOwner && p.status === 'rented') { stats.push([t('rent_due'), fmtDate(p.rentDue)]); stats.push([t('overdue'), String(p.overdue || 0)]); }

    let acts = `<button class="btn ghost" data-act="waypoint" data-id="${p.id}">${icon('pin')}${t('a_waypoint')}</button>`;
    let extra = '';
    if (p.hasKey) acts += `<button class="btn ghost" data-act="lock" data-id="${p.id}">${icon(p.locked ? 'unlock' : 'lock')}${t(p.locked ? 'a_unlock' : 'a_lock')}</button>`;
    if (p.isOwner) {
        acts += `<button class="btn primary" data-act="go" data-view="shop" data-prop="${p.id}">${icon('sofa')}${t('a_furniture')}</button>`;
        if (p.status === 'rented') {
            const due = p.rentPrice * Math.max(p.overdue || 0, 1);
            acts += `<button class="btn green" data-act="payrent" data-id="${p.id}">${icon('cash')}${t('a_payrent', moneyText(due))}</button>`;
            acts += `<button class="btn danger wide" data-act="endlease" data-id="${p.id}">${icon('x')}${t('a_endlease')}</button>`;
        } else if (S.st.marketplace) {
            acts += p.salePrice ? `<button class="btn danger" data-act="unlist" data-id="${p.id}">${icon('x')}${t('a_unlist')}</button>`
                : `<button class="btn ghost" data-act="list" data-id="${p.id}">${icon('tag')}${t('a_list')}</button>`;
        }
        const keys = p.keys || [];
        extra = `<div class="section-title">${t('keys', keys.length, S.st.maxKeys)}</div><div class="keys">
            ${keys.length ? keys.map((k) => `<div class="keyrow">${icon('key')}<span class="grow">${esc(k.name)}</span><button class="icon-btn" data-act="removekey" data-id="${p.id}" data-ident="${esc(k.identifier)}">${icon('trash')}</button></div>`).join('') : `<div class="keyrow muted">${t('no_keys')}</div>`}
            <button class="btn ghost" data-act="givekey" data-id="${p.id}">${icon('plus')}${t('a_givekey')}</button></div>`;
    } else if (p.status === 'available') {
        if (S.st.directPurchase) acts += `<button class="btn primary" data-act="request" data-id="${p.id}">${icon('pen')}${p.ptype === 'rent' ? t('a_rentit', moneyText(p.rentPrice)) : t('a_buy', moneyText(p.price))}</button>`;
    } else if (p.salePrice) {
        acts += `<button class="btn primary" data-act="marketbuy" data-id="${p.id}">${icon('cart')}${t('a_buy', moneyText(p.salePrice))}</button>`;
    }
    const canDecor = p.hasDecor && (p.isOwner || (S.data.apps && S.data.apps.manage));
    if (canDecor) {
        const styles = S.st.decorStyles || [];
        extra = `<div class="section-title">${t('decor_title')}</div>
            <div class="decor-grid">${styles.map((d) => `<button class="decor-opt ${p.decor === d.key ? 'on' : ''}" data-act="setdecor" data-id="${p.id}" data-v="${d.key}">
                ${icon({ logistics: 'box', storage: 'grid', workshop: 'briefcase', off: 'x' }[d.key] || 'box')}<b>${esc(LANG === 'ar' && d.labelAr ? d.labelAr : d.label)}</b></button>`).join('')}</div>
            <div class="hint">${t('decor_hint')}</div>` + extra;
    }
    const alert = p.isOwner && p.overdue > 0 ? `<div class="alert">${icon('alert')}${t('overdue_alert', p.overdue, S.st.maxOverdue)}</div>` : '';
    return `<div class="page">${appbar(esc(p.label), `#${p.id} · ${esc(p.street || '')}`)}
        <div class="detail">
            <div ${propImg(p, 'hero')}><div class="chips">${statusChip(p)}<span class="chip">${t('rooms', p.rooms)}</span>${p.hasKey ? `<span class="chip ${p.locked ? 'red' : 'green'}">${icon(p.locked ? 'lock' : 'unlock')}</span>` : ''}</div>
                <h2>${esc(p.label)}</h2><p>${icon('pin')}${esc(p.street || '')}</p></div>
            <div class="info">${alert}
                <div class="stats">${stats.map(([k, v, m]) => `<div class="stat"><small>${k}</small><b class="${m ? 'money' : ''}">${v}</b></div>`).join('')}</div>
                <div class="actions">${acts}</div>${extra}
            </div>
        </div></div>`;
};

/* furniture shop ------------------------------------------------------ */
Views.shop = () => {
    const st = S.st;
    const owned = props().filter((p) => p.isOwner);
    if (!owned.find((p) => p.id === S.shopProp)) S.shopProp = owned.length ? owned[0].id : null;
    const cats = st.categories;
    let items = st.furniture;
    if (S.shopCat !== 'all') items = items.filter((f) => f.cat === S.shopCat);
    const q = S.shopSearch.toLowerCase();
    if (q) items = items.filter((f) => f.label.toLowerCase().includes(q) || f.model.includes(q));
    const cartCount = S.cart.reduce((a, c) => a + c.qty, 0);
    const total = S.cart.reduce((a, c) => a + c.qty * c.price, 0);
    const catBtn = (key, label, count, ic) => `<button class="cat ${S.shopCat === key ? 'on' : ''}" data-act="shopcat" data-cat="${key}">${catIconTile(key, ic)}<span><b>${label}</b><small>${t('pieces', count)}</small></span></button>`;
    const curCat = cats.find((c) => c.key === S.shopCat);
    return `<div class="page"><div class="appbar"><button class="icon-btn flip" data-act="back">${icon('back')}</button><div class="grow"></div></div>
    <div class="shop" style="margin-top:-46px">
        <div class="shop-side">
            <div style="padding-inline-start:46px"><h2>${t('shop_title')}</h2><div class="sub">${t('shop_sub')}</div></div>
            <div class="toolbar"><div class="search" style="max-width:none">${icon('search')}<input class="input" data-bind="shopSearch" data-rerender="1" placeholder="${t('search')}" value="${esc(S.shopSearch)}"></div></div>
            <div class="cats">${catBtn('all', t('all_furniture'), st.furniture.length, 'grid')}
                ${cats.map((c) => catBtn(c.key, catName(c), st.furniture.filter((f) => f.cat === c.key).length, c.icon)).join('')}</div>
            <div class="card shop-foot"><div><small>${t('pieces_lbl')}</small><b>${S.shopCount + cartCount}/${st.maxFurniture}</b></div><div><small>${t('bank')}</small><b class="acc">${moneyText(S.data.money)}</b></div></div>
        </div>
        <div class="shop-main">
            <div class="head"><h3>${curCat ? catName(curCat) : t('all_furniture')}</h3><span class="muted" style="font-size:11px">${t('pieces', items.length)}</span></div>
            <div class="fgrid">${items.map((f) => `<div class="card fitem"><div class="thumb">${furnIcon(f.cat)}${furnImg(f.model)}</div><b>${esc(f.label)}</b>
                <div class="row"><span class="price">${money(f.price)}</span><button class="add" data-act="addcart" data-model="${f.model}">${icon('plus')}</button></div></div>`).join('')}</div>
        </div>
        <div class="card cart">
            <div class="cart-head"><span>${t('cart')}</span><span class="chip">${cartCount}</span></div>
            <div class="field"><label>${t('for_property')}</label>
                ${owned.length ? `<select class="input" data-act-change="shopprop">${owned.map((p) => `<option value="${p.id}" ${p.id === S.shopProp ? 'selected' : ''}>#${p.id} ${esc(p.label)}</option>`).join('')}</select>` : `<div class="hint">${t('no_property')}</div>`}</div>
            ${S.cart.length ? `<div class="cart-list">${S.cart.map((c) => `<div class="citem"><div class="thumb">${furnIcon(c.cat)}${furnImg(c.model)}</div>
                <div class="ct"><b>${esc(c.label)}</b><small>${moneyText(c.price * c.qty)}</small></div>
                <div class="qty"><button data-act="qty" data-model="${c.model}" data-d="-1">${icon('minus')}</button>${c.qty}<button data-act="qty" data-model="${c.model}" data-d="1">${icon('plus')}</button></div></div>`).join('')}</div>`
                : `<div class="cart-empty"><b>${t('cart_empty')}</b><small>${t('cart_hint')}</small></div>`}
            <div class="cart-foot">
                <div class="r"><span>${t('pieces_lbl')}</span><b>${S.shopCount + cartCount}/${st.maxFurniture}</b></div>
                <div class="r"><span>${t('order_total')}</span><b class="total">${moneyText(total)}</b></div>
                <button class="btn ${S.cart.length && S.shopProp ? 'primary' : 'ghost'}" data-act="order" ${S.cart.length && S.shopProp ? '' : 'disabled'}>${t('place_order')} ${icon('back').replace('<svg', '<svg style="transform:scaleX(' + (LANG === 'ar' ? 1 : -1) + ')"')}</button>
            </div>
        </div>
    </div></div>`;
};
async function loadShopCount() {
    if (!S.shopProp) { S.shopCount = 0; return; }
    const r = await call('getFurniture', S.shopProp);
    S.shopCount = r && r.ok !== false && r.data && r.data.pieces ? r.data.pieces.length : (r && r.pieces ? r.pieces.length : 0);
    if (S.view === 'shop') render();
}

/* contracts ----------------------------------------------------------- */
Views.contracts = () => {
    const list = S.data.contracts || [];
    return `<div class="page">${appbar(t('contracts_title'), t('contracts_sub'))}
        <div class="scroll" style="flex:1">${list.length ? `<div class="rows">${list.map((c) => {
            const i = { image: c.image };
            return `<div class="rowi crow" data-act="opencontract" data-id="${c.id}"><div ${bgImage(c.image, 'mid')}></div>
                <div><b>${esc(c.label)}</b><small>#${c.id} · ${esc(c.buyerName || '')}</small></div>
                <div><span class="chip ${c.ctype === 'rent' ? 'blue' : ''}">${t(c.ctype === 'rent' ? 't_rent' : 't_sale')}</span></div>
                <div class="money">${moneyText(c.ctype === 'rent' ? c.rentPrice : c.price)}</div>
                <div style="text-align:end">${contractChip(c)}</div></div>`;
        }).join('')}</div>` : `<div class="empty">${icon('file')}<b>${t('empty_contracts')}</b></div>`}</div></div>`;
};

/* create property (realtor) ------------------------------------------- */
const noAccess = () => `<div class="page">${appbar(t('no_access_title'), '')}<div class="empty">${icon('lock')}<b>${t('no_access_title')}</b>${t('no_access_sub')}</div></div>`;

Views.create = () => {
    if (!(S.data.apps && S.data.apps.create)) return noAccess();
    if (!S.create) resetCreate();
    const c = S.create;
    const steps = ['s_interior', 's_details', 's_location', 's_confirm'];
    const stepper = `<div class="steps">${steps.map((s, i) => `<div class="step ${c.step === i + 1 ? 'on' : ''} ${c.step > i + 1 ? 'done' : ''}"><i>${c.step > i + 1 ? '✓' : i + 1}</i>${t(s)}</div>`).join('')}</div>`;
    let body = '';
    if (c.step === 1) {
        const list = S.st.interiors.filter((i) => S.interiorFilter === 'all' || (S.interiorFilter === 'shell' ? i.shell : S.interiorFilter === 'auto' ? i.auto : (!i.shell && !i.custom) || i.custom));
        const n = { all: S.st.interiors.length, ipl: S.st.interiors.filter((i) => !i.shell).length, shell: S.st.interiors.filter((i) => i.shell).length, auto: S.st.interiors.filter((i) => i.auto).length };
        const fb = (k, l) => `<button class="${S.interiorFilter === k ? 'on' : ''}" data-act="ifilter" data-f="${k}">${l} <span class="muted">${n[k]}</span></button>`;
        body = `<div class="toolbar" style="margin-bottom:10px"><div class="filters">${fb('all', t('all'))}${fb('ipl', t('f_ipl'))}${fb('shell', t('f_shells'))}${fb('auto', t('f_detected'))}</div>
            <div class="grow" style="flex:1"></div><button class="btn ghost" data-act="rescan" style="height:34px">${icon('search')}${t('rescan')}</button></div>
            <div class="igrid">${list.map((i) => {
            const off = i.available === false;
            const tags = [i.decor ? `<span class="chip rox-chip">ROX</span>` : '', i.custom ? `<span class="chip blue">MLO</span>` : '', i.shell ? `<span class="chip shell-chip">${i.auto ? t('detected') : 'SHELL'}</span>` : ''].join('');
            return `<div class="card icard ${c.interior === i.key ? 'on' : ''} ${off ? 'off' : ''}" ${off ? '' : `data-act="pickinterior" data-key="${i.key}"`}>
            <div ${bgImage(i.image, i.tier)}><span class="chip orange">${t('tier_' + i.tier)}</span>${tags}</div>
            <div class="ib"><b>${esc(interiorName(i))}</b><small>${off ? `<span style="color:var(--red)">${t('not_installed')}</span>` : i.needsEntry ? t('auto_entry_short') : i.custom ? t('custom_hint') : t('rooms', i.rooms)}</small></div></div>`;
        }).join('') || `<div class="empty">${icon('building')}${t('empty_list')}</div>`}</div>`;
    } else if (c.step === 2) {
        body = `<div class="form">
            <div class="field full"><label>${t('f_name')}</label><input class="input" data-bind="create.label" maxlength="48" placeholder="${t('f_name_ph')}" value="${esc(c.label)}"></div>
            <div class="field"><label>${t('f_type')}</label><div class="seg"><button class="${c.ptype === 'sale' ? 'on' : ''}" data-act="ptype" data-v="sale">${t('t_sale')}</button><button class="${c.ptype === 'rent' ? 'on' : ''}" data-act="ptype" data-v="rent">${t('t_rent')}</button></div></div>
            <div class="field"><label>${t('f_buyer')}</label><input class="input" type="number" min="1" data-bind="create.buyerId" value="${esc(c.buyerId)}" placeholder="ID"><span class="hint">${t('f_buyer_hint')}</span></div>
            ${c.ptype === 'sale' ? `<div class="field full"><label>${t('f_price')} (${S.st.currency})</label><input class="input" type="number" min="0" data-bind="create.price" value="${esc(c.price)}" placeholder="250000"></div>`
            : `<div class="field"><label>${t('f_rent')} (${S.st.currency})</label><input class="input" type="number" min="0" data-bind="create.rentPrice" value="${esc(c.rentPrice)}" placeholder="2500"></div>
               <div class="field"><label>${t('f_days')}</label><input class="input" type="number" min="1" max="60" data-bind="create.rentDays" value="${esc(c.rentDays)}"></div>`}
            <div class="field full"><label>${t('f_image')}</label><input class="input" data-bind="create.image" value="${esc(c.image)}" placeholder="https://..."><span class="hint">${t('f_image_hint')}</span></div>
        </div>`;
    } else if (c.step === 3) {
        const ci = interiorOf(c.interior);
        const insideBox = ci && ci.custom ? `<div class="locbox" style="margin-top:14px">
            <div class="aim" data-act="aiminside"><div class="aim-ic">${icon('door_open')}</div><b>${c.inside ? t('aim_repick') : t('aim_inside')}</b><p>${t('aim_inside_desc')}</p></div>
            <div class="card locinfo"><div class="section-title">${t('inside_point')}</div>
                ${c.inside ? `<div class="coords">x ${c.inside.x.toFixed(2)} · y ${c.inside.y.toFixed(2)} · z ${c.inside.z.toFixed(2)} · h ${c.inside.h.toFixed(0)}°</div><span class="chip green" style="align-self:flex-start">${icon('check')} OK</span>`
                : `<div class="empty" style="padding:10px">${icon('door_open')}${t('aim_none')}</div>`}</div></div>` : '';
        body = `<div class="locbox">
            <div class="aim" data-act="aim"><div class="aim-ic">${icon('crosshair')}</div><b>${c.door ? t('aim_repick') : t('aim_title')}</b><p>${t('aim_desc')}</p>
                <div class="keys-help"><kbd>E</kbd>${t('k_confirm')} <kbd>⌫</kbd>${t('k_cancel')}</div></div>
            <div class="card locinfo"><div class="section-title">${t('location')}</div>
                ${c.door ? `<b style="font-size:16px">${esc(c.street || '')}</b><div class="coords">x ${c.door.x.toFixed(2)} · y ${c.door.y.toFixed(2)} · z ${c.door.z.toFixed(2)} · h ${c.door.h.toFixed(0)}°</div><span class="chip green" style="align-self:flex-start">${icon('check')} OK</span>`
                : `<div class="empty" style="padding:10px">${icon('door')}${t('aim_none')}</div>`}</div></div>${insideBox}`;
    } else {
        const i = interiorOf(c.interior);
        const fake = { id: 0, ctype: c.ptype, price: Number(c.price) || 0, rentPrice: Number(c.rentPrice) || 0, rentDays: Number(c.rentDays) || 7, buyerName: c.buyerId ? `ID ${c.buyerId}` : t('unknown'),
            realtorName: S.data.name, status: 'pending', createdAt: Date.now() / 1000, label: c.label, interiorLabel: interiorName(i), image: c.image || (i && i.image), street: c.street, rooms: i && i.rooms };
        body = `<div style="max-width:760px;margin:0 auto">${contractPaper(fake, true)}</div>`;
    }
    const nextBtn = c.step < 4 ? `<button class="btn primary" data-act="cnext">${t('next')}</button>`
        : `<button class="btn primary" data-act="csubmit">${icon('send')}${c.buyerId ? t('send_contract') : t('create_listing')}</button>`;
    return `<div class="page">${appbar(t('create_title'), t('create_sub'))}${stepper}
        <div class="wizard"><div class="wizard-body">${body}</div>
        <div class="wizard-foot"><button class="btn ghost" data-act="cprev" ${c.step === 1 ? 'disabled' : ''}>${t('back')}</button>${nextBtn}</div></div></div>`;
};

function validateStep() {
    const c = S.create;
    if (c.step === 1 && !c.interior) return t('err_interior');
    if (c.step === 2) {
        if (!c.label.trim()) return t('err_name');
        if (c.ptype === 'sale' && !(Number(c.price) > 0)) return t('err_price');
        if (c.ptype === 'rent' && !(Number(c.rentPrice) > 0)) return t('err_price');
    }
    if (c.step === 3 && !c.door) return t('err_location');
    if (c.step === 3 && interiorOf(c.interior) && interiorOf(c.interior).custom && !c.inside) return t('err_inside');
    return null;
}

/* manage (realtor) ----------------------------------------------------- */
Views.manage = () => {
    if (!(S.data.apps && S.data.apps.manage)) return noAccess();
    const f = S.manageFilter;
    let list = props();
    if (f === 'market') list = list.filter((p) => p.salePrice);
    else if (f !== 'all') list = list.filter((p) => p.status === f);
    const q = S.manageSearch.toLowerCase();
    if (q) list = list.filter((p) => `${p.id} ${p.label} ${p.street || ''} ${p.ownerName || ''}`.toLowerCase().includes(q));
    list.sort((a, b) => b.id - a.id);
    const fb = (k, l) => `<button class="${f === k ? 'on' : ''}" data-act="mfilter" data-f="${k}">${l}</button>`;
    return `<div class="page">${appbar(t('manage_title'), t('manage_sub'), `<button class="btn primary" data-act="go" data-view="create">${icon('plus')}${t('app_create')}</button>`)}
        <div class="toolbar"><div class="search">${icon('search')}<input class="input" data-bind="manageSearch" data-rerender="1" placeholder="${t('search')}" value="${esc(S.manageSearch)}"></div>
            <div class="filters">${fb('all', t('all'))}${fb('available', t('st_available'))}${fb('pending', t('st_pending'))}${fb('owned', t('st_owned'))}${fb('rented', t('st_rented'))}${fb('market', t('st_sale'))}</div></div>
        <div class="scroll" style="flex:1">${list.length ? `<div class="rows">${list.map((p) => `<div class="rowi" data-act="go" data-view="mdetail" data-id="${p.id}">
            <div ${propImg(p)}></div><div><b>#${p.id} ${esc(p.label)}</b><small>${esc(p.street || '')}</small></div>
            <div>${statusChip(p)}</div><div><small>${t('owner')}</small><b style="font-size:12px">${esc(p.ownerName || t('unknown'))}</b></div><div class="money">${priceLine(p)}</div></div>`).join('')}</div>`
            : `<div class="empty">${icon('building')}<b>${t('empty_list')}</b></div>`}</div></div>`;
};

Views.mdetail = () => {
    const p = findProp(S.params.id);
    if (!p) return `<div class="page">${appbar('#', '')}<div class="empty">${icon('alert')}</div></div>`;
    if (!S.params.edit || S.params.edit.id !== p.id) S.params.edit = { id: p.id, label: p.label, ptype: p.ptype, price: p.price, rentPrice: p.rentPrice, rentDays: p.rentDays, image: p.image || '', interior: p.interior };
    const e = S.params.edit;
    const free = !p.ownerName;
    return `<div class="page">${appbar(`#${p.id} ${esc(p.label)}`, esc(p.street || ''), statusChip(p))}
        <div class="detail">
            <div class="info">
                <div class="form" style="grid-template-columns:1fr 1fr">
                    <div class="field full"><label>${t('f_name')}</label><input class="input" data-bind="params.edit.label" value="${esc(e.label)}"></div>
                    <div class="field"><label>${t('f_type')}</label><div class="seg"><button class="${e.ptype === 'sale' ? 'on' : ''}" data-act="eptype" data-v="sale" ${free ? '' : 'disabled'}>${t('t_sale')}</button><button class="${e.ptype === 'rent' ? 'on' : ''}" data-act="eptype" data-v="rent" ${free ? '' : 'disabled'}>${t('t_rent')}</button></div></div>
                    <div class="field"><label>${t('interior')}</label><select class="input" data-bind="params.edit.interior" ${free ? '' : 'disabled'}>${S.st.interiors.map((i) => `<option value="${i.key}" ${i.key === e.interior ? 'selected' : ''}>${esc(interiorName(i))}</option>`).join('')}</select></div>
                    <div class="field"><label>${t('f_price')}</label><input class="input" type="number" data-bind="params.edit.price" value="${esc(e.price)}"></div>
                    <div class="field"><label>${t('f_rent')}</label><input class="input" type="number" data-bind="params.edit.rentPrice" value="${esc(e.rentPrice)}"></div>
                    <div class="field"><label>${t('f_days')}</label><input class="input" type="number" data-bind="params.edit.rentDays" value="${esc(e.rentDays)}"></div>
                    <div class="field"><label>${t('f_image')}</label><input class="input" data-bind="params.edit.image" value="${esc(e.image)}" placeholder="https://..."></div>
                </div>
                <button class="btn primary" data-act="msave" data-id="${p.id}">${icon('check')}${t('save')}</button>
            </div>
            <div class="info">
                <div ${propImg(p, '', 'height:150px;border-radius:12px;flex-shrink:0')}></div>
                <div class="stats"><div class="stat"><small>${t('owner')}</small><b>${esc(p.ownerName || t('unknown'))}</b></div><div class="stat"><small>${t('realtor')}</small><b>${esc(p.realtorName || t('unknown'))}</b></div>
                    ${p.status === 'rented' ? `<div class="stat"><small>${t('rent_due')}</small><b>${fmtDate(p.rentDue)}</b></div><div class="stat"><small>${t('overdue')}</small><b>${p.overdue || 0}</b></div>` : ''}</div>
                <div class="actions">
                    <button class="btn ghost" data-act="waypoint" data-id="${p.id}">${icon('pin')}${t('a_waypoint')}</button>
                    <button class="btn ghost" data-act="mdoor" data-id="${p.id}">${icon('crosshair')}${t('a_door')}</button>
                    ${interiorOf(p.interior) && interiorOf(p.interior).custom ? `<button class="btn ghost wide" data-act="minside" data-id="${p.id}">${icon('door_open')}${t('a_inside')}</button>` : ''}
                    ${free ? `<button class="btn primary wide" data-act="msend" data-id="${p.id}">${icon('send')}${t('a_send')}</button>` : ''}
                    ${S.data.canManage && !free ? `<button class="btn danger" data-act="mevict" data-id="${p.id}">${icon('door_open')}${t('a_evict')}</button>` : ''}
                    ${S.data.canManage ? `<button class="btn danger ${free ? 'wide' : ''}" data-act="mdelete" data-id="${p.id}">${icon('trash')}${t('a_delete')}</button>` : ''}
                </div>
            </div>
        </div></div>`;
};

/* ------------------------------------------------------------------ overlays */
function contractPaper(c, preview) {
    const rent = c.ctype === 'rent';
    const terms = rent ? t('terms_rent').map((x) => x.replace('{0}', moneyText(c.rentPrice)).replace('{1}', c.rentDays).replace('{2}', S.st.maxOverdue)) : t('terms_sale');
    const canSign = !preview && c.status === 'pending' && c.isMine;
    const left = c.expiresAt ? Math.max(0, c.expiresAt - Math.floor(Date.now() / 1000)) : 0;
    return `<div class="paper">
        <div class="c-head"><div class="c-logo">${icon('file')}</div><div><h2>${t(rent ? 'c_title_rent' : 'c_title_sale')}</h2><p>${t('c_no', c.id || '—', fmtDate(c.createdAt))}</p></div><div class="grow"></div><span class="stamp ${c.status}">${t('st_' + c.status)}</span>${preview ? '' : `<button class="modal-x static" data-act="closeov">${icon('close')}</button>`}</div>
        <div class="c-body">
            <div class="c-top"><div ${bgImage(c.image, 'mid')}></div>
                <div class="c-grid">
                    <div><small>${t('card_view')}</small><b>${esc(c.label)}</b></div>
                    <div><small>${t('interior')}</small><b>${esc(c.interior && interiorOf(c.interior) ? interiorName(interiorOf(c.interior)) : (c.interiorLabel || ''))}</b></div>
                    <div><small>${t('location')}</small><b>${esc(c.street || t('unknown'))}</b></div>
                    <div><small>${t('rooms', '').trim() || 'Rooms'}</small><b>${c.rooms || 1}</b></div>
                    <div><small>${t('type')}</small><b>${t(rent ? 't_rent' : 't_sale')}</b></div>
                    <div><small>${rent ? t('rent') : t('price')}</small><b class="money">${moneyText(rent ? c.rentPrice : c.price)}</b> ${rent ? `<small class="muted">${t('per_days', c.rentDays)}</small>` : ''}</div>
                </div></div>
            <div class="c-due"><small>${t('c_due')}</small><b>${moneyText(rent ? c.rentPrice : c.price)}</b></div>
            <div class="parties"><div class="party"><small>${t('c_seller')}</small><b>${esc(c.realtorName || '')}</b></div><div class="party"><small>${t('c_buyer')}</small><b>${esc(c.buyerName || '')}</b></div></div>
            <ol class="terms">${terms.map((x) => `<li>${esc(x)}</li>`).join('')}</ol>
            <div class="sign"><div class="sigline">${c.signature ? `<span class="done">${esc(c.signature)}</span>` : canSign ? `<input id="sigInput" maxlength="40" placeholder="${t('c_signhere')}" value="">` : `<span class="muted">—</span>`}</div>
                ${canSign && left ? `<div class="timer">${t('c_expires')}<br><b id="cTimer">${fmtLeft(left)}</b></div>` : ''}</div>
        </div></div>`;
}
const fmtLeft = (s) => { s = Math.floor(s); return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };
let contractTimer = null;

function showOverlay(html, type) {
    S.overlay = type;
    const o = $('#overlay');
    o.innerHTML = html;
    o.classList.remove('hidden');
    const inp = o.querySelector('input');
    if (inp) setTimeout(() => inp.focus(), 50);
}
function closeOverlay() {
    $('#overlay').classList.add('hidden');
    $('#overlay').innerHTML = '';
    S.overlay = null;
    clearInterval(contractTimer);
    if (S.extFocus) { S.extFocus = false; post('closeOverlay'); }
}

function showContract(c) {
    const canSign = c.status === 'pending' && c.isMine;
    const realtorCancel = c.status === 'pending' && !c.isMine && S.data && S.data.isRealtor;
    showOverlay(`<div class="contract">${contractPaper(c)}
        <div class="modal-actions">${canSign ? `<button class="btn outline" data-act="cdecline" data-id="${c.id}">${icon('x')}${t('c_decline')}</button><button class="btn primary" data-act="csign" data-id="${c.id}">${icon('pen')}${t('c_sign')}</button>`
            : `<button class="btn outline" data-act="closeov" ${realtorCancel ? '' : 'style="grid-column:span 2"'}>${t('close')}</button>${realtorCancel ? `<button class="btn danger" data-act="cdecline" data-id="${c.id}">${t('cancel')}</button>` : ''}`}</div></div>`, 'contract');
    clearInterval(contractTimer);
    if (canSign) contractTimer = setInterval(() => {
        const el = $('#cTimer'); if (!el) return clearInterval(contractTimer);
        const left = Math.max(0, c.expiresAt - Math.floor(Date.now() / 1000));
        el.textContent = fmtLeft(left);
    }, 1000);
}

let dialogCb = null;
function modal(title, body, actions) {
    return `<div class="modal"><button class="modal-x" data-act="dlgno">${icon('close')}</button>
        <h3>${esc(title)}</h3>${body}<div class="modal-actions">${actions}</div></div>`;
}
function confirmDialog(msg, okLabel, cb, title) {
    dialogCb = cb;
    showOverlay(modal(title || t('confirm_title'), `<p>${esc(msg)}</p>`,
        `<button class="btn outline" data-act="dlgno">${t('cancel')}</button><button class="btn primary" data-act="dlgyes">${okLabel || t('confirm')}</button>`), 'dialog');
}
function promptDialog(msg, type, cb, title) {
    dialogCb = cb;
    showOverlay(modal(title || t('prompt_title'), `<p>${esc(msg)}</p><input class="input" id="dlgInput" type="${type || 'text'}">`,
        `<button class="btn outline" data-act="dlgno">${t('cancel')}</button><button class="btn primary" data-act="dlgyes">${t('confirm')}</button>`), 'dialog');
}

function showPropertyCard(p) {
    const buy = p.status === 'available' ? (S.st.directPurchase ? `<button class="btn primary" data-act="request" data-id="${p.id}">${p.ptype === 'rent' ? t('a_rentit', moneyText(p.rentPrice)) : t('a_buy', moneyText(p.price))}</button>` : '')
        : p.salePrice ? `<button class="btn primary" data-act="marketbuy" data-id="${p.id}">${t('a_buy', moneyText(p.salePrice))}</button>` : '';
    const visit = p.status === 'available' && S.st.visit ? `<button class="btn outline" data-act="visit" data-id="${p.id}">${icon('eye')}${t('a_visit')}</button>` : '';
    showOverlay(`<div class="modal modal-card"><button class="modal-x" data-act="closeov">${icon('close')}</button>
        <div ${propImg(p, 'modal-img')}></div>
        <div class="modal-pad"><div class="modal-title-row"><h3>${esc(p.label)}</h3>${statusChip(p)}</div>
        <div class="meta"><span>${icon('pin')}${esc(p.street || '')}</span><span>${icon('door')}${t('rooms', p.rooms)}</span><span>${esc(interiorName(interiorOf(p.interior)))}</span></div>
        <div class="modal-price">${priceLine(p)}</div>
        <div class="modal-actions" style="grid-template-columns:repeat(${Math.max(1, [buy, visit].filter(Boolean).length)},1fr)">${visit}${buy || `<button class="btn outline" data-act="closeov">${t('close')}</button>`}</div></div></div>`, 'card');
}

/* ------------------------------------------------------------------ furniture panel (inside house) */
function renderFP() {
    const fp = S.fp;
    if (!fp) return;
    const q = (fp.search || '').toLowerCase();
    let list = fp.pieces.filter((p) => (fp.tab === 'placed' ? p.placed : !p.placed));
    if (q) list = list.filter((p) => p.label.toLowerCase().includes(q));
    const el = $('#furniturePanel');
    el.innerHTML = `<div class="fp-head"><div><h2>${t('fp_title')}</h2><p>${esc(fp.label || t('fp_sub'))}</p></div><button class="fp-close" data-act="fpclose">${icon('close')}</button></div>
        <div class="seg"><button class="${fp.tab === 'storage' ? 'on' : ''}" data-act="fptab" data-tab="storage">${icon('box')} ${t('fp_storage')} (${fp.pieces.filter((p) => !p.placed).length})</button>
            <button class="${fp.tab === 'placed' ? 'on' : ''}" data-act="fptab" data-tab="placed">${icon('edit')} ${t('fp_placed')} (${fp.pieces.filter((p) => p.placed).length})</button></div>
        <div class="toolbar"><div class="search" style="max-width:none">${icon('search')}<input class="input" id="fpSearch" placeholder="${t('search')}" value="${esc(fp.search || '')}"></div></div>
        <div class="fp-list">${list.length ? list.map((p) => `<div class="ftile" data-act="fpplace" data-id="${p.id}"><div class="thumb">${furnIcon(p.cat)}${furnImg(p.model)}</div><b>${esc(p.label)}</b>
            <div class="tools">${p.placed ? `<button data-act="fpstore" data-id="${p.id}" title="${t('h_store')}">${icon('box')}</button>` : ''}<button class="sell" data-act="fpsell" data-id="${p.id}" title="sell">${icon('trash')}</button></div></div>`).join('')
            : `<div class="fp-empty">${t('fp_empty')}</div>`}</div>
        <div class="fp-foot"><span>${t(fp.tab === 'placed' ? 'fp_click_edit' : 'fp_click')}</span><span><b>●</b> ${t('fp_count', fp.pieces.length, fp.max)}</span></div>`;
    el.classList.remove('hidden');
    const s = $('#fpSearch');
    s.oninput = () => { fp.search = s.value; const pos = s.selectionStart; renderFP(); const n = $('#fpSearch'); n.focus(); n.setSelectionRange(pos, pos); };
}
async function refreshFP() {
    const r = await post('furnitureRefresh');
    if (S.fp && r && r.pieces) { S.fp.pieces = r.pieces; renderFP(); }
}

/* ------------------------------------------------------------------ render */
function render() {
    if (!S.open || !S.data) return;
    const v = Views[S.view] || Views.home;
    $('#screen').classList.toggle('in-app', S.view !== 'home');
    $('#view').innerHTML = v();
    if (S.view === 'dashboard') requestAnimationFrame(setupMap);
}

/* ------------------------------------------------------------------ actions */
const A = {
    home, back,
    go: (el) => {
        const view = el.dataset.view;
        if (view === 'list') S.listSearch = '';
        if (view === 'create' && (!S.create || S.create.step === 4)) resetCreate();
        if (view === 'shop') { if (el.dataset.prop) { S.shopProp = Number(el.dataset.prop); S.cart = []; } go(view, {}); loadShopCount(); return; }
        go(view, { kind: el.dataset.kind, id: el.dataset.id ? Number(el.dataset.id) : undefined });
    },
    pin: (el) => go('detail', { id: Number(el.dataset.id) }),
    zoom: (el) => zoomAt(el.dataset.d === '1' ? 1.35 : 1 / 1.35),
    waypoint: (el) => { const p = findProp(el.dataset.id); if (p) post('waypoint', { x: p.door.x, y: p.door.y }); },
    lock: async (el) => { await call('toggleLock', Number(el.dataset.id)); },
    payrent: async (el) => { const r = await call('payRent', Number(el.dataset.id)); if (r.ok) refresh(); },
    endlease: (el) => confirmDialog(t('q_endlease'), t('yes'), async () => { const r = await call('endLease', Number(el.dataset.id)); if (r.ok) back(); }),
    list: (el) => promptDialog(t('q_list', Math.round((S.st.marketTax || 0) * 100)), 'number', async (v) => { await call('listForSale', Number(el.dataset.id), Number(v)); }),
    unlist: async (el) => { await call('cancelListing', Number(el.dataset.id)); },
    givekey: (el) => promptDialog(t('q_givekey'), 'number', async (v) => { await call('giveKey', Number(el.dataset.id), Number(v)); }),
    removekey: async (el) => { await call('removeKey', Number(el.dataset.id), el.dataset.ident); },
    request: async (el) => {
        const id = Number(el.dataset.id);
        if (S.overlay) closeOverlayKeepFocus();
        const r = await call('requestAvailable', id); // server answers with the contract event
        if (!r.ok && !S.overlay && S.extFocus) { S.extFocus = false; post('closeOverlay'); }
    },
    marketbuy: (el) => {
        const p = findProp(el.dataset.id) || S.cardProp; if (!p) return;
        confirmDialog(t('q_buy', p.label, moneyText(p.salePrice)), t('yes'), async () => { const r = await call('marketBuy', p.id); if (r.ok) { if (S.open) refresh(); else closeOverlay(); } });
    },
    visit: (el) => { S.extFocus = false; closeOverlayKeepFocus(); post('visit', { id: Number(el.dataset.id) }); },
    closeov: () => closeOverlay(),
    dlgno: () => { dialogCb = null; closeOverlay(); },
    dlgyes: () => {
        const inp = $('#dlgInput'); const val = inp ? inp.value : true;
        if (inp && !val) return;
        const cb = dialogCb; dialogCb = null; closeOverlay(); if (cb) cb(val);
    },
    opencontract: (el) => { const c = (S.data.contracts || []).find((x) => x.id === Number(el.dataset.id)); if (c) showContract(c); },
    csign: async (el) => {
        const sig = ($('#sigInput') || {}).value || '';
        if (!sig.trim()) { $('#sigInput').focus(); return; }
        const r = await call('signContract', Number(el.dataset.id), sig.trim());
        if (r.ok) { closeOverlay(); if (S.open) refresh(); }
    },
    cdecline: async (el) => { const r = await call('declineContract', Number(el.dataset.id)); if (r.ok) { closeOverlay(); if (S.open) refresh(); } },
    // shop
    shopcat: (el) => { S.shopCat = el.dataset.cat; render(); },
    addcart: (el) => {
        const f = S.st.furniture.find((x) => x.model === el.dataset.model); if (!f) return;
        const c = S.cart.find((x) => x.model === f.model);
        const count = S.cart.reduce((a, x) => a + x.qty, 0);
        if (S.shopCount + count >= S.st.maxFurniture) return toast(`${S.shopCount + count}/${S.st.maxFurniture}`, 'error');
        if (c) c.qty++; else S.cart.push({ ...f, qty: 1 });
        render();
    },
    qty: (el) => {
        const c = S.cart.find((x) => x.model === el.dataset.model); if (!c) return;
        const count = S.cart.reduce((a, x) => a + x.qty, 0);
        if (el.dataset.d === '1' && S.shopCount + count >= S.st.maxFurniture) return;
        c.qty += Number(el.dataset.d);
        if (c.qty <= 0) S.cart = S.cart.filter((x) => x !== c);
        render();
    },
    order: async () => {
        if (!S.cart.length || !S.shopProp) return;
        const r = await call('orderFurniture', S.shopProp, S.cart.map((c) => ({ model: c.model, qty: c.qty })));
        if (r.ok) { S.cart = []; if (r.data && r.data.money !== undefined) S.data.money = r.data.money; await loadShopCount(); render(); }
    },
    // create
    pickinterior: (el) => { S.create.interior = el.dataset.key; render(); },
    ptype: (el) => { S.create.ptype = el.dataset.v; render(); },
    cprev: () => { if (S.create.step > 1) { S.create.step--; render(); } },
    cnext: () => { const err = validateStep(); if (err) return toast(err, 'error'); S.create.step++; render(); },
    aim: () => { S.pickTarget = { type: 'create' }; post('pickLocation'); },
    aiminside: () => { S.pickTarget = { type: 'createInside' }; post('pickLocation', { mode: 'floor' }); },
    ifilter: (el) => { S.interiorFilter = el.dataset.f; render(); },
    rescan: async () => { await call('rescan'); },
    setdecor: async (el) => { await call('setDecor', Number(el.dataset.id), el.dataset.v); },
    minside: (el) => { S.pickTarget = { type: 'inside', id: Number(el.dataset.id) }; post('pickLocation', { mode: 'floor' }); },
    csubmit: async (el) => {
        const c = S.create;
        el.disabled = true;
        const r = await call('createProperty', {
            label: c.label.trim(), interior: c.interior, ptype: c.ptype, price: Number(c.price) || 0, rentPrice: Number(c.rentPrice) || 0,
            rentDays: Number(c.rentDays) || 7, buyerId: c.buyerId ? Number(c.buyerId) : null, image: c.image.trim() || null, door: c.door, street: c.street, inside: c.inside || null,
        });
        el.disabled = false;
        if (r.ok) { resetCreate(); await refresh(); S.history = [{ view: 'home', params: {} }]; S.view = 'mdetail'; S.params = { id: r.data }; render(); }
    },
    // manage
    mfilter: (el) => { S.manageFilter = el.dataset.f; render(); },
    eptype: (el) => { S.params.edit.ptype = el.dataset.v; render(); },
    msave: async (el) => {
        const e = S.params.edit;
        await call('updateProperty', Number(el.dataset.id), { label: e.label, ptype: e.ptype, price: Number(e.price), rentPrice: Number(e.rentPrice), rentDays: Number(e.rentDays), image: e.image, interior: e.interior });
        S.params.edit = null;
    },
    mdoor: (el) => { S.pickTarget = { type: 'door', id: Number(el.dataset.id) }; post('pickLocation'); },
    msend: (el) => promptDialog(t('q_sendcontract'), 'number', async (v) => { await call('sendContract', Number(el.dataset.id), Number(v)); }),
    mevict: (el) => confirmDialog(t('q_evict'), t('yes'), async () => { await call('evictProperty', Number(el.dataset.id)); }),
    mdelete: (el) => confirmDialog(t('q_delete'), t('yes'), async () => { const r = await call('deleteProperty', Number(el.dataset.id)); if (r.ok) back(); }),
    // settings
    setwall: (el) => { S.settings.wallpaper = el.dataset.src; saveSettings(); applySettings(); render(); },
    setwallurl: () => { const v = ($('#customWall').value || '').trim(); if (v && !/^https:\/\//.test(v)) return toast('https://...', 'error'); S.settings.wallpaper = v || null; saveSettings(); applySettings(); render(); },
    resetscale: () => { S.settings.scale = 1; saveSettings(); applySettings(); render(); },
    setlang: (el) => { S.settings.lang = el.dataset.v; saveSettings(); applySettings(); post('setLang', { lang: S.settings.lang }); render(); },
    // furniture panel
    fpclose: () => { S.fp = null; $('#furniturePanel').classList.add('hidden'); post('furnitureClose'); },
    fptab: (el) => { S.fp.tab = el.dataset.tab; renderFP(); },
    fpplace: (el) => {
        const p = S.fp.pieces.find((x) => x.id === Number(el.dataset.id)); if (!p) return;
        S.fp = null; $('#furniturePanel').classList.add('hidden');
        post('furniturePlace', { id: p.id, model: p.model, label: p.label, placed: p.placed, rz: p.rz });
    },
    fpstore: async (el) => { const r = await post('furnitureStore', { id: Number(el.dataset.id) }); if (r && r.ok) refreshFP(); },
    fpsell: (el) => {
        const p = S.fp.pieces.find((x) => x.id === Number(el.dataset.id)); if (!p) return;
        confirmDialog(t('q_sell_piece', moneyText(p.price * (S.st.sellBack || 0.5))), t('yes'), async () => { const r = await post('furnitureSell', { id: p.id }); if (r && r.ok) refreshFP(); });
    },
};
function closeOverlayKeepFocus() { $('#overlay').classList.add('hidden'); $('#overlay').innerHTML = ''; S.overlay = null; }

document.addEventListener('click', (e) => {
    const el = e.target.closest('[data-act]');
    if (!el || el.disabled) return;
    const fn = A[el.dataset.act];
    if (fn) { e.stopPropagation(); fn(el); }
});
document.addEventListener('input', (e) => {
    const el = e.target;
    if (el.id === 'scaleRange') {
        S.settings.scale = Number(el.value) / 100; saveSettings(); applySettings();
        const v = $('#scaleVal'); if (v) v.textContent = el.value + '%';
        return;
    }
    if (!el.dataset || !el.dataset.bind) return;
    const path = el.dataset.bind.split('.');
    let obj = S;
    for (let i = 0; i < path.length - 1; i++) obj = obj[path[i]];
    obj[path[path.length - 1]] = el.value;
    if (el.dataset.rerender) {
        const pos = el.selectionStart; const bind = el.dataset.bind;
        render();
        const n = document.querySelector(`[data-bind="${bind}"]`); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
    }
});
document.addEventListener('change', (e) => {
    if (e.target.dataset.actChange === 'shopprop') { S.shopProp = Number(e.target.value); S.cart = []; loadShopCount(); }
});
document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && S.overlay === 'dialog') return A.dlgyes();
    if (e.key !== 'Escape') return;
    if (S.overlay) { if (S.overlay === 'dialog') { dialogCb = null; } closeOverlay(); return; }
    if (S.fp) return A.fpclose();
    if (S.open) {
        if (S.view !== 'home') back();
        else post('close');
    }
});

/* ------------------------------------------------------------------ messages from Lua */
function applyStatic(st) {
    if (!st) return;
    S.st = Object.assign(S.st || {}, st);
    applySettings();
}

window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    switch (m.action) {
        case 'open':
            applyStatic(m.static);
            S.data = m.data; S.open = true; S.history = []; S.view = m.app || 'home'; S.params = {};
            $('#tablet').classList.remove('hidden');
            render();
            break;
        case 'close':
            S.open = false;
            $('#tablet').classList.add('hidden');
            if (S.overlay) closeOverlayKeepFocus();
            break;
        case 'hide':
            $('#tablet').classList.add('hidden');
            break;
        case 'sync':
            if (S.data) { S.data.properties = m.properties; if (S.open && !document.activeElement.matches('input,select')) render(); }
            break;
        case 'registry':
            if (S.st) { if (m.static.interiors) S.st.interiors = m.static.interiors; S.st.furnitureImages = m.static.furnitureImages || {}; }
            else S.st = m.static;
            if (S.open && (S.view === 'create' || S.view === 'shop')) render();
            break;
        case 'locationPicked':
            if (S.open) $('#tablet').classList.remove('hidden');
            if (m.location && S.pickTarget) {
                if (S.pickTarget.type === 'create') { S.create.door = m.location; S.create.street = m.street || ''; render(); }
                else if (S.pickTarget.type === 'createInside') { S.create.inside = m.location; render(); }
                else if (S.pickTarget.type === 'inside') call('setInside', S.pickTarget.id, m.location);
                else if (S.pickTarget.type === 'door') call('setDoor', S.pickTarget.id, m.location, m.street || '');
            }
            S.pickTarget = null;
            break;
        case 'contract':
            applyStatic(m.static);
            if (!S.data) S.data = { contracts: [], properties: [], name: '' };
            S.extFocus = true;
            showContract(m.contract);
            break;
        case 'propertyCard':
            applyStatic(m.static);
            if (!S.data) S.data = { contracts: [], properties: [], name: '' };
            S.cardProp = m.property;
            S.extFocus = true;
            showPropertyCard(m.property);
            break;
        case 'furniturePanel':
            applyStatic(m.static);
            S.fp = { propertyId: m.propertyId, label: m.label, pieces: m.pieces || [], max: m.max, tab: (S.fp && S.fp.tab) || 'storage', search: '' };
            renderFP();
            break;
        case 'furniturePanelClose':
            S.fp = null;
            $('#furniturePanel').classList.add('hidden');
            break;
        case 'placeHint': {
            const h = $('#placeHint');
            if (!m.show) { h.classList.add('hidden'); break; }
            h.innerHTML = `<span class="ttl">${esc(m.label || '')}</span><span><kbd>E</kbd>${t('h_place')}</span><span><kbd>⇅</kbd><kbd>← →</kbd>${t('h_rotate')}</span>
                <span><kbd>↑ ↓</kbd>${t('h_height')}</span><span><kbd>Shift</kbd>${t('h_precise')}</span><span><kbd>G</kbd>${t('h_snap')}</span>
                ${m.edit ? `<span><kbd>Del</kbd>${t('h_store')}</span>` : ''}<span><kbd>⌫</kbd>${t('h_cancel')}</span>`;
            h.classList.remove('hidden');
            break;
        }
        case 'notify':
            toast(m.msg, m.kind);
            break;
    }
});

const tick = () => { const c = $('#clock'); if (c) c.textContent = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }); };
tick(); setInterval(tick, 1000);

/* ------------------------------------------------------------------ browser preview (outside FiveM) */
const Mock = {
    post(name, data) {
        if (name === 'call') {
            if (data.name === 'bootstrap') return Promise.resolve({ ok: true, data: Mock.data });
            if (data.name === 'getFurniture') return Promise.resolve({ ok: true, data: { pieces: [], max: 25 } });
            toast(`[preview] ${data.name}`, 'info');
            return Promise.resolve({ ok: true, data: 1 });
        }
        if (name === 'close') { $('#tablet').classList.add('hidden'); S.open = false; }
        if (name === 'pickLocation') setTimeout(() => window.postMessage({ action: 'locationPicked', location: { x: -47.3, y: -585.9, z: 37.95, h: 70 }, street: 'Alta St, Pillbox Hill' }, '*'), 400);
        return Promise.resolve({ ok: true });
    },
};
if (!IS_GAME) {
    document.body.style.background = 'linear-gradient(160deg,#3a4c5c,#1b2530)';
    const ints = [['low_apartment', 'Low-End Apartment', 'شقة اقتصادية', 'low', 1], ['medium_apartment', 'Medium Apartment', 'شقة متوسطة', 'mid', 2], ['integrity_way', '4 Integrity Way Apt', 'شقة انتغريتي واي', 'high', 2], ['north_conker', 'North Conker Villa', 'فيلا نورث كونكر', 'high', 3], ['franklin_vinewood', 'Vinewood Hills Villa', 'فيلا فاينوود هيلز', 'luxury', 4], ['penthouse_modern', 'Eclipse Penthouse - Modern', 'بنتهاوس إكلبس - مودرن', 'luxury', 3]]
        .map(([key, label, labelAr, tier, rooms]) => ({ key, label, labelAr, tier, rooms, image: `img/houses/${key}.jpg` }))
        .concat([{ key: 'rox_wh_large', label: 'ROX Warehouse · Large', labelAr: 'مخزن ROX · كبير', tier: 'luxury', rooms: 1, image: 'img/houses/rox_wh_large.png', decor: true },
            { key: 'rox_wh_vehicle', label: 'ROX Vehicle Warehouse', labelAr: 'مخزن سيارات ROX', tier: 'luxury', rooms: 1, image: 'img/houses/rox_wh_vehicle.png', decor: true },
            { key: 'custom', label: 'Custom location / MLO', labelAr: 'موقع مخصص / MLO', tier: 'mid', rooms: 1, custom: true },
            { key: 'shell_ranch', label: 'Ranch House', labelAr: 'بيت مزرعة', tier: 'mid', rooms: 3, shell: 'shell_ranch', available: true },
            { key: 'shell_highend', label: 'Highend', labelAr: 'Highend', tier: 'mid', rooms: 1, shell: 'shell_highend', auto: true, needsEntry: true, available: true },
            { key: 'shell_michael', label: 'Grand Mansion (Shell)', labelAr: 'قصر فخم', tier: 'luxury', rooms: 5, shell: 'shell_michael', available: false }]);
    const cats = [['bathroom', 'Bathroom', 'الحمام', 'bath'], ['bed', 'Bed', 'غرف النوم', 'bed'], ['chair', 'Chair & Sofa', 'كراسي وكنب', 'chair'], ['electronic', 'Electronic', 'إلكترونيات', 'tv'], ['kitchen', 'Kitchen', 'المطبخ', 'kitchen'], ['light', 'Light', 'إضاءة', 'light']].map(([key, label, labelAr, icon]) => ({ key, label, labelAr, icon }));
    const furn = [['prop_sink_02', 'Bathroom Sink (Rounded)', 'bathroom', 280], ['prop_sink_04', 'Bathroom Sink (Pedestal)', 'bathroom', 250], ['prop_toilet_01', 'Toilet', 'bathroom', 350], ['p_mbbed_s', 'Master Bed', 'bed', 2500], ['prop_couch_01', 'Leather Couch', 'chair', 1200], ['prop_tv_flat_01', 'Flat TV (Large)', 'electronic', 1500], ['prop_fridge_01', 'Fridge', 'kitchen', 900], ['apa_mp_h_floorlamp_a', 'Floor Lamp', 'light', 180]].map(([model, label, cat, price]) => ({ model, label, cat, price }));
    const P = (id, label, interior, status, x, y, extra = {}) => ({ id, label, interior, status, ptype: 'sale', price: 180000 + id * 25000, rentPrice: 2500, rentDays: 7, door: { x, y, z: 30, h: 0 }, street: 'Alta St, Pillbox Hill', locked: true, rooms: 2, realtorName: 'Saad Realty', ...extra });
    Mock.data = {
        name: 'Jaber Ali', money: 42347, serverId: 1, isRealtor: true, canManage: true, grade: 3, apps: { create: true, manage: true, contracts: true },
        properties: [P(1, 'ROX Logistics Depot', 'rox_wh_large', 'owned', -47, -585, { isOwner: true, hasKey: true, ownerName: 'Jaber Ali', keys: [], hasDecor: true, decor: 'logistics' }),
            P(2, 'Vinewood Villa', 'franklin_vinewood', 'available', 7, 538), P(3, 'Grove Room', 'low_apartment', 'rented', -14, -1440, { ptype: 'rent', isOwner: true, hasKey: true, ownerName: 'Jaber Ali', overdue: 1, rentDue: Date.now() / 1000 + 86400 }),
            P(4, 'Conker Hills', 'north_conker', 'owned', 342, 437, { ownerName: 'Omar', salePrice: 650000 }), P(5, 'Mirror Park 4', 'medium_apartment', 'available', 1100, -500, { ptype: 'rent' })],
        contracts: [{ id: 7, propertyId: 2, ctype: 'sale', price: 230000, rentPrice: 0, rentDays: 7, buyerName: 'Jaber Ali', realtorName: 'Saad Realty', status: 'pending', isMine: true, createdAt: Date.now() / 1000, expiresAt: Date.now() / 1000 + 1700, label: 'Vinewood Villa', interior: 'franklin_vinewood', street: 'Wild Oats Dr', rooms: 4 }],
    };
    const st = { locale: 'en', defaultLocale: 'en', wallpaper: 'img/wallpapers/street.jpg', currency: '$', interiors: ints, furniture: furn, categories: cats, maxFurniture: 25, furnitureImage: false, map: { image: 'img/map.jpg', minX: -4140, maxX: 4860, minY: -4300, maxY: 8400 }, rentDays: 7, directPurchase: true, marketplace: true, marketTax: 0.05, sellBack: 0.5, maxKeys: 5, maxOverdue: 3, contractMinutes: 30, visit: true, decorStyles: [{ key: 'logistics', label: 'Logistics Hub', labelAr: 'مركز لوجستي' }, { key: 'off', label: 'Empty', labelAr: 'فاضي' }, { key: 'storage', label: 'Dense Storage', labelAr: 'تخزين كثيف' }, { key: 'workshop', label: 'Workshop Garage', labelAr: 'ورشة وكراج' }] };
    const q = new URLSearchParams(location.search);
    if (q.get('lang')) S.settings.lang = q.get('lang');
    if (q.get('wall')) S.settings.wallpaper = `img/wallpapers/${q.get('wall')}.jpg`;
    setTimeout(() => {
        window.postMessage({ action: 'open', data: Mock.data, static: st, app: q.get('app') || 'home' }, '*');
        if (q.get('dialog')) setTimeout(() => confirmDialog('Someone wants to buy your property. Do you want to allow it?', null, null, 'Sale Request'), 100);
        if (q.get('card')) setTimeout(() => window.postMessage({ action: 'propertyCard', property: Mock.data.properties[1], static: st }, '*'), 100);
        if (q.get('contract')) setTimeout(() => window.postMessage({ action: 'contract', contract: Mock.data.contracts[0], static: st }, '*'), 100);
        if (q.get('fp')) setTimeout(() => { window.postMessage({ action: 'close' }, '*'); window.postMessage({ action: 'furniturePanel', propertyId: 1, label: 'Alta Street 12', max: 25, pieces: [{ id: 1, model: 'prop_couch_01', label: 'Leather Couch', cat: 'chair', placed: false, price: 1200 }, { id: 2, model: 'prop_tv_flat_01', label: 'Flat TV', cat: 'electronic', placed: true, price: 1500 }], static: st }, '*'); }, 100);
        if (q.get('step')) setTimeout(() => { S.create.interior = 'integrity_way'; S.create.label = 'Alta Street 12'; S.create.price = '250000'; S.create.buyerId = '12'; S.create.door = { x: -47.3, y: -585.9, z: 37.95, h: 70 }; S.create.street = 'Alta St, Pillbox Hill'; S.create.step = Number(q.get('step')); render(); }, 150);
    }, 50);
}
