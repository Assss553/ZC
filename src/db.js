// قاعدة البيانات: SQLite المدمجة في Node.js (بدون إضافات خارجية)
// كل الاستعلامات مُعاملة (prepared statements) لمنع حقن SQL.
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const file = resolve(process.env.DB_PATH || 'data/rox.db');
mkdirSync(dirname(file), { recursive: true });

export const db = new DatabaseSync(file);
db.exec(`
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

CREATE TABLE IF NOT EXISTS admins (
  id INTEGER PRIMARY KEY,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  pass_hash TEXT NOT NULL,
  failed INTEGER NOT NULL DEFAULT 0,
  locked_until INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  admin_id INTEGER NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  csrf TEXT NOT NULL,
  ip TEXT, ua TEXT,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL,
  price INTEGER NOT NULL,
  compare_price INTEGER,
  bg TEXT NOT NULL DEFAULT '#0b0a09',
  fg TEXT NOT NULL DEFAULT '#efeae2',
  art_svg TEXT,
  photo BLOB,
  photo_type TEXT,
  sizes TEXT NOT NULL DEFAULT '[]',
  specs TEXT NOT NULL DEFAULT '[]',
  tags TEXT NOT NULL DEFAULT '[]',
  stock INTEGER,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  ai INTEGER NOT NULL DEFAULT 0,
  prompt TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  customer_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  city TEXT NOT NULL,
  address TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  payment TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  subtotal INTEGER NOT NULL,
  shipping INTEGER NOT NULL,
  total INTEGER NOT NULL,
  ip TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS orders_created ON orders(created_at);

CREATE TABLE IF NOT EXISTS order_items (
  id INTEGER PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  size TEXT NOT NULL DEFAULT '',
  qty INTEGER NOT NULL,
  unit_price INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY,
  admin_id INTEGER,
  action TEXT NOT NULL,
  detail TEXT,
  ip TEXT,
  at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS email_log (
  id INTEGER PRIMARY KEY,
  recipient TEXT NOT NULL,
  subject TEXT NOT NULL,
  status TEXT NOT NULL,
  error TEXT,
  at INTEGER NOT NULL
);
`);

// معاملة (transaction) آمنة
export function tx(fn) {
  db.exec('BEGIN IMMEDIATE');
  try { const r = fn(); db.exec('COMMIT'); return r; }
  catch (e) { db.exec('ROLLBACK'); throw e; }
}

export const one = (sql, ...p) => db.prepare(sql).get(...p);
export const all = (sql, ...p) => db.prepare(sql).all(...p);
export const run = (sql, ...p) => db.prepare(sql).run(...p);

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

export function getSettings() {
  const out = structuredClone(DEFAULT_SETTINGS);
  for (const r of all('SELECT key, value FROM settings')) {
    try { out[r.key] = JSON.parse(r.value); } catch { /* تجاهل القيم التالفة */ }
  }
  return out;
}

export function setSettings(obj) {
  const st = db.prepare('INSERT INTO settings(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value');
  tx(() => { for (const [k, v] of Object.entries(obj)) st.run(k, JSON.stringify(v)); });
}

export function audit(adminId, action, detail, ip) {
  run('INSERT INTO audit_log(admin_id, action, detail, ip, at) VALUES (?, ?, ?, ?, ?)',
    adminId ?? null, action, detail ? String(detail).slice(0, 500) : null, ip ?? null, Date.now());
}
