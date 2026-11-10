// اختبارات الخادم: npm test  (يشغّل خادم مؤقت بقاعدة بيانات مؤقتة)
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const PORT = 3200 + Math.floor(Math.random() * 500), B = `http://localhost:${PORT}`;
const dir = mkdtempSync(join(tmpdir(), 'rox-'));
let srv, cookie = '', csrf = '';

before(async () => {
  srv = spawn(process.execPath, ['--disable-warning=ExperimentalWarning', 'server.js'], { env: { ...process.env, PORT, DB_PATH: join(dir, 'db'), SETUP_TOKEN: 'tok-1234567', ANTHROPIC_API_KEY: '', SMTP_HOST: '' }, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) { try { await fetch(B + '/api/store'); return; } catch { await new Promise((r) => setTimeout(r, 100)); } }
});
after(() => { srv.kill(); rmSync(dir, { recursive: true, force: true }); });

const req = async (path, { method = 'GET', body, auth = false, headers = {} } = {}) => {
  const r = await fetch(B + path, { method, headers: { 'Content-Type': 'application/json', Origin: B, ...(auth ? { Cookie: cookie, 'X-CSRF-Token': csrf } : {}), ...headers }, body: body && JSON.stringify(body) });
  const sc = r.headers.get('set-cookie'); if (sc) cookie = sc.split(';')[0];
  return { status: r.status, body: await r.json().catch(() => null) };
};

test('setup requires the token and a strong password', async () => {
  assert.equal((await req('/api/admin/setup', { method: 'POST', body: { email: 'a@b.co', password: 'Strongpass123', setupToken: 'wrong' } })).status, 403);
  assert.equal((await req('/api/admin/setup', { method: 'POST', body: { email: 'a@b.co', password: 'weak', setupToken: 'tok-1234567' } })).status, 400);
  assert.equal((await req('/api/admin/setup', { method: 'POST', body: { email: 'a@b.co', password: 'Strongpass123', setupToken: 'tok-1234567' } })).status, 200);
  assert.equal((await req('/api/admin/setup', { method: 'POST', body: { email: 'x@b.co', password: 'Strongpass123', setupToken: 'tok-1234567' } })).status, 403);
});

test('admin routes need a session and CSRF token', async () => {
  assert.equal((await req('/api/admin/stats')).status, 401);
  assert.equal((await req('/api/admin/login', { method: 'POST', body: { email: 'a@b.co', password: 'nope' } })).status, 401);
  const r = await req('/api/admin/login', { method: 'POST', body: { email: 'a@b.co', password: 'Strongpass123' } });
  assert.equal(r.status, 200); csrf = r.body.csrf;
  assert.match(cookie, /^rox_s=/);
  assert.equal((await req('/api/admin/stats', { auth: true })).status, 200);
  // بدون رمز CSRF
  const noCsrf = await fetch(B + '/api/admin/settings', { method: 'PUT', headers: { 'Content-Type': 'application/json', Cookie: cookie, Origin: B }, body: '{"tagline":"x"}' });
  assert.equal(noCsrf.status, 403);
  // من موقع خارجي
  assert.equal((await req('/api/admin/settings', { method: 'PUT', auth: true, body: { tagline: 'x' }, headers: { Origin: 'https://evil.example' } })).status, 403);
});

test('orders use server-side prices and validate input', async () => {
  const { body } = await req('/api/store');
  const p = body.products.find((x) => x.sizes.length);
  const order = { name: 'عميل', email: 'c@d.co', phone: '0551234567', city: 'الرياض', address: 'حي النخيل', payment: 'cod', items: [{ id: p.id, size: 'M', qty: 2, price: 1 }] };
  const r = await req('/api/orders', { method: 'POST', body: order });
  assert.equal(r.status, 201);
  assert.equal(r.body.total, p.price * 2 + (p.price * 2 >= 300 ? 0 : 25));
  assert.match(r.body.code, /^ROX-[A-Z2-9]{6}$/);
  assert.equal((await req('/api/orders', { method: 'POST', body: { ...order, items: [{ id: p.id, size: 'XXXL', qty: 1 }] } })).status, 400);
  assert.equal((await req('/api/orders', { method: 'POST', body: { ...order, email: 'bad' } })).status, 400);
  assert.equal((await req('/api/orders', { method: 'POST', body: { ...order, website: 'spam' } })).status, 400);
  // التتبّع يحتاج الإيميل الصحيح
  assert.equal((await req('/api/track', { method: 'POST', body: { code: r.body.code, email: 'x@y.co' } })).status, 404);
  const t = await req('/api/track', { method: 'POST', body: { code: r.body.code, email: 'c@d.co' } });
  assert.equal(t.status, 200); assert.equal(t.body.statusName, 'جديد');
});

test('SQL-injection style search is harmless', async () => {
  const r = await req(`/api/admin/orders?q=${encodeURIComponent("' OR 1=1; DROP TABLE orders; --")}`, { auth: true });
  assert.equal(r.status, 200); assert.equal(r.body.orders.length, 0);
  assert.equal((await req('/api/admin/orders', { auth: true })).body.orders.length, 1);
});

test('drafts are hidden from the public, artwork is sanitized', async () => {
  const r = await req('/api/admin/products', { method: 'POST', auth: true, body: { name: 'تجربة', price: 99, type: 'tee', status: 'draft', art: [{ kind: 'path', d: 'M0 0 L10 10"/><script>alert(1)</script>' }, { kind: 'text', x: 100, y: 100, text: '<script>x</script>', fill: 'javascript:1' }] } });
  assert.equal(r.status, 201);
  const id = r.body.product.id;
  assert.equal((await fetch(`${B}/img/${id}.svg`)).status, 404);
  const svg = await (await fetch(`${B}/img/${id}.svg`, { headers: { Cookie: cookie } })).text();
  assert.ok(!svg.includes('<script'));
  assert.ok(!svg.includes('javascript:'));
  assert.ok((await req('/api/store')).body.products.every((p) => p.id !== id));
});

test('photo upload checks the real file signature', async () => {
  const fake = 'data:image/png;base64,' + Buffer.from('<svg onload=alert(1)>').toString('base64');
  assert.equal((await req('/api/admin/products/1/photo', { method: 'POST', auth: true, body: { data: fake } })).status, 400);
});

test('login locks after repeated failures', async () => {
  for (let i = 0; i < 5; i++) await req('/api/admin/login', { method: 'POST', body: { email: 'a@b.co', password: 'wrong' + i } });
  const r = await req('/api/admin/login', { method: 'POST', body: { email: 'a@b.co', password: 'Strongpass123' } });
  assert.equal(r.status, 401); assert.match(r.body.error, /مقفل|قفل/);
});
