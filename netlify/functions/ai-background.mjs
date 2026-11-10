// دالة بالخلفية (تشتغل لين 15 دقيقة) لتصميم المنتجات بالذكاء الاصطناعي.
// آمنة للاستدعاء من أي أحد: ما تشغّل إلا مهمة موجودة ومعلّقة، وبرمزها السري.
import { runJob } from '../../src/app.js';

export default async (req) => {
  const body = await req.json().catch(() => ({}));
  await runJob(body.id, body.token).catch((e) => console.error('[ai-background]', e));
};
