// طبقة الحماية: كلمات مرور مشفّرة، جلسات آمنة، CSRF، قفل الحساب، تحقق من المدخلات
import './env.js';
import { scrypt, randomBytes, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { one, run, audit } from './db.js';

const scryptAsync = promisify(scrypt);
const SCRYPT = { N: 2 ** 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
export const SESSION_COOKIE = process.env.NODE_ENV === 'production' ? '__Host-rox_s' : 'rox_s';
const SESSION_TTL = 12 * 60 * 60 * 1000;      // 12 ساعة
const MAX_FAILED = 5;                           // محاولات قبل القفل
const LOCK_MS = 15 * 60 * 1000;                 // مدة القفل

// ---------- كلمات المرور (scrypt + ملح عشوائي) ----------
export async function hashPassword(pw) {
  const salt = randomBytes(16);
  const key = await scryptAsync(pw.normalize('NFKC'), salt, 64, SCRYPT);
  return `scrypt$${salt.toString('base64')}$${key.toString('base64')}`;
}

export async function verifyPassword(pw, stored) {
  const [alg, s, k] = String(stored).split('$');
  if (alg !== 'scrypt' || !s || !k) return false;
  const key = await scryptAsync(pw.normalize('NFKC'), Buffer.from(s, 'base64'), 64, SCRYPT);
  const exp = Buffer.from(k, 'base64');
  return exp.length === key.length && timingSafeEqual(exp, key);
}

// نفس الوقت تقريبًا سواء كان الإيميل موجود أو لا (يمنع تخمين الحسابات)
let dummyHash;
const DUMMY_HASH = () => (dummyHash ??= hashPassword(randomBytes(12).toString('hex')));

export function passwordProblem(pw) {
  if (typeof pw !== 'string' || pw.length < 10) return 'كلمة المرور لازم تكون 10 أحرف أو أكثر';
  if (pw.length > 200) return 'كلمة المرور طويلة جدًا';
  if (!/[A-Za-z؀-ۿ]/.test(pw) || !/\d/.test(pw)) return 'كلمة المرور لازم تحتوي حروف وأرقام';
  return null;
}

const sha256 = (x) => createHash('sha256').update(x).digest('hex');
export const randomToken = (n = 32) => randomBytes(n).toString('base64url');

// ---------- تسجيل الدخول ----------
export async function login(email, password, ip, ua) {
  const a = await one('SELECT * FROM admins WHERE email = ?', String(email || '').trim().toLowerCase());
  const now = Date.now();
  if (!a) { await verifyPassword(String(password || 'x'), await DUMMY_HASH()); return { error: 'الإيميل أو كلمة المرور غلط' }; }
  if (a.locked_until > now) {
    const mins = Math.ceil((a.locked_until - now) / 60000);
    return { error: `الحساب مقفل مؤقتًا بسبب محاولات كثيرة. حاول بعد ${mins} دقيقة.` };
  }
  const ok = await verifyPassword(String(password || ''), a.pass_hash);
  if (!ok) {
    const failed = a.failed + 1;
    const lock = failed >= MAX_FAILED ? now + LOCK_MS : 0;
    await run('UPDATE admins SET failed = ?, locked_until = ? WHERE id = ?', lock ? 0 : failed, lock, a.id);
    await audit(a.id, lock ? 'login.locked' : 'login.failed', null, ip);
    return { error: lock ? 'تم قفل الحساب 15 دقيقة بسبب محاولات كثيرة.' : 'الإيميل أو كلمة المرور غلط' };
  }
  await run('UPDATE admins SET failed = 0, locked_until = 0 WHERE id = ?', a.id);
  await run('DELETE FROM sessions WHERE expires_at < ?', now);
  const token = randomToken(32), csrf = randomToken(24);
  await run('INSERT INTO sessions(token_hash, admin_id, csrf, ip, ua, created_at, expires_at) VALUES (?,?,?,?,?,?,?)',
    sha256(token), a.id, csrf, ip, String(ua || '').slice(0, 200), now, now + SESSION_TTL);
  await audit(a.id, 'login.ok', null, ip);
  return { token, csrf, admin: { id: a.id, email: a.email } };
}

export async function logout(token) { if (token) await run('DELETE FROM sessions WHERE token_hash = ?', sha256(token)); }
export async function logoutAll(adminId) { await run('DELETE FROM sessions WHERE admin_id = ?', adminId); }

export function cookieOptions() {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/',
    maxAge: SESSION_TTL,
  };
}

function readCookie(req, name) {
  const h = req.headers.cookie || '';
  for (const part of h.split(';')) {
    const i = part.indexOf('=');
    if (i > 0 && part.slice(0, i).trim() === name) return decodeURIComponent(part.slice(i + 1).trim());
  }
  return null;
}

// ---------- وسيط التحقق من الأدمن ----------
export async function sessionFrom(req) {
  const token = readCookie(req, SESSION_COOKIE);
  const s = token && await one(
    `SELECT s.*, a.email FROM sessions s JOIN admins a ON a.id = s.admin_id WHERE s.token_hash = ?`, sha256(token));
  return s && s.expires_at > Date.now() ? { ...s, token } : null;
}

export async function requireAdmin(req, res, next) {
  const s = await sessionFrom(req);
  if (!s) return res.status(401).json({ error: 'سجّل الدخول من جديد' });

  // حماية CSRF: كل طلب يغيّر البيانات لازم يحمل الرمز السري للجلسة + يكون من نفس الموقع
  if (!['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    const sent = String(req.get('x-csrf-token') || '');
    const a = Buffer.from(sent), b = Buffer.from(s.csrf);
    if (a.length !== b.length || !timingSafeEqual(a, b)) return res.status(403).json({ error: 'طلب مرفوض (CSRF)' });
    if (!sameOrigin(req)) return res.status(403).json({ error: 'طلب مرفوض (مصدر غير موثوق)' });
  }
  req.admin = { id: s.admin_id, email: s.email, csrf: s.csrf, token: s.token };
  next();
}

export function sameOrigin(req) {
  const origin = req.get('origin') || req.get('referer');
  if (!origin) return req.get('sec-fetch-site') !== 'cross-site';
  try {
    const u = new URL(origin);
    const allowed = (process.env.PUBLIC_URL ? [new URL(process.env.PUBLIC_URL).host] : []).concat(req.get('host'));
    return allowed.includes(u.host);
  } catch { return false; }
}

// ---------- التحقق من المدخلات ----------
const CTRL = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F‪-‮⁦-⁩]/g;
export function str(v, max, { required = false, multiline = false } = {}) {
  if (v == null) v = '';
  if (typeof v !== 'string' && typeof v !== 'number') throw new InputError('قيمة غير صالحة');
  let s = String(v).replace(CTRL, '');
  if (!multiline) s = s.replace(/[\r\n\t]+/g, ' ');
  s = s.trim();
  if (required && !s) throw new InputError('حقل مطلوب ناقص');
  if (s.length > max) throw new InputError(`النص أطول من المسموح (${max} حرف)`);
  return s;
}
export function int(v, min, max, def) {
  if ((v === undefined || v === null || v === '') && def !== undefined) return def;
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new InputError('رقم غير صالح');
  return n;
}
export function email(v) {
  const s = str(v, 160, { required: true }).toLowerCase();
  if (!/^[^\s@<>()[\]\\,;:"]+@[a-z0-9-]+(\.[a-z0-9-]+)+$/i.test(s)) throw new InputError('الإيميل غير صحيح');
  return s;
}
export function phone(v) {
  const s = str(v, 20, { required: true }).replace(/[^\d+]/g, '');
  if (!/^\+?\d{9,15}$/.test(s)) throw new InputError('رقم الجوال غير صحيح');
  return s;
}
export function color(v, def) {
  const s = String(v || '').trim();
  return /^#[0-9a-f]{6}$/i.test(s) ? s.toLowerCase() : def;
}
export function url(v) {
  const s = str(v, 300);
  if (!s) return '';
  try { const u = new URL(s); if (u.protocol === 'https:' || u.protocol === 'http:') return u.href; } catch { /* */ }
  throw new InputError('رابط غير صالح: ' + s.slice(0, 40));
}

export class InputError extends Error { constructor(m) { super(m); this.status = 400; } }
