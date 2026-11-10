// إنشاء حساب أدمن أو تغيير كلمة مروره من سطر الأوامر:
//   npm run create-admin -- you@example.com "كلمة-مرور-قوية-123"
import { existsSync } from 'node:fs';
if (existsSync('.env')) process.loadEnvFile('.env');
const { one, run, ready, close } = await import('../src/db.js');
await ready;
const sec = await import('../src/security.js');
const [email, password] = process.argv.slice(2);
try {
  const em = sec.email(email);
  const prob = sec.passwordProblem(password);
  if (prob) throw new Error(prob);
  const hash = await sec.hashPassword(password);
  if (await one('SELECT id FROM admins WHERE email = ?', em)) {
    await run('UPDATE admins SET pass_hash = ?, failed = 0, locked_until = 0 WHERE email = ?', hash, em);
    await run('DELETE FROM sessions WHERE admin_id = (SELECT id FROM admins WHERE email = ?)', em);
    console.log('✓ تم تحديث كلمة المرور لـ', em);
  } else {
    await run('INSERT INTO admins(email, pass_hash, created_at) VALUES (?,?,?)', em, hash, Date.now());
    console.log('✓ تم إنشاء حساب الأدمن', em);
  }
} catch (e) { console.error('✗', e.message); process.exitCode = 1; }
await close();
