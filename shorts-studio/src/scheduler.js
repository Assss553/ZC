// المجدول: يحوّل "كم مقطع باليوم + متى أبدأ" إلى مواعيد، ويشغّل الإنتاج والنشر تلقائياً
import { getDb, save, newId } from './store.js';
import { generateVideo } from './generator.js';
import { upload } from './youtube.js';

// "now" | "+1h" | "+2h" | "+30m" | "tomorrow" | "tomorrow 18:00" | ISO/datetime-local
export function parseStart(s, now = new Date()) {
  s = String(s || 'now').trim().toLowerCase();
  if (s === 'now') return now;
  const rel = s.match(/^\+(\d+(?:\.\d+)?)\s*([mhd])$/);
  if (rel) return new Date(now.getTime() + rel[1] * { m: 6e4, h: 36e5, d: 864e5 }[rel[2]]);
  const tm = s.match(/^tomorrow(?:\s+(\d{1,2}):(\d{2}))?$/);
  if (tm) {
    const d = new Date(now); d.setDate(d.getDate() + 1);
    d.setHours(tm[1] ? +tm[1] : 9, tm[2] ? +tm[2] : 0, 0, 0); return d;
  }
  const d = new Date(s);
  if (isNaN(d)) throw new Error('وقت البداية غير مفهوم');
  return d;
}

export function createPlan({ ideas, style, perDay = 1, days = 1, start = 'now', voice, lang, seconds, autoPublish = true, privacy = 'public' }) {
  const list = String(ideas).split('\n').map(x => x.trim()).filter(Boolean);
  if (!list.length) throw new Error('اكتب فكرة واحدة على الأقل');
  perDay = Math.min(Math.max(+perDay || 1, 1), 24); days = Math.min(Math.max(+days || 1, 1), 60);
  const t0 = parseStart(start), gap = 864e5 / perDay;
  const db = getDb(), plan = { id: newId(), style, perDay, days, start: t0.toISOString(), createdAt: new Date().toISOString() };
  db.plans.push(plan);
  for (let n = 0; n < perDay * days; n++) {
    const base = list[n % list.length], round = Math.floor(n / list.length);
    db.jobs.push({
      id: newId(), planId: plan.id, idea: round ? `${base} (جزء ${round + 1}، بقصة مختلفة)` : base,
      style, voice, lang, seconds: +seconds || 40, autoPublish, privacy,
      publishAt: new Date(t0.getTime() + n * gap).toISOString(), status: 'queued', step: '',
    });
  }
  save();
  return plan;
}

let busy = false;
async function tick() {
  if (busy) return; busy = true;
  const db = getDb();
  try {
    // نشر الجاهز اللي جاء وقته
    for (const j of db.jobs.filter(j => j.status === 'ready' && j.autoPublish && new Date(j.publishAt) <= new Date())) {
      if (!db.youtube) { j.step = 'بانتظار ربط القناة'; continue; }
      j.status = 'uploading'; save();
      try { j.youtubeId = await upload({ ...j.result, privacy: j.privacy }); j.status = 'published'; j.step = ''; }
      catch (e) { j.status = 'ready'; j.step = 'فشل الرفع: ' + e.message; }
      save();
    }
    // أنتج المقطع التالي (يبدأ قبل موعده بساعتين كحد أقصى حتى يكون جاهز في وقته)
    const next = db.jobs.filter(j => j.status === 'queued' && new Date(j.publishAt) - Date.now() < 2 * 36e5)
      .sort((a, b) => a.publishAt.localeCompare(b.publishAt))[0];
    if (next) {
      next.status = 'generating'; save();
      try {
        next.result = await generateVideo(next, s => { next.step = s; save(); });
        next.status = 'ready'; next.step = '';
      } catch (e) { next.status = 'failed'; next.step = e.message; }
      save();
    }
  } finally { busy = false; }
}

export function startScheduler() {
  for (const j of getDb().jobs) if (j.status === 'generating' || j.status === 'uploading') j.status = j.result ? 'ready' : 'queued';
  save();
  setInterval(tick, 20000); tick();
}
export const runNow = tick;
