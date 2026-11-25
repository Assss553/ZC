import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import { getDb, save, VIDEOS_DIR } from './store.js';
import { STYLES } from './styles.js';
import { createPlan, startScheduler, runNow } from './scheduler.js';
import { authUrl, handleCallback, upload } from './youtube.js';

// تحميل .env بدون مكتبات
if (fs.existsSync('.env')) for (const l of fs.readFileSync('.env', 'utf8').split('\n')) {
  const m = l.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/); if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
}

const app = express();
app.use(express.json());
app.use(express.static('public'));
app.use('/videos', express.static(VIDEOS_DIR));

app.get('/api/state', (_req, res) => {
  const db = getDb();
  res.json({
    styles: Object.fromEntries(Object.entries(STYLES).map(([k, v]) => [k, v.name])),
    channel: db.youtube?.channel || null,
    keys: { claude: !!process.env.ANTHROPIC_API_KEY, openai: !!process.env.OPENAI_API_KEY, google: !!process.env.GOOGLE_CLIENT_ID },
    jobs: db.jobs.map(({ result, ...j }) => ({ ...j, title: result?.title, video: result ? `/videos/${j.id}/final.mp4` : null }))
      .sort((a, b) => a.publishAt.localeCompare(b.publishAt)),
  });
});

app.post('/api/plans', (req, res) => {
  try { const p = createPlan(req.body); runNow(); res.json(p); }
  catch (e) { res.status(400).json({ error: e.message }); }
});

app.post('/api/jobs/:id/:action', async (req, res) => {
  const db = getDb(), j = db.jobs.find(x => x.id === req.params.id);
  if (!j) return res.sendStatus(404);
  const a = req.params.action;
  if (a === 'retry') { j.status = 'queued'; j.step = ''; }                       // إعادة توليد
  if (a === 'regenerate') { j.status = 'queued'; j.result = null; j.publishAt = new Date().toISOString(); }
  if (a === 'cancel') db.jobs.splice(db.jobs.indexOf(j), 1), fs.rmSync(path.join(VIDEOS_DIR, j.id), { recursive: true, force: true });
  if (a === 'reschedule') j.publishAt = new Date(req.body.publishAt).toISOString();
  if (a === 'publish' && j.result) {
    try { j.youtubeId = await upload({ ...j.result, privacy: j.privacy }); j.status = 'published'; }
    catch (e) { save(); return res.status(400).json({ error: e.message }); }
  }
  save(); runNow(); res.json({ ok: true });
});

app.get('/auth/youtube', (_req, res) => res.redirect(authUrl()));
app.get('/auth/youtube/callback', async (req, res) => {
  try { await handleCallback(req.query.code); res.redirect('/'); }
  catch (e) { res.status(400).send('فشل الربط: ' + e.message); }
});
app.post('/api/youtube/disconnect', (_req, res) => { getDb().youtube = null; save(); res.json({ ok: true }); });

const port = process.env.PORT || 4000;
app.listen(port, () => { console.log(`Shorts Studio → http://localhost:${port}`); startScheduler(); });
