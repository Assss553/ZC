// خط الإنتاج: فكرة ← سيناريو مقسّم مشاهد ← صورة لكل مشهد ← تعليق صوتي ← مونتاج 1080x1920 بـ ffmpeg
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { STYLES } from './styles.js';
import { VIDEOS_DIR } from './store.js';
import { localText, localImage, localVoice } from './local-ai.js';

const LOCAL = () => process.env.AI_MODE === 'local';

const W = 1080, H = 1920, FPS = 30;

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let err = '';
    p.stderr.on('data', d => (err += d).length > 8000 && (err = err.slice(-4000)));
    p.on('close', c => (c === 0 ? resolve() : reject(new Error(`${cmd} failed: ${err.slice(-800)}`))));
  });
}

// 1) السيناريو
async function writeScript(idea, styleKey, lang, seconds) {
  const scenes = Math.max(4, Math.round(seconds / 6));
  if (!LOCAL() && !process.env.ANTHROPIC_API_KEY) {
    return {
      title: idea.slice(0, 80), description: idea, tags: ['shorts'],
      scenes: Array.from({ length: scenes }, (_, i) => ({ narration: i === 0 ? idea : `المشهد ${i + 1}`, visual: idea })),
    };
  }
  const ask = `You are a viral YouTube Shorts writer. Idea: "${idea}".
Visual style: ${STYLES[styleKey].name}. Narration language: ${lang}. Total length about ${seconds} seconds, exactly ${scenes} scenes.
Start with a strong hook in the first scene, end with a twist or call to action.
Return ONLY JSON: {"title": "<=90 chars catchy, include #shorts", "description": "...", "tags": ["..."],
"scenes": [{"narration": "spoken text in ${lang}, 1-2 short sentences", "visual": "detailed English image prompt for this scene, same main character description repeated every time"}]}`;
  if (LOCAL()) { const t = await localText(ask); return JSON.parse(t.slice(t.indexOf('{'), t.lastIndexOf('}') + 1)); }
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': process.env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({
      model: process.env.CLAUDE_MODEL || 'claude-opus-5-5',
      max_tokens: 3000,
      messages: [{ role: 'user', content:
`You are a viral YouTube Shorts writer. Idea: "${idea}".
Visual style: ${STYLES[styleKey].name}. Narration language: ${lang}. Total length about ${seconds} seconds, exactly ${scenes} scenes.
Start with a strong hook in the first scene, end with a twist or call to action.
Return ONLY JSON: {"title": "<=90 chars catchy, include #shorts", "description": "...", "tags": ["..."],
"scenes": [{"narration": "spoken text in ${lang}, 1-2 short sentences", "visual": "detailed English image prompt for this scene, same main character description repeated every time"}]}` }],
    }),
  });
  if (!res.ok) throw new Error('Claude: ' + (await res.text()).slice(0, 300));
  const text = (await res.json()).content.map(b => b.text || '').join('');
  return JSON.parse(text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1));
}

// 2) الصور
async function makeImage(prompt, styleKey, out, i) {
  if (LOCAL()) return localImage(`${prompt}, ${STYLES[styleKey].prompt}, masterpiece, best quality`, out);
  if (!process.env.OPENAI_API_KEY) {
    const colors = ['0x7a1f4d', '0x1f4d7a', '0x2d7a1f', '0x7a5a1f', '0x4d1f7a'];
    await run('ffmpeg', ['-y', '-f', 'lavfi', '-i', `gradients=s=${W}x${H}:c0=${colors[i % colors.length]}:c1=0x101020:duration=1`, '-frames:v', '1', out]);
    return;
  }
  const res = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-image-1', size: '1024x1536', quality: 'high',
      prompt: `${prompt}. ${STYLES[styleKey].prompt}. Vertical 9:16 composition, no text, no watermark.` }),
  });
  if (!res.ok) throw new Error('Image: ' + (await res.text()).slice(0, 300));
  fs.writeFileSync(out, Buffer.from((await res.json()).data[0].b64_json, 'base64'));
}

// 3) الصوت
async function makeVoice(text, voice, out) {
  if (LOCAL()) return localVoice(text, out);
  if (!process.env.OPENAI_API_KEY) return false;
  const res = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-4o-mini-tts', voice: voice || 'onyx', input: text, response_format: 'mp3' }),
  });
  if (!res.ok) throw new Error('TTS: ' + (await res.text()).slice(0, 300));
  fs.writeFileSync(out, Buffer.from(await res.arrayBuffer()));
  return true;
}

function duration(file) {
  return new Promise(resolve => {
    const p = spawn('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file]);
    let o = ''; p.stdout.on('data', d => (o += d)); p.on('close', () => resolve(parseFloat(o) || 0));
  });
}

const srtTime = s => new Date(s * 1000).toISOString().slice(11, 23).replace('.', ',');

// خط الإنتاج كامل
export async function generateVideo(job, onStep = () => {}) {
  const dir = path.join(VIDEOS_DIR, job.id);
  fs.mkdirSync(dir, { recursive: true });
  const seconds = job.seconds || 40;

  onStep('كتابة السيناريو');
  const script = await writeScript(job.idea, job.style, job.lang || 'Arabic', seconds);
  const per = seconds / script.scenes.length;

  const clips = [];
  let srt = '', t = 0;
  for (const [i, sc] of script.scenes.entries()) {
    onStep(`مشهد ${i + 1}/${script.scenes.length}: صورة وصوت`);
    const img = path.join(dir, `s${i}.png`), mp3 = path.join(dir, `s${i}.mp3`), clip = path.join(dir, `c${i}.mp4`);
    const [, hasVoice] = await Promise.all([makeImage(sc.visual, job.style, img, i), makeVoice(sc.narration, job.voice, mp3)]);
    const d = hasVoice ? Math.max(2.5, (await duration(mp3)) + 0.3) : per;
    const frames = Math.ceil(d * FPS);
    // حركة كاميرا (Ken Burns): تقريب أو إبعاد بالتناوب
    const zoom = i % 2 === 0 ? `min(1+0.0009*on,1.25)` : `max(1.25-0.0009*on,1)`;
    const vf = `scale=${W * 2}:${H * 2}:force_original_aspect_ratio=increase,crop=${W * 2}:${H * 2},` +
      `zoompan=z='${zoom}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${W}x${H}:fps=${FPS},format=yuv420p`;
    const audioIn = hasVoice ? ['-i', mp3] : ['-f', 'lavfi', '-t', String(d), '-i', 'anullsrc=r=44100:cl=stereo'];
    await run('ffmpeg', ['-y', '-loop', '1', '-i', img, ...audioIn, '-vf', vf, '-t', d.toFixed(2),
      '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-shortest', clip]);
    clips.push(clip);
    srt += `${i + 1}\n${srtTime(t)} --> ${srtTime(t + d)}\n${sc.narration}\n\n`;
    t += d;
  }

  onStep('المونتاج النهائي والترجمة');
  const list = path.join(dir, 'list.txt');
  fs.writeFileSync(list, clips.map(c => `file '${c}'`).join('\n'));
  fs.writeFileSync(path.join(dir, 'subs.srt'), srt);
  const out = path.join(dir, 'final.mp4');
  const subStyle = 'FontName=DejaVu Sans,FontSize=13,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=1,Outline=3,Alignment=2,MarginV=70';
  await run('ffmpeg', ['-y', '-f', 'concat', '-safe', '0', '-i', list,
    '-vf', `subtitles=${path.join(dir, 'subs.srt')}:force_style='${subStyle}'`,
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-c:a', 'aac', '-movflags', '+faststart', out]);
  for (const c of clips) fs.rmSync(c, { force: true });
  return { file: out, title: script.title, description: script.description, tags: script.tags };
}
