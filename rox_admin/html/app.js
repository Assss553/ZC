/* ROX Store | rox_admin | All rights reserved. */
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const RES = window.GetParentResourceName ? GetParentResourceName() : 'rox_admin';
const PREVIEW = !window.invokeNative;
const post = (n, d = {}) => PREVIEW ? Promise.resolve(Mock(n, d)) : fetch(`https://${RES}/${n}`, { method: 'POST', body: JSON.stringify(d) }).then(r => r.json()).catch(() => null);
const call = (name, args) => post('call', { name, args });

/* ---------------- i18n ---------------- */
const T = {
  en: { subtitle: 'Players & character management', dashboard: 'Dashboard', players: 'Players', characters: 'Characters', logs: 'Join / Quit', coords: 'Coords', actions: 'Admin log', staff: 'Staff', perms: 'Permissions', keys: 'Keybinds',
    online: 'Players online', police: 'Police', ems: 'EMS', staffOn: 'Staff online', uptime: 'Server uptime', today: 'Unique today', avgPing: 'Average ping', activity: 'Player activity', admins: 'Administrators online',
    search: 'Search name, Steam, Steam ID, Character ID, Server ID…', name: 'Name', character: 'Character', steam: 'Steam', steamId: 'Steam ID', sid: 'ID', cid: 'Character ID', job: 'Job', joined: 'Joined', session: 'Session', status: 'Status',
    profile: 'Profile', goto: 'Go to', bring: 'Bring', freeze: 'Freeze', revive: 'Revive', kick: 'Kick', setJob: 'Set job', money: 'Money', all: 'All', onlineNow: 'Online now', quit: 'Quit', dropped: 'Lost connection', kicked: 'Kicked', server: 'Server restart',
    left: 'Left', duration: 'Duration', reason: 'Reason', from: 'From', to: 'To', created: 'Created', lastLogin: 'Last login', inUse: 'IN USE', offline: 'Offline', owner: 'Owner account', history: 'History', open: 'Open',
    current: 'My position', copy: 'Copy', save: 'Save', label: 'Label', shared: 'Shared', tp: 'Teleport', del: 'Delete', saved: 'Saved locations', manual: 'Go to coordinates', waypoint: 'Waypoint', lastPos: 'Last known position',
    account: 'Account', chars: 'Characters', sessions: 'Sessions', switches: 'Character switches', adminActs: 'Admin actions on this player', totalPlay: 'Total play time', firstSeen: 'First seen', lastSeen: 'Last activity', cur: 'Current / last character',
    admin: 'Admin', action: 'Action', target: 'Target', details: 'Details', time: 'Time', identifier: 'Identifier', rank: 'Rank', addStaff: 'Add staff', none: 'None', remove: 'Remove',
    perm: 'Permission', keysHelp: 'Click a key, then press the new key. ESC clears. Saved for you only.', reset: 'Reset to default', conflict: 'Key already used by', press: 'PRESS…', done: 'Done', denied: 'No permission', failed: 'Failed', amount: 'Amount', grade: 'Grade', ip: 'IP', yes: 'Yes', no: 'No', type: 'Type', unknown: 'Unknown' },
  ar: { subtitle: 'إدارة اللاعبين والشخصيات', dashboard: 'الرئيسية', players: 'اللاعبين', characters: 'الشخصيات', logs: 'الدخول والخروج', coords: 'الإحداثيات', actions: 'سجل الإدارة', staff: 'الطاقم', perms: 'الصلاحيات', keys: 'الأزرار',
    online: 'اللاعبين المتصلين', police: 'الشرطة', ems: 'الإسعاف', staffOn: 'الإدارة المتصلة', uptime: 'مدة تشغيل السيرفر', today: 'لاعبين اليوم', avgPing: 'متوسط البنق', activity: 'نشاط اللاعبين', admins: 'الإداريين المتصلين',
    search: 'ابحث بالاسم، ستيم، Steam ID، رقم الشخصية، الآي دي…', name: 'الاسم', character: 'الشخصية', steam: 'ستيم', steamId: 'Steam ID', sid: 'ID', cid: 'رقم الشخصية', job: 'الوظيفة', joined: 'الدخول', session: 'الجلسة', status: 'الحالة',
    profile: 'الملف', goto: 'انتقال', bring: 'سحب', freeze: 'تجميد', revive: 'إنعاش', kick: 'طرد', setJob: 'تغيير الوظيفة', money: 'الفلوس', all: 'الكل', onlineNow: 'متصل الآن', quit: 'خروج طبيعي', dropped: 'انقطاع', kicked: 'طرد', server: 'ريستارت',
    left: 'الخروج', duration: 'المدة', reason: 'السبب', from: 'من', to: 'إلى', created: 'الإنشاء', lastLogin: 'آخر دخول', inUse: 'مستخدمة', offline: 'غير متصل', owner: 'حساب المالك', history: 'السجل', open: 'فتح',
    current: 'موقعي الحالي', copy: 'نسخ', save: 'حفظ', label: 'الاسم', shared: 'مشترك', tp: 'انتقال', del: 'حذف', saved: 'المواقع المحفوظة', manual: 'انتقال لإحداثيات', waypoint: 'تحديد', lastPos: 'آخر موقع معروف',
    account: 'الحساب', chars: 'الشخصيات', sessions: 'الجلسات', switches: 'تبديل الشخصيات', adminActs: 'الإجراءات الإدارية عليه', totalPlay: 'إجمالي اللعب', firstSeen: 'أول دخول', lastSeen: 'آخر نشاط', cur: 'الشخصية الحالية / الأخيرة',
    admin: 'الإداري', action: 'الإجراء', target: 'الهدف', details: 'التفاصيل', time: 'الوقت', identifier: 'المعرّف', rank: 'الرتبة', addStaff: 'إضافة إداري', none: 'بدون', remove: 'إزالة',
    perm: 'الصلاحية', keysHelp: 'اضغط على الزر ثم اضغط الزر الجديد. ESC يمسحه. محفوظ لك أنت فقط.', reset: 'إرجاع الافتراضي', conflict: 'الزر مستخدم في', press: 'اضغط…', done: 'تم', denied: 'ما عندك صلاحية', failed: 'فشل', amount: 'المبلغ', grade: 'الرتبة', ip: 'IP', yes: 'نعم', no: 'لا', type: 'النوع', unknown: 'غير معروف' },
};
let lang = (() => { try { return localStorage.getItem('rox_admin_lang'); } catch { return null; } })() || 'en';
const t = (k) => T[lang][k] ?? k;
function setLang(l) { lang = l; try { localStorage.setItem('rox_admin_lang', l); } catch {}
  document.documentElement.lang = l; document.documentElement.dir = l === 'ar' ? 'rtl' : 'ltr'; $('lang').textContent = l === 'ar' ? 'EN' : 'ع';
  document.querySelectorAll('[data-t]').forEach(e => e.textContent = t(e.dataset.t)); renderTabs(); show(tab); }
$('lang').onclick = () => setLang(lang === 'ar' ? 'en' : 'ar');

/* ---------------- formatting ---------------- */
const fDate = (u) => u ? new Date(u * 1000).toLocaleString(lang === 'ar' ? 'ar-EG-u-nu-latn' : 'en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';
const fDur = (s) => { if (s == null) return '—'; s = Math.max(0, s | 0); const h = s / 3600 | 0, m = (s % 3600) / 60 | 0; return h ? `${h}h ${m}m` : `${m}m ${s % 60}s`; };
const now = () => Date.now() / 1000 | 0;
const initials = (n) => String(n || '?').trim().split(/\s+/).map(w => w[0]).slice(0, 2).join('').toUpperCase();
const steamHex = (s) => s ? s.replace('steam:', '') : '';
const steam64 = (s) => { try { return s ? (BigInt('0x' + steamHex(s))).toString() : ''; } catch { return ''; } };
const steamCell = (s) => s ? `<span class="mono" title="steam64: ${steam64(s)}">${esc(s)}</span>` : `<span class="pill bad">no steam</span>`;
const quitPill = (q) => !q ? `<span class="pill ok"><span class="dot on"></span>${t('onlineNow')}</span>` : `<span class="pill ${q === 'quit' ? '' : q === 'kicked' ? 'bad' : 'warn'}">${t(q) || q}</span>`;
function toast(m, bad) { const e = $('toast'); e.textContent = m; e.className = 'toast on' + (bad ? ' bad' : ''); clearTimeout(e._t); e._t = setTimeout(() => e.className = 'toast', 2200); }
function copy(txt) { const c = $('clip'); c.value = txt; c.select(); document.execCommand('copy'); toast(t('copy') + ': ' + txt); }

/* ---------------- state ---------------- */
let me = null, tab = 'dashboard', timer = null;
const TABS = [['dashboard', 'gauge-high', 'view_players'], ['players', 'users', 'view_players'], ['characters', 'id-card', 'view_characters'], ['logs', 'right-left', 'view_logs'],
  ['coords', 'location-crosshairs', 'coords'], ['actions', 'clipboard-list', 'view_actions'], ['staff', 'user-shield', 'manage_staff'], ['perms', 'key', 'manage_perms'], ['keys', 'keyboard', null]];
const can = (p) => !p || me?.rank === 'owner' || me?.perms?.[p];
function renderTabs() {
  $('tabs').innerHTML = TABS.filter(x => can(x[2])).map(([k, i]) => `<button data-k="${k}" class="${k === tab ? 'on' : ''}"><i class="fa-solid fa-${i}"></i>${t(k)}</button>`).join('');
  if (me) $('meBadge').innerHTML = `${esc(me.name)} · <b>${esc(rankLabel(me.rank))}</b>`;
}
const rankLabel = (r) => (me?.ranks || []).find(x => x.name === r)?.label || r || '—';
$('tabs').onclick = (e) => { const b = e.target.closest('button'); if (b) show(b.dataset.k); };
function show(k) { tab = k; renderTabs(); clearInterval(timer); const v = $('view'); v.innerHTML = '';
  (V[k] || V.dashboard)(v); }
function live(fn) { fn(); timer = setInterval(() => { if (!$('modal').classList.contains('on')) fn(); }, 3000); }

/* ---------------- views ---------------- */
const V = {};
V.dashboard = (v) => {
  v.innerHTML = `<div class="grid g4" id="dStats"></div><div class="card"><div class="h"><i class="fa-solid fa-chart-line"></i>${t('activity')}<span class="sp"></span>
    <div class="acts" id="rng"><button class="btn sm p" data-r="3600">1H</button><button class="btn sm" data-r="21600">6H</button><button class="btn sm" data-r="86400">24H</button></div></div><svg class="chart" id="chart"></svg></div>
    <div class="grid g2"><div class="card"><div class="h"><i class="fa-solid fa-user-shield"></i>${t('admins')}</div><div id="dStaff"></div></div>
    <div class="card"><div class="h"><i class="fa-solid fa-users"></i>${t('players')}</div><div id="dPl"></div></div></div>`;
  let range = 3600, last;
  $('rng').onclick = (e) => { const b = e.target.closest('button'); if (!b) return; range = +b.dataset.r; [...$('rng').children].forEach(x => x.classList.toggle('p', x === b)); if (last) chart(last.activity, range); };
  live(async () => {
    const d = await call('dashboard'); if (!d || d.denied) return; last = d;
    $('dStats').innerHTML = [['users', t('online'), `${d.online}<small style="font-size:16px;opacity:.6">/${d.max}</small>`, `${d.police} ${t('police')} · ${d.ems} ${t('ems')}`, ''],
      ['user-shield', t('staffOn'), d.staff.length, me.rank ? rankLabel(me.rank) : '', 'b'], ['calendar-day', t('today'), d.today, '24h', 'g'],
      ['power-off', t('uptime'), fDur(d.uptime), `${t('avgPing')} ${d.ping} ms`, 'g']].map(([i, l, b, s, c]) =>
      `<div class="card stat ${c}"><small><i class="fa-solid fa-${i}"></i>${l}</small><b>${b}</b><span>${s}</span><i class="fa-solid fa-${i} bg"></i></div>`).join('');
    $('dStaff').innerHTML = d.staff.map(s => `<div class="row"><div class="av">${initials(s.name)}</div><div class="nm"><b>${esc(s.name)}</b><span>ID ${s.id}</span></div><span class="pill a">${esc(rankLabel(s.rank))}</span></div>`).join('') || `<div class="empty">—</div>`;
    chart(d.activity, range);
    const pl = await call('players') || [];
    $('dPl').innerHTML = pl.slice(0, 6).map(p => `<div class="row"><div class="av">${p.id}</div><div class="nm"><b>${esc(p.char || p.name)}</b><span>${esc(p.name)} · ${esc(p.job || '')}</span></div><span class="pill">${fDur(now() - p.joined)}</span></div>`).join('') || `<div class="empty">—</div>`;
  });
};
function chart(act, range) {
  const s = $('chart'); if (!s) return; const W = s.clientWidth || 1000, H = 220, P = 30, tt = now();
  const pts = (act || []).filter(a => a.t >= tt - range); if (!pts.length || pts[pts.length - 1].t < tt - 30) pts.push({ t: tt, n: pts.length ? pts[pts.length - 1].n : 0 });
  const mx = Math.max(4, ...pts.map(p => p.n)); const X = (x) => P + (W - P * 2) * (1 - (tt - x) / range), Y = (n) => H - P - (H - P * 2) * n / mx;
  const line = pts.map((p, i) => `${i ? 'L' : 'M'}${X(p.t).toFixed(1)} ${Y(p.n).toFixed(1)}`).join(' ');
  let g = ''; for (let i = 0; i <= 4; i++) { const n = Math.round(mx * i / 4); g += `<line x1="${P}" x2="${W - P}" y1="${Y(n)}" y2="${Y(n)}" stroke="rgba(255,255,255,.06)"/><text x="6" y="${Y(n) + 4}" fill="rgba(255,255,255,.5)" font-size="11">${n}</text>`; }
  for (let i = 0; i <= 4; i++) { const x = P + (W - P * 2) * i / 4; g += `<text x="${x}" y="${H - 6}" fill="rgba(255,255,255,.45)" font-size="10" text-anchor="middle" font-weight="700">${i === 4 ? 'NOW' : '-' + Math.round(range / 60 * (1 - i / 4)) + 'M'}</text>`; }
  const lp = pts[pts.length - 1];
  s.setAttribute('viewBox', `0 0 ${W} ${H}`);
  s.innerHTML = `<defs><linearGradient id="cg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff5a1f" stop-opacity=".35"/><stop offset="1" stop-color="#ff5a1f" stop-opacity="0"/></linearGradient></defs>${g}
    <path d="${line} L${X(lp.t)} ${H - P} L${X(pts[0].t)} ${H - P}Z" fill="url(#cg)"/><path d="${line}" fill="none" stroke="#ff5a1f" stroke-width="2.5"/><circle cx="${X(lp.t)}" cy="${Y(lp.n)}" r="5" fill="#ff5a1f"/>`;
}

V.players = (v) => {
  v.innerHTML = `<div class="card"><div class="bar"><input class="grow" id="pq" placeholder="${t('search')}"></div><div class="tbl"><table><thead><tr><th>${t('sid')}</th><th>${t('character')}</th><th>${t('cid')}</th><th>${t('steam')}</th><th>${t('steamId')}</th><th>${t('job')}</th><th>${t('joined')}</th><th>${t('session')}</th><th></th></tr></thead><tbody id="pb"></tbody></table></div></div>`;
  let rows = [];
  const draw = () => { const q = $('pq').value.toLowerCase();
    const f = rows.filter(p => !q || [p.id, p.name, p.char, p.cid, p.steam, steam64(p.steam), p.license, p.job].some(x => String(x ?? '').toLowerCase().includes(q)));
    $('pb').innerHTML = f.map(p => `<tr class="click" data-id="${p.id}"><td><b>${p.id}</b></td><td><span class="dot on"></span><b>${esc(p.char || '—')}</b></td><td class="mono">${esc(p.cid || '—')}</td><td>${esc(p.name)} ${p.staff ? `<span class="pill a">${esc(rankLabel(p.staff))}</span>` : ''}</td>
      <td>${steamCell(p.steam)}</td><td>${esc(p.job || '—')}${p.grade != null ? ' · ' + esc(p.grade) : ''}</td><td>${fDate(p.joined)}</td><td>${fDur(now() - p.joined)}</td><td><span class="pill">${p.ping}ms</span></td></tr>`).join('') || `<tr><td colspan="9" class="empty">—</td></tr>`; };
  $('pq').oninput = draw;
  $('pb').onclick = (e) => { const r = e.target.closest('tr[data-id]'); if (r) profile({ id: +r.dataset.id }); };
  live(async () => { rows = await call('players') || []; draw(); });
};

V.characters = (v) => {
  v.innerHTML = `<div class="card"><div class="bar"><input class="grow" id="cq" placeholder="${t('search')}"><button class="btn p" id="cgo"><i class="fa-solid fa-magnifying-glass"></i></button></div><div class="tbl"><table><thead><tr><th>${t('status')}</th><th>${t('character')}</th><th>${t('cid')}</th><th>${t('steam')}</th><th>${t('job')}</th><th>${t('created')}</th><th>${t('lastLogin')}</th><th></th></tr></thead><tbody id="cb"></tbody></table></div></div>`;
  const load = async () => { const r = await call('characters', { q: $('cq').value.trim() }) || [];
    $('cb').innerHTML = r.map(c => `<tr class="click" data-l="${esc(c.license)}" data-cid="${esc(c.cid)}"><td>${c.online ? `<span class="pill ok"><span class="dot on"></span>${t('inUse')} · ${c.serverId}</span>` : `<span class="pill">${t('offline')}</span>`}</td>
      <td><b>${esc(c.name)}</b></td><td class="mono">${esc(c.cid)}</td><td>${esc(c.steamName)}</td><td>${esc(c.job || '—')}${c.grade != null ? ' · ' + esc(c.grade) : ''}</td><td>${fDate(c.created)}</td><td>${fDate(c.lastSeen)}</td>
      <td><button class="btn sm" data-h="${esc(c.cid)}"><i class="fa-solid fa-clock-rotate-left"></i>${t('history')}</button></td></tr>`).join('') || `<tr><td colspan="8" class="empty">—</td></tr>`; };
  $('cgo').onclick = load; $('cq').onkeydown = (e) => e.key === 'Enter' && load();
  $('cb').onclick = (e) => { const h = e.target.closest('[data-h]'); if (h) return charHistory(h.dataset.h); const r = e.target.closest('tr[data-l]'); if (r) profile({ license: r.dataset.l }); };
  load();
};
async function charHistory(cid) {
  const r = await call('charHistory', { cid }) || [];
  modal(`<div class="h" style="font-size:22px">${t('history')} · <span class="mono">${esc(cid)}</span></div>${sessTable(r, false)}<div><button class="btn" onclick="closeModal()">${t('done')}</button></div>`);
}

const sessTable = (r, full = true) => `<div class="tbl" style="max-height:44vh"><table><thead><tr>${full ? `<th>${t('steam')}</th><th>${t('character')}</th>` : `<th>${t('steam')}</th>`}<th>${t('sid')}</th><th>${t('joined')}</th><th>${t('left')}</th><th>${t('duration')}</th><th>${t('type')}</th>${full ? `<th>${t('reason')}</th>` : ''}${r.some(x => x.ip) ? `<th>${t('ip')}</th>` : ''}</tr></thead><tbody>
  ${r.map(s => `<tr${full && s.license ? ` class="click" data-l="${esc(s.license)}"` : ''}><td><b>${esc(s.steam_name)}</b>${full && s.steam ? `<br>${steamCell(s.steam)}` : ''}</td>${full ? `<td>${esc(s.char_name || '—')}<br><span class="mono">${esc(s.citizenid || '')}</span></td>` : ''}
  <td>${s.server_id ?? '—'}</td><td>${fDate(s.joined_at)}</td><td>${fDate(s.left_at)}</td><td>${fDur(s.duration ?? (s.left_at ? 0 : now() - s.joined_at))}</td><td>${quitPill(s.quit_type)}</td>${full ? `<td style="max-width:220px;font-size:11px;color:var(--mut)">${esc(s.quit_reason || '')}</td>` : ''}${s.ip !== undefined && r.some(x => x.ip) ? `<td class="mono">${esc(s.ip || '')}</td>` : ''}</tr>`).join('') || `<tr><td colspan="9" class="empty">—</td></tr>`}</tbody></table></div>`;

V.logs = (v) => {
  v.innerHTML = `<div class="card"><div class="bar"><input class="grow" id="lq" placeholder="${t('search')}">
    <select id="lt"><option value="">${t('all')}</option><option value="online">${t('onlineNow')}</option><option value="quit">${t('quit')}</option><option value="dropped">${t('dropped')}</option><option value="kicked">${t('kicked')}</option><option value="server">${t('server')}</option></select>
    <label>${t('from')} <input type="date" id="lf"></label><label>${t('to')} <input type="date" id="lto"></label><button class="btn p" id="lgo"><i class="fa-solid fa-magnifying-glass"></i></button></div><div id="lb"></div></div>`;
  const load = async () => { const d = (id, end) => { const x = $(id).value; return x ? (new Date(x + (end ? 'T23:59:59' : 'T00:00:00')).getTime() / 1000 | 0) : undefined; };
    const r = await call('logs', { q: $('lq').value.trim(), type: $('lt').value, from: d('lf'), to: d('lto', 1) }) || []; $('lb').innerHTML = sessTable(r); };
  $('lgo').onclick = load; $('lt').onchange = load; $('lq').onkeydown = (e) => e.key === 'Enter' && load();
  $('lb').onclick = (e) => { const r = e.target.closest('tr[data-l]'); if (r) profile({ license: r.dataset.l }); };
  live(load);
};

V.coords = (v) => {
  v.innerHTML = `<div class="grid g2"><div class="card"><div class="h"><i class="fa-solid fa-location-crosshairs"></i>${t('current')}<span class="sp"></span><span class="pill" id="czone"></span></div>
    <div class="coord" id="cc"></div><div class="bar" style="margin-top:10px"><button class="btn" data-f="v3"><i class="fa-solid fa-copy"></i>vector3</button><button class="btn" data-f="v4"><i class="fa-solid fa-copy"></i>vector4</button>
    <button class="btn" data-f="xyz"><i class="fa-solid fa-copy"></i>x, y, z</button><button class="btn" data-f="json"><i class="fa-solid fa-copy"></i>JSON</button><button class="btn" data-f="rot"><i class="fa-solid fa-copy"></i>rotation</button></div>
    ${can('coords_save') ? `<div class="bar"><input class="grow" id="clabel" placeholder="${t('label')}"><label class="btn"><input type="checkbox" id="cshared" checked style="height:auto"> ${t('shared')}</label><button class="btn p" id="csave"><i class="fa-solid fa-floppy-disk"></i>${t('save')}</button></div>` : ''}</div>
    <div class="card"><div class="h"><i class="fa-solid fa-paper-plane"></i>${t('manual')}</div><div class="bar"><input class="grow" id="cin" placeholder="vector3(…) / x, y, z"></div>
    <div class="bar">${can('teleport') ? `<button class="btn p" id="cgo"><i class="fa-solid fa-location-arrow"></i>${t('tp')}</button>` : ''}<button class="btn" id="cwp"><i class="fa-solid fa-map-pin"></i>${t('waypoint')}</button></div></div></div>
    <div class="card"><div class="h"><i class="fa-solid fa-bookmark"></i>${t('saved')}</div><div id="cl"></div></div>`;
  let cur = {};
  const fmt = { v3: c => `vector3(${c.x.toFixed(2)}, ${c.y.toFixed(2)}, ${c.z.toFixed(2)})`, v4: c => `vector4(${c.x.toFixed(2)}, ${c.y.toFixed(2)}, ${c.z.toFixed(2)}, ${c.h.toFixed(2)})`,
    xyz: c => `${c.x.toFixed(2)}, ${c.y.toFixed(2)}, ${c.z.toFixed(2)}`, json: c => JSON.stringify({ x: +c.x.toFixed(2), y: +c.y.toFixed(2), z: +c.z.toFixed(2), w: +c.h.toFixed(2) }), rot: c => `vector3(${c.rx.toFixed(2)}, ${c.ry.toFixed(2)}, ${c.rz.toFixed(2)})` };
  v.querySelectorAll('[data-f]').forEach(b => b.onclick = () => cur.x != null && copy(fmt[b.dataset.f](cur)));
  const parse = () => { const n = ($('cin').value.match(/-?\d+(\.\d+)?/g) || []).map(Number); return n.length >= 2 ? { x: n[0], y: n[1], z: n[2] ?? 0, h: n[3] } : null; };
  if ($('cgo')) $('cgo').onclick = async () => { const c = parse(); if (!c) return; toast(await call('teleport', c) ? t('done') : t('failed')); };
  $('cwp').onclick = () => { const c = parse(); if (c) { post('waypoint', c); toast(t('done')); } };
  const loadSaved = async () => { const r = await call('coordsList') || [];
    $('cl').innerHTML = `<table><thead><tr><th>${t('label')}</th><th>x, y, z, h</th><th>${t('admin')}</th><th>${t('time')}</th><th></th></tr></thead><tbody>${r.map(c => `<tr><td><b>${esc(c.label)}</b> ${c.shared ? '' : '<i class="fa-solid fa-lock" style="opacity:.5"></i>'}</td>
      <td class="mono">${(+c.x).toFixed(2)}, ${(+c.y).toFixed(2)}, ${(+c.z).toFixed(2)}, ${(+c.h).toFixed(1)}</td><td>${esc(c.owner_name)}</td><td>${fDate(c.at)}</td>
      <td class="acts">${can('teleport') ? `<button class="btn sm p" data-tp="${c.id}"><i class="fa-solid fa-location-arrow"></i>${t('tp')}</button>` : ''}<button class="btn sm" data-cp="${c.id}"><i class="fa-solid fa-copy"></i></button>${can('coords_save') ? `<button class="btn sm r" data-del="${c.id}"><i class="fa-solid fa-trash"></i></button>` : ''}</td></tr>`).join('') || `<tr><td colspan="5" class="empty">—</td></tr>`}</tbody></table>`;
    $('cl').onclick = async (e) => { const b = e.target.closest('button'); if (!b) return; const c = r.find(x => x.id == (b.dataset.tp || b.dataset.cp || b.dataset.del));
      if (b.dataset.tp) toast(await call('teleport', c) ? t('done') : t('failed'));
      if (b.dataset.cp) copy(`vector4(${(+c.x).toFixed(2)}, ${(+c.y).toFixed(2)}, ${(+c.z).toFixed(2)}, ${(+c.h).toFixed(2)})`);
      if (b.dataset.del) { await call('coordsDelete', { id: c.id }); loadSaved(); } }; };
  if ($('csave')) $('csave').onclick = async () => { const l = $('clabel').value.trim(); if (!l || cur.x == null) return;
    toast(await call('coordsSave', { ...cur, label: l, shared: $('cshared').checked }) ? t('done') : t('failed')); $('clabel').value = ''; loadSaved(); };
  loadSaved();
  const tick = async () => { const c = await post('myCoords'); if (!c || !$('cc')) return; cur = c;
    $('cc').innerHTML = [['X', c.x], ['Y', c.y], ['Z', c.z], ['HEADING', c.h]].map(([k, n]) => `<div><small>${k}</small><b>${n.toFixed(2)}</b></div>`).join('');
    $('czone').textContent = [c.zone, c.street].filter(Boolean).join(' · '); };
  tick(); timer = setInterval(tick, 500);
};

V.actions = (v) => {
  v.innerHTML = `<div class="card"><div class="bar"><input class="grow" id="aq" placeholder="${t('search')}"></div><div id="ab"></div></div>`;
  const load = async () => { const r = await call('actions', { q: $('aq').value.trim() }) || []; $('ab').innerHTML = actTable(r); };
  $('aq').onkeydown = (e) => e.key === 'Enter' && load(); live(load);
};
const actTable = (r) => `<div class="tbl" style="max-height:44vh"><table><thead><tr><th>${t('time')}</th><th>${t('admin')}</th><th>${t('action')}</th><th>${t('target')}</th><th>${t('details')}</th></tr></thead><tbody>
  ${r.map(a => `<tr><td>${fDate(a.at)}</td><td><b>${esc(a.admin_name)}</b></td><td><span class="pill a">${esc(a.action)}</span></td><td>${esc(a.target_name || '—')} <span class="mono">${esc(a.target_cid || '')}</span></td><td class="mono" style="max-width:300px">${esc(a.details || '')}</td></tr>`).join('') || `<tr><td colspan="5" class="empty">—</td></tr>`}</tbody></table></div>`;

V.staff = (v) => {
  const rk = (sel) => `<option value="">${t('none')}</option>` + me.ranks.map(r => `<option value="${r.name}" ${r.name === sel ? 'selected' : ''}>${esc(r.label)}</option>`).join('');
  v.innerHTML = `<div class="card"><div class="h"><i class="fa-solid fa-user-plus"></i>${t('addStaff')}</div><div class="bar"><select id="sp"></select><input class="grow" id="si" placeholder="${t('identifier')} (license:… / steam:… / discord:…)"><select id="sr">${rk('moderator')}</select><button class="btn p" id="sadd"><i class="fa-solid fa-plus"></i>${t('save')}</button></div></div>
    <div class="card"><div class="h"><i class="fa-solid fa-user-shield"></i>${t('staff')}</div><div id="sl"></div></div>`;
  call('players').then(p => $('sp').innerHTML = `<option value="">— ${t('players')} —</option>` + (p || []).map(x => `<option value="${x.id}">[${x.id}] ${esc(x.name)}</option>`).join(''));
  const load = async () => { const r = await call('staffList') || [];
    $('sl').innerHTML = `<table><thead><tr><th>${t('name')}</th><th>${t('identifier')}</th><th>${t('rank')}</th><th>${t('admin')}</th><th>${t('time')}</th></tr></thead><tbody>${r.map(s => `<tr><td><b>${esc(s.name)}</b></td><td class="mono">${esc(s.identifier)}</td>
      <td>${s.locked ? `<span class="pill a">${esc(rankLabel(s.rank))}</span>` : `<select data-i="${esc(s.identifier)}" data-n="${esc(s.name)}">${rk(s.rank)}</select>`}</td><td>${esc(s.added_by || '')}</td><td>${fDate(s.at)}</td></tr>`).join('') || `<tr><td colspan="5" class="empty">—</td></tr>`}</tbody></table>`;
    $('sl').querySelectorAll('select').forEach(s => s.onchange = async () => { toast(await call('staffSet', { identifier: s.dataset.i, name: s.dataset.n, rank: s.value }) ? t('done') : t('failed')); load(); }); };
  $('sadd').onclick = async () => { const ok = await call('staffSet', { id: $('sp').value || undefined, identifier: $('si').value.trim(), rank: $('sr').value }); toast(ok ? t('done') : t('failed'), !ok); load(); };
  load();
};

V.perms = async (v) => {
  const P = await call('permsGet') || {}; const ranks = me.ranks;
  v.innerHTML = `<div class="card"><div class="tbl"><table><thead><tr><th>${t('perm')}</th>${ranks.map(r => `<th style="text-align:center">${esc(r.label)}</th>`).join('')}</tr></thead><tbody>
    ${Object.keys(me.permNames).sort().map(p => `<tr><td class="mono">${p}</td>${ranks.map(r => `<td style="text-align:center"><span class="chk ${r.name === 'owner' || P[r.name]?.[p] ? 'on' : ''} ${r.name === 'owner' ? 'lock' : ''}" data-r="${r.name}" data-p="${p}"></span></td>`).join('')}</tr>`).join('')}</tbody></table></div></div>`;
  v.onclick = async (e) => { const c = e.target.closest('.chk'); if (!c || c.classList.contains('lock')) return; const on = !c.classList.contains('on');
    if (await call('permsSet', { rank: c.dataset.r, perm: c.dataset.p, allowed: on })) { c.classList.toggle('on', on); toast(t('done')); } else toast(t('failed'), 1); };
};

V.keys = (v) => {
  const K = { ...Object.fromEntries(me.keybinds.map(k => [k.action, k.default])), ...(me.keys || {}) };
  const OK = ['F1','F2','F3','F5','F6','F7','F9','F10','F11','HOME','INSERT','DELETE','PAGEUP','PAGEDOWN','NUM4','NUM5','NUM6','NUM7','NUM8','NUM9','Z','X','G','H','K','L','U','Y','N','B'];
  const draw = () => { v.innerHTML = `<div class="card"><div class="h"><i class="fa-solid fa-keyboard"></i>${t('keys')}<span class="sp"></span><button class="btn" id="kr"><i class="fa-solid fa-rotate-left"></i>${t('reset')}</button></div>
    <p style="font-size:12px;color:var(--mut);margin-bottom:8px">${t('keysHelp')}</p>${me.keybinds.map(k => `<div class="row"><div class="nm"><b>${esc(k.label)}</b><span class="mono">${k.action}${k.action === 'open' ? ' · GTA Settings › Key Bindings › FiveM' : ''}</span></div>
    <kbd data-a="${k.action}" class="${K[k.action] ? '' : 'empty'}">${K[k.action] || '—'}</kbd></div>`).join('')}</div>`;
    $('kr').onclick = () => { me.keybinds.forEach(k => K[k.action] = k.default); store(); draw(); };
    v.querySelectorAll('kbd').forEach(b => b.onclick = () => { b.textContent = t('press'); b.className = 'wait';
      const h = (e) => { e.preventDefault(); document.removeEventListener('keydown', h, true);
        let key = e.key === 'Escape' ? '' : (e.code.startsWith('Numpad') ? 'NUM' + e.code.slice(6) : e.code.startsWith('Key') ? e.code.slice(3) : e.key).toUpperCase();
        if (key && !OK.includes(key)) { toast(key + ' ✕', 1); return draw(); }
        const used = key && Object.entries(K).find(([a, v2]) => v2 === key && a !== b.dataset.a);
        if (used) { toast(`${t('conflict')}: ${me.keybinds.find(x => x.action === used[0])?.label}`, 1); return draw(); }
        K[b.dataset.a] = key; store(); draw(); };
      document.addEventListener('keydown', h, true); }); };
  const store = () => { me.keys = { ...K }; post('saveKeys', { keys: K }); toast(t('done')); };
  draw();
};

/* ---------------- player profile ---------------- */
async function profile(q) {
  const d = await call('profile', q); if (!d || d.denied) return toast(t('denied'), 1);
  const L = d.live, cur = d.chars.find(c => c.cid === d.lastCid);
  const act = (k, i, cls = '') => can(k === 'setJob' ? 'set_job' : k === 'money' ? 'give_money' : k) ? `<button class="btn sm ${cls}" data-a="${k}"><i class="fa-solid fa-${i}"></i>${t(k)}</button>` : '';
  modal(`<div class="m-head"><div class="av">${L ? L.id : initials(d.steamName)}</div><div class="nm"><b>${esc(cur?.name || d.steamName)}</b><span>${esc(d.steamName)} · ${L ? `<span class="pill ok"><span class="dot on"></span>${t('onlineNow')}</span>` : `<span class="pill">${t('offline')}</span>`}</span></div>
    <span class="sp" style="flex:1"></span><button class="ic" onclick="closeModal()"><i class="fa-solid fa-xmark"></i></button></div>
    ${L ? `<div class="acts">${act('goto', 'location-arrow')}${act('bring', 'hand')}${act('freeze', 'snowflake')}${act('revive', 'heart-pulse')}${act('setJob', 'briefcase')}${act('money', 'money-bill')}${act('kick', 'right-from-bracket', 'r')}</div>` : ''}
    <div class="grid g3"><div class="card"><div class="h"><i class="fa-solid fa-user"></i>${t('account')}</div><div class="kv">
      <span>${t('steam')}</span><b>${esc(d.steamName)}</b><span>${t('steamId')}</span><b>${steamCell(d.steam)}</b>${d.steam ? `<span>steam64</span><b class="mono">${steam64(d.steam)}</b>` : ''}
      <span>License</span><b class="mono">${esc(d.license)}</b>${L ? `<span>${t('sid')}</span><b>${L.id}</b>` : ''}</div></div>
    <div class="card"><div class="h"><i class="fa-solid fa-clock"></i>${t('session')}</div><div class="kv"><span>${t('totalPlay')}</span><b>${fDur(d.total)}</b><span>${t('sessions')}</span><b>${d.sessionCount}</b>
      <span>${t('firstSeen')}</span><b>${fDate(d.first)}</b><span>${t('lastSeen')}</span><b>${L ? t('onlineNow') : fDate(d.sessions[0]?.left_at || d.last)}</b>${L ? `<span>${t('joined')}</span><b>${fDate(L.joined)} (${fDur(now() - L.joined)})</b>` : ''}</div></div>
    <div class="card"><div class="h"><i class="fa-solid fa-id-badge"></i>${t('cur')}</div>${cur ? `<div class="kv"><span>${t('name')}</span><b>${esc(cur.name)}</b><span>${t('cid')}</span><b class="mono">${esc(cur.cid)}</b>
      <span>${t('job')}</span><b>${esc(cur.job || '—')} ${cur.grade != null ? '· ' + esc(cur.grade) : ''}</b><span>${t('lastPos')}</span><b class="mono">${L?.coords ? xyz(L.coords) : cur.lastPos ? xyz(cur.lastPos) : '—'}</b></div>` : `<div class="empty">—</div>`}</div></div>
    <div class="card"><div class="h"><i class="fa-solid fa-id-card"></i>${t('chars')} (${d.chars.length})</div><table><thead><tr><th></th><th>${t('character')}</th><th>${t('cid')}</th><th>${t('job')}</th><th>${t('created')}</th><th>${t('lastLogin')}</th><th>${t('lastPos')}</th><th></th></tr></thead><tbody>
      ${d.chars.map(c => `<tr><td>${c.cid === d.lastCid ? `<span class="pill ${L ? 'ok' : 'a'}">${L ? t('inUse') : t('cur')}</span>` : ''}</td><td><b>${esc(c.name)}</b></td><td class="mono">${esc(c.cid)}</td><td>${esc(c.job || '—')}${c.grade != null ? ' · ' + esc(c.grade) : ''}</td>
      <td>${fDate(c.created)}</td><td>${fDate(c.lastSeen)}</td><td class="mono">${c.lastPos ? xyz(c.lastPos) : '—'}</td><td class="acts">${c.lastPos ? `<button class="btn sm" data-cp='${esc(JSON.stringify(c.lastPos))}'><i class="fa-solid fa-copy"></i></button>${can('teleport') ? `<button class="btn sm" data-tp='${esc(JSON.stringify(c.lastPos))}'><i class="fa-solid fa-location-arrow"></i></button>` : ''}` : ''}
      <button class="btn sm" data-h="${esc(c.cid)}"><i class="fa-solid fa-clock-rotate-left"></i></button></td></tr>`).join('') || `<tr><td colspan="8" class="empty">—</td></tr>`}</tbody></table></div>
    ${d.switches.length ? `<div class="card"><div class="h"><i class="fa-solid fa-shuffle"></i>${t('switches')}</div><div class="acts">${d.switches.map(s => `<span class="pill">${fDate(s.at)} → ${esc(s.char_name)} <span class="mono">${esc(s.citizenid)}</span></span>`).join('')}</div></div>` : ''}
    ${can('view_logs') ? `<div class="card"><div class="h"><i class="fa-solid fa-right-left"></i>${t('logs')}</div>${sessTable(d.sessions.map(s => ({ ...s, license: undefined })))}</div>` : ''}
    ${can('view_actions') ? `<div class="card"><div class="h"><i class="fa-solid fa-gavel"></i>${t('adminActs')}</div>${actTable(d.actions)}</div>` : ''}`);
  $('mBox').onclick = async (e) => { const b = e.target.closest('button'); if (!b) return;
    if (b.dataset.h) return charHistory(b.dataset.h);
    if (b.dataset.cp) return copy(xyz(JSON.parse(b.dataset.cp)));
    if (b.dataset.tp) { const p = JSON.parse(b.dataset.tp); return toast(await call('teleport', p) ? t('done') : t('failed')); }
    const a = b.dataset.a; if (!a || !L) return; let args = { id: L.id };
    if (a === 'kick') { const r = prompt(t('reason')); if (r === null) return; args.reason = r; }
    if (a === 'setJob') { const j = prompt(t('job') + ' (name)'); if (!j) return; args.job = j; args.grade = +(prompt(t('grade'), '0') || 0); }
    if (a === 'money') { const acc = prompt('cash / bank', 'cash'); const n = +(prompt(t('amount') + ' (+/-)') || 0); if (!n) return; args.account = acc; args.amount = n; }
    const r = await call(a, args); toast(r === false || r == null || r.denied ? t('failed') : t('done'), r === false || r == null);
    if (a === 'kick' && r) { closeModal(); } };
}
const xyz = (p) => `${(+p.x).toFixed(2)}, ${(+p.y).toFixed(2)}, ${(+p.z).toFixed(2)}`;
function modal(html) { $('mBox').innerHTML = html; $('modal').classList.add('on'); }
function closeModal() { $('modal').classList.remove('on'); }
$('modal').onclick = (e) => { if (e.target.id === 'modal') closeModal(); };

/* ---------------- open / close ---------------- */
function close() { $('app').classList.remove('on'); closeModal(); clearInterval(timer); post('close'); }
$('close').onclick = close;
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && $('app').classList.contains('on') && !document.querySelector('kbd.wait')) { if ($('modal').classList.contains('on')) closeModal(); else close(); } });
window.addEventListener('message', (e) => { const d = e.data || {};
  if (d.action === 'open') { if (!d.open) { $('app').classList.remove('on'); clearInterval(timer); return; } me = d.me; if (me.locale && !localStorage.getItem?.('rox_admin_lang')) lang = me.locale; $('app').classList.add('on'); setLang(lang); }
  if (d.action === 'me') { me = d.me; renderTabs(); }
  if (d.action === 'clip') copy(d.text); });

/* ---------------- browser preview (no game data – shape only) ---------------- */
function Mock(n, d) {
  if (n !== 'call') return n === 'myCoords' ? { x: 425.13, y: -979.55, z: 30.71, h: 91.4, rx: 0, ry: 0, rz: 91.4, zone: 'Mission Row', street: 'Atlee St' } : 1;
  const tt = now(), A = (o) => o;
  const pl = [A({ id: 1, name: 'PreviewUser', char: 'Preview Character', cid: 'ABC12345', steam: 'steam:110000100000001', license: 'license:preview', job: 'Police', grade: 'Captain', joined: tt - 4100, ping: 32, staff: 'owner' })];
  switch (d.name) {
    case 'dashboard': return { online: 1, max: 48, police: 0, ems: 0, staff: [{ id: 1, name: 'PreviewUser', rank: 'owner' }], uptime: 4100, ping: 32, today: 1, activity: [{ t: tt - 3000, n: 0 }, { t: tt - 300, n: 1 }] };
    case 'players': return pl;
    case 'profile': return { live: pl[0], license: 'license:preview', steam: pl[0].steam, steamName: 'PreviewUser', first: tt - 86400, last: tt - 4100, total: 9000, sessionCount: 2, lastCid: 'ABC12345',
      chars: [{ cid: 'ABC12345', name: 'Preview Character', job: 'Police', grade: 'Captain', created: tt - 86400, lastSeen: tt, lastPos: { x: 425, y: -979, z: 30 } }], switches: [], sessions: [{ steam_name: 'PreviewUser', server_id: 1, joined_at: tt - 4100, left_at: null }], actions: [] };
    case 'characters': return [{ cid: 'ABC12345', name: 'Preview Character', steamName: 'PreviewUser', license: 'license:preview', job: 'Police', grade: 'Captain', online: true, serverId: 1, created: tt - 86400, lastSeen: tt }];
    case 'logs': return [{ license: 'license:preview', steam: pl[0].steam, steam_name: 'PreviewUser', server_id: 1, citizenid: 'ABC12345', char_name: 'Preview Character', joined_at: tt - 4100 },
      { license: 'license:preview', steam: pl[0].steam, steam_name: 'PreviewUser', server_id: 3, citizenid: 'ABC12345', char_name: 'Preview Character', joined_at: tt - 90000, left_at: tt - 85000, duration: 5000, quit_type: 'dropped', quit_reason: 'Server->client connection timed out.' }];
    case 'permsGet': return { admin: { view_players: true }, supervisor: {}, moderator: {} };
    default: return [];
  }
}
if (PREVIEW) { document.body.classList.add('preview'); const q = new URLSearchParams(location.search);
  setTimeout(() => { window.postMessage({ action: 'open', open: true, me: { name: 'PreviewUser', rank: 'owner', perms: {}, ranks: [{ name: 'owner', label: 'Owner' }, { name: 'admin', label: 'Admin' }, { name: 'supervisor', label: 'Supervisor' }, { name: 'moderator', label: 'Moderator' }],
    permNames: { view_players: 1, kick: 1, teleport: 1 }, keybinds: [{ action: 'open', label: 'Open panel', default: 'F10' }, { action: 'noclip', label: 'Noclip', default: '' }], locale: q.get('lang') || 'en' } }, '*');
    setTimeout(() => { if (q.get('tab')) show(q.get('tab')); if (q.get('profile')) profile({ id: 1 }); }, 200); }, 100); }
