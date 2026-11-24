# Builds the time-lapse video from the step renders: caption, progress bar, Ken-Burns zoom and cross-fades.
#   python3 timelapse.py <render dir> <out.mp4> [music.wav]
import sys, os, subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
D, OUT = sys.argv[1], sys.argv[2]; MUSIC = sys.argv[3] if len(sys.argv) > 3 else None
AR = {'Split': 'الانقسام: البرج يصير برجين', 'Crowns': 'التيجان وخطوط LED والجسر المعلّق', 'Rooftops': 'السطوح: مهبط هيليكوبتر وأضواء',
      'Ground': 'الأرضية: الساحة والشارع وممر المشاة', 'Podium: chamfered': 'القاعدة: زجاج غامق بزوايا مشطوفة', 'Podium: fins': 'القاعدة: زعانف وإضاءة LED على الحواف',
      'Entrance': 'المدخل: مظلة ولوحة ROX', 'Mid tower: dark': 'البرج الأوسط: زجاج أسود', 'Curtain': 'الواجهة: زعانف وأدوار ومكاتب منوّرة',
      'Setback': 'التراجع: حافة LED', 'Upper tower': 'البرج العلوي', 'Crown': 'التاج: خطوط LED', 'Rooftop': 'السطح: مهبط هيليكوبتر وأضواء',
      'Street': 'الشارع: أعمدة إنارة وشجر', 'City': 'المدينة حول البرج', 'Final - aerial': 'النهائي: من الجو', 'Final - street': 'النهائي: من الشارع', 'Final - top': 'النهائي: من فوق'}
steps = [l.strip().split('|', 1) for l in open(os.path.join(D, 'steps.txt')) if l.strip()]
W, H, FPS = 1920, 1080, 30
fb = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 44)
fs = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 26)
from PIL import features
if features.check('raqm'):
    shape = lambda t: t          # Pillow with libraqm shapes Arabic itself
else:
  try:
    import arabic_reshaper, bidi.algorithm as bd
    shape = lambda t: bd.get_display(arabic_reshaper.reshape(t))
  except Exception:
    shape = lambda t: t
def ar_font(sz):
    for p in ('/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        if os.path.exists(p): return ImageFont.truetype(p, sz)
fa = ar_font(40)
frames = os.path.join(D, 'frames'); os.makedirs(frames, exist_ok=True)
imgs = [Image.open(os.path.join(D, f'step_{int(n):02d}.png')).convert('RGB').resize((W, H), Image.LANCZOS) for n, _ in steps]
HOLD, FADE = 54, 14
k = 0
def overlay(im, i, t):
    im = im.copy(); d = ImageDraw.Draw(im, 'RGBA')
    d.rectangle((0, H - 150, W, H), fill=(0, 0, 0, 150))
    n, title = steps[i]
    d.text((60, H - 128), f'STEP {int(n):02d} / {len(steps):02d}', font=fs, fill=(255, 140, 80))
    d.text((60, H - 92), title.upper(), font=fb, fill=(255, 255, 255))
    a = next((v for kk, v in AR.items() if title.startswith(kk)), '')
    if a: d.text((W - 60, H - 100), shape(a), font=fa, fill=(255, 255, 255), anchor='ra')
    d.rectangle((0, H - 8, int(W * (i + t) / len(steps)), H), fill=(255, 90, 31))
    d.rounded_rectangle((50, 40, 330, 100), 16, fill=(0, 0, 0, 140)); d.text((70, 52), 'ROX  ·  BLENDER', font=fs, fill=(255, 255, 255))
    return im
def zoom(im, t):
    s = 1.0 + 0.05 * t; w, h = int(W / s), int(H / s); x, y = (W - w) // 2, (H - h) // 2
    return im.crop((x, y, x + w, y + h)).resize((W, H), Image.BILINEAR)
for i, im in enumerate(imgs):
    for f in range(HOLD):
        t = f / HOLD; fr = overlay(zoom(im, t), i, t)
        if i + 1 < len(imgs) and f >= HOLD - FADE:
            a = (f - (HOLD - FADE)) / FADE; nx = overlay(zoom(imgs[i + 1], 0), i + 1, 0); fr = Image.blend(fr, nx, a)
        fr.save(os.path.join(frames, f'f{k:05d}.jpg'), quality=92); k += 1
od = os.path.join(D, 'orbit')
if os.path.isdir(od):        # finale: camera flying around the towers (each orbit frame shown twice = 15 fps motion)
    ofs = sorted(os.listdir(od)); ff = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 64)
    for j, fn in enumerate(ofs):
        im = Image.open(os.path.join(od, fn)).convert('RGB').resize((W, H), Image.LANCZOS)
        if j < 8 and k: im = Image.blend(Image.open(os.path.join(frames, f'f{k - 1:05d}.jpg')), im, (j + 1) / 8)
        d = ImageDraw.Draw(im, 'RGBA'); a = min(1, j / 12) * (1 - max(0, (j - len(ofs) + 10) / 10))
        d.text((W // 2, H - 120), 'ROX TOWERS', font=ff, fill=(255, 255, 255, int(255 * a)), anchor='mm')
        d.text((W // 2, H - 66), shape('برجين روكس · تصميم بلندر'), font=fa, fill=(255, 140, 80, int(255 * a)), anchor='mm')
        for _ in range(2): im.save(os.path.join(frames, f'f{k:05d}.jpg'), quality=92); k += 1
dur = k / FPS
cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', os.path.join(frames, 'f%05d.jpg')]
if MUSIC: cmd += ['-i', MUSIC, '-af', f'afade=t=out:st={dur - 2:.2f}:d=2', '-shortest', '-c:a', 'aac', '-b:a', '192k']
cmd += ['-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', OUT]
subprocess.run(cmd, check=True); print('video', OUT, round(dur, 1), 's')
