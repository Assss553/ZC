// ROX Store — تطبيق الخادم (يُشغَّل من server.js محليًا، أو من netlify/functions على Netlify)
import { SERVERLESS } from './env.js';
import { fileURLToPath } from 'node:url';
import express from 'express';
import helmet from 'helmet';
import { rateLimit, ipKeyGenerator } from 'express-rate-limit';
import { randomInt } from 'node:crypto';
import { ready, one, all, run, tx, getSettings, setSettings, audit, DEFAULT_SETTINGS } from './db.js';
import * as sec from './security.js';
import { str, int, InputError } from './security.js';
import { renderMockup, TYPES } from './svg.js';
import { generateProducts } from './ai.js';
import { createHash } from 'node:crypto';
import * as mail from './mail.js';
import { seed } from './seed.js';

const PROD = process.env.NODE_ENV === 'production';
const CLOTHING = ['hood', 'tee', 'crew'];
const DEFAULT_SIZES = ['S', 'M', 'L', 'XL', 'XXL'];

// تجهيز قاعدة البيانات مرة وحدة لكل تشغيل (بدون await في أعلى الملف عشان دوال Netlify)
export const state = { dbKind: null, setupToken: null };
export const init = (async () => {
  state.dbKind = await ready;
  await seed();
  state.setupToken = await setupToken();
})();

const app = express();
app.disable('x-powered-by');
app.use((req, res, next) => init.then(() => next(), next));
// على Netlify الطلبات توصل بمسار الدالة، نرجّعها لمسارها الأصلي
app.use((req, res, next) => { const p = '/.netlify/functions/api'; if (req.url.startsWith(p)) req.url = req.url.slice(p.length) || '/'; next(); });
app.set('trust proxy', process.env.TRUST_PROXY ? Number(process.env.TRUST_PROXY) : false);

// ---------- ترويسات الحماية ----------
app.use(helmet({
  contentSecurityPolicy: {
    useDefaults: false,
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
      fontSrc: ["'self'", 'https://fonts.gstatic.com'],
      imgSrc: ["'self'", 'data:'],
      connectSrc: ["'self'"],
      objectSrc: ["'none'"],
      baseUri: ["'none'"],
      formAction: ["'self'"],
      frameAncestors: ["'none'"],
      ...(PROD ? { upgradeInsecureRequests: [] } : {}),
    },
  },
  strictTransportSecurity: PROD ? { maxAge: 31536000, includeSubDomains: true } : false,
  crossOriginEmbedderPolicy: false,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
app.use((req, res, next) => { res.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()'); next(); });

// IP الزائر: على Netlify من ترويسة الحافة (ما يقدر الزائر يزوّرها)، وإلا من Express
const ip = (req) => (SERVERLESS && req.get('x-nf-client-connection-ip')) || req.ip || req.socket?.remoteAddress || 'unknown';
const limiter = (windowMin, limit, msg) => rateLimit({
  keyGenerator: (req) => ipKeyGenerator(ip(req)),
  windowMs: windowMin * 60 * 1000, limit, standardHeaders: 'draft-8', legacyHeaders: false,
  handler: (req, res) => res.status(429).json({ error: msg || 'طلبات كثيرة. انتظر شوي وحاول مرة ثانية.' }),
});
app.use('/api/', limiter(1, 120));
app.use('/api/', (req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });

const json = express.json({ limit: '100kb', strict: true });
const bigJson = express.json({ limit: '4mb', strict: true });
const ah = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);


// ---------- تحويل المنتج للعرض ----------
const parse = (s, d) => { try { return JSON.parse(s); } catch { return d; } };
function pub(p) {
  const v = p.updated_at;
  return {
    id: p.id, slug: p.slug, name: p.name, description: p.description, type: p.type, typeName: TYPES[p.type]?.ar || p.type,
    price: p.price, comparePrice: p.compare_price || null, bg: p.bg, fg: p.fg,
    sizes: parse(p.sizes, []), specs: parse(p.specs, []), tags: parse(p.tags, []),
    inStock: p.stock == null || p.stock > 0, lowStock: p.stock != null && p.stock > 0 && p.stock <= 5,
    image: `/img/${p.id}.svg?v=${v}`, photo: p.photo_type ? `/img/${p.id}/photo?v=${v}` : null,
  };
}
function adminProduct(p) {
  return { ...pub(p), status: p.status, stock: p.stock, ai: !!p.ai, prompt: p.prompt, art: parse(p.art_svg, []), createdAt: p.created_at, updatedAt: p.updated_at };
}
const PRODUCT_COLS = 'id, slug, name, description, type, price, compare_price, bg, fg, sizes, specs, tags, stock, status, ai, prompt, art_svg, photo_type, created_at, updated_at';

async function publicSettings() {
  const s = await getSettings();
  return {
    storeName: s.storeName, tagline: s.tagline, maintenance: !!s.maintenance, maintenanceMsg: s.maintenanceMsg,
    maintenanceUntil: s.maintenanceUntil, dropDate: s.dropDate, shippingFee: s.shippingFee, freeShippingOver: s.freeShippingOver,
    socials: s.socials, payments: s.payments, cities: s.cities, whatsapp: s.whatsapp,
  };
}

// =====================================================================
//                              واجهة المتجر
// =====================================================================
app.get('/healthz', ah(async (req, res) => { await one('SELECT 1 AS ok'); res.json({ ok: true, db: state.dbKind }); }));

app.get('/api/store', ah(async (req, res) => {
  const settings = await publicSettings();
  const products = settings.maintenance ? [] : (await all(`SELECT ${PRODUCT_COLS} FROM products WHERE status = 'published' ORDER BY created_at DESC`)).map(pub);
  res.json({ settings, products, types: TYPES });
}));

// صورة المنتج (SVG مبني من قائمة بيضاء + سياسة تمنع أي محتوى نشط)
function imageHeaders(res, type) {
  res.set({ 'Content-Type': type, 'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; sandbox", 'X-Content-Type-Options': 'nosniff', 'Cache-Control': 'public, max-age=86400' });
}
async function visibleProduct(req, id) {
  const p = await one('SELECT * FROM products WHERE id = ?', id);
  if (!p) return null;
  if (p.status === 'published') return p;
  return (await sec.sessionFrom(req)) ? p : null; // المسودات تظهر للأدمن فقط
}
app.get('/img/:id.svg', ah(async (req, res) => {
  const p = await visibleProduct(req, int(req.params.id, 1, 2e9, 0) || 0);
  if (!p) return res.status(404).end();
  imageHeaders(res, 'image/svg+xml; charset=utf-8');
  if (p.status !== 'published') res.set('Cache-Control', 'private, no-store');
  res.send(renderMockup(p));
}));
app.get('/img/:id/photo', ah(async (req, res) => {
  const p = await visibleProduct(req, int(req.params.id, 1, 2e9, 0) || 0);
  if (!p || !p.photo) return res.status(404).end();
  imageHeaders(res, p.photo_type);
  if (p.status !== 'published') res.set('Cache-Control', 'private, no-store');
  res.send(Buffer.from(p.photo));
}));

// ---------- إنشاء طلب ----------
const ALPH = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const newCode = () => 'ROX-' + Array.from({ length: 6 }, () => ALPH[randomInt(ALPH.length)]).join('');

app.post('/api/orders', limiter(10, 6, 'طلبات كثيرة من نفس الجهاز. حاول بعد شوي.'), json, ah(async (req, res) => {
  const s = await getSettings();
  if (s.maintenance) return res.status(503).json({ error: 'المتجر تحت الصيانة حاليًا' });
  const b = req.body || {};
  if (b.website) return res.status(400).json({ error: 'طلب غير صالح' }); // فخ للبوتات
  const c = {
    name: str(b.name, 80, { required: true }), email: sec.email(b.email), phone: sec.phone(b.phone),
    city: str(b.city, 60, { required: true }), address: str(b.address, 300, { required: true, multiline: true }),
    notes: str(b.notes, 500, { multiline: true }),
    payment: ['cod', 'bank'].includes(b.payment) && s.payments?.[b.payment] ? b.payment : null,
  };
  if (!c.payment) throw new InputError('اختر طريقة دفع متاحة');
  if (!Array.isArray(b.items) || !b.items.length || b.items.length > 20) throw new InputError('السلة فاضية أو كبيرة جدًا');

  const order = await tx(async (t) => {
    let subtotal = 0;
    const lines = [];
    for (const it of b.items) {
      const p = await t.one('SELECT * FROM products WHERE id = ? AND status = ? FOR UPDATE', int(it.id, 1, 2e9), 'published');
      if (!p) throw new InputError('منتج في السلة لم يعد متوفرًا. حدّث الصفحة.');
      const qty = int(it.qty, 1, 10);
      const sizes = parse(p.sizes, []);
      const size = sizes.length ? str(it.size, 8) : '';
      if (sizes.length && !sizes.includes(size)) throw new InputError(`اختر مقاس صحيح لـ ${p.name}`);
      if (p.stock != null) {
        const u = await t.run('UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?', qty, p.id, qty);
        if (!u.changes) throw new InputError(`الكمية المتوفرة من ${p.name}: ${p.stock}`);
      }
      subtotal += p.price * qty; // السعر من قاعدة البيانات، مو من المتصفح
      lines.push({ product_id: p.id, name: p.name, size, qty, unit_price: p.price });
    }
    const shipping = s.freeShippingOver && subtotal >= s.freeShippingOver ? 0 : Number(s.shippingFee) || 0;
    const now = Date.now();
    let code; do { code = newCode(); } while (await t.one('SELECT 1 FROM orders WHERE code = ?', code));
    const r = await t.run(`INSERT INTO orders(code, customer_name, email, phone, city, address, notes, payment, status, subtotal, shipping, total, ip, created_at, updated_at)
      VALUES (?,?,?,?,?,?,?,?,0,?,?,?,?,?,?) RETURNING id`, code, c.name, c.email, c.phone, c.city, c.address, c.notes, c.payment, subtotal, shipping, subtotal + shipping, ip(req), now, now);
    for (const l of lines) await t.run('INSERT INTO order_items(order_id, product_id, name, size, qty, unit_price) VALUES (?,?,?,?,?,?)', r.id, l.product_id, l.name, l.size, l.qty, l.unit_price);
    return { id: r.id, code, customer_name: c.name, email: c.email, phone: c.phone, city: c.city, address: c.address, payment: c.payment, subtotal, shipping, total: subtotal + shipping, status: 0, items: lines };
  });

  // ننتظر الإيميلات قبل الرد (في serverless الدالة تتوقف بعد الرد مباشرة)
  await Promise.allSettled([mail.sendOrderConfirmation(order), mail.notifyOwner(order)]);
  res.status(201).json({ code: order.code, total: order.total, shipping: order.shipping, payment: order.payment, bankInfo: order.payment === 'bank' ? s.bankInfo : '' });
}));

// ---------- تتبّع الطلب (يحتاج رقم الطلب + الإيميل) ----------
app.post('/api/track', limiter(10, 20), json, ah(async (req, res) => {
  const code = str(req.body?.code, 20).toUpperCase();
  const em = String(req.body?.email || '').trim().toLowerCase();
  const o = await one('SELECT * FROM orders WHERE code = ?', code);
  if (!o || o.email !== em) return res.status(404).json({ error: 'ما لقينا طلب بهذي البيانات' });
  const items = await all('SELECT name, size, qty, unit_price FROM order_items WHERE order_id = ? ORDER BY id', o.id);
  res.json({ code: o.code, status: o.status, statusName: mail.STATUS[o.status], total: o.total, shipping: o.shipping, createdAt: o.created_at, updatedAt: o.updated_at, items });
}));

// =====================================================================
//                              لوحة التحكم
// =====================================================================
const adminCount = async () => (await one('SELECT COUNT(*) AS n FROM admins')).n;
// رمز إعداد أول أدمن: من SETUP_TOKEN، أو رمز عشوائي ينحفظ في قاعدة البيانات (ثابت بين التشغيلات)
async function setupToken() {
  if (process.env.SETUP_TOKEN) return process.env.SETUP_TOKEN;
  await run('INSERT INTO settings(key, value) VALUES (?, ?) ON CONFLICT(key) DO NOTHING', '_setupToken', JSON.stringify(sec.randomToken(12)));
  return JSON.parse((await one('SELECT value FROM settings WHERE key = ?', '_setupToken')).value);
}


app.get('/api/admin/status', ah(async (req, res) => res.json({ needsSetup: (await adminCount()) === 0 })));

// إنشاء أول حساب أدمن (يتطلب رمز الإعداد اللي يظهر في سجل الخادم)
app.post('/api/admin/setup', limiter(15, 5), json, ah(async (req, res) => {
  if ((await adminCount()) > 0) return res.status(403).json({ error: 'تم إنشاء الأدمن مسبقًا' });
  if (!sec.sameOrigin(req)) return res.status(403).json({ error: 'طلب مرفوض' });
  if (String(req.body?.setupToken || '') !== state.setupToken) return res.status(403).json({ error: 'رمز الإعداد غلط. تلقاه في سجل الخادم.' });
  const em = sec.email(req.body?.email);
  const prob = sec.passwordProblem(req.body?.password);
  if (prob) throw new InputError(prob);
  await run('INSERT INTO admins(email, pass_hash, created_at) VALUES (?,?,?) ON CONFLICT (email) DO NOTHING', em, await sec.hashPassword(req.body.password), Date.now());
  await audit(null, 'admin.setup', em, ip(req));
  res.json({ ok: true });
}));

app.post('/api/admin/login', limiter(15, 10, 'محاولات دخول كثيرة. انتظر 15 دقيقة.'), json, ah(async (req, res) => {
  if (!sec.sameOrigin(req)) return res.status(403).json({ error: 'طلب مرفوض' });
  const r = await sec.login(req.body?.email, req.body?.password, ip(req), req.get('user-agent'));
  if (r.error) return res.status(401).json({ error: r.error });
  res.cookie(sec.SESSION_COOKIE, r.token, sec.cookieOptions());
  res.json({ csrf: r.csrf, admin: r.admin });
}));

const admin = express.Router();
admin.use(sec.requireAdmin);
app.use('/api/admin', admin);

admin.get('/me', (req, res) => res.json({ admin: { id: req.admin.id, email: req.admin.email }, csrf: req.admin.csrf, mail: mail.mailReady(), ai: !!(process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN) }));

admin.post('/logout', ah(async (req, res) => {
  await sec.logout(req.admin.token);
  res.clearCookie(sec.SESSION_COOKIE, { ...sec.cookieOptions(), maxAge: undefined });
  res.json({ ok: true });
}));

admin.post('/password', json, ah(async (req, res) => {
  const a = await one('SELECT * FROM admins WHERE id = ?', req.admin.id);
  if (!(await sec.verifyPassword(String(req.body?.current || ''), a.pass_hash))) return res.status(400).json({ error: 'كلمة المرور الحالية غلط' });
  const prob = sec.passwordProblem(req.body?.next);
  if (prob) throw new InputError(prob);
  await run('UPDATE admins SET pass_hash = ? WHERE id = ?', await sec.hashPassword(req.body.next), a.id);
  await run('DELETE FROM sessions WHERE admin_id = ? AND csrf != ?', a.id, req.admin.csrf); // يطلع كل الأجهزة الثانية
  await audit(a.id, 'password.change', null, ip(req));
  res.json({ ok: true });
}));

// ---------- الإحصائيات ----------
admin.get('/stats', ah(async (req, res) => {
  const days = int(req.query.days, 1, 365, 30);
  const DAY = 864e5, now = Date.now();
  const from = now - days * DAY, prevFrom = now - 2 * days * DAY;
  const rows = await all('SELECT total, created_at FROM orders WHERE status != 4 AND created_at >= ?', prevFrom);
  const series = Array(days).fill(0);
  let sum = 0, prev = 0, n = 0;
  for (const r of rows) {
    if (r.created_at >= from) { series[Math.floor((now - r.created_at) / DAY)] += r.total; sum += r.total; n++; }
    else prev += r.total;
  }
  const byStatus = [0, 0, 0, 0, 0];
  for (const r of await all('SELECT status, COUNT(*) AS n FROM orders GROUP BY status')) byStatus[r.status] = r.n;
  const top = await all(`SELECT oi.name, SUM(oi.qty) AS qty, SUM(oi.qty * oi.unit_price) AS revenue FROM order_items oi
    JOIN orders o ON o.id = oi.order_id WHERE o.status != 4 GROUP BY oi.name ORDER BY revenue DESC LIMIT 5`);
  const pending = await withItems(await all('SELECT * FROM orders WHERE status = 0 ORDER BY created_at DESC LIMIT 4'));
  res.json({
    days, series, sum, prev, orders: n, avg: n ? Math.round(sum / n) : 0, byStatus, top, pending,
    customers: (await one('SELECT COUNT(DISTINCT email) AS n FROM orders')).n,
    products: (await one("SELECT COUNT(*) AS n FROM products WHERE status = 'published'")).n,
    drafts: (await one("SELECT COUNT(*) AS n FROM products WHERE status = 'draft'")).n,
  });
}));

// ---------- الطلبات ----------
// يجيب منتجات كل الطلبات باستعلام واحد
async function withItems(orders) {
  if (!orders.length) return [];
  const items = await all(`SELECT order_id, name, size, qty, unit_price, product_id FROM order_items WHERE order_id = ANY(?::int[]) ORDER BY id`, orders.map((o) => o.id));
  return orders.map((o) => ({ ...o, ip: undefined, items: items.filter((i) => i.order_id === o.id) }));
}
const orderOut = async (o) => (await withItems([o]))[0];
admin.get('/orders', ah(async (req, res) => {
  const st = req.query.status === undefined || req.query.status === '' ? null : int(req.query.status, 0, 4);
  const q = str(req.query.q, 80);
  const where = [], params = [];
  if (st !== null) { where.push('status = ?'); params.push(st); }
  if (q) {
    const like = `%${q.replace(/[%_\\]/g, (m) => '\\' + m)}%`;
    where.push('(code ILIKE ? OR customer_name ILIKE ? OR phone ILIKE ? OR email ILIKE ?)'); params.push(like, like, like, like);
  }
  const rows = await all(`SELECT * FROM orders ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY created_at DESC LIMIT 300`, ...params);
  const counts = [0, 0, 0, 0, 0];
  for (const r of await all('SELECT status, COUNT(*) AS n FROM orders GROUP BY status')) counts[r.status] = r.n;
  res.json({ orders: await withItems(rows), counts });
}));

admin.patch('/orders/:id', json, ah(async (req, res) => {
  const o = await one('SELECT * FROM orders WHERE id = ?', int(req.params.id, 1, 2e9));
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  const status = int(req.body?.status, 0, 4);
  const changed = status !== o.status;
  await tx(async (t) => {
    await t.run('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?', status, Date.now(), o.id);
    // عند الإلغاء نرجّع الكمية للمخزون، وعند التراجع عن الإلغاء نخصمها
    if (changed && (status === 4 || o.status === 4)) {
      const sign = status === 4 ? 1 : -1;
      for (const it of await t.all('SELECT product_id, qty FROM order_items WHERE order_id = ?', o.id))
        if (it.product_id) await t.run('UPDATE products SET stock = GREATEST(0, stock + ?) WHERE id = ? AND stock IS NOT NULL', sign * it.qty, it.product_id);
    }
  });
  await audit(req.admin.id, 'order.status', `${o.code} → ${status}`, ip(req));
  let emailed = false;
  if (changed && req.body?.notify !== false) emailed = await mail.sendStatusUpdate({ ...o, status });
  res.json({ ok: true, emailed, order: await orderOut(await one('SELECT * FROM orders WHERE id = ?', o.id)) });
}));

admin.delete('/orders/:id', ah(async (req, res) => {
  const o = await one('SELECT id, code FROM orders WHERE id = ?', int(req.params.id, 1, 2e9));
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  await run('DELETE FROM orders WHERE id = ?', o.id);
  await audit(req.admin.id, 'order.delete', o.code, ip(req));
  res.json({ ok: true });
}));

admin.post('/orders/:id/resend', ah(async (req, res) => {
  const o = await one('SELECT * FROM orders WHERE id = ?', int(req.params.id, 1, 2e9));
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  const ok = await mail.sendOrderConfirmation(await orderOut(o));
  res.json({ ok });
}));

// ---------- المنتجات ----------
function readProduct(b, old = {}) {
  const type = TYPES[b.type] ? b.type : old.type || 'tee';
  let sizes = Array.isArray(b.sizes) ? b.sizes.map((x) => str(x, 8)).filter(Boolean).slice(0, 10) : parse(old.sizes, CLOTHING.includes(type) ? DEFAULT_SIZES : []);
  const specs = Array.isArray(b.specs) ? b.specs.slice(0, 8).map((s) => ({ label: str(s?.label, 40), value: str(s?.value, 80) })).filter((s) => s.label && s.value) : parse(old.specs, []);
  const tags = Array.isArray(b.tags) ? b.tags.map((t) => str(t, 24)).filter(Boolean).slice(0, 8) : parse(old.tags, []);
  const price = int(b.price, 1, 100000);
  const cmp = int(b.comparePrice || 0, 0, 100000);
  return {
    name: str(b.name, 80, { required: true }), description: str(b.description, 1200, { multiline: true }), type, price,
    compare_price: cmp > price ? cmp : null, bg: sec.color(b.bg, old.bg || '#0b0a09'), fg: sec.color(b.fg, old.fg || '#efeae2'),
    sizes: JSON.stringify(sizes), specs: JSON.stringify(specs), tags: JSON.stringify(tags),
    stock: b.stock === null || b.stock === '' || b.stock === undefined ? null : int(b.stock, 0, 1e6),
    status: ['draft', 'published', 'archived'].includes(b.status) ? b.status : old.status || 'draft',
    art_svg: Array.isArray(b.art) ? JSON.stringify(b.art.slice(0, 60)) : old.art_svg ?? '[]',
  };
}
const slug = () => sec.randomToken(8).toLowerCase().replace(/[^a-z0-9]/g, 'x');
const getProduct = async (id) => adminProduct(await one(`SELECT ${PRODUCT_COLS} FROM products WHERE id = ?`, id));
async function insertProduct(p, extra = {}) {
  const now = Date.now();
  const r = await run(`INSERT INTO products(slug, name, description, type, price, compare_price, bg, fg, sizes, specs, tags, stock, status, art_svg, ai, prompt, created_at, updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) RETURNING id`, slug(), p.name, p.description, p.type, p.price, p.compare_price, p.bg, p.fg,
  p.sizes, p.specs, p.tags, p.stock, p.status, p.art_svg, extra.ai ? 1 : 0, extra.prompt ?? null, now, now);
  return r.id;
}
const pid = (req) => int(req.params.id, 1, 2e9);

admin.get('/products', ah(async (req, res) => {
  const rows = await all(`SELECT ${PRODUCT_COLS} FROM products ORDER BY CASE status WHEN 'draft' THEN 0 WHEN 'published' THEN 1 ELSE 2 END, created_at DESC`);
  res.json({ products: rows.map(adminProduct) });
}));
admin.post('/products', bigJson, ah(async (req, res) => {
  const p = readProduct(req.body || {});
  const id = await insertProduct(p);
  await audit(req.admin.id, 'product.create', p.name, ip(req));
  res.status(201).json({ product: await getProduct(id) });
}));
admin.put('/products/:id', bigJson, ah(async (req, res) => {
  const old = await one('SELECT * FROM products WHERE id = ?', pid(req));
  if (!old) return res.status(404).json({ error: 'المنتج غير موجود' });
  const p = readProduct(req.body || {}, old);
  await run(`UPDATE products SET name=?, description=?, type=?, price=?, compare_price=?, bg=?, fg=?, sizes=?, specs=?, tags=?, stock=?, status=?, art_svg=?, updated_at=? WHERE id=?`,
    p.name, p.description, p.type, p.price, p.compare_price, p.bg, p.fg, p.sizes, p.specs, p.tags, p.stock, p.status, p.art_svg, Date.now(), old.id);
  await audit(req.admin.id, 'product.update', `${old.id} ${p.name} [${p.status}]`, ip(req));
  res.json({ product: await getProduct(old.id) });
}));
admin.patch('/products/:id/status', json, ah(async (req, res) => {
  const st = ['draft', 'published', 'archived'].includes(req.body?.status) ? req.body.status : null;
  if (!st) throw new InputError('حالة غير صالحة');
  const r = await run('UPDATE products SET status = ?, updated_at = ? WHERE id = ?', st, Date.now(), pid(req));
  if (!r.changes) return res.status(404).json({ error: 'المنتج غير موجود' });
  await audit(req.admin.id, 'product.status', `${req.params.id} → ${st}`, ip(req));
  res.json({ ok: true });
}));
admin.delete('/products/:id', ah(async (req, res) => {
  const p = await one('SELECT id, name FROM products WHERE id = ?', pid(req));
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });
  await run('DELETE FROM products WHERE id = ?', p.id);
  await audit(req.admin.id, 'product.delete', p.name, ip(req));
  res.json({ ok: true });
}));

// رفع صورة حقيقية للمنتج (PNG/JPEG/WEBP فقط، يتم التحقق من محتوى الملف نفسه)
admin.post('/products/:id/photo', bigJson, ah(async (req, res) => {
  const id = pid(req);
  const m = /^data:(image\/(?:png|jpeg|webp));base64,([A-Za-z0-9+/=]+)$/.exec(String(req.body?.data || ''));
  if (!m) throw new InputError('صيغة الصورة غير مدعومة (PNG / JPG / WEBP)');
  const buf = Buffer.from(m[2], 'base64');
  if (buf.length > 2.5 * 1024 * 1024) throw new InputError('حجم الصورة أكبر من 2.5 ميجا');
  const sig = buf.subarray(0, 12);
  const real = sig[0] === 0x89 && sig.toString('latin1', 1, 4) === 'PNG' ? 'image/png'
    : sig[0] === 0xff && sig[1] === 0xd8 && sig[2] === 0xff ? 'image/jpeg'
      : sig.toString('latin1', 0, 4) === 'RIFF' && sig.toString('latin1', 8, 12) === 'WEBP' ? 'image/webp' : null;
  if (!real) throw new InputError('الملف ليس صورة حقيقية');
  const r = await run('UPDATE products SET photo = ?, photo_type = ?, updated_at = ? WHERE id = ?', buf, real, Date.now(), id);
  if (!r.changes) return res.status(404).json({ error: 'المنتج غير موجود' });
  await audit(req.admin.id, 'product.photo', String(id), ip(req));
  res.json({ product: await getProduct(id) });
}));
admin.delete('/products/:id/photo', ah(async (req, res) => {
  const id = pid(req);
  await run('UPDATE products SET photo = NULL, photo_type = NULL, updated_at = ? WHERE id = ?', Date.now(), id);
  res.json({ product: await getProduct(id) });
}));

// ---------- استوديو الذكاء الاصطناعي (مهام بالخلفية لأن التصميم ياخذ دقيقة أو أكثر) ----------
const sha = (x) => createHash('sha256').update(x).digest('hex');
export async function runJob(id, token) {
  await init;
  const job = (await run(`UPDATE ai_jobs SET status = 'running', updated_at = ? WHERE id = ? AND status = 'pending' AND token_hash = ? RETURNING *`,
    Date.now(), int(id, 1, 2e9), sha(String(token || '')))).rows[0];
  if (!job) return false;
  try {
    const { products } = await generateProducts({ brief: job.brief, type: job.type, count: job.count });
    const ids = [];
    for (const g of products) {
      try {
        const t = TYPES[g.type] ? g.type : job.type !== 'any' ? job.type : 'tee';
        const p = readProduct({
          name: g.name, description: g.description, type: t, price: Math.max(1, Math.round(g.price) || 99), comparePrice: Math.round(g.comparePrice) || 0,
          bg: g.background, fg: g.garment, tags: g.tags, specs: g.specs, art: g.artwork,
          sizes: CLOTHING.includes(t) ? DEFAULT_SIZES : [], status: job.publish ? 'published' : 'draft',
        });
        ids.push(await insertProduct(p, { ai: true, prompt: job.brief }));
      } catch (e) { console.warn('[ai] skipped product:', e.message); }
    }
    await run(`UPDATE ai_jobs SET status = 'done', result = ?, updated_at = ? WHERE id = ?`, JSON.stringify(ids), Date.now(), job.id);
    await audit(job.admin_id, 'ai.generate', `${ids.length} × "${job.brief.slice(0, 80)}"`, null);
  } catch (e) {
    const msg = /[\u0600-\u06FF]/.test(e.message) ? e.message : 'تعذّر التصميم. حاول مرة ثانية.';
    console.error('[ai] job failed:', e.message);
    await run(`UPDATE ai_jobs SET status = 'error', error = ?, updated_at = ? WHERE id = ?`, msg, Date.now(), job.id);
  }
  return true;
}

admin.post('/ai/generate', limiter(60, 30, 'وصلت الحد المسموح من التوليد هذي الساعة.'), json, ah(async (req, res) => {
  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) return res.status(503).json({ error: 'مفتاح الذكاء الاصطناعي غير مضبوط. أضف ANTHROPIC_API_KEY.' });
  const brief = str(req.body?.brief, 1500, { required: true, multiline: true });
  const type = TYPES[req.body?.type] ? req.body.type : 'any';
  const count = int(req.body?.count, 1, 6, 3);
  const token = sec.randomToken(24), now = Date.now();
  const job = await run(`INSERT INTO ai_jobs(admin_id, token_hash, brief, type, count, publish, status, created_at, updated_at)
    VALUES (?,?,?,?,?,?, 'pending', ?, ?) RETURNING id`, req.admin.id, sha(token), brief, type, count, req.body?.publish === true ? 1 : 0, now, now);
  if (SERVERLESS) {
    // دالة Netlify بالخلفية (تشتغل لين 15 دقيقة)
    const base = process.env.PUBLIC_URL || `https://${req.get('host')}`;
    const r = await fetch(new URL('/.netlify/functions/ai-background', base), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: job.id, token }) }).catch((e) => ({ ok: false, status: e.message }));
    if (!r.ok) console.error('[ai] background trigger failed:', r.status);
  } else {
    runJob(job.id, token).catch((e) => console.error('[ai]', e));
  }
  res.status(202).json({ job: job.id });
}));
admin.get('/ai/jobs/:id', ah(async (req, res) => {
  const j = await one('SELECT id, status, error, result, created_at FROM ai_jobs WHERE id = ? AND admin_id = ?', int(req.params.id, 1, 2e9), req.admin.id);
  if (!j) return res.status(404).json({ error: 'المهمة غير موجودة' });
  if (j.status === 'pending' && Date.now() - j.created_at > 20 * 60 * 1000) j.status = 'error', j.error = 'انتهت مهلة التصميم. حاول مرة ثانية.';
  const ids = j.status === 'done' ? JSON.parse(j.result || '[]') : [];
  const products = ids.length ? (await all(`SELECT ${PRODUCT_COLS} FROM products WHERE id = ANY(?::int[])`, ids)).map(adminProduct) : [];
  res.json({ status: j.status, error: j.error, products });
}));

// ---------- الإعدادات ----------
admin.get('/settings', ah(async (req, res) => res.json({ settings: await getSettings() })));
admin.put('/settings', json, ah(async (req, res) => {
  const b = req.body || {}, out = {};
  const S = DEFAULT_SETTINGS;
  if ('storeName' in b) out.storeName = str(b.storeName, 40, { required: true });
  if ('tagline' in b) out.tagline = str(b.tagline, 140);
  if ('maintenance' in b) out.maintenance = b.maintenance === true;
  if ('maintenanceMsg' in b) out.maintenanceMsg = str(b.maintenanceMsg, 300, { multiline: true });
  if ('maintenanceUntil' in b) out.maintenanceUntil = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(b.maintenanceUntil) ? b.maintenanceUntil : '';
  if ('dropDate' in b) out.dropDate = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(b.dropDate) ? b.dropDate : S.dropDate;
  if ('shippingFee' in b) out.shippingFee = int(b.shippingFee, 0, 1000);
  if ('freeShippingOver' in b) out.freeShippingOver = int(b.freeShippingOver, 0, 100000);
  if ('bankInfo' in b) out.bankInfo = str(b.bankInfo, 400, { multiline: true });
  if ('whatsapp' in b) out.whatsapp = String(b.whatsapp || '').replace(/\D/g, '').slice(0, 15);
  if ('notifyEmail' in b) out.notifyEmail = b.notifyEmail ? sec.email(b.notifyEmail) : '';
  if ('socials' in b) out.socials = Object.fromEntries(Object.keys(S.socials).map((k) => [k, sec.url(b.socials?.[k])]));
  if ('payments' in b) out.payments = { cod: b.payments?.cod !== false, bank: b.payments?.bank !== false };
  if ('cities' in b && Array.isArray(b.cities)) out.cities = b.cities.map((c) => str(c, 40)).filter(Boolean).slice(0, 60);
  await setSettings(out);
  await audit(req.admin.id, 'settings.update', Object.keys(out).join(','), ip(req));
  res.json({ settings: await getSettings() });
}));

admin.post('/mail/test', json, ah(async (req, res) => {
  if (!mail.mailReady()) return res.status(400).json({ error: 'SMTP غير مضبوط في ملف .env' });
  res.json({ ok: await mail.sendTest(sec.email(req.body?.to || req.admin.email)) });
}));
admin.get('/logs', ah(async (req, res) => res.json({
  audit: await all('SELECT l.*, a.email FROM audit_log l LEFT JOIN admins a ON a.id = l.admin_id ORDER BY l.id DESC LIMIT 100'),
  emails: await all('SELECT * FROM email_log ORDER BY id DESC LIMIT 100'),
  sessions: await all('SELECT ip, ua, created_at, expires_at FROM sessions WHERE admin_id = ? AND expires_at > ? ORDER BY created_at DESC', req.admin.id, Date.now()),
})));
admin.post('/logout-all', ah(async (req, res) => {
  await sec.logoutAll(req.admin.id);
  await audit(req.admin.id, 'sessions.revoke', null, ip(req));
  res.clearCookie(sec.SESSION_COOKIE, { ...sec.cookieOptions(), maxAge: undefined });
  res.json({ ok: true });
}));

// ---------- الملفات الثابتة ----------
app.use('/api', (req, res) => res.status(404).json({ error: 'غير موجود' }));
const PUBLIC = fileURLToPath(new URL('../public', import.meta.url));
app.use(express.static(PUBLIC, { extensions: ['html'], index: 'index.html', maxAge: PROD ? '1h' : 0 }));
app.use((req, res) => res.status(404).sendFile('index.html', { root: PUBLIC }));

// ---------- معالج الأخطاء (بدون كشف تفاصيل داخلية) ----------
app.use((err, req, res, next) => {
  if (err.type === 'entity.too.large') return res.status(413).json({ error: 'حجم البيانات كبير جدًا' });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'بيانات غير صالحة' });
  if (err instanceof InputError) return res.status(400).json({ error: err.message });
  if (err.status && err.status < 600 && err.expose !== false && /[؀-ۿ]/.test(err.message)) return res.status(err.status).json({ error: err.message });
  console.error(err);
  res.status(500).json({ error: 'صار خطأ في الخادم. حاول مرة ثانية.' });
});

export async function cleanup() {
  const now = Date.now(), old = now - 180 * 864e5;
  await run('DELETE FROM sessions WHERE expires_at < ?', now);
  await run('DELETE FROM audit_log WHERE at < ?', old);
  await run('DELETE FROM email_log WHERE at < ?', old);
  await run('DELETE FROM ai_jobs WHERE created_at < ?', now - 30 * 864e5);
}
export { adminCount };
export default app;
