// قاعدة البيانات: PostgreSQL
import './env.js';
// - في الاستضافة: تتصل بقاعدة Postgres حقيقية عبر DATABASE_URL (مثل Neon أو Supabase أو Render).
// - محليًا وبالاختبارات: PGlite (نسخة Postgres مدمجة) بدون تثبيت أي شي.
// كل الاستعلامات مُعاملة (parameterized) لمنع حقن SQL.
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS admins (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  pass_hash TEXT NOT NULL,
  failed INTEGER NOT NULL DEFAULT 0,
  locked_until BIGINT NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  admin_id INTEGER NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  csrf TEXT NOT NULL,
  ip TEXT, ua TEXT,
  created_at BIGINT NOT NULL,
  expires_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_admin ON sessions(admin_id);
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL,
  price INTEGER NOT NULL CHECK (price > 0),
  compare_price INTEGER,
  bg TEXT NOT NULL DEFAULT '#0b0a09',
  fg TEXT NOT NULL DEFAULT '#efeae2',
  art_svg TEXT,
  photo BYTEA,
  photo_type TEXT,
  sizes TEXT NOT NULL DEFAULT '[]',
  specs TEXT NOT NULL DEFAULT '[]',
  tags TEXT NOT NULL DEFAULT '[]',
  stock INTEGER CHECK (stock IS NULL OR stock >= 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  ai INTEGER NOT NULL DEFAULT 0,
  prompt TEXT,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS products_status ON products(status, created_at DESC);
CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  customer_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  city TEXT NOT NULL,
  address TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  payment TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0 CHECK (status BETWEEN 0 AND 4),
  subtotal INTEGER NOT NULL,
  shipping INTEGER NOT NULL,
  total INTEGER NOT NULL,
  ip TEXT,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS orders_created ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS orders_status ON orders(status);
CREATE TABLE IF NOT EXISTS order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  size TEXT NOT NULL DEFAULT '',
  qty INTEGER NOT NULL CHECK (qty > 0),
  unit_price INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS order_items_order ON order_items(order_id);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS audit_log (
  id SERIAL PRIMARY KEY,
  admin_id INTEGER,
  action TEXT NOT NULL,
  detail TEXT,
  ip TEXT,
  at BIGINT NOT NULL
);
CREATE TABLE IF NOT EXISTS ai_jobs (
  id SERIAL PRIMARY KEY,
  admin_id INTEGER NOT NULL,
  token_hash TEXT NOT NULL,
  brief TEXT NOT NULL,
  type TEXT NOT NULL,
  count INTEGER NOT NULL,
  publish INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL CHECK (status IN ('pending','running','done','error')),
  result TEXT,
  error TEXT,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);
CREATE TABLE IF NOT EXISTS email_log (
  id SERIAL PRIMARY KEY,
  recipient TEXT NOT NULL,
  subject TEXT NOT NULL,
  status TEXT NOT NULL,
  error TEXT,
  at BIGINT NOT NULL
);`;

// يحوّل ? إلى $1, $2 ... (صيغة Postgres)
const pgSql = (sql) => { let i = 0; return sql.replace(/\?/g, () => '$' + ++i); };
const num = (v) => (v === null ? null : Number(v));

let driver; // { query(sql, params) -> {rows, rowCount}, transaction(fn), kind }

async function connect() {
  if (process.env.DATABASE_URL) {
    const { default: pg } = await import('pg');
    pg.types.setTypeParser(20, num);   // BIGINT → رقم
    pg.types.setTypeParser(1700, num); // NUMERIC → رقم
    const url = process.env.DATABASE_URL;
    const local = /@(localhost|127\.0\.0\.1)[:/]/.test(url);
    const pool = new pg.Pool({
      connectionString: url,
      ssl: local || process.env.DATABASE_SSL === 'false' ? false : { rejectUnauthorized: process.env.DATABASE_SSL_STRICT !== 'false' },
      max: Number(process.env.DATABASE_POOL || 5),
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 15000,
    });
    pool.on('error', (e) => console.error('[db] pool error:', e.message));
    return {
      kind: 'postgres',
      query: (s, p) => pool.query(s, p),
      async transaction(fn) {
        const c = await pool.connect();
        try { await c.query('BEGIN'); const r = await fn((s, p) => c.query(s, p)); await c.query('COMMIT'); return r; }
        catch (e) { await c.query('ROLLBACK').catch(() => {}); throw e; }
        finally { c.release(); }
      },
      close: () => pool.end(),
    };
  }
  const { PGlite } = await import('@electric-sql/pglite');
  const path = process.env.PGLITE_PATH || 'data/pglite';
  if (path !== 'memory://') mkdirSync(resolve(path), { recursive: true });
  const db = await PGlite.create(path === 'memory://' ? undefined : resolve(path), { parsers: { 20: num, 1700: num } });
  const wrap = (r) => ({ rows: r.rows, rowCount: r.affectedRows ?? r.rows.length });
  return {
    kind: 'pglite',
    query: async (s, p) => wrap(await db.query(s, p)),
    transaction: (fn) => db.transaction((t) => fn(async (s, p) => wrap(await t.query(s, p)))),
    close: () => db.close(),
  };
}

function api(q) {
  return {
    one: async (sql, ...p) => (await q(pgSql(sql), p)).rows[0],
    all: async (sql, ...p) => (await q(pgSql(sql), p)).rows,
    run: async (sql, ...p) => { const r = await q(pgSql(sql), p); return { changes: r.rowCount, rows: r.rows, id: r.rows[0]?.id }; },
  };
}

export const ready = (async () => {
  driver = await connect();
  await driver.query('SELECT 1');
  for (const stmt of SCHEMA.split(';').map((s) => s.trim()).filter(Boolean)) await driver.query(stmt);
  return driver.kind;
})();

const q = (s, p) => driver.query(s, p);
export const { one, all, run } = api(q);
export const tx = (fn) => driver.transaction((tq) => fn(api(tq)));
export const close = () => driver?.close();

// ---------- الإعدادات ----------
export const DEFAULT_SETTINGS = {
  storeName: 'ROX',
  tagline: 'تصاميم ما تتكرر. كل قطعة مولودة من فكرة.',
  maintenance: false,
  maintenanceMsg: 'نجهّز لكم شيئًا أفضل. نرجع قريبًا.',
  maintenanceUntil: '',
  dropDate: '2026-12-01T00:00',
  shippingFee: 25,
  freeShippingOver: 300,
  bankInfo: '',
  whatsapp: '',
  notifyEmail: '',
  socials: { youtube: '', x: '', instagram: '', tiktok: '', snapchat: '', discord: '', kick: '' },
  payments: { cod: true, bank: true },
  cities: ['الرياض', 'جدة', 'الدمام', 'مكة', 'المدينة', 'الخبر', 'أبها', 'تبوك'],
};

export async function getSettings() {
  const out = structuredClone(DEFAULT_SETTINGS);
  for (const r of await all("SELECT key, value FROM settings WHERE key NOT LIKE '\_%'")) {
    try { out[r.key] = JSON.parse(r.value); } catch { /* تجاهل القيم التالفة */ }
  }
  return out;
}

export async function setSettings(obj) {
  await tx(async (t) => {
    for (const [k, v] of Object.entries(obj))
      await t.run('INSERT INTO settings(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', k, JSON.stringify(v));
  });
}

export function audit(adminId, action, detail, ip) {
  return run('INSERT INTO audit_log(admin_id, action, detail, ip, at) VALUES (?, ?, ?, ?, ?)',
    adminId ?? null, action, detail ? String(detail).slice(0, 500) : null, ip ?? null, Date.now())
    .catch((e) => console.error('[audit]', e.message));
}
