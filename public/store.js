(() => {
'use strict';
const $ = (s, r = document) => r.querySelector(s);
const esc = (x) => String(x ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
const STATUS = ['جديد', 'قيد التجهيز', 'تم الشحن', 'تم التوصيل', 'ملغي'];
const SOC = { youtube: ['YT', 'يوتيوب', '#c4302b'], x: ['X', 'إكس', '#111'], instagram: ['IG', 'إنستغرام', '#c13584'], tiktok: ['TK', 'تيك توك', '#0d8a8a'], snapchat: ['SC', 'سناب', '#d9b800'], discord: ['DC', 'ديسكورد', '#5865f2'], kick: ['K', 'كيك', '#53a90e'] };

let S = {}, P = [], T = {}, filter = 'all', sort = 'new', cur = null, curSize = '', curQty = 1;
let cart = [];
try { cart = JSON.parse(localStorage.getItem('rox_cart') || '[]'); if (!Array.isArray(cart)) cart = []; } catch { cart = []; }
const saveCart = () => { try { localStorage.setItem('rox_cart', JSON.stringify(cart)); } catch { /* */ } };

async function api(path, opts = {}) {
  const r = await fetch(path, { ...opts, headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) }, credentials: 'same-origin' });
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.error || 'صار خطأ، حاول مرة ثانية');
  return d;
}
function toast(m) { const t = $('#toast'); t.textContent = m; t.classList.add('on'); clearTimeout(toast.h); toast.h = setTimeout(() => t.classList.remove('on'), 2200); }

// ---------- تحميل ----------
const loader = $('#loader');
let pct = 0; const lp = $('#lpct');
const lt = setInterval(() => { pct = Math.min(pct + 7 + Math.random() * 12, 92); lp.textContent = Math.round(pct); }, 80);
function doneLoading() { clearInterval(lt); lp.textContent = '100'; setTimeout(() => loader.classList.add('done'), RM ? 0 : 250); }

api('/api/store').then((d) => {
  S = d.settings; P = d.products; T = d.types;
  if (S.maintenance) {
    $('#mtm').textContent = S.maintenanceMsg || '';
    $('#mtd').textContent = S.maintenanceUntil ? 'نرجع ' + new Date(S.maintenanceUntil + ':00+03:00').toLocaleString('ar-SA-u-nu-latn', { dateStyle: 'long', timeStyle: 'short' }) : '';
    $('#mt').hidden = false; doneLoading(); return;
  }
  document.title = `${S.storeName} | متجر`;
  $('#tagline').textContent = S.tagline || $('#tagline').textContent;
  $('#foot').textContent = `© ${new Date().getFullYear()} ${S.storeName} — جميع الحقوق محفوظة`;
  $('#perkship').textContent = S.freeShippingOver ? `مجاني فوق ${S.freeShippingOver} ر.س` : 'لكل مدن المملكة';
  const words = ['ROX', 'STREETWEAR', 'ORIGINAL', 'LIMITED', 'DROP'].concat(P.slice(0, 3).map((p) => T[p.type]?.en || ''));
  $('#tick').innerHTML = (words.map((w) => esc(w) + '<b>/</b>').join('')).repeat(2);
  cart = cart.filter((c) => P.some((p) => p.id === c.id));
  saveCart();
  chips(); grid(); socials(); countdown(); badge();
  doneLoading();
}).catch((e) => { $('#grid').innerHTML = `<p class="empty">${esc(e.message)}</p>`; doneLoading(); });

addEventListener('scroll', () => $('#hd').classList.toggle('solid', scrollY > 40), { passive: true });

// ---------- المنتجات ----------
function chips() {
  const types = [...new Set(P.map((p) => p.type))];
  $('#chips').innerHTML = [['all', 'الكل']].concat(types.map((t) => [t, T[t]?.ar || t]))
    .map(([k, l]) => `<button type="button" role="tab" data-f="${esc(k)}" class="${k === filter ? 'on' : ''}" aria-selected="${k === filter}">${esc(l)}</button>`).join('');
}
$('#chips').addEventListener('click', (e) => { const b = e.target.closest('[data-f]'); if (!b) return; filter = b.dataset.f; chips(); grid(); });
$('#sort').addEventListener('change', (e) => { sort = e.target.value; grid(); });

function grid() {
  let L = P.filter((p) => filter === 'all' || p.type === filter);
  if (sort === 'lo') L = [...L].sort((a, b) => a.price - b.price);
  if (sort === 'hi') L = [...L].sort((a, b) => b.price - a.price);
  $('#grid').innerHTML = L.map((p, k) => `<article class="card" style="--k:${k}">
    <button class="im" type="button" data-open="${p.id}" aria-label="${esc(p.name)}"><img src="${esc(p.photo || p.image)}" alt="${esc(p.name)}" loading="lazy" width="400" height="400">
    ${p.comparePrice ? `<span class="badge">خصم ${Math.round((1 - p.price / p.comparePrice) * 100)}%</span>` : ''}${!p.inStock ? '<span class="badge dk">نفدت الكمية</span>' : p.lowStock ? '<span class="badge dk">كمية محدودة</span>' : ''}</button>
    <div class="in"><small>${esc(p.typeName)}</small><h3 data-open="${p.id}">${esc(p.name)}</h3></div>
    <div class="price"><b class="lat">${p.price}</b>${p.comparePrice ? `<s class="lat">${p.comparePrice}</s>` : ''}<small>ر.س</small></div>
    <button class="quick" type="button" data-q="${p.id}" ${p.inStock ? '' : 'disabled'}>${p.inStock ? (p.sizes.length ? 'اختر المقاس' : 'أضف للسلة') : 'نفدت الكمية'}</button>
  </article>`).join('') || '<p class="empty">ما فيه منتجات هنا حاليًا. ترقّب الإصدار الجاي!</p>';
}
$('#grid').addEventListener('click', (e) => {
  const o = e.target.closest('[data-open]'); if (o) return openP(+o.dataset.open);
  const q = e.target.closest('[data-q]'); if (!q) return;
  const p = P.find((x) => x.id === +q.dataset.q);
  if (p.sizes.length) return openP(p.id);
  add(p, '', 1, q);
});

// ---------- النوافذ ----------
let lastFocus = null;
function openOv(el) { lastFocus = document.activeElement; el.hidden = false; document.body.classList.add('lock'); setTimeout(() => el.querySelector('[data-close]')?.focus(), 30); }
function closeOv(el) { el.hidden = true; if (![...document.querySelectorAll('.ov')].some((o) => !o.hidden)) document.body.classList.remove('lock'); lastFocus?.focus?.(); }
document.addEventListener('click', (e) => { if (e.target.matches('[data-close]')) closeOv(e.target.closest('.ov')); else if (e.target.classList.contains('ov')) closeOv(e.target); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') { const o = [...document.querySelectorAll('.ov')].reverse().find((x) => !x.hidden); if (o) closeOv(o); } });

function openP(id) {
  const p = P.find((x) => x.id === id); if (!p) return;
  cur = p; curSize = p.sizes.length === 1 ? p.sizes[0] : ''; curQty = 1;
  $('#pdv').style.background = p.bg;
  $('#pdg').textContent = T[p.type]?.en || '';
  setImg(p.photo || p.image);
  $('#pdt').innerHTML = p.photo ? `<button type="button" class="on" data-img="${esc(p.photo)}">صورة</button><button type="button" data-img="${esc(p.image)}">التصميم</button>` : '';
  $('#pdty').textContent = p.typeName;
  $('#pdn').textContent = p.name;
  $('#pdp').textContent = p.price;
  $('#pdc').textContent = p.comparePrice || '';
  $('#pdd').textContent = p.description;
  $('#pds').innerHTML = p.sizes.length ? `<span class="szl">المقاس</span><div class="sz">${p.sizes.map((z) => `<button type="button" data-z="${esc(z)}" class="${z === curSize ? 'on' : ''}">${esc(z)}</button>`).join('')}</div>` : '';
  $('#pdsp').innerHTML = p.specs.map((s) => `<div><dt>${esc(s.label)}</dt><dd>${esc(s.value)}</dd></div>`).join('');
  $('#pdq').textContent = 1; $('#pde').textContent = '';
  const a = $('#pda'); a.disabled = !p.inStock; a.textContent = p.inStock ? 'أضف للسلة' : 'نفدت الكمية';
  openOv($('#pd'));
}
function setImg(src) { const i = $('#pdi'); i.src = src; i.alt = cur?.name || ''; $('#pdg').hidden = src !== cur?.image; }
$('#pdt').addEventListener('click', (e) => { const b = e.target.closest('[data-img]'); if (!b) return; $('#pdt').querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b)); setImg(b.dataset.img); });
$('#pds').addEventListener('click', (e) => { const b = e.target.closest('[data-z]'); if (!b) return; curSize = b.dataset.z; $('#pds').querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b)); $('#pde').textContent = ''; });
$('#pd').addEventListener('click', (e) => { const b = e.target.closest('[data-q]'); if (!b) return; curQty = Math.min(10, Math.max(1, curQty + +b.dataset.q)); $('#pdq').textContent = curQty; });
$('#pda').addEventListener('click', (e) => {
  if (cur.sizes.length && !curSize) { $('#pde').textContent = 'اختر المقاس أول'; return; }
  add(cur, curSize, curQty, e.currentTarget); closeOv($('#pd'));
});

// ---------- السلة ----------
function add(p, size, qty, from) {
  const l = cart.find((c) => c.id === p.id && c.size === size);
  if (l) l.qty = Math.min(10, l.qty + qty); else cart.push({ id: p.id, size, qty });
  saveCart(); badge(); fly(from); toast(`انضاف ${p.name} للسلة`);
}
function fly(from) {
  if (RM || !from) return;
  const a = from.getBoundingClientRect(), b = $('#cc').getBoundingClientRect(), d = document.createElement('i');
  d.className = 'fly'; d.style.left = a.left + a.width / 2 + 'px'; d.style.top = a.top + a.height / 2 + 'px'; document.body.append(d);
  d.animate([{ transform: 'translate(0,0) scale(1)' }, { transform: `translate(${b.left - a.left - a.width / 2}px, ${b.top - a.top - a.height / 2}px) scale(.4)`, opacity: .6 }], { duration: 650, easing: 'cubic-bezier(.5,0,.2,1)' }).onfinish = () => d.remove();
}
function badge() { const n = cart.reduce((s, c) => s + c.qty, 0), c = $('#cc'); c.textContent = n; c.classList.remove('bump'); void c.offsetWidth; c.classList.add('bump'); }
function totals() {
  const sub = cart.reduce((s, c) => s + (P.find((p) => p.id === c.id)?.price || 0) * c.qty, 0);
  const ship = !sub ? 0 : S.freeShippingOver && sub >= S.freeShippingOver ? 0 : S.shippingFee || 0;
  return { sub, ship, total: sub + ship };
}
function renderCart() {
  const t = totals();
  $('#ci').innerHTML = cart.map((c, i) => { const p = P.find((x) => x.id === c.id); return `<div class="ln"><img src="${esc(p.photo || p.image)}" alt=""><div><b>${esc(p.name)}</b><small>${c.size ? 'المقاس ' + esc(c.size) : esc(p.typeName)}</small><div class="qt"><button type="button" data-cq="${i}" data-d="-1" aria-label="أقل">−</button><b>${c.qty}</b><button type="button" data-cq="${i}" data-d="1" aria-label="أكثر">+</button><button type="button" class="rm" data-rm="${i}">حذف</button></div></div><b class="lat">${p.price * c.qty}</b></div>`; }).join('') || '<p class="empty">سلتك فاضية. شوف التشكيلة!</p>';
  $('#st').textContent = t.sub; $('#sp').textContent = t.ship ? t.ship : 'مجاني'; $('#tot').textContent = t.total;
  $('#go').disabled = !cart.length;
  if (S.freeShippingOver && t.sub) {
    const left = S.freeShippingOver - t.sub;
    $('#fs').innerHTML = (left > 0 ? `باقي <b>${left} ر.س</b> وتحصل شحن مجاني` : 'مبروك! الشحن مجاني 🎉') + `<i><b style="width:${Math.min(100, t.sub / S.freeShippingOver * 100)}%"></b></i>`;
  } else $('#fs').innerHTML = '';
}
$('#cartBtn').addEventListener('click', () => { renderCart(); openOv($('#cart')); });
$('#ci').addEventListener('click', (e) => {
  const q = e.target.closest('[data-cq]'), r = e.target.closest('[data-rm]');
  if (q) { const c = cart[+q.dataset.cq]; c.qty = Math.min(10, c.qty + +q.dataset.d); if (c.qty < 1) cart.splice(+q.dataset.cq, 1); }
  else if (r) cart.splice(+r.dataset.rm, 1); else return;
  saveCart(); badge(); renderCart();
});

// ---------- إتمام الطلب ----------
$('#go').addEventListener('click', () => {
  closeOv($('#cart'));
  $('#city').innerHTML = '<option value="">اختر المدينة</option>' + (S.cities || []).map((c) => `<option>${esc(c)}</option>`).join('');
  const pays = [['cod', 'الدفع عند الاستلام', 'كاش أو شبكة عند المندوب'], ['bank', 'تحويل بنكي', 'نرسل لك بيانات الحساب بعد الطلب']].filter(([k]) => S.payments?.[k]);
  $('#pay').innerHTML = '<legend>طريقة الدفع</legend>' + pays.map(([k, l, d], i) => `<label><input type="radio" name="payment" value="${k}" ${i ? '' : 'checked'}><span>${l}<small>${d}</small></span></label>`).join('');
  const t = totals();
  $('#cosum').innerHTML = `<div><span>${cart.reduce((s, c) => s + c.qty, 0)} قطعة</span><span>${t.sub} ر.س</span></div><div><span>الشحن</span><span>${t.ship ? t.ship + ' ر.س' : 'مجاني'}</span></div><div class="t"><span>الإجمالي</span><span>${t.total} ر.س</span></div>`;
  $('#cof').hidden = false; $('#cok').hidden = true; $('#coe').textContent = '';
  openOv($('#co'));
});
$('#cform').addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = new FormData(e.target), o = Object.fromEntries(f);
  const err = !o.name.trim() ? 'اكتب اسمك' : !/^\S+@\S+\.\S+$/.test(o.email) ? 'الإيميل غير صحيح' : o.phone.replace(/\D/g, '').length < 9 ? 'رقم الجوال غير صحيح' : !o.city ? 'اختر المدينة' : !o.address.trim() ? 'اكتب العنوان' : !o.payment ? 'اختر طريقة الدفع' : '';
  if (err) { $('#coe').textContent = err; return; }
  const b = $('#cosub'); b.disabled = true; b.textContent = 'جاري إرسال الطلب…';
  try {
    const r = await api('/api/orders', { method: 'POST', body: JSON.stringify({ ...o, items: cart }) });
    cart = []; saveCart(); badge(); e.target.reset();
    $('#cof').hidden = true;
    $('#cok').innerHTML = `<div class="ok"><div class="stamp lat">${esc(r.code)}</div><h2>تم استلام طلبك!</h2><p class="mute">أرسلنا تأكيد الطلب على إيميلك. احتفظ برقم الطلب عشان تتبّعه.</p><p>الإجمالي: <b>${r.total} ر.س</b></p>${r.payment === 'bank' && r.bankInfo ? `<div class="bank"><b>بيانات التحويل:</b>\n${esc(r.bankInfo)}\n\nاكتب رقم الطلب في ملاحظة التحويل.</div>` : ''}<button class="btn red" type="button" data-close>تمام</button></div>`;
    $('#cok').hidden = false;
    $('#tf').code.value = r.code; $('#tf').email.value = o.email;
  } catch (x) { $('#coe').textContent = x.message; }
  finally { b.disabled = false; b.textContent = 'أكّد الطلب'; }
});

// ---------- تتبّع ----------
$('#tf').addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = e.target, out = $('#tr');
  out.innerHTML = '<p class="mute" style="margin-top:20px">جاري البحث…</p>';
  try {
    const o = await api('/api/track', { method: 'POST', body: JSON.stringify({ code: f.code.value.trim(), email: f.email.value.trim() }) });
    out.innerHTML = `<div class="tl ${o.status === 4 ? 'cx' : ''}"><h3><span class="lat" dir="ltr">${esc(o.code)}</span><span>${esc(o.statusName)}</span></h3>
      <div class="steps">${STATUS.slice(0, 4).map((s, i) => `<div class="${o.status !== 4 && i <= o.status ? 'on' : ''}">${s}</div>`).join('')}</div>
      <ul>${o.items.map((i) => `<li>${esc(i.name)}${i.size ? ' — ' + esc(i.size) : ''} × ${i.qty}</li>`).join('')}</ul>
      <p class="mute" style="margin-top:10px">الإجمالي ${o.total} ر.س — آخر تحديث ${new Date(o.updatedAt).toLocaleString('ar-SA-u-nu-latn', { dateStyle: 'medium', timeStyle: 'short' })}</p></div>`;
  } catch (x) { out.innerHTML = `<p class="err" style="margin-top:20px">${esc(x.message)}</p>`; }
});

// ---------- الحسابات ----------
function socials() {
  const L = Object.entries(S.socials || {}).filter(([, v]) => v);
  if (!L.length) { $('#social').hidden = true; $('#navsoc').hidden = true; return; }
  $('#soc').innerHTML = L.map(([k, v], i) => { const s = SOC[k]; return `<a class="sc" href="${esc(v)}" target="_blank" rel="noopener noreferrer" style="--r:${[-6, 4, -3, 7, -5, 3, -7][i % 7]}deg"><b class="lat" style="--c:${s[2]}">${s[0]}</b>${s[1]}</a>`; }).join('');
}

// ---------- العدّاد ----------
function countdown() {
  const end = new Date((S.dropDate || '') + ':00+03:00').getTime();
  if (!end || end < Date.now()) { $('#drop').hidden = true; document.querySelector('a[href="#drop"]').hidden = true; return; }
  const L = ['يوم', 'ساعة', 'دقيقة', 'ثانية'];
  $('#flip').innerHTML = L.map((l) => `<div class="tile"><div class="lat">00</div><small>${l}</small></div>`).join('');
  const tiles = [...$('#flip').querySelectorAll('.tile div')];
  const tickFn = () => {
    const d = Math.max(0, end - Date.now()) / 1000;
    [Math.floor(d / 86400), Math.floor(d / 3600) % 24, Math.floor(d / 60) % 60, Math.floor(d) % 60].forEach((v, i) => {
      const s = String(v).padStart(2, '0'); const t = tiles[i];
      if (t.textContent !== s) { t.textContent = s; if (!RM) { t.classList.remove('f'); void t.offsetWidth; t.classList.add('f'); } }
    });
  };
  tickFn(); setInterval(tickFn, 1000);
}
})();
