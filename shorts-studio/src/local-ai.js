// الذكاء الاصطناعي الخاص: كل شي يشتغل على سيرفرك بدون أي مفتاح خارجي
//  - النص: Ollama (نموذج qwen2.5 يدعم العربي)
//  - الصور: Stable Diffusion WebUI (AUTOMATIC1111 / Forge) عبر --api
//  - الصوت: Piper (صوت عربي ar_JO-kareem)
import fs from 'node:fs';
import { spawn } from 'node:child_process';

const OLLAMA = () => process.env.OLLAMA_URL || 'http://localhost:11434';
const SD = () => process.env.SD_URL || 'http://localhost:7860';

export async function localText(prompt) {
  const res = await fetch(`${OLLAMA()}/api/generate`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ model: process.env.OLLAMA_MODEL || 'qwen2.5:14b', prompt, stream: false, format: 'json' }),
  });
  if (!res.ok) throw new Error('Ollama: ' + (await res.text()).slice(0, 300));
  return (await res.json()).response;
}

export async function localImage(prompt, out) {
  const res = await fetch(`${SD()}/sdapi/v1/txt2img`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      prompt, negative_prompt: 'text, watermark, lowres, blurry, deformed, extra fingers, bad anatomy',
      width: 768, height: 1344, steps: +process.env.SD_STEPS || 28, cfg_scale: 6, sampler_name: 'DPM++ 2M',
      enable_hr: true, hr_scale: 1.5, denoising_strength: 0.35, hr_upscaler: 'R-ESRGAN 4x+',  // تكبير لدقة عالية
    }),
  });
  if (!res.ok) throw new Error('Stable Diffusion: ' + (await res.text()).slice(0, 300));
  fs.writeFileSync(out, Buffer.from((await res.json()).images[0], 'base64'));
}

export function localVoice(text, out) {
  const wav = out.replace(/\.mp3$/, '.wav');
  return new Promise((resolve, reject) => {
    const p = spawn(process.env.PIPER_BIN || 'piper', ['--model', process.env.PIPER_VOICE || 'voices/ar_JO-kareem-medium.onnx', '--output_file', wav]);
    p.stdin.end(text);
    p.on('error', reject);
    p.on('close', c => c ? reject(new Error('Piper failed')) :
      spawn('ffmpeg', ['-y', '-i', wav, out]).on('close', k => k ? reject(new Error('ffmpeg mp3')) : resolve(true)));
  });
}
