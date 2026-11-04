const $ = i => document.getElementById(i);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const send = (n, d = {}) => RES ? fetch(`https://${RES}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d) }).catch(() => {}) : console.log('NUI', n, d);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ICON = {
  Beds: '<path d="M3 18V8M21 18v-5a3 3 0 0 0-3-3H10v5M3 15h18M3 18h18"/><circle cx="6.5" cy="11.5" r="1.8"/>',
  Seating: '<path d="M5 11V8a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v3M3 13a2 2 0 0 1 4 0v2h10v-2a2 2 0 0 1 4 0v4H3zM6 17v2M18 17v2"/>',
  Tables: '<path d="M3 9h18M5 9v10M19 9v10M8 9l1-4h6l1 4"/>',
  Kitchen: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M5 10h14M9 6v1M9 13v3"/>',
  Bathroom: '<path d="M4 12h16v2a6 6 0 0 1-6 6h-4a6 6 0 0 1-6-6zM6 12V5a2 2 0 0 1 3.5-1.3M7 20l-1 2M17 20l1 2"/>',
  Tech: '<rect x="2" y="4" width="20" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>',
  Decor: '<path d="M12 22V12M12 12c0-4 3-7 7-7 0 4-3 7-7 7zM12 15c0-3-2.5-5.5-6-5.5 0 3 2.5 5.5 6 5.5z"/>',
  Storage: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M4 9h16M4 15h16M11 6h2M11 12h2M11 18h2"/>',
};
const ic = c => `<svg viewBox="0 0 24 24">${ICON[c] || ICON.Decor}</svg>`;
let D = { catalog: [], furniture: [], colors: [], neon: [], exterior: {}, currency: '$', max: 40, liveries: 0, canEdit: true, deployed: true, lights: false };
let cat = 'All', K = 1;

function toast(m, bad) { const t = $('toast'); t.textContent = m; t.classList.toggle('bad', !!bad); t.classList.add('on'); clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('on'), 2600); }
function page(t) { document.querySelectorAll('.pg').forEach(p => p.classList.toggle('on', p.id === t)); document.querySelectorAll('#nav button').forEach(b => b.classList.toggle('on', b.dataset.t === t)); }
document.querySelectorAll('#nav button').forEach(b => b.onclick = () => page(b.dataset.t));
document.querySelectorAll('[data-go]').forEach(b => b.onclick = () => page(b.dataset.go));

function home() {
  $('hstate').textContent = D.deployed ? 'Set up' : 'Packed';
  $('hdot').classList.toggle('off', !D.deployed);
  $('hsub').textContent = D.deployed ? 'Your caravan is set up and level. Make yourself at home.' : 'Park the caravan and press Q to set it up.';
  $('hslide').textContent = D.deployed ? 'Extended' : 'Retracted';
  $('hfurn').textContent = `${D.furniture.length} / ${D.max}`;
  $('pcount').textContent = D.furniture.length;
  $('plate').textContent = D.plate || '';
  $('lights').classList.toggle('lit', D.lights); $('lstate').textContent = D.lights ? 'ON' : 'OFF';
  document.body.classList.toggle('ro', !D.canEdit);
}
function cats() {
  const all = ['All', ...new Set(D.catalog.map(f => f.cat))];
  $('cats').innerHTML = all.map(c => `<button class="${c === cat ? 'on' : ''}" data-c="${esc(c)}">${esc(c)}</button>`).join('');
  $('cats').querySelectorAll('button').forEach(b => b.onclick = () => { cat = b.dataset.c; cats(); grid(); });
}
function grid() {
  const list = D.catalog.filter(f => cat === 'All' || f.cat === cat);
  $('fgrid').innerHTML = list.length ? list.map((f, i) => `<div class="it" style="--i:${i}"><div class="ic">${ic(f.cat)}</div><small>${esc(f.cat)}</small><h4>${esc(f.label)}</h4>
    <div class="row"><b>${f.price ? D.currency + Number(f.price).toLocaleString('en-US') : 'Free'}</b><button data-m="${esc(f.model)}">PLACE</button></div></div>`).join('')
    : '<div class="none" style="grid-column:1/-1">No furniture available.</div>';
  $('fgrid').querySelectorAll('[data-m]').forEach(b => b.onclick = () => {
    if (D.furniture.length >= D.max) return toast(`Maximum ${D.max} items`, true);
    send('place', { model: b.dataset.m }); if (!RES) toast('Preview: placement happens in game');
  });
}
function placed() {
  const name = m => (D.catalog.find(f => f.model === m) || { label: m, cat: 'Decor' });
  $('plist').innerHTML = D.furniture.length ? D.furniture.map((f, i) => { const c = name(f.model); return `<div class="li" style="--i:${i}"><div class="ic">${ic(c.cat)}</div>
    <div><b>${esc(c.label)}</b><small>${esc(c.cat)} · #${f.id}</small></div><button data-id="${f.id}">REMOVE</button></div>`; }).join('')
    : '<div class="none">Nothing placed yet.<br>Open <b>Furniture</b> to start decorating.</div>';
  $('plist').querySelectorAll('[data-id]').forEach(b => b.onclick = () => {
    send('remove', { id: +b.dataset.id });
    if (!RES) { D.furniture = D.furniture.filter(f => f.id !== +b.dataset.id); placed(); home(); }
  });
}
function exterior() {
  const e = D.exterior;
  document.querySelectorAll('.sw[data-k]').forEach(el => {
    const k = el.dataset.k;
    el.innerHTML = D.colors.map(c => `<button title="${esc(c.label)}" style="background:${esc(c.hex)}" class="${e[k] === c.index ? 'on' : ''}" data-v="${c.index}"></button>`).join('');
    el.querySelectorAll('button').forEach(b => b.onclick = () => { e[k] = +b.dataset.v; exterior(); push(); });
  });
  const n = e.neon || { on: false, r: 228, g: 80, b: 28 };
  $('neonOn').checked = !!n.on;
  $('neon').innerHTML = D.neon.map((c, i) => `<button title="${esc(c.label)}" style="background:rgb(${c.rgb.join(',')})" class="${n.r === c.rgb[0] && n.g === c.rgb[1] && n.b === c.rgb[2] ? 'on' : ''}" data-i="${i}"></button>`).join('');
  $('neon').querySelectorAll('button').forEach(b => b.onclick = () => { const c = D.neon[+b.dataset.i].rgb; e.neon = { on: true, r: c[0], g: c[1], b: c[2] }; exterior(); push(); });
  $('livWrap').style.display = D.liveries > 0 ? '' : 'none';
  $('liv').innerHTML = Array.from({ length: D.liveries }, (_, i) => `<button class="${e.livery === i ? 'on' : ''}" data-l="${i}">${i + 1}</button>`).join('');
  $('liv').querySelectorAll('button').forEach(b => b.onclick = () => { e.livery = +b.dataset.l; exterior(); push(); });
}
$('neonOn').onchange = ev => { D.exterior.neon = Object.assign({ r: 228, g: 80, b: 28 }, D.exterior.neon || {}, { on: ev.target.checked }); exterior(); push(); };
let pushT; function push() { clearTimeout(pushT); pushT = setTimeout(() => { send('exterior', D.exterior); toast('Saved'); }, 150); }
$('lights').onclick = () => { D.lights = !D.lights; home(); send('lights', { on: D.lights }); };
$('exit').onclick = () => send('exit');

function render() { home(); cats(); grid(); placed(); exterior(); }
function open(d) { Object.assign(D, d); D.exterior = Object.assign({}, d.exterior || {}); cat = 'All'; render(); page('home'); document.body.classList.add('open'); $('tab').classList.remove('out'); }
function close() { if (!document.body.classList.contains('open')) return; $('tab').classList.add('out'); setTimeout(() => document.body.classList.remove('open'), 230); }

addEventListener('message', ev => {
  const d = ev.data || {};
  if (d.action === 'open') open(d);
  if (d.action === 'hide') close();
  if (d.action === 'data') { D.furniture = d.furniture || []; if (d.exterior && Object.keys(d.exterior).length) D.exterior = d.exterior; render(); }
});
addEventListener('keydown', e => { if (e.key === 'Escape') { send('close'); if (!RES) close(); } });
function fit() { K = Math.min(innerWidth / 1180, innerHeight / 760) * 0.92; $('stage').style.transform = `translate(${(innerWidth - 1180 * K) / 2}px,${(innerHeight - 760 * K) / 2}px) scale(${K})`; }
addEventListener('resize', fit); fit();

// ---------- browser preview
if (!RES) {
  document.body.classList.add('web');
  const cat2 = [['Beds', 'Double bed', 1500], ['Beds', 'Single bed', 900], ['Seating', 'Sofa', 1200], ['Seating', 'Large sofa', 1800], ['Seating', 'Chair', 150], ['Tables', 'Dining table', 400], ['Kitchen', 'Fridge', 900], ['Kitchen', 'Cooker', 700], ['Bathroom', 'Toilet', 350], ['Tech', 'Flat TV', 1100], ['Decor', 'Plant', 120], ['Storage', 'Wardrobe', 650]];
  open({
    plate: 'VC2 4821', deployed: true, canEdit: true, currency: '$', max: 40, liveries: 3, lights: true,
    catalog: cat2.map(([c, l, p], i) => ({ cat: c, label: l, price: p, model: 'm' + i })),
    furniture: [{ id: 1, model: 'm0' }, { id: 2, model: 'm2' }, { id: 3, model: 'm6' }, { id: 4, model: 'm9' }],
    colors: [['Frost White', 111, '#f2f3f5'], ['Silver', 4, '#b7bbc1'], ['Graphite', 1, '#3b3d42'], ['Black', 0, '#121316'], ['VC2 Orange', 38, '#e4501c'], ['Red', 27, '#b3141b'], ['Sand', 99, '#c8b48a'], ['Olive', 151, '#5c6b3a'], ['Sky Blue', 70, '#4f8fd6'], ['Navy', 62, '#1f2f5c'], ['Forest Green', 53, '#1f6b3a'], ['Yellow', 88, '#f2c21b']].map(([label, index, hex]) => ({ label, index, hex })),
    neon: [['Orange', [228, 80, 28]], ['White', [255, 255, 255]], ['Blue', [40, 120, 255]], ['Green', [60, 220, 90]], ['Purple', [160, 60, 255]], ['Red', [255, 30, 40]]].map(([label, rgb]) => ({ label, rgb })),
    exterior: { primary: 111, secondary: 38, pearl: 111, wheel: 4, neon: { on: true, r: 228, g: 80, b: 28 }, livery: 0 },
  });
  const t = new URLSearchParams(location.search).get('tab'); if (t) page(t);
}
