// ROX Store — الخادم الرئيسي
import { existsSync } from 'node:fs';
if (existsSync('.env')) process.loadEnvFile('.env');

import express from 'express';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { randomInt } from 'node:crypto';
import { db, one, all, run, tx, getSettings, setSettings, audit, DEFAULT_SETTINGS } from './src/db.js';
import * as sec from './src/security.js';
import { str, int, InputError } from './src/security.js';
import { renderMockup, TYPES } from './src/svg.js';
import { generateProducts } from './src/ai.js';
import * as mail from './src/mail.js';
import { seed } from './src/seed.js';

const PROD = process.env.NODE_ENV === 'production';
const PORT = Number(process.env.PORT || 3000);
const CLOTHING = ['hood', 'tee', 'crew'];
const DEFAULT_SIZES = ['S', 'M', 'L', 'XL', 'XXL'];

seed();

const app = express();
app.disable('x-powered-by');
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

const limiter = (windowMin, limit, msg) => rateLimit({
  windowMs: windowMin * 60 * 1000, limit, standardHeaders: 'draft-8', legacyHeaders: false,
  handler: (req, res) => res.status(429).json({ error: msg || 'طلبات كثيرة. انتظر شوي وحاول مرة ثانية.' }),
});
app.use('/api/', limiter(1, 120));
app.use('/api/', (req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });

const json = express.json({ limit: '100kb', strict: true });
const bigJson = express.json({ limit: '4mb', strict: true });
const ah = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const ip = (req) => req.ip;

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

function publicSettings() {
  const s = getSettings();
  return {
    storeName: s.storeName, tagline: s.tagline, maintenance: !!s.maintenance, maintenanceMsg: s.maintenanceMsg,
    maintenanceUntil: s.maintenanceUntil, dropDate: s.dropDate, shippingFee: s.shippingFee, freeShippingOver: s.freeShippingOver,
    socials: s.socials, payments: s.payments, cities: s.cities, whatsapp: s.whatsapp,
  };
}

// =====================================================================
//                              واجهة المتجر
// =====================================================================
app.get('/api/store', (req, res) => {
  const products = all(`SELECT ${PRODUCT_COLS} FROM products WHERE status = 'published' ORDER BY created_at DESC`).map(pub);
  res.json({ settings: publicSettings(), products: getSettings().maintenance ? [] : products, types: TYPES });
});

// صورة المنتج (SVG مبني من قائمة بيضاء + سياسة تمنع أي محتوى نشط)
function imageHeaders(res, type) {
  res.set({ 'Content-Type': type, 'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; sandbox", 'X-Content-Type-Options': 'nosniff', 'Cache-Control': 'public, max-age=86400' });
}
function visibleProduct(req, id) {
  const p = one('SELECT * FROM products WHERE id = ?', id);
  if (!p) return null;
  if (p.status === 'published') return p;
  return sec.sessionFrom(req) ? p : null; // المسودات تظهر للأدمن فقط
}
app.get('/img/:id.svg', (req, res) => {
  const p = visibleProduct(req, Number(req.params.id) || 0);
  if (!p) return res.status(404).end();
  imageHeaders(res, 'image/svg+xml; charset=utf-8');
  if (p.status !== 'published') res.set('Cache-Control', 'private, no-store');
  res.send(renderMockup(p));
});
app.get('/img/:id/photo', (req, res) => {
  const p = visibleProduct(req, Number(req.params.id) || 0);
  if (!p || !p.photo) return res.status(404).end();
  imageHeaders(res, p.photo_type);
  if (p.status !== 'published') res.set('Cache-Control', 'private, no-store');
  res.send(Buffer.from(p.photo));
});

// ---------- إنشاء طلب ----------
const ALPH = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const newCode = () => 'ROX-' + Array.from({ length: 6 }, () => ALPH[randomInt(ALPH.length)]).join('');

app.post('/api/orders', limiter(10, 6, 'طلبات كثيرة من نفس الجهاز. حاول بعد شوي.'), json, ah(async (req, res) => {
  const s = getSettings();
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

  const order = tx(() => {
    let subtotal = 0;
    const lines = b.items.map((it) => {
      const p = one('SELECT * FROM products WHERE id = ? AND status = ?', int(it.id, 1, 1e9), 'published');
      if (!p) throw new InputError('منتج في السلة لم يعد متوفرًا. حدّث الصفحة.');
      const qty = int(it.qty, 1, 10);
      const sizes = parse(p.sizes, []);
      const size = sizes.length ? str(it.size, 8) : '';
      if (sizes.length && !sizes.includes(size)) throw new InputError(`اختر مقاس صحيح لـ ${p.name}`);
      if (p.stock != null) {
        if (p.stock < qty) throw new InputError(`الكمية المتوفرة من ${p.name}: ${p.stock}`);
        run('UPDATE products SET stock = stock - ? WHERE id = ?', qty, p.id);
      }
      subtotal += p.price * qty; // السعر من قاعدة البيانات، مو من المتصفح
      return { product_id: p.id, name: p.name, size, qty, unit_price: p.price };
    });
    const shipping = s.freeShippingOver && subtotal >= s.freeShippingOver ? 0 : Number(s.shippingFee) || 0;
    const now = Date.now();
    let code; do { code = newCode(); } while (one('SELECT 1 FROM orders WHERE code = ?', code));
    const r = run(`INSERT INTO orders(code, customer_name, email, phone, city, address, notes, payment, status, subtotal, shipping, total, ip, created_at, updated_at)
      VALUES (?,?,?,?,?,?,?,?,0,?,?,?,?,?,?)`, code, c.name, c.email, c.phone, c.city, c.address, c.notes, c.payment, subtotal, shipping, subtotal + shipping, ip(req), now, now);
    const ins = db.prepare('INSERT INTO order_items(order_id, product_id, name, size, qty, unit_price) VALUES (?,?,?,?,?,?)');
    for (const l of lines) ins.run(r.lastInsertRowid, l.product_id, l.name, l.size, l.qty, l.unit_price);
    return { id: Number(r.lastInsertRowid), code, customer_name: c.name, email: c.email, phone: c.phone, city: c.city, address: c.address, payment: c.payment, subtotal, shipping, total: subtotal + shipping, status: 0, items: lines };
  });

  // الإيميلات تنرسل بالخلفية عشان ما يتأخر العميل
  mail.sendOrderConfirmation(order).catch(() => {});
  mail.notifyOwner(order).catch(() => {});
  res.status(201).json({ code: order.code, total: order.total, shipping: order.shipping, payment: order.payment, bankInfo: order.payment === 'bank' ? s.bankInfo : '' });
}));

// ---------- تتبّع الطلب (يحتاج رقم الطلب + الإيميل) ----------
app.post('/api/track', limiter(10, 20), json, (req, res) => {
  const code = str(req.body?.code, 20).toUpperCase();
  const em = String(req.body?.email || '').trim().toLowerCase();
  const o = one('SELECT * FROM orders WHERE code = ?', code);
  if (!o || o.email !== em) return res.status(404).json({ error: 'ما لقينا طلب بهذي البيانات' });
  const items = all('SELECT name, size, qty, unit_price FROM order_items WHERE order_id = ?', o.id);
  res.json({ code: o.code, status: o.status, statusName: mail.STATUS[o.status], total: o.total, shipping: o.shipping, createdAt: o.created_at, updatedAt: o.updated_at, items });
});

// =====================================================================
//                              لوحة التحكم
// =====================================================================
const adminCount = () => one('SELECT COUNT(*) AS n FROM admins').n;
const SETUP_TOKEN = process.env.SETUP_TOKEN || sec.randomToken(12);

app.get('/api/admin/status', (req, res) => res.json({ needsSetup: adminCount() === 0 }));

// إنشاء أول حساب أدمن (يتطلب رمز الإعداد اللي يظهر في سجل الخادم)
app.post('/api/admin/setup', limiter(15, 5), json, ah(async (req, res) => {
  if (adminCount() > 0) return res.status(403).json({ error: 'تم إنشاء الأدمن مسبقًا' });
  if (!sec.sameOrigin(req)) return res.status(403).json({ error: 'طلب مرفوض' });
  if (String(req.body?.setupToken || '') !== SETUP_TOKEN) return res.status(403).json({ error: 'رمز الإعداد غلط. تلقاه في سجل الخادم.' });
  const em = sec.email(req.body?.email);
  const prob = sec.passwordProblem(req.body?.password);
  if (prob) throw new InputError(prob);
  run('INSERT INTO admins(email, pass_hash, created_at) VALUES (?,?,?)', em, await sec.hashPassword(req.body.password), Date.now());
  audit(null, 'admin.setup', em, ip(req));
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

admin.post('/logout', (req, res) => {
  sec.logout(req.admin.token);
  res.clearCookie(sec.SESSION_COOKIE, { ...sec.cookieOptions(), maxAge: undefined });
  res.json({ ok: true });
});

admin.post('/password', json, ah(async (req, res) => {
  const a = one('SELECT * FROM admins WHERE id = ?', req.admin.id);
  if (!(await sec.verifyPassword(String(req.body?.current || ''), a.pass_hash))) return res.status(400).json({ error: 'كلمة المرور الحالية غلط' });
  const prob = sec.passwordProblem(req.body?.next);
  if (prob) throw new InputError(prob);
  run('UPDATE admins SET pass_hash = ? WHERE id = ?', await sec.hashPassword(req.body.next), a.id);
  run('DELETE FROM sessions WHERE admin_id = ? AND csrf != ?', a.id, req.admin.csrf); // يطلع كل الأجهزة الثانية
  audit(a.id, 'password.change', null, ip(req));
  res.json({ ok: true });
}));

// ---------- الإحصائيات ----------
admin.get('/stats', (req, res) => {
  const days = int(req.query.days, 1, 365, 30);
  const DAY = 864e5, now = Date.now();
  const from = now - days * DAY, prevFrom = now - 2 * days * DAY;
  const rows = all('SELECT total, created_at FROM orders WHERE status != 4 AND created_at >= ?', prevFrom);
  const series = Array(days).fill(0);
  let sum = 0, prev = 0, n = 0;
  for (const r of rows) {
    if (r.created_at >= from) { series[Math.floor((now - r.created_at) / DAY)] += r.total; sum += r.total; n++; }
    else prev += r.total;
  }
  const byStatus = [0, 0, 0, 0, 0];
  for (const r of all('SELECT status, COUNT(*) AS n FROM orders GROUP BY status')) byStatus[r.status] = r.n;
  const top = all(`SELECT oi.name, SUM(oi.qty) AS qty, SUM(oi.qty * oi.unit_price) AS revenue FROM order_items oi
    JOIN orders o ON o.id = oi.order_id WHERE o.status != 4 GROUP BY oi.name ORDER BY revenue DESC LIMIT 5`);
  const pending = all('SELECT * FROM orders WHERE status = 0 ORDER BY created_at DESC LIMIT 4').map(orderOut);
  res.json({
    days, series, sum, prev, orders: n, avg: n ? Math.round(sum / n) : 0, byStatus, top, pending,
    customers: one('SELECT COUNT(DISTINCT email) AS n FROM orders').n,
    products: one("SELECT COUNT(*) AS n FROM products WHERE status = 'published'").n,
    drafts: one("SELECT COUNT(*) AS n FROM products WHERE status = 'draft'").n,
  });
});

// ---------- الطلبات ----------
function orderOut(o) {
  return { ...o, ip: undefined, items: all('SELECT name, size, qty, unit_price, product_id FROM order_items WHERE order_id = ?', o.id) };
}
admin.get('/orders', (req, res) => {
  const st = req.query.status === undefined || req.query.status === '' ? null : int(req.query.status, 0, 4);
  const q = str(req.query.q, 80);
  const like = `%${q.replace(/[%_\\]/g, (m) => '\\' + m)}%`;
  const rows = all(`SELECT * FROM orders WHERE (? IS NULL OR status = ?) AND (? = '' OR code LIKE ? ESCAPE '\\' OR customer_name LIKE ? ESCAPE '\\' OR phone LIKE ? ESCAPE '\\' OR email LIKE ? ESCAPE '\\')
    ORDER BY created_at DESC LIMIT 300`, st, st, q, like, like, like, like);
  const counts = [0, 0, 0, 0, 0];
  for (const r of all('SELECT status, COUNT(*) AS n FROM orders GROUP BY status')) counts[r.status] = r.n;
  res.json({ orders: rows.map(orderOut), counts });
});

admin.patch('/orders/:id', json, ah(async (req, res) => {
  const o = one('SELECT * FROM orders WHERE id = ?', int(req.params.id, 1, 1e9));
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  const status = int(req.body?.status, 0, 4);
  const changed = status !== o.status;
  tx(() => {
    run('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?', status, Date.now(), o.id);
    // عند الإلغاء نرجّع الكمية للمخزون، وعند التراجع عن الإلغاء نخصمها
    if (changed && (status === 4 || o.status === 4)) {
      const sign = status === 4 ? 1 : -1;
      for (const it of all('SELECT product_id, qty FROM order_items WHERE order_id = ?', o.id))
        if (it.product_id) run('UPDATE products SET stock = MAX(0, stock + ?) WHERE id = ? AND stock IS NOT NULL', sign * it.qty, it.product_id);
    }
  });
  audit(req.admin.id, 'order.status', `${o.code} → ${status}`, ip(req));
  let emailed = false;
  if (changed && req.body?.notify !== false) emailed = await mail.sendStatusUpdate({ ...o, status });
  res.json({ ok: true, emailed, order: orderOut(one('SELECT * FROM orders WHERE id = ?', o.id)) });
}));

admin.delete('/orders/:id', (req, res) => {
  const o = one('SELECT code FROM orders WHERE id = ?', int(req.params.id, 1, 1e9));
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  run('DELETE FROM orders WHERE id = ?', Number(req.params.id));
  audit(req.admin.id, 'order.delete', o.code, ip(req));
  res.json({ ok: true });
});

admin.post('/orders/:id/resend', ah(async (req, res) => {
  const o = one('SELECT * FROM orders WHERE id = ?', int(req.params.id, 1, 1e9));
  if (!o) return res.status(404).json({ error: 'الطلب غير موجود' });
  const ok = await mail.sendOrderConfirmation(orderOut(o));
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
const slug = () => sec.randomToken(6).toLowerCase().replace(/[^a-z0-9]/g, 'x');

admin.get('/products', (req, res) => {
  res.json({ products: all(`SELECT ${PRODUCT_COLS} FROM products ORDER BY CASE status WHEN 'draft' THEN 0 WHEN 'published' THEN 1 ELSE 2 END, created_at DESC`).map(adminProduct) });
});
admin.post('/products', bigJson, (req, res) => {
  const p = readProduct(req.body || {}), now = Date.now();
  const r = run(`INSERT INTO products(slug, name, description, type, price, compare_price, bg, fg, sizes, specs, tags, stock, status, art_svg, created_at, updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, slug(), p.name, p.description, p.type, p.price, p.compare_price, p.bg, p.fg, p.sizes, p.specs, p.tags, p.stock, p.status, p.art_svg, now, now);
  audit(req.admin.id, 'product.create', p.name, ip(req));
  res.status(201).json({ product: adminProduct(one(`SELECT ${PRODUCT_COLS} FROM products WHERE id = ?`, r.lastInsertRowid)) });
});
admin.put('/products/:id', bigJson, (req, res) => {
  const old = one('SELECT * FROM products WHERE id = ?', int(req.params.id, 1, 1e9));
  if (!old) return res.status(404).json({ error: 'المنتج غير موجود' });
  const p = readProduct(req.body || {}, old);
  run(`UPDATE products SET name=?, description=?, type=?, price=?, compare_price=?, bg=?, fg=?, sizes=?, specs=?, tags=?, stock=?, status=?, art_svg=?, updated_at=? WHERE id=?`,
    p.name, p.description, p.type, p.price, p.compare_price, p.bg, p.fg, p.sizes, p.specs, p.tags, p.stock, p.status, p.art_svg, Date.now(), old.id);
  audit(req.admin.id, 'product.update', `${old.id} ${p.name} [${p.status}]`, ip(req));
  res.json({ product: adminProduct(one(`SELECT ${PRODUCT_COLS} FROM products WHERE id = ?`, old.id)) });
});
admin.patch('/products/:id/status', json, (req, res) => {
  const st = ['draft', 'published', 'archived'].includes(req.body?.status) ? req.body.status : null;
  if (!st) throw new InputError('حالة غير صالحة');
  const r = run('UPDATE products SET status = ?, updated_at = ? WHERE id = ?', st, Date.now(), int(req.params.id, 1, 1e9));
  if (!r.changes) return res.status(404).json({ error: 'المنتج غير موجود' });
  audit(req.admin.id, 'product.status', `${req.params.id} → ${st}`, ip(req));
  res.json({ ok: true });
});
admin.delete('/products/:id', (req, res) => {
  const p = one('SELECT name FROM products WHERE id = ?', int(req.params.id, 1, 1e9));
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });
  run('DELETE FROM products WHERE id = ?', Number(req.params.id));
  audit(req.admin.id, 'product.delete', p.name, ip(req));
  res.json({ ok: true });
});

// رفع صورة حقيقية للمنتج (PNG/JPEG/WEBP فقط، يتم التحقق من محتوى الملف نفسه)
admin.post('/products/:id/photo', bigJson, (req, res) => {
  const id = int(req.params.id, 1, 1e9);
  const m = /^data:(image\/(?:png|jpeg|webp));base64,([A-Za-z0-9+/=]+)$/.exec(String(req.body?.data || ''));
  if (!m) throw new InputError('صيغة الصورة غير مدعومة (PNG / JPG / WEBP)');
  const buf = Buffer.from(m[2], 'base64');
  if (buf.length > 2.5 * 1024 * 1024) throw new InputError('حجم الصورة أكبر من 2.5 ميجا');
  const sig = buf.subarray(0, 12);
  const real = sig[0] === 0x89 && sig.toString('latin1', 1, 4) === 'PNG' ? 'image/png'
    : sig[0] === 0xff && sig[1] === 0xd8 && sig[2] === 0xff ? 'image/jpeg'
      : sig.toString('latin1', 0, 4) === 'RIFF' && sig.toString('latin1', 8, 12) === 'WEBP' ? 'image/webp' : null;
  if (!real) throw new InputError('الملف ليس صورة حقيقية');
  const r = run('UPDATE products SET photo = ?, photo_type = ?, updated_at = ? WHERE id = ?', buf, real, Date.now(), id);
  if (!r.changes) return res.status(404).json({ error: 'المنتج غير موجود' });
  audit(req.admin.id, 'product.photo', String(id), ip(req));
  res.json({ product: adminProduct(one(`SELECT ${PRODUCT_COLS} FROM products WHERE id = ?`, id)) });
});
admin.delete('/products/:id/photo', (req, res) => {
  run('UPDATE products SET photo = NULL, photo_type = NULL, updated_at = ? WHERE id = ?', Date.now(), int(req.params.id, 1, 1e9));
  res.json({ product: adminProduct(one(`SELECT ${PRODUCT_COLS} FROM products WHERE id = ?`, Number(req.params.id))) });
});

// ---------- استوديو الذكاء الاصطناعي ----------
admin.post('/ai/generate', limiter(60, 30, 'وصلت الحد المسموح من التوليد هذي الساعة.'), json, ah(async (req, res) => {
  const brief = str(req.body?.brief, 1500, { required: true, multiline: true });
  const type = TYPES[req.body?.type] ? req.body.type : 'any';
  const count = int(req.body?.count, 1, 6, 3);
  const publish = req.body?.publish === true;
  const { products } = await generateProducts({ brief, type, count });
  const now = Date.now();
  const created = [];
  for (const g of products) {
    try {
      const t = TYPES[g.type] ? g.type : type !== 'any' ? type : 'tee';
      const p = readProduct({
        name: g.name, description: g.description, type: t, price: Math.max(1, Math.round(g.price) || 99), comparePrice: Math.round(g.comparePrice) || 0,
        bg: g.background, fg: g.garment, tags: g.tags, specs: g.specs, art: g.artwork,
        sizes: CLOTHING.includes(t) ? DEFAULT_SIZES : [], status: publish ? 'published' : 'draft',
      });
      const r = run(`INSERT INTO products(slug, name, description, type, price, compare_price, bg, fg, sizes, specs, tags, stock, status, art_svg, ai, prompt, created_at, updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,?,?,?)`, slug(), p.name, p.description, p.type, p.price, p.compare_price, p.bg, p.fg, p.sizes, p.specs, p.tags, null, p.status, p.art_svg, brief, now, now);
      created.push(adminProduct(one(`SELECT ${PRODUCT_COLS} FROM products WHERE id = ?`, r.lastInsertRowid)));
    } catch (e) { console.warn('[ai] skipped product:', e.message); }
  }
  audit(req.admin.id, 'ai.generate', `${created.length} × "${brief.slice(0, 80)}"`, ip(req));
  res.json({ products: created });
}));

// ---------- الإعدادات ----------
admin.get('/settings', (req, res) => res.json({ settings: getSettings() }));
admin.put('/settings', json, (req, res) => {
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
  setSettings(out);
  audit(req.admin.id, 'settings.update', Object.keys(out).join(','), ip(req));
  res.json({ settings: getSettings() });
});

admin.post('/mail/test', json, ah(async (req, res) => {
  if (!mail.mailReady()) return res.status(400).json({ error: 'SMTP غير مضبوط في ملف .env' });
  res.json({ ok: await mail.sendTest(sec.email(req.body?.to || req.admin.email)) });
}));
admin.get('/logs', (req, res) => res.json({
  audit: all('SELECT l.*, a.email FROM audit_log l LEFT JOIN admins a ON a.id = l.admin_id ORDER BY l.id DESC LIMIT 100'),
  emails: all('SELECT * FROM email_log ORDER BY id DESC LIMIT 100'),
  sessions: all('SELECT ip, ua, created_at, expires_at FROM sessions WHERE admin_id = ? AND expires_at > ? ORDER BY created_at DESC', req.admin.id, Date.now()),
}));
admin.post('/logout-all', (req, res) => {
  sec.logoutAll(req.admin.id);
  audit(req.admin.id, 'sessions.revoke', null, ip(req));
  res.clearCookie(sec.SESSION_COOKIE, { ...sec.cookieOptions(), maxAge: undefined });
  res.json({ ok: true });
});

// ---------- الملفات الثابتة ----------
app.use('/api', (req, res) => res.status(404).json({ error: 'غير موجود' }));
app.use(express.static('public', { extensions: ['html'], index: 'index.html', maxAge: PROD ? '1h' : 0 }));
app.use((req, res) => res.status(404).sendFile('index.html', { root: 'public' }));

// ---------- معالج الأخطاء (بدون كشف تفاصيل داخلية) ----------
app.use((err, req, res, next) => {
  if (err.type === 'entity.too.large') return res.status(413).json({ error: 'حجم البيانات كبير جدًا' });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'بيانات غير صالحة' });
  if (err instanceof InputError) return res.status(400).json({ error: err.message });
  if (err.status && err.status < 600 && err.expose !== false && /[؀-ۿ]/.test(err.message)) return res.status(err.status).json({ error: err.message });
  console.error(err);
  res.status(500).json({ error: 'صار خطأ في الخادم. حاول مرة ثانية.' });
});

app.listen(PORT, () => {
  console.log(`\n  ROX Store يعمل على  http://localhost:${PORT}`);
  console.log(`  لوحة التحكم:        http://localhost:${PORT}/admin/`);
  if (adminCount() === 0) console.log(`\n  ⚠ لا يوجد حساب أدمن بعد. رمز الإعداد (Setup token): ${SETUP_TOKEN}\n`);
  if (!mail.mailReady()) console.log('  ℹ SMTP غير مضبوط — الإيميلات تُسجّل فقط ولا تُرسل.');
  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) console.log('  ℹ ANTHROPIC_API_KEY غير مضبوط — استوديو الذكاء الاصطناعي معطّل.');
});
