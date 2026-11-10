// تشغيل المتجر على سيرفر عادي (محليًا، Render، Koyeb، Docker...)
import './src/env.js';
import app, { init, state, adminCount, cleanup } from './src/app.js';
import { mailReady } from './src/mail.js';

const PORT = Number(process.env.PORT || 3000);
setInterval(() => cleanup().catch(() => {}), 6 * 60 * 60 * 1000).unref();
await init;
const needsAdmin = (await adminCount()) === 0;

app.listen(PORT, () => {
  console.log(`\n  ROX Store يعمل على  http://localhost:${PORT}`);
  console.log(`  لوحة التحكم:        http://localhost:${PORT}/admin/`);
  console.log(`  قاعدة البيانات:      ${state.dbKind === 'postgres' ? 'PostgreSQL' : 'PGlite محلية (data/pglite)'}`);
  if (needsAdmin) console.log(`\n  ⚠ لا يوجد حساب أدمن بعد. رمز الإعداد (Setup token): ${state.setupToken}\n`);
  if (!mailReady()) console.log('  ℹ SMTP غير مضبوط — الإيميلات تُسجّل فقط ولا تُرسل.');
  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) console.log('  ℹ ANTHROPIC_API_KEY غير مضبوط — استوديو الذكاء الاصطناعي معطّل.');
});
