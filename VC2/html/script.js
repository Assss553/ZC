const $ = i => document.getElementById(i);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const PAY = {
  bank: { label: 'Bank', icon: '<path d="M3 21h18M5 21V10M19 21V10M9 21v-7M15 21v-7M2 10l10-6 10 6"/>' },
  cash: { label: 'Cash', icon: '<rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 12h.01M18 12h.01"/>' }
};
const STATS = [['speed', 'Top speed'], ['accel', 'Acceleration'], ['brake', 'Braking'], ['handling', 'Handling']];

let D = { vehicles: [], categories: [], colors: [], money: { cash: 0, bank: 0 }, currency: '$', payments: ['bank', 'cash'], testDrive: true, kiosk: '', imageUrl: '' };
let cat = 'all', query = '', cur = null, col = 1, pay = 'bank', K = 1, confirmT = null, buying = false;

/* ---------------- utils ---------------- */
function send(n, d = {}) {
  if (!RES) { console.log('NUI', n, d); return Promise.resolve({}); }
  return fetch(`https://${RES}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d) }).then(r => r.json()).catch(() => ({}));
}
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = n => D.currency + Number(n || 0).toLocaleString('en-US');
const catOf = id => D.categories.find(c => c.id === id) || { label: id };
function bump(el) { el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump'); }
function toast(msg) { const t = $('toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('on'), 3200); }

/* ---------------- car drawings ---------------- */
const SHAPES = {
  sedan: { body: 'M14 70 L16 56 Q18 48 32 46 L72 43 L98 25 Q104 21 114 21 L160 21 Q170 21 178 28 L198 43 L222 47 Q232 49 233 58 L234 70 Z', win: ['M82 43 L102 28 Q106 25 112 25 L132 25 L132 43 Z', 'M138 25 L158 25 Q166 25 172 31 L184 43 L138 43 Z'], wheels: [[62, 72, 14], [190, 72, 14]] },
  sport: { body: 'M8 72 L10 62 Q12 54 28 52 L80 47 L112 31 Q118 28 128 28 L156 29 Q166 30 176 37 L198 49 L226 55 Q234 57 234 65 L234 72 Z', win: ['M94 47 L116 33 Q120 31 126 31 L150 32 L150 47 Z', 'M156 32 Q166 33 174 39 L186 47 L156 47 Z'], wheels: [[58, 73, 14], [196, 73, 14]] },
  super: { body: 'M6 70 L8 60 Q10 54 26 52 L92 44 L124 30 Q130 28 140 29 L170 33 Q180 35 190 42 L214 52 L232 58 Q236 60 235 66 L234 70 Z', win: ['M104 44 L128 32 Q132 31 138 31 L164 34 L176 44 Z'], wheels: [[56, 71, 14], [198, 71, 14]] },
  suv: { body: 'M12 74 L12 50 Q12 42 22 41 L60 40 L82 16 Q86 12 94 12 L176 12 Q184 12 190 18 L212 40 L226 42 Q234 44 234 54 L234 74 Z', win: ['M70 40 L88 19 Q90 17 94 17 L128 17 L128 40 Z', 'M134 17 L174 17 Q180 17 184 22 L200 40 L134 40 Z'], wheels: [[60, 74, 17], [192, 74, 17]] }
};
function carSVG(shape, color) {
  if (shape === 'moto') return `<svg viewBox="0 0 240 100"><ellipse cx="120" cy="94" rx="100" ry="5" fill="#000" opacity=".45"/>
    <g fill="none" stroke="#2c2c31" stroke-width="5" stroke-linecap="round"><path d="M64 72 L100 50 L150 52 L180 72"/><path d="M150 52 L166 30 L176 28"/></g>
    <path d="M92 46 Q112 28 146 34 L156 48 L100 54 Z" fill="${color}"/><path d="M60 50 Q80 42 98 46 L96 54 L64 56 Z" fill="${color}" opacity=".85"/>
    <path d="M150 34 L170 26 L176 40 Z" fill="${color}"/><path d="M78 46 L104 44" stroke="#111" stroke-width="5" stroke-linecap="round"/>
    ${[[64, 72], [180, 72]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="20" fill="#0d0d0f"/><circle cx="${x}" cy="${y}" r="11" fill="none" stroke="#6b6d74" stroke-width="3"/><circle cx="${x}" cy="${y}" r="3" fill="#9a9ca3"/>`).join('')}</svg>`;
  const s = SHAPES[shape] || SHAPES.sedan;
  return `<svg viewBox="0 0 240 100"><ellipse cx="122" cy="${s.wheels[0][1] + 14}" rx="112" ry="6" fill="#000" opacity=".5"/>
    <path d="${s.body}" fill="${color}" stroke="#ffffff30" stroke-width="1.2"/>
    <path d="${s.body}" fill="url(#shine)" opacity=".55"/>
    ${s.win.map(w => `<path d="${w}" fill="#101318" opacity=".92"/>`).join('')}
    <path d="M20 60 H228" stroke="#000" stroke-opacity=".25" stroke-width="2"/>
    <rect x="224" y="52" width="9" height="5" rx="2" fill="#ffd9a8"/><rect x="12" y="56" width="7" height="5" rx="2" fill="#d22"/>
    ${s.wheels.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r + 3}" fill="#0d0d0f"/><circle cx="${x}" cy="${y}" r="${r - 3}" fill="#45474d"/><circle cx="${x}" cy="${y}" r="${r - 7}" fill="none" stroke="#8a8c93" stroke-width="2" stroke-dasharray="3 3"/><circle cx="${x}" cy="${y}" r="3" fill="#b5b7bd"/>`).join('')}
    <defs><linearGradient id="shine" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".45" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient></defs></svg>`;
}
const CLASS_SHAPE = { 2: 'suv', 9: 'suv', 12: 'suv', 7: 'super', 6: 'sport', 5: 'sport', 4: 'sport', 3: 'sport', 8: 'moto' };
const shapeOf = v => v.shape || CLASS_SHAPE[v.class] || 'sedan';

/* real pictures: own image -> images/<model>.png -> Config.ImageUrl -> drawn silhouette */
const imgOk = {}, imgNone = {};
function sources(v) {
  if (imgOk[v.model]) return [imgOk[v.model]];
  return [v.image, `images/${v.model}.png`, D.imageUrl ? D.imageUrl.replace('%s', v.model) : null].filter(Boolean);
}
function imgOf(v, color) {
  if (imgNone[v.model]) return carSVG(shapeOf(v), color);
  const c = sources(v);
  return `<img src="${esc(c[0])}" data-n="1" data-m="${esc(v.model)}" data-col="${esc(color)}" onload="imgLoad(this)" onerror="imgFail(this)" alt="">`;
}
window.imgLoad = el => { imgOk[el.dataset.m] = el.getAttribute('src'); };
window.imgFail = el => {
  const v = D.vehicles.find(x => x.model === el.dataset.m); if (!v) return;
  const c = sources(v), n = +el.dataset.n;
  if (n < c.length) { el.dataset.n = n + 1; el.src = c[n]; }
  else { imgNone[v.model] = true; el.outerHTML = carSVG(shapeOf(v), el.dataset.col); }
};

/* ---------------- header ---------------- */
function money(m) {
  if (m) D.money = m;
  const c = fmt(D.money.cash), b = fmt(D.money.bank);
  if ($('mcash').textContent !== c) { $('mcash').textContent = c; bump($('mcash')); }
  if ($('mbank').textContent !== b) { $('mbank').textContent = b; bump($('mbank')); }
}

/* ---------------- screen 1 ---------------- */
function tabs() {
  const all = [{ id: 'all', label: 'All' }, ...D.categories.filter(c => D.vehicles.some(v => v.category === c.id))];
  $('tabs').innerHTML = all.map(c => {
    const n = c.id === 'all' ? D.vehicles.length : D.vehicles.filter(v => v.category === c.id).length;
    return `<button class="tab ${cat === c.id ? 'sel' : ''}" data-c="${esc(c.id)}">${esc(c.label)}<b>${n}</b></button>`;
  }).join('');
  document.querySelectorAll('.tab').forEach(b => b.onclick = () => { cat = b.dataset.c; tabs(); grid(); });
}
function grid() {
  const q = query.trim().toLowerCase();
  const list = D.vehicles.filter(v => (cat === 'all' || v.category === cat) && (!q || (v.label + ' ' + v.brand + ' ' + v.model).toLowerCase().includes(q)));
  const c0 = (D.colors[0] || {}).hex || '#888';
  $('grid').innerHTML = list.length ? list.map((v, i) => `<button class="vc" style="--i:${i}" data-m="${esc(v.model)}">
    <span class="vcat">${esc(catOf(v.category).label)}</span><div class="vimg">${imgOf(v, D.colors[(i + 3) % D.colors.length]?.hex || c0)}</div>
    <h4>${esc(v.label)}</h4><div class="vb">${esc(v.brand)}</div><div class="vpr">${fmt(v.price)}</div></button>`).join('')
    : `<div class="empty">No cars match your search</div>`;
  $('count').textContent = list.length ? `${list.length} cars available · pick the one you want` : 'Try another category';
  document.querySelectorAll('.vc').forEach(b => b.onclick = () => detail(D.vehicles.find(v => v.model === b.dataset.m)));
}

/* ---------------- screen 2 ---------------- */
function view(n) {
  ['s1', 's2', 's3'].forEach((s, i) => $(s).classList.toggle('on', i + 1 === n));
  $('title').textContent = ['Car showroom', 'Vehicle details', 'Purchase receipt'][n - 1];
}
function go(n) {
  const on = document.querySelector('.scr.on');
  on.classList.add('out');
  setTimeout(() => { on.classList.remove('out'); view(n); }, 260);
}
function paint() {
  const c = D.colors[col - 1] || D.colors[0];
  $('pcar').innerHTML = imgOf(cur, c.hex);
  $('pglow').style.background = c.hex;
  $('cname').textContent = c.label;
  document.querySelectorAll('.sw button').forEach((b, i) => b.classList.toggle('sel', i + 1 === col));
}
function payRender() {
  $('pay').innerHTML = D.payments.map(p => {
    const bal = D.money[p] ?? 0, low = cur && bal < cur.price;
    return `<button class="pm ${pay === p ? 'sel' : ''} ${low ? 'low' : ''}" data-p="${p}"><svg viewBox="0 0 24 24">${PAY[p]?.icon || ''}</svg><div><b>${PAY[p]?.label || p}</b><small>${fmt(bal)}</small></div></button>`;
  }).join('');
  document.querySelectorAll('.pm').forEach(b => b.onclick = () => { pay = b.dataset.p; payRender(); });
  const low = (D.money[pay] ?? 0) < cur.price;
  $('warn').textContent = low ? `Not enough money in ${PAY[pay]?.label || pay} · you need ${fmt(cur.price - (D.money[pay] || 0))} more` : '';
  $('buy').disabled = low;
}
function detail(v) {
  if (!v) return;
  cur = v; col = 1; unconfirm();
  $('dname').textContent = v.label; $('dbrand').textContent = v.brand; $('dprice').textContent = fmt(v.price);
  $('dcat').textContent = catOf(v.category).label; $('dseats').textContent = `${v.seats || 2} seats`; $('dtop').textContent = v.topSpeed ? `${v.topSpeed} km/h` : '';
  $('sw').innerHTML = D.colors.map((c, i) => `<button style="background:${esc(c.hex)}" data-i="${i + 1}" title="${esc(c.label)}"></button>`).join('');
  document.querySelectorAll('.sw button').forEach(b => b.onclick = () => { col = +b.dataset.i; paint(); });
  const st = v.stats || {};
  $('stats').innerHTML = STATS.map(([k, l]) => `<div class="stat"><span>${l}<b>${st[k] ?? 0}</b></span><i><u data-w="${Math.min(100, st[k] ?? 0)}"></u></i></div>`).join('');
  $('test').style.display = D.testDrive ? '' : 'none';
  payRender(); paint();
  go(2);
  setTimeout(() => {
    $('pcar').classList.remove('in'); void $('pcar').offsetWidth; $('pcar').classList.add('in');
    document.querySelectorAll('.stat u').forEach(u => u.style.width = u.dataset.w + '%');
  }, 300);
}
function unconfirm() { clearTimeout(confirmT); $('buy').classList.remove('cf', 'ld'); $('btxt').textContent = 'Buy this car'; buying = false; }
$('buy').onclick = () => {
  if (buying || !cur) return;
  if (!$('buy').classList.contains('cf')) {
    $('buy').classList.add('cf'); $('btxt').textContent = `Tap again to confirm · ${fmt(cur.price)}`;
    confirmT = setTimeout(unconfirm, 3500); return;
  }
  clearTimeout(confirmT); buying = true;
  $('buy').classList.remove('cf'); $('buy').classList.add('ld'); $('btxt').textContent = 'Processing payment...';
  $('nfc').classList.add('on'); $('printer').classList.add('printing');
  send('buy', { model: cur.model, color: col, payment: pay });
  if (!RES) setTimeout(() => {
    const m = { ...D.money }; m[pay] -= cur.price;
    onReceipt({ order: 27, plate: 'VC2 ' + String(Math.floor(Math.random() * 1e4)).padStart(4, '0'), vehicle: cur.brand + ' ' + cur.label, color: D.colors[col - 1].label, price: cur.price, payment: pay }, m);
  }, 1200);
};
$('test').onclick = () => { if (cur) send('testDrive', { model: cur.model, color: col }); if (!RES) toast('Preview mode: test drives run in-game'); };
$('back').onclick = () => { unconfirm(); go(1); };

/* ---------------- screen 3 ---------------- */
function roll(el, final) {
  let i = 0; const ch = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';
  const t = setInterval(() => {
    el.textContent = i < 14 ? final.replace(/[A-Z0-9]/g, () => ch[Math.floor(Math.random() * ch.length)]) : final;
    if (i++ >= 14) { clearInterval(t); const p = el.parentElement; p.classList.remove('flash'); void p.offsetWidth; p.classList.add('flash'); }
  }, 55);
}
function onReceipt(r, m) {
  $('nfc').classList.remove('on');
  money(m);
  $('rorder').textContent = '#' + r.order; $('rprice').textContent = fmt(r.price); $('rpay').textContent = PAY[r.payment]?.label || r.payment;
  $('rcar').textContent = r.vehicle; $('rcol').textContent = r.color; $('rplate').textContent = '--------';
  $('okmsg').textContent = `Purchase complete! Your plate is ${r.plate}`;
  go(3); setTimeout(() => roll($('rplate'), r.plate), 700);
  setTimeout(() => { buying = false; }, 300);
}
$('more').onclick = () => { unconfirm(); $('printer').classList.remove('printing'); go(1); };
$('done').onclick = () => closeUI();
$('close1').onclick = () => closeUI();
$('q').oninput = e => { query = e.target.value; grid(); };

/* ---------------- open / close ---------------- */
const P = $('panel');
function bootIn() { P.classList.remove('off', 'boot'); void P.offsetWidth; P.classList.add('boot'); }
function reset() { unconfirm(); $('printer').classList.remove('printing'); $('nfc').classList.remove('on'); cat = 'all'; query = ''; $('q').value = ''; ['s1', 's2', 's3'].forEach(s => $(s).classList.remove('out')); view(1); }
function openUI(d) {
  Object.assign(D, d);
  pay = D.payments[0] || 'bank';
  $('kname').textContent = D.kiosk || 'VC2 Showroom';
  money(d.money); reset(); tabs(); grid();
  document.body.classList.add('open'); bootIn();
}
let closing = false;
function closeUI(fromGame) {
  if (!document.body.classList.contains('open') || closing) return;
  closing = true;
  P.classList.remove('boot'); void P.offsetWidth; P.classList.add('off');
  if (!fromGame) send('close');
  setTimeout(() => { document.body.classList.remove('open'); closing = false; if (!RES) setTimeout(() => openUI({}), 900); }, 360);
}

addEventListener('message', e => {
  const d = e.data || {};
  switch (d.action) {
    case 'open': openUI(d); break;
    case 'hide': closeUI(true); break;
    case 'money': money(d.money); break;
    case 'receipt': onReceipt(d.receipt, d.money); break;
    case 'error': unconfirm(); $('printer').classList.remove('printing'); $('nfc').classList.remove('on'); toast(d.msg || 'Something went wrong'); break;
    case 'prompt': $('prompt').classList.toggle('on', !!d.show); break;
    case 'timer': {
      const t = $('timer'); t.classList.toggle('on', !!d.show);
      if (d.show) { const s = d.seconds | 0; $('tleft').textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; t.classList.toggle('low', s <= 10); }
      break;
    }
  }
});
addEventListener('keydown', e => { if (e.key === 'Escape') closeUI(); });
addEventListener('pointerdown', e => {
  const b = e.target.closest('.btn'); if (!b) return;
  const r = b.getBoundingClientRect(), s = document.createElement('span'), d = Math.max(r.width, r.height) * 2 / K;
  s.className = 'rip'; s.style.cssText = `width:${d}px;height:${d}px;left:${(e.clientX - r.left) / K - d / 2}px;top:${(e.clientY - r.top) / K - d / 2}px`;
  b.appendChild(s); setTimeout(() => s.remove(), 600);
});
function fit() { K = Math.min(innerWidth / 1390, innerHeight / 801) * .96; $('stage').style.transform = `translate(${(innerWidth - 1390 * K) / 2}px,${(innerHeight - 801 * K) / 2}px) scale(${K})`; }
addEventListener('resize', fit); fit();

/* ---------------- browser preview (outside FiveM) ---------------- */
if (!RES) {
  document.body.classList.add('web');
  const V = (model, label, brand, cls, category, price, seats, top, st) => ({ model, label, brand, class: cls, category, price, seats, topSpeed: top, stats: { speed: st[0], accel: st[1], brake: st[2], handling: st[3] } });
  openUI({
    kiosk: 'VC2 Showroom - Downtown', currency: '$', payments: ['bank', 'cash'], testDrive: true, money: { cash: 42500, bank: 960000 },
    imageUrl: 'https://docs.fivem.net/vehicles/%s.webp',
    categories: [{ id: 'sedans', label: 'Sedans' }, { id: 'suvs', label: 'SUVs' }, { id: 'sports', label: 'Sports' }, { id: 'super', label: 'Super' }, { id: 'motos', label: 'Bikes' }],
    colors: [{ label: 'Black', hex: '#15161a' }, { label: 'White', hex: '#eceef0' }, { label: 'Silver', hex: '#a9adb3' }, { label: 'Red', hex: '#b3141b' }, { label: 'Orange', hex: '#e4501c' }, { label: 'Yellow', hex: '#f2c21b' }, { label: 'Blue', hex: '#1f4fae' }, { label: 'Green', hex: '#1f6b3a' }],
    vehicles: [
      V('asea', 'Asea', 'Declasse', 1, 'sedans', 18000, 4, 151, [60, 38, 42, 66]),
      V('tailgater', 'Tailgater', 'Obey', 1, 'sedans', 45000, 4, 166, [66, 52, 50, 74]),
      V('baller2', 'Baller', 'Gallivanter', 2, 'suvs', 90000, 4, 158, [63, 50, 48, 70]),
      V('granger', 'Granger', 'Declasse', 2, 'suvs', 55000, 8, 152, [61, 40, 42, 68]),
      V('elegy2', 'Elegy RH8', 'Annis', 6, 'sports', 150000, 2, 184, [74, 72, 66, 82]),
      V('comet2', 'Comet', 'Pfister', 6, 'sports', 175000, 2, 183, [73, 70, 70, 84]),
      V('zentorno', 'Zentorno', 'Pegassi', 7, 'super', 725000, 2, 197, [79, 82, 84, 90]),
      V('t20', 'T20', 'Progen', 7, 'super', 850000, 2, 198, [80, 84, 84, 92]),
      V('bati', 'Bati 801', 'Pegassi', 8, 'motos', 25000, 2, 180, [72, 88, 60, 70])
    ]
  });
}
