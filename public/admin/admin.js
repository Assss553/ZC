(() => {
'use strict';
const $ = (s, r = document) => r.querySelector(s);
const esc = (x) => String(x ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
const ST = ['جديد', 'قيد التجهيز', 'تم الشحن', 'تم التوصيل', 'ملغي'];
const PAY = { cod: 'عند الاستلام', bank: 'تحويل بنكي' };
const DY = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
const TY = { hood: 'هودي', tee: 'تيشيرت', crew: 'سويت شيرت', cap: 'كاب', tote: 'شنطة قماش', pad: 'ماوس باد' };
const PS = { draft: 'مسودة', published: 'منشور', archived: 'مؤرشف' };
const SOC = [['youtube', 'يوتيوب'], ['x', 'إكس'], ['instagram', 'إنستغرام'], ['tiktok', 'تيك توك'], ['snapchat', 'سناب'], ['discord', 'ديسكورد'], ['kick', 'كيك']];
const TB = [['نظرة عامة', 'OVERVIEW'], ['الطلبات', 'ORDERS'], ['المنتجات', 'PRODUCTS'], ['استوديو AI', 'AI STUDIO'], ['الإعدادات', 'SETTINGS'], ['الأمان', 'SECURITY']];
const IDEAS = ['تشكيلة شتوية مستوحاة من صحراء نجد بالليل', 'هودي جيمنج بطابع نيون وخطوط سرعة', 'تيشيرتات بخط عربي حديث وكلمات حماسية', 'كاب وشنطة بطابع ريترو تسعينات', 'إصدار محدود لموسم الرياض'];

let CSRF = '', ME = null, at = 0, rg = 7, flt = -1, qs = '', stats = null, orders = [], counts = [0, 0, 0, 0, 0], prods = [], cfg = null, info = {};

// ---------- اتصال آمن بالخادم ----------
async function api(path, opts = {}) {
  const r = await fetch('/api/admin' + path, {
    ...opts, credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': CSRF, ...(opts.headers || {}) },
  });
  const d = await r.json().catch(() => ({}));
  if (r.status === 401 && !path.startsWith('/login') && !path.startsWith('/setup')) { lock('انتهت الجلسة، سجّل دخولك من جديد'); throw new Error(d.error || 'سجّل الدخول'); }
  if (!r.ok) throw new Error(d.error || 'صار خطأ');
  return d;
}
const send = (path, method, body) => api(path, { method, body: body === undefined ? undefined : JSON.stringify(body) });
function toast(m) { const t = $('#ts'); t.textContent = m; t.classList.add('on'); clearTimeout(toast.h); toast.h = setTimeout(() => t.classList.remove('on'), 2400); }
function ago(t) { const m = Math.max(Math.round((Date.now() - t) / 6e4), 1); return m < 60 ? `قبل ${m} دقيقة` : m < 1440 ? `قبل ${Math.round(m / 60)} ساعة` : `قبل ${Math.round(m / 1440)} يوم`; }
const dt = (t) => new Date(t).toLocaleString('ar-SA-u-nu-latn', { dateStyle: 'medium', timeStyle: 'short' });
function confirmBtn(b, f) { if (b.dataset.c) { f(); return; } b.dataset.c = 1; const o = b.textContent; b.textContent = 'اضغط للتأكيد'; setTimeout(() => { delete b.dataset.c; b.textContent = o; }, 2500); }
function countUp(el) { const v = +el.dataset.v, t0 = performance.now(); (function f(n) { const k = Math.min((n - t0) / 900, 1); el.textContent = Math.round(v * (1 - Math.pow(1 - k, 3))); if (k < 1) requestAnimationFrame(f); })(t0); }

// ---------- الدخول ----------
let needsSetup = false;
function lock(msg) { $('#app').hidden = true; $('#lk').hidden = false; $('#lerr').textContent = msg || ''; $('#lp').value = ''; $('#le').focus(); }
async function boot() {
  try {
    const s = await fetch('/api/admin/status').then((r) => r.json());
    needsSetup = s.needsSetup;
    if (needsSetup) { $('#lh').textContent = 'أنشئ حساب الأدمن الأول'; $('#ls').hidden = false; $('#go').textContent = 'إنشاء الحساب'; $('#lp').autocomplete = 'new-password'; $('#lp').placeholder = 'كلمة مرور قوية (10+ حروف وأرقام)'; return lock(); }
    const me = await api('/me'); start(me);
  } catch { lock(); }
}
$('#lf').addEventListener('submit', async (e) => {
  e.preventDefault();
  const b = $('#go'); b.disabled = true; $('#lerr').textContent = '';
  try {
    const body = { email: $('#le').value.trim(), password: $('#lp').value };
    if (needsSetup) {
      await send('/setup', 'POST', { ...body, setupToken: $('#ls').value.trim() });
      needsSetup = false; $('#ls').hidden = true; $('#lh').textContent = 'تم إنشاء الحساب'; $('#go').textContent = 'دخول';
    }
    const r = await send('/login', 'POST', body);
    CSRF = r.csrf; start(await api('/me'));
  } catch (x) { $('#lerr').textContent = x.message; }
  finally { b.disabled = false; }
});
function start(me) { ME = me.admin; CSRF = me.csrf; info = me; $('#who').textContent = ME.email; $('#lk').hidden = true; $('#app').hidden = false; $('#lp').value = ''; tab(at); }
$('#lo').onclick = async () => { try { await send('/logout', 'POST'); } catch { /* */ } CSRF = ''; lock('تم تسجيل الخروج'); };

// ---------- التنقل ----------
const VW = [vOverview, vOrders, vProducts, vStudio, vSettings, vSecurity];
function nav() { const n = counts[0]; const h = TB.map((t, i) => `<button class="nb${i === at ? ' on' : ''}" data-t="${i}" type="button">${t[0]}<small class="lat">${t[1]}</small>${i === 1 && n ? `<i>${n}</i>` : ''}</button>`).join(''); $('#nv').innerHTML = h; $('#tb').innerHTML = h; }
async function tab(i, quiet) {
  at = i; $('#ttl').textContent = TB[i][0]; nav();
  const v = $('#v');
  if (!quiet) v.innerHTML = '<p class="em">جاري التحميل…</p>';
  try { await VW[i](v, quiet); } catch (x) { v.innerHTML = `<p class="em">${esc(x.message)}</p>`; }
  v.classList.toggle('na', !!quiet);
  v.querySelectorAll('.cu').forEach((e) => { if (quiet || RM) e.textContent = e.dataset.v; else countUp(e); });
  nav();
}
$('#nv').onclick = $('#tb').onclick = (e) => { const b = e.target.closest('.nb'); if (b) { tab(+b.dataset.t); scrollTo(0, 0); } };

// ---------- نافذة جانبية ----------
function sheet(html) { $('#sb').innerHTML = html; $('#sh').classList.add('on'); setTimeout(() => $('#sb').querySelector('input,select,textarea,button')?.focus(), 50); }
function closeSheet() { $('#sh').classList.remove('on'); }
$('#sh').addEventListener('click', (e) => { if (e.target.id === 'sh' || e.target.closest('[data-x]')) closeSheet(); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeSheet(); });

// =================== نظرة عامة ===================
function hero(s) {
  const a = s.series.slice(0, rg), sum = a.reduce((x, y) => x + y, 0), mx = Math.max(...a) || 1, step = 280 / rg, w = rg > 7 ? step * 0.62 : 22;
  const prevSum = rg === s.days ? s.prev : null;
  const dl = prevSum ? Math.round((sum - prevSum) / prevSum * 100) : null;
  let h = '';
  a.forEach((v, k) => {
    const bh = Math.max(v / mx * 60, v ? 3 : 1);
    h += `<rect class="b${k ? '' : ' t'}" style="--k:${k}" x="${(280 - (k + 1) * step + (step - w) / 2).toFixed(1)}" y="${(68 - bh).toFixed(1)}" width="${w.toFixed(1)}" height="${bh.toFixed(1)}"><title>${v} ر.س</title></rect>`;
    if (rg === 7) h += `<text x="${280 - (k + 1) * step + step / 2}" y="84" text-anchor="middle">${DY[new Date(Date.now() - k * 864e5).getDay()]}</text>`;
  });
  return `<div class="hero"><div class="hl"><small>إجمالي المبيعات</small><div class="seg">${[7, 30].map((n) => `<button type="button" data-r="${n}" class="${n === rg ? 'on' : ''}">${n} ${n === 7 ? 'أيام' : 'يوم'}</button>`).join('')}</div></div>
  <div class="num lat"><span class="cu" data-v="${sum}">0</span><em>ر.س</em></div>
  <div class="dl">${dl === null ? 'لا توجد فترة سابقة للمقارنة' : `${dl >= 0 ? '▲' : '▼'} ${Math.abs(dl)}% عن الفترة السابقة`}</div>
  <svg viewBox="0 0 280 90" role="img" aria-label="مبيعات آخر ${rg} يوم">${h}</svg></div>`;
}
function ticket(o, mini) {
  return `<div class="tk"><button class="in" type="button" data-od="${o.id}"><b class="lat" dir="ltr">${esc(o.code)}</b><span class="pm">${PAY[o.payment] || ''}</span>
  <strong class="cn">${esc(o.customer_name)}</strong><small><bdi dir="ltr">${esc(o.phone)}</bdi> — ${esc(o.city)}</small>
  <small>${o.items.map((x) => esc(x.name) + (x.size ? ' ' + esc(x.size) : '') + ' ×' + x.qty).join('، ')}</small><small>${ago(o.created_at)}</small></button>
  <div class="sb"><b class="lat">${o.total}<em>ر.س</em></b><button type="button" class="ch s${o.status}" data-next="${o.id}" title="نقل للمرحلة التالية">${ST[o.status]}</button>${mini ? '' : ''}</div></div>`;
}
async function vOverview(v) {
  stats = await api('/stats?days=30');
  counts = stats.byStatus;
  const s = stats, m = s.top[0]?.revenue || 1;
  const dd = cfg ? Math.ceil((new Date(cfg.dropDate + ':00+03:00') - Date.now()) / 864e5) : null;
  v.innerHTML = (s.drafts ? `<div class="note">عندك ${s.drafts} منتج مسودة بانتظار المراجعة. <button type="button" data-go="2">راجعها</button></div>` : '')
    + (!info.mail ? '<div class="note info">الإيميلات غير مفعّلة: أضف إعدادات SMTP في ملف .env عشان توصل رسائل للعملاء.</div>' : '')
    + hero(s)
    + `<div class="ks"><div><small>طلبات آخر 30 يوم</small><b class="lat cu" data-v="${s.orders}">0</b></div><div><small>بانتظارك</small><b class="lat cu" data-v="${s.byStatus[0]}">0</b></div><div><small>متوسط الطلب (ر.س)</small><b class="lat cu" data-v="${s.avg}">0</b></div><div><small>العملاء</small><b class="lat cu" data-v="${s.customers}">0</b></div></div>`
    + `<div class="hh">بانتظارك (${s.byStatus[0]})<button type="button" class="sp hint" data-go="1">كل الطلبات ←</button></div>${s.pending.map((o) => ticket(o)).join('') || '<p class="em">كل الطلبات متابَعة. ما فيه شي ينتظرك.</p>'}`
    + `<div class="hh">الأعلى مبيعًا</div>${s.top.map((t, j) => `<div class="tp"><span>${esc(t.name)}</span><div><i style="--w:${Math.round(t.revenue / m * 100)}%;animation-delay:${0.2 + j * 0.08}s"></i></div><b class="lat">${t.revenue}</b></div>`).join('') || '<p class="em">ما فيه مبيعات بعد.</p>'}`
    + `<div class="hh">المتجر</div><div class="cd"><span>منتجات منشورة</span><b class="lat">${s.products}</b>${dd !== null && dd > 0 ? `<span style="margin-inline-start:auto">الإصدار الجاي بعد</span><b class="lat">${dd}</b><span>يوم</span>` : ''}</div>`;
  if (!cfg) api('/settings').then((d) => { cfg = d.settings; }).catch(() => {});
}

// =================== الطلبات ===================
async function loadOrders() {
  const p = new URLSearchParams(); if (flt >= 0) p.set('status', flt); if (qs.trim()) p.set('q', qs.trim());
  const d = await api('/orders?' + p); orders = d.orders; counts = d.counts;
}
function orderList() { return orders.map((o) => ticket(o)).join('') || '<p class="em">ما فيه طلبات تطابق هذا الفلتر.</p>'; }
async function vOrders(v) {
  await loadOrders();
  const all = counts.reduce((a, b) => a + b, 0);
  v.innerHTML = `<div class="fl">${[['الكل', -1, all]].concat(ST.map((s, i) => [s, i, counts[i]])).map(([l, i, n]) => `<button type="button" data-f="${i}" class="${i === flt ? 'on' : ''}">${l} (${n})</button>`).join('')}</div>
  <input class="q" id="q" type="search" placeholder="ابحث بالاسم أو الجوال أو الإيميل أو رقم الطلب" value="${esc(qs)}">
  <p class="hint">اضغط على ختم الحالة لنقل الطلب للمرحلة التالية (يوصل العميل إيميل تلقائي).</p><div id="ol">${orderList()}</div>`;
}
let qt;
$('#v').addEventListener('input', (e) => {
  if (e.target.id === 'q') { qs = e.target.value; clearTimeout(qt); qt = setTimeout(async () => { await loadOrders(); $('#ol').innerHTML = orderList(); }, 250); }
});
function findOrder(id) { return orders.find((o) => o.id === id) || stats?.pending.find((o) => o.id === id); }
async function setStatus(id, status, notify = true) {
  const r = await send(`/orders/${id}`, 'PATCH', { status, notify });
  toast(`الحالة الآن: ${ST[status]}${r.emailed ? ' — تم إشعار العميل بالإيميل' : ''}`);
  return r.order;
}
function orderSheet(o) {
  const wa = o.phone.replace(/\D/g, '').replace(/^0/, '966').replace(/^00/, '');
  sheet(`<h2><span class="lat" dir="ltr">${esc(o.code)}</span></h2><p class="hint">${dt(o.created_at)}</p>
  <div class="ct"><a href="tel:${esc(o.phone)}">اتصال</a><a target="_blank" rel="noopener noreferrer" href="https://wa.me/${esc(wa)}">واتساب</a><a href="mailto:${esc(o.email)}">إيميل</a></div>
  <dl class="kv"><dt>العميل</dt><dd>${esc(o.customer_name)}</dd><dt>الجوال</dt><dd dir="ltr">${esc(o.phone)}</dd><dt>الإيميل</dt><dd dir="ltr">${esc(o.email)}</dd><dt>العنوان</dt><dd>${esc(o.city)} — ${esc(o.address)}</dd><dt>الدفع</dt><dd>${PAY[o.payment]}</dd>${o.notes ? `<dt>ملاحظات</dt><dd>${esc(o.notes)}</dd>` : ''}</dl>
  <div class="oi">${o.items.map((i) => `<div><span>${esc(i.name)}${i.size ? ' — ' + esc(i.size) : ''} × ${i.qty}</span><span>${i.unit_price * i.qty} ر.س</span></div>`).join('')}<div><span>الشحن</span><span>${o.shipping ? o.shipping + ' ر.س' : 'مجاني'}</span></div><div class="t"><span>الإجمالي</span><span>${o.total} ر.س</span></div></div>
  <div class="f2"><label>الحالة<select id="ost">${ST.map((s, i) => `<option value="${i}" ${o.status === i ? 'selected' : ''}>${s}</option>`).join('')}</select></label><label class="ck" style="align-self:end"><input type="checkbox" id="onf" checked> إشعار العميل بالإيميل</label></div>
  <small class="fe" id="oe"></small>
  <button class="bt p" type="button" data-osave="${o.id}">حفظ الحالة</button><button class="bt" type="button" data-oresend="${o.id}">إعادة إرسال التأكيد</button><button class="bt d" type="button" data-odel="${o.id}">حذف الطلب</button><button class="bt" type="button" data-x>إغلاق</button>`);
}
$('#sb').addEventListener('click', async (e) => {
  const b = e.target.closest('button'); if (!b) return; const d = b.dataset;
  try {
    if (d.osave) { b.disabled = true; await setStatus(+d.osave, +$('#ost').value, $('#onf').checked); closeSheet(); tab(at, 1); }
    else if (d.oresend) { b.disabled = true; const r = await send(`/orders/${d.oresend}/resend`, 'POST'); toast(r.ok ? 'تم إرسال الإيميل' : 'ما انرسل الإيميل (راجع إعدادات SMTP)'); }
    else if (d.odel) confirmBtn(b, async () => { await send(`/orders/${d.odel}`, 'DELETE'); closeSheet(); toast('تم حذف الطلب'); tab(at, 1); });
    else if (d.psave !== undefined) await saveProduct(b, d.psave);
    else if (d.pdel) confirmBtn(b, async () => { await send(`/products/${d.pdel}`, 'DELETE'); closeSheet(); toast('تم حذف المنتج'); tab(at, 1); });
    else if (d.phrm) { const r = await send(`/products/${d.phrm}/photo`, 'DELETE'); upsert(r.product); closeSheet(); toast('تم حذف الصورة'); tab(at, 1); }
  } catch (x) { const fe = $('#sb .fe'); if (fe) fe.textContent = x.message; else toast(x.message); }
  finally { b.disabled = false; }
});
$('#sb').addEventListener('change', async (e) => {
  if (e.target.id !== 'pph') return;
  const f = e.target.files[0]; if (!f) return;
  if (f.size > 2.5 * 1024 * 1024) { $('#pe').textContent = 'حجم الصورة أكبر من 2.5 ميجا'; return; }
  const data = await new Promise((res) => { const r = new FileReader(); r.onload = () => res(r.result); r.readAsDataURL(f); });
  try { const r = await send(`/products/${e.target.dataset.id}/photo`, 'POST', { data }); upsert(r.product); $('#pimg').src = r.product.photo; toast('تم رفع الصورة'); }
  catch (x) { $('#pe').textContent = x.message; }
});

// =================== المنتجات ===================
function upsert(p) { const i = prods.findIndex((x) => x.id === p.id); if (i >= 0) prods[i] = p; else prods.unshift(p); }
function pcard(p) {
  return `<div class="pt"><button class="th" type="button" data-e="${p.id}" style="background:${esc(p.bg)}" aria-label="تعديل ${esc(p.name)}"><img src="${esc(p.photo || p.image)}" alt="" loading="lazy"></button>
  <span class="st ${p.status}">${PS[p.status]}</span>${p.ai ? '<span class="st ai lat">AI</span>' : ''}
  <b>${esc(p.name)}</b><small>${TY[p.type] || p.type}${p.stock != null ? ` — المخزون ${p.stock}` : ''}</small>
  <span class="lat pp">${p.price}${p.comparePrice ? `<s>${p.comparePrice}</s>` : ''}<em>ر.س</em></span>
  <div class="ac"><button type="button" data-pub="${p.id}">${p.status === 'published' ? 'إخفاء' : 'نشر'}</button><button type="button" data-e="${p.id}">تعديل</button><button type="button" data-pd="${p.id}">حذف</button></div></div>`;
}
async function vProducts(v) {
  prods = (await api('/products')).products;
  const dr = prods.filter((p) => p.status === 'draft').length;
  v.innerHTML = (dr ? `<div class="note">${dr} مسودة: راجعها واضغط "نشر" عشان تنزل في المتجر.</div>` : '')
    + `<div class="pg">${prods.map(pcard).join('')}<button class="pt nw" id="np" type="button">+ منتج يدوي</button><button class="pt nw" type="button" data-go="3">✦ صمّم بالذكاء الاصطناعي</button></div>`;
}
function productSheet(p) {
  const n = !p;
  p = p || { name: '', price: '', comparePrice: '', type: 'tee', bg: '#0b0a09', fg: '#efeae2', sizes: ['S', 'M', 'L', 'XL', 'XXL'], specs: [], tags: [], stock: null, status: 'draft', description: '' };
  sheet(`<h2>${n ? 'منتج جديد' : 'تعديل المنتج'}</h2>
  ${n ? '' : `<div class="prev"><img id="pimg" src="${esc(p.photo || p.image)}" alt=""><div><label>صورة حقيقية للمنتج (اختياري)<input type="file" id="pph" data-id="${p.id}" accept="image/png,image/jpeg,image/webp"></label>${p.photo ? `<button class="bt d" type="button" data-phrm="${p.id}" style="margin:0">حذف الصورة</button>` : ''}</div></div>`}
  <label>الاسم<input id="pn" value="${esc(p.name)}" maxlength="80"></label>
  <div class="f3"><label>السعر (ر.س)<input id="pp" type="number" inputmode="numeric" min="1" value="${esc(p.price)}"></label><label>قبل الخصم<input id="pc" type="number" inputmode="numeric" min="0" value="${esc(p.comparePrice || '')}" placeholder="—"></label><label>المخزون<input id="pk" type="number" inputmode="numeric" min="0" value="${p.stock ?? ''}" placeholder="بلا حد"></label></div>
  <div class="f3"><label>النوع<select id="pt">${Object.entries(TY).map(([k, l]) => `<option value="${k}" ${p.type === k ? 'selected' : ''}>${l}</option>`).join('')}</select></label><label>لون الخلفية<input id="pb" type="color" value="${esc(p.bg)}"></label><label>لون القطعة<input id="pf" type="color" value="${esc(p.fg)}"></label></div>
  <div class="f2"><label>المقاسات (افصل بفاصلة)<input id="pz" dir="ltr" value="${esc(p.sizes.join(', '))}" placeholder="بدون مقاسات"></label><label>الحالة<select id="ps">${Object.entries(PS).map(([k, l]) => `<option value="${k}" ${p.status === k ? 'selected' : ''}>${l}</option>`).join('')}</select></label></div>
  <label>الوصف<textarea id="pdsc" rows="3" maxlength="1200">${esc(p.description)}</textarea></label>
  <label>المواصفات (سطر لكل مواصفة: العنوان: القيمة)<textarea id="psp" rows="3">${esc(p.specs.map((s) => `${s.label}: ${s.value}`).join('\n'))}</textarea></label>
  <small class="fe" id="pe"></small>
  <button class="bt p" type="button" data-psave="${n ? '' : p.id}">حفظ المنتج</button>${n ? '' : `<button class="bt d" type="button" data-pdel="${p.id}">حذف</button>`}<button class="bt" type="button" data-x>إلغاء</button>`);
}
async function saveProduct(b, id) {
  const old = id ? prods.find((x) => x.id === +id) : null;
  const body = {
    name: $('#pn').value.trim(), price: +$('#pp').value, comparePrice: +$('#pc').value || 0, stock: $('#pk').value === '' ? null : +$('#pk').value,
    type: $('#pt').value, bg: $('#pb').value, fg: $('#pf').value, status: $('#ps').value, description: $('#pdsc').value.trim(),
    sizes: $('#pz').value.split(/[,،]/).map((s) => s.trim().toUpperCase()).filter(Boolean),
    specs: $('#psp').value.split('\n').map((l) => { const i = l.indexOf(':'); return i > 0 ? { label: l.slice(0, i).trim(), value: l.slice(i + 1).trim() } : null; }).filter(Boolean),
    tags: old?.tags || [], ...(old ? { art: old.art } : {}),
  };
  if (!body.name || !(body.price > 0)) { $('#pe').textContent = 'أدخل اسم المنتج وسعرًا أكبر من صفر.'; return; }
  b.disabled = true;
  const r = id ? await send(`/products/${id}`, 'PUT', body) : await send('/products', 'POST', body);
  upsert(r.product); closeSheet(); toast('تم حفظ المنتج'); tab(at, 1);
}

// =================== استوديو الذكاء الاصطناعي ===================
let genBusy = false, lastGen = [];
async function vStudio(v) {
  if (!prods.length) prods = (await api('/products')).products;
  const drafts = prods.filter((p) => p.status === 'draft' && p.ai);
  v.innerHTML = `<div class="studio"><h2>صمّم تشكيلة كاملة بجملة وحدة</h2><p>اكتب الفكرة، والذكاء الاصطناعي يصمّم الرسمة، ويختار الألوان، ويكتب الاسم والوصف، ويحدد السعر. بعدها تراجع وتنشر بضغطة.</p>
  ${info.ai ? '' : '<div class="note">مفتاح الذكاء الاصطناعي غير مضبوط. أضف ANTHROPIC_API_KEY في ملف .env وأعد تشغيل الخادم.</div>'}
  <textarea id="br" rows="4" maxlength="1500" placeholder="مثال: تشكيلة هوديات مستوحاة من ليل الرياض، فيها نجوم وخطوط مائلة حمراء، للشباب اللي يحبون الجيمنج">${esc(sessionStorage.getItem('rox_brief') || '')}</textarea>
  <div class="ideas">${IDEAS.map((i) => `<button type="button" data-idea="${esc(i)}">${esc(i)}</button>`).join('')}</div>
  <div class="srow"><label>نوع القطع<select id="gt"><option value="any">الذكاء الاصطناعي يختار</option>${Object.entries(TY).map(([k, l]) => `<option value="${k}">${l}</option>`).join('')}</select></label><label>العدد<input id="gc" type="number" min="1" max="6" value="3"></label></div>
  <label class="ck"><input type="checkbox" id="gp"> انشر مباشرة في المتجر (بدون مراجعة)</label>
  <button class="gen${genBusy ? ' busy' : ''}" id="gen" type="button" ${genBusy || !info.ai ? 'disabled' : ''}>${genBusy ? 'جاري التصميم…' : '✦ صمّم المنتجات'}</button>
  <div class="prog" id="gprog" aria-live="polite"></div></div>
  ${lastGen.length ? `<div class="hh">آخر تصميم</div><div class="pg">${lastGen.map((id) => prods.find((p) => p.id === id)).filter(Boolean).map(pcard).join('')}</div>` : ''}
  <div class="hh">مسودات الذكاء الاصطناعي (${drafts.length})${drafts.length ? '<button type="button" class="sp bt p" data-puball="1" style="margin:0">نشر الكل</button>' : ''}</div>
  ${drafts.length ? `<div class="pg">${drafts.map(pcard).join('')}</div>` : '<p class="em">ما فيه مسودات. صمّم شي جديد!</p>'}`;
}
const STEPS = ['يقرأ الفكرة…', 'يرسم الأفكار الأولية…', 'يختار الألوان والخامات…', 'يضبط الرسمة على القطعة…', 'يكتب الأسماء والأوصاف…', 'يحسب الأسعار…', 'اللمسات الأخيرة…'];
async function generate() {
  const brief = $('#br').value.trim();
  if (brief.length < 6) { $('#gprog').textContent = 'اكتب فكرة أوضح (6 أحرف على الأقل)'; return; }
  sessionStorage.setItem('rox_brief', brief);
  genBusy = true; const b = $('#gen'); b.disabled = true; b.classList.add('busy'); b.textContent = 'جاري التصميم…';
  let k = 0; const pr = $('#gprog'); pr.textContent = STEPS[0];
  const timer = setInterval(() => { k = Math.min(k + 1, STEPS.length - 1); const el = $('#gprog'); if (el) el.textContent = STEPS[k]; }, 7000);
  try {
    const r = await send('/ai/generate', 'POST', { brief, type: $('#gt').value, count: Math.min(6, Math.max(1, +$('#gc').value || 3)), publish: $('#gp').checked });
    r.products.forEach(upsert); lastGen = r.products.map((p) => p.id);
    toast(`تم تصميم ${r.products.length} منتج ✦`);
  } catch (x) { toast(x.message); genBusy = false; clearInterval(timer); if (at === 3) { await tab(3, 1); $('#gprog').textContent = x.message; } return; }
  genBusy = false; clearInterval(timer);
  if (at === 3) tab(3, 1);
}

// =================== الإعدادات ===================
const UI0 = { th: 'auto', ac: '#e1281c' };
let UI = { ...UI0 };
try { Object.assign(UI, JSON.parse(localStorage.getItem('rox_admin_ui') || '{}')); } catch { /* */ }
function lum(h) { const c = [1, 3, 5].map((i) => { const v = parseInt(h.substr(i, 2), 16) / 255; return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; }
function cr(a, b) { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
function mix(h, t, p) { let o = '#'; [1, 3, 5].forEach((i) => { const a = parseInt(h.substr(i, 2), 16), b = parseInt(t.substr(i, 2), 16); o += ('0' + Math.round(a + (b - a) * p).toString(16)).slice(-2); }); return o; }
function applyUI() {
  const r = document.documentElement;
  if (UI.th === 'auto') r.removeAttribute('data-theme'); else r.dataset.theme = UI.th;
  const dk = UI.th === 'dark' || (UI.th === 'auto' && matchMedia('(prefers-color-scheme: dark)').matches);
  let a = UI.ac, k = 0; while (cr(a, '#000000') < 4.5 && k++ < 14) a = mix(UI.ac, '#ffffff', k * 0.06);
  let t = a, j = 0; const bg = dk ? '#0b0a09' : '#efeae2'; while (cr(t, bg) < 4.5 && j++ < 14) t = mix(a, dk ? '#ffffff' : '#000000', j * 0.06);
  r.style.setProperty('--red', a); r.style.setProperty('--rt', t);
}
applyUI(); matchMedia('(prefers-color-scheme: dark)').addEventListener('change', applyUI);
const AC = ['#e1281c', '#ff7a1a', '#f2b705', '#2ec27e', '#18b8c9', '#3b82f6', '#8b5cf6', '#ec4899'];

async function vSettings(v) {
  cfg = (await api('/settings')).settings;
  const c = cfg;
  const sg = (id, on, a, b) => `<div class="sg" data-sg="${id}"><button type="button" data-val="0" class="${on ? '' : 'on'}">${a}</button><button type="button" data-val="1" class="${on ? 'on' : ''}">${b}</button></div>`;
  v.innerHTML = `${c.maintenance ? '<div class="note">وضع الصيانة مفعّل. المتجر مغلق للزوار.</div>' : ''}
  <div class="hh">وضع الصيانة</div>
  <div class="or"><div>حالة المتجر<small>لما تفعّله ما أحد يقدر يطلب من المتجر</small></div>${sg('maintenance', c.maintenance, 'مفتوح', 'تحت الصيانة')}</div>
  <div class="fg" style="margin-top:12px"><label>رسالة الصيانة<textarea id="s_mm" rows="2">${esc(c.maintenanceMsg)}</textarea></label><label>موعد الرجوع (اختياري)<input id="s_mu" type="datetime-local" value="${esc(c.maintenanceUntil)}"></label></div>
  <div class="hh">المتجر</div>
  <div class="fg"><label>اسم المتجر<input id="s_name" value="${esc(c.storeName)}" maxlength="40"></label><label>الشعار النصي<input id="s_tag" value="${esc(c.tagline)}" maxlength="140"></label>
  <label>موعد الإصدار الجاي (توقيت السعودية)<input id="s_drop" type="datetime-local" value="${esc(c.dropDate)}"></label><label>المدن (افصل بفاصلة)<input id="s_city" value="${esc(c.cities.join('، '))}"></label></div>
  <div class="hh">الشحن والدفع</div>
  <div class="fg"><label>رسوم الشحن (ر.س)<input id="s_ship" type="number" min="0" value="${c.shippingFee}"></label><label>شحن مجاني فوق (ر.س، 0 = بدون)<input id="s_free" type="number" min="0" value="${c.freeShippingOver}"></label></div>
  <label class="ck"><input type="checkbox" id="s_cod" ${c.payments.cod ? 'checked' : ''}> الدفع عند الاستلام</label>
  <label class="ck"><input type="checkbox" id="s_bank" ${c.payments.bank ? 'checked' : ''}> تحويل بنكي</label>
  <label>بيانات التحويل البنكي (تنرسل للعميل)<textarea id="s_bi" rows="3" placeholder="اسم البنك، اسم المستفيد، رقم الآيبان">${esc(c.bankInfo)}</textarea></label>
  <div class="hh">التنبيهات والإيميل</div>
  <div class="fg"><label>إيميل استلام تنبيهات الطلبات<input id="s_ne" type="email" dir="ltr" value="${esc(c.notifyEmail)}"></label><label>واتساب المتجر (مع رمز الدولة)<input id="s_wa" dir="ltr" inputmode="numeric" placeholder="9665XXXXXXXX" value="${esc(c.whatsapp)}"></label></div>
  <div class="or"><div>حالة SMTP<small>${info.mail ? 'مضبوط — الإيميلات تنرسل للعملاء' : 'غير مضبوط — أضف SMTP_HOST وبقية الإعدادات في .env'}</small></div><button class="bt" type="button" id="mtest" style="margin:0" ${info.mail ? '' : 'disabled'}>أرسل إيميل تجريبي</button></div>
  <div class="hh">روابط الحسابات</div>
  <div class="fg">${SOC.map(([k, n]) => `<label>${n}<input class="ssc" data-k="${k}" dir="ltr" inputmode="url" placeholder="https://" value="${esc(c.socials[k] || '')}"></label>`).join('')}</div>
  <small class="fe" id="se"></small>
  <button class="bt p" type="button" id="ss">حفظ الإعدادات</button>
  <div class="hh">مظهر لوحة التحكم</div>
  <div class="or"><div>الثيم<small>على هذا الجهاز فقط</small></div><div class="sg" data-ui="th">${[['auto', 'تلقائي'], ['light', 'فاتح'], ['dark', 'داكن']].map(([k, l]) => `<button type="button" data-val="${k}" class="${UI.th === k ? 'on' : ''}">${l}</button>`).join('')}</div></div>
  <div class="or"><div>لون التمييز</div><div class="sw">${AC.map((a) => `<button type="button" data-ac="${a}" style="background:${a}" class="${UI.ac === a ? 'on' : ''}" aria-label="${a}"></button>`).join('')}<input type="color" id="cc" value="${esc(UI.ac)}" aria-label="لون مخصص"></div></div>`;
}
async function saveSettings(b, extra) {
  const g = (id) => $('#' + id);
  const body = extra || {
    maintenanceMsg: g('s_mm').value, maintenanceUntil: g('s_mu').value, storeName: g('s_name').value, tagline: g('s_tag').value,
    dropDate: g('s_drop').value, cities: g('s_city').value.split(/[,،]/).map((s) => s.trim()).filter(Boolean),
    shippingFee: +g('s_ship').value || 0, freeShippingOver: +g('s_free').value || 0, payments: { cod: g('s_cod').checked, bank: g('s_bank').checked },
    bankInfo: g('s_bi').value, notifyEmail: g('s_ne').value.trim(), whatsapp: g('s_wa').value,
    socials: Object.fromEntries([...document.querySelectorAll('.ssc')].map((i) => [i.dataset.k, i.value.trim()])),
  };
  if (b) b.disabled = true;
  try { cfg = (await send('/settings', 'PUT', body)).settings; toast('تم حفظ الإعدادات'); tab(4, 1); }
  catch (x) { const e = $('#se'); if (e) e.textContent = x.message; toast(x.message); }
  finally { if (b) b.disabled = false; }
}

// =================== الأمان ===================
const ACT = { 'login.ok': 'تسجيل دخول', 'login.failed': 'محاولة دخول فاشلة', 'login.locked': 'قفل الحساب', 'admin.setup': 'إنشاء الأدمن', 'password.change': 'تغيير كلمة المرور', 'sessions.revoke': 'إنهاء كل الجلسات', 'order.status': 'تغيير حالة طلب', 'order.delete': 'حذف طلب', 'product.create': 'إضافة منتج', 'product.update': 'تعديل منتج', 'product.status': 'نشر/إخفاء منتج', 'product.delete': 'حذف منتج', 'product.photo': 'رفع صورة', 'ai.generate': 'تصميم بالذكاء الاصطناعي', 'settings.update': 'تعديل الإعدادات' };
async function vSecurity(v) {
  const L = await api('/logs');
  const C = [
    ['كلمات المرور مشفّرة', 'scrypt مع ملح عشوائي — ما تنحفظ كنص'], ['قفل تلقائي', 'بعد 5 محاولات دخول فاشلة لمدة 15 دقيقة'],
    ['جلسات آمنة', 'كوكي HttpOnly + SameSite=Strict، تنتهي بعد 12 ساعة'], ['حماية CSRF', 'رمز سري لكل جلسة + التحقق من مصدر الطلب'],
    ['حماية من حقن SQL', 'PostgreSQL مع استعلامات مُعاملة بالكامل'], ['حماية من XSS', 'سياسة CSP صارمة + تنظيف كل المدخلات'],
    ['تحديد معدل الطلبات', 'على الدخول والطلبات والتتبع والذكاء الاصطناعي'], ['الأسعار من الخادم', 'المتصفح ما يقدر يغيّر سعر أي منتج'],
    ['صور آمنة', 'الرسومات تنبني من قائمة بيضاء، والصور المرفوعة يُفحص محتواها'], ['فخ البوتات', 'حقل مخفي يكشف السبام في صفحة الطلب'],
  ];
  v.innerHTML = `<div class="chk">${C.map(([a, b]) => `<div><b>✓ ${a}</b>${b}</div>`).join('')}<div><b class="${location.protocol === 'https:' ? '' : 'no'}">${location.protocol === 'https:' ? '✓' : '!'} HTTPS</b>${location.protocol === 'https:' ? 'الاتصال مشفّر' : 'شغّل الموقع على HTTPS في الإنتاج (NODE_ENV=production)'}</div></div>
  <div class="hh">تغيير كلمة المرور</div>
  <div class="fg"><label>كلمة المرور الحالية<input id="pw0" type="password" autocomplete="current-password" dir="ltr"></label><label>كلمة المرور الجديدة (10+ حروف وأرقام)<input id="pw1" type="password" autocomplete="new-password" dir="ltr"></label></div>
  <small class="fe" id="pwe"></small><button class="bt p" type="button" id="pwb">تغيير كلمة المرور</button>
  <div class="hh">الجلسات النشطة (${L.sessions.length})<button type="button" class="sp bt d" id="lall" style="margin:0">إنهاء كل الجلسات</button></div>
  <div class="tw"><table class="tbl"><tr><th>IP</th><th>الجهاز</th><th>بدأت</th></tr>${L.sessions.map((s) => `<tr><td dir="ltr">${esc(s.ip)}</td><td dir="ltr">${esc((s.ua || '').slice(0, 60))}</td><td>${dt(s.created_at)}</td></tr>`).join('')}</table></div>
  <div class="hh">سجل النشاط</div>
  <div class="tw"><table class="tbl"><tr><th>الوقت</th><th>العملية</th><th>التفاصيل</th><th>IP</th></tr>${L.audit.map((a) => `<tr><td>${dt(a.at)}</td><td class="${/failed|locked/.test(a.action) ? 's0' : ''}">${ACT[a.action] || esc(a.action)}</td><td>${esc(a.detail || '')}</td><td dir="ltr">${esc(a.ip || '')}</td></tr>`).join('')}</table></div>
  <div class="hh">سجل الإيميلات</div>
  <div class="tw"><table class="tbl"><tr><th>الوقت</th><th>إلى</th><th>الموضوع</th><th>الحالة</th></tr>${L.emails.map((m) => `<tr><td>${dt(m.at)}</td><td dir="ltr">${esc(m.recipient)}</td><td>${esc(m.subject)}</td><td class="${m.status === 'sent' ? 's3' : m.status === 'failed' ? 's0' : 's4'}" title="${esc(m.error || '')}">${{ sent: 'انرسل', failed: 'فشل', skipped: 'متوقف (SMTP)' }[m.status] || esc(m.status)}</td></tr>`).join('') || '<tr><td colspan="4">ما فيه إيميلات بعد</td></tr>'}</table></div>`;
}

// ---------- كل الأزرار ----------
$('#v').addEventListener('click', async (e) => {
  const b = e.target.closest('button'); if (!b) return; const d = b.dataset;
  try {
    if (d.r) { rg = +d.r; $('#v').querySelector('.hero').outerHTML = hero(stats); $('#v').querySelectorAll('.hero .cu').forEach((x) => (RM ? (x.textContent = x.dataset.v) : countUp(x))); }
    else if (d.go) tab(+d.go);
    else if (d.f !== undefined) { flt = +d.f; tab(1, 1); }
    else if (d.od) { const o = findOrder(+d.od); if (o) orderSheet(o); }
    else if (d.next) { b.disabled = true; const o = findOrder(+d.next); const n = o.status >= 3 ? 0 : o.status + 1; await setStatus(o.id, n); tab(at, 1); }
    else if (d.e) productSheet(prods.find((p) => p.id === +d.e));
    else if (b.id === 'np') productSheet(null);
    else if (d.pub) { const p = prods.find((x) => x.id === +d.pub); const st = p.status === 'published' ? 'draft' : 'published'; await send(`/products/${p.id}/status`, 'PATCH', { status: st }); p.status = st; toast(st === 'published' ? 'نزل المنتج في المتجر ✓' : 'تم إخفاء المنتج'); tab(at, 1); }
    else if (d.puball) { const L = prods.filter((p) => p.status === 'draft' && p.ai); for (const p of L) { await send(`/products/${p.id}/status`, 'PATCH', { status: 'published' }); p.status = 'published'; } toast(`تم نشر ${L.length} منتج`); tab(at, 1); }
    else if (d.pd) confirmBtn(b, async () => { await send(`/products/${d.pd}`, 'DELETE'); prods = prods.filter((p) => p.id !== +d.pd); toast('تم حذف المنتج'); tab(at, 1); });
    else if (d.idea) { $('#br').value = d.idea; $('#br').focus(); }
    else if (b.id === 'gen') generate();
    else if (b.closest('[data-sg="maintenance"]')) saveSettings(null, { maintenance: d.val === '1', maintenanceMsg: $('#s_mm').value, maintenanceUntil: $('#s_mu').value });
    else if (b.id === 'ss') saveSettings(b);
    else if (b.id === 'mtest') { b.disabled = true; const r = await send('/mail/test', 'POST', {}); toast(r.ok ? 'انرسل الإيميل التجريبي ✓' : 'فشل الإرسال — راجع سجل الإيميلات'); b.disabled = false; }
    else if (b.closest('[data-ui]')) { UI.th = d.val; try { localStorage.setItem('rox_admin_ui', JSON.stringify(UI)); } catch { /* */ } applyUI(); tab(4, 1); }
    else if (d.ac) { UI.ac = d.ac; try { localStorage.setItem('rox_admin_ui', JSON.stringify(UI)); } catch { /* */ } applyUI(); tab(4, 1); }
    else if (b.id === 'pwb') { b.disabled = true; try { await send('/password', 'POST', { current: $('#pw0').value, next: $('#pw1').value }); toast('تم تغيير كلمة المرور. الأجهزة الثانية انطلعت.'); tab(5, 1); } catch (x) { $('#pwe').textContent = x.message; } b.disabled = false; }
    else if (b.id === 'lall') confirmBtn(b, async () => { await send('/logout-all', 'POST'); CSRF = ''; lock('تم إنهاء كل الجلسات'); });
  } catch (x) { toast(x.message); b.disabled = false; }
});
$('#v').addEventListener('input', (e) => { if (e.target.id === 'cc') { UI.ac = e.target.value; applyUI(); try { localStorage.setItem('rox_admin_ui', JSON.stringify(UI)); } catch { /* */ } } });

boot();
})();
