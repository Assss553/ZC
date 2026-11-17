exec(open('/tmp/claude-0/-home-user-ZC/3eac5cd8-a0c6-5bdc-9017-57c8f915549a/scratchpad/wall_gen.py').read().split('for name, fn in')[0])

def ridge(rng, base, amp, freq, oct=4):
    xs = np.arange(W + 1); y = np.zeros(W + 1)
    for o in range(oct):
        ph = rng.uniform(0, 6.28); f = freq * 2 ** o; a = amp / 1.9 ** o
        y += a * np.sin(xs * f + ph) + a * .5 * np.sin(xs * f * 1.7 + ph * 2)
    return base - np.abs(y)

def mountains(img, layers, rng):
    for col, base, amp, freq, haze in layers:
        ys = ridge(rng, base, amp, freq)
        m = Image.new('L', (W, H), 0); md = ImageDraw.Draw(m)
        md.polygon([(x, ys[x]) for x in range(W + 1)] + [(W, H), (0, H)], fill=255)
        layer = to_img(np.broadcast_to(np.array(col, float), (H, W, 3)).copy())
        img = Image.composite(layer, img, m.filter(ImageFilter.GaussianBlur(haze)))
    return img

# ============ 4. CHILIAD DAWN ============
def chiliad():
    rng = np.random.RandomState(4)
    sky = grad([(0, (40, 50, 110)), (.25, (150, 110, 170)), (.42, (255, 170, 140)), (.5, (255, 210, 170)), (1, (255, 210, 170))])
    sky = screen(sky, radial(300, 1000, 700, (255, 170, 110), 1.6))
    img = to_img(sky); d = ImageDraw.Draw(img); d.ellipse([220, 920, 380, 1080], fill=(255, 240, 210))
    # clouds band
    cl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); cd = ImageDraw.Draw(cl); r = random.Random(3)
    for i in range(40): x = r.randint(-200, W); y = r.randint(500, 1050); w = r.randint(200, 520); cd.ellipse([x, y, x + w, y + r.randint(30, 70)], fill=(255, 220, 220, r.randint(40, 100)))
    img.paste(cl.filter(ImageFilter.GaussianBlur(14)), (0, 0), cl.filter(ImageFilter.GaussianBlur(14)))
    img = mountains(img, [((190, 140, 175), 1250, 200, .004, 3), ((130, 90, 140), 1450, 260, .005, 2), ((80, 55, 100), 1650, 240, .006, 1.5), ((44, 30, 60), 1880, 200, .008, 1), ((20, 14, 30), 2120, 150, .011, .5)], rng)
    # snow caps on 2nd layer: light rim
    # pine trees foreground
    d = ImageDraw.Draw(img); r = random.Random(9)
    for i in range(70):
        x = r.randint(-20, W + 20); base = 2050 + r.randint(0, 260); h = r.randint(140, 380); w = h * .32
        for k in range(6):
            t = k / 6; d.polygon([(x, base - h + h * t * .9), (x - w * (.3 + t * .7), base - h * (1 - t) * .55 + h * .1), (x + w * (.3 + t * .7), base - h * (1 - t) * .55 + h * .1)], fill=(10, 8, 16))
        d.rectangle([x - 4, min(base - 20, H - 1), x + 4, H], fill=(10, 8, 16))
    # birds
    for i in range(9):
        x = 520 + r.randint(0, 380); y = 700 + r.randint(0, 240); s = r.uniform(.6, 1.4)
        d.line([(x - 14 * s, y - 6 * s), (x, y), (x + 14 * s, y - 6 * s)], fill=(40, 30, 50), width=2)
    img = bloom(img, 60, .45, 210)
    return grain(vignette(img, .5), 5)

# ============ 5. DESERT HIGHWAY (Sandy Shores) ============
def desert():
    sky = grad([(0, (20, 60, 150)), (.3, (90, 130, 200)), (.45, (250, 170, 110)), (.5, (255, 200, 140)), (1, (255, 200, 140))])
    sky = screen(sky, radial(780, 1120, 600, (255, 150, 80), 1.7))
    img = to_img(sky); d = ImageDraw.Draw(img); d.ellipse([700, 1040, 860, 1200], fill=(255, 235, 190))
    img = mountains(img, [((180, 110, 110), 1200, 150, .006, 2), ((140, 80, 70), 1280, 90, .009, 1)], np.random.RandomState(8))
    a = np.asarray(img).astype(float); ground = grad([(0, (190, 110, 70)), (.4, (120, 60, 40)), (1, (40, 20, 20))], h=H - 1280); a[1280:] = ground; img = to_img(a); d = ImageDraw.Draw(img)
    vp = (W / 2, 1282)
    d.polygon([(vp[0] - 6, 1282), (vp[0] + 6, 1282), (W * .95, H), (W * .05, H)], fill=(38, 30, 34))
    for i in range(18):
        t0 = (i / 18) ** 2.3; t1 = ((i + .5) / 18) ** 2.3; y0 = 1282 + (H - 1282) * t0; y1 = 1282 + (H - 1282) * t1
        w0, w1 = 1 + 14 * t0, 1 + 14 * t1; d.polygon([(W / 2 - w0, y0), (W / 2 + w0, y0), (W / 2 + w1, y1), (W / 2 - w1, y1)], fill=(240, 200, 90))
    # telephone poles
    for i in range(9):
        t = ((i + 1) / 9) ** 2; x = W / 2 + 40 + t * 700; yb = 1282 + (H - 1282) * t * .7; h = 30 + t * 900
        d.line([(x, yb), (x, yb - h)], fill=(30, 18, 20), width=int(2 + t * 12)); d.line([(x - 30 * t - 6, yb - h + 20 * t), (x + 30 * t + 6, yb - h + 20 * t)], fill=(30, 18, 20), width=int(2 + t * 6))
    # cacti + rocks
    r = random.Random(5)
    for (x, y, s) in [(150, 1700, 1.6), (90, 2050, 2.6), (880, 1600, 1.1), (330, 1450, .7)]:
        c = (30, 22, 20); d.rounded_rectangle([x - 14 * s, y - 160 * s, x + 14 * s, y], 14 * s, fill=c)
        d.rounded_rectangle([x - 60 * s, y - 110 * s, x - 34 * s, y - 50 * s], 12 * s, fill=c); d.rectangle([x - 60 * s, y - 64 * s, x, y - 50 * s], fill=c)
        d.rounded_rectangle([x + 34 * s, y - 130 * s, x + 58 * s, y - 70 * s], 12 * s, fill=c); d.rectangle([x, y - 84 * s, x + 58 * s, y - 70 * s], fill=c)
    img = bloom(img, 50, .5, 205)
    return grain(vignette(img, .55), 6)

# ============ 6. VINEWOOD NIGHT (hills + city lights from above) ============
def vinewood():
    sky = grad([(0, (6, 8, 26)), (.35, (20, 24, 70)), (.5, (70, 50, 110)), (.55, (170, 80, 110)), (1, (10, 10, 20))])
    img = to_img(sky); d = ImageDraw.Draw(img); r = random.Random(12)
    for i in range(260): x = r.randint(0, W); y = r.randint(0, 1100); rr = r.random() * 1.8; d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(255, 255, 255))
    d.ellipse([760, 260, 880, 380], fill=(255, 248, 225)); img = bloom(img, 40, .6, 230)
    # far city lights carpet
    lights = Image.new('RGB', (W, H), (0, 0, 0)); ld = ImageDraw.Draw(lights)
    for i in range(9000):
        t = r.random() ** .7; y = 1290 + t * 520; x = r.randint(0, W); s = .6 + t * 2.2
        c = r.choice([(255, 200, 120), (255, 170, 90), (255, 230, 190), (140, 200, 255), (255, 120, 120)])
        ld.ellipse([x - s, y - s * .6, x + s, y + s * .6], fill=c)
    # boulevards as glowing lines
    for i in range(10): y = 1300 + i * 50; ld.line([(0, y + r.randint(-10, 10)), (W, y + r.randint(-30, 30))], fill=(255, 170, 80), width=2)
    a = np.asarray(img).astype(float); a[1280:] = a[1280:] * .2 + np.array([18, 14, 30]) * .8
    a = screen(a, np.asarray(lights.filter(ImageFilter.GaussianBlur(1.2))).astype(float)); a = screen(a, np.asarray(lights.filter(ImageFilter.GaussianBlur(10))).astype(float) * .8)
    img = to_img(a)
    # dark hills foreground + sign letters
    pass
    m = Image.new('L', (W, H), 0); md = ImageDraw.Draw(m); md.polygon([(0, 1700), (200, 1640), (420, 1720), (700, 1660), (W, 1760), (W, H), (0, H)], fill=255)
    img = Image.composite(to_img(np.full((H, W, 3), (8, 7, 14), float)), img, m); d = ImageDraw.Draw(img)
    # car on the overlook with headlights cone
    cone = Image.new('RGB', (W, H), (0, 0, 0)); cd = ImageDraw.Draw(cone); cd.polygon([(560, 1760), (W, 1660), (W, 1900)], fill=(120, 110, 90)); img = to_img(screen(np.asarray(img).astype(float), np.asarray(cone.filter(ImageFilter.GaussianBlur(30))).astype(float)))
    d = ImageDraw.Draw(img); s = 1.6; cx, cy = 180, 1700
    d.polygon([(cx + px * s, cy + py * s) for px, py in [(0, 44), (14, 28), (52, 18), (96, 4), (150, 0), (196, 10), (238, 26), (262, 34), (268, 48), (268, 58), (0, 58)]], fill=(4, 4, 8))
    for wx in (56, 214): d.ellipse([cx + (wx - 20) * s, cy + 38 * s, cx + (wx + 20) * s, cy + 78 * s], fill=(2, 2, 4))
    d.line([(cx + 14 * s, cy + 28 * s), (cx + 96 * s, cy + 4 * s), (cx + 150 * s, cy), (cx + 238 * s, cy + 26 * s)], fill=(140, 150, 220), width=3)
    d.polygon([(cx + 254 * s, cy + 34 * s), (cx + 268 * s, cy + 40 * s), (cx + 266 * s, cy + 46 * s), (cx + 250 * s, cy + 42 * s)], fill=(255, 250, 220))
    img = bloom(img, 30, .5, 200)
    return grain(vignette(img, .5), 6)

# ============ 7. ROX ABSTRACT (premium dark fluid) ============
def roxabs():
    y, x = np.mgrid[0:H, 0:W].astype(float)
    f = np.sin(x / 160 + np.sin(y / 260) * 2.2) + np.sin(y / 210 + np.cos(x / 300) * 1.8) + np.sin((x + y) / 380)
    f = (f - f.min()) / (f.max() - f.min())
    base = np.stack([8 + 30 * f ** 3, 8 + 12 * f ** 4, 12 + 18 * f ** 2], -1)
    bands = np.clip(1 - np.abs(((f * 7) % 1) - .5) * 14, 0, 1) ** 2
    glow = np.stack([255 * bands, 90 * bands, 31 * bands], -1) * (.25 + .75 * f[..., None])
    img = to_img(screen(base, glow * .8))
    img = to_img(screen(np.asarray(img).astype(float), radial(W * .8, 300, 900, (120, 40, 10), 1.5)))
    d = ImageDraw.Draw(img)
    img = bloom(img, 30, .6, 150)
    return grain(vignette(img, .6), 7)

# ============ 8. PIER SUNSET ============
def pier():
    sky = grad([(0, (30, 30, 90)), (.3, (170, 70, 120)), (.44, (255, 140, 100)), (.5, (255, 200, 150)), (1, (255, 200, 150))])
    img = to_img(screen(sky, radial(W / 2, 1150, 700, (255, 140, 80), 1.6))); d = ImageDraw.Draw(img); d.ellipse([W / 2 - 120, 1030, W / 2 + 120, 1270], fill=(255, 236, 200))
    a = np.asarray(img).astype(float); sea = grad([(0, (120, 70, 120)), (1, (12, 12, 40))], h=H - 1170); a[1170:] = sea; img = to_img(a); d = ImageDraw.Draw(img); r = random.Random(4)
    for i in range(800):
        t = r.random() ** 1.6; yy = 1175 + t * 900; xx = W / 2 + r.gauss(0, 30 + t * 300); l = 5 + t * 40; d.line([(xx, yy), (xx + l, yy)], fill=(255, 215, 170), width=1 + int(t * 2))
    c = (14, 8, 20)
    # pier deck + pillars + ferris wheel + coaster
    d.rectangle([520, 1120, W, 1150], fill=c)
    for i in range(14): x = 540 + i * 40; d.rectangle([x, 1150, x + 8, 1260], fill=c)
    cx, cy, R = 800, 900, 210
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=c, width=10); d.ellipse([cx - R * .8, cy - R * .8, cx + R * .8, cy + R * .8], outline=c, width=4)
    for k in range(24):
        an = k * math.pi / 12; d.line([(cx, cy), (cx + R * math.cos(an), cy + R * math.sin(an))], fill=c, width=3)
        gx, gy = cx + R * math.cos(an), cy + R * math.sin(an); d.rounded_rectangle([gx - 13, gy - 6, gx + 13, gy + 22], 5, fill=c)
    d.polygon([(cx - 40, 1120), (cx, cy), (cx + 40, 1120)], fill=c)
    pts = [(560 + i * 8, 1060 - 80 * abs(math.sin(i / 9))) for i in range(30)]; d.line(pts, fill=c, width=6)
    for px, py in pts[::3]: d.line([(px, py), (px, 1120)], fill=c, width=3)
    # lights on wheel
    lt = Image.new('RGB', (W, H), (0, 0, 0)); ldd = ImageDraw.Draw(lt)
    for k in range(48): an = k * math.pi / 24; x, y = cx + R * math.cos(an), cy + R * math.sin(an); ldd.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 120, 200) if k % 2 else (120, 220, 255))
    img = to_img(screen(np.asarray(img).astype(float), np.asarray(lt).astype(float))); img = to_img(screen(np.asarray(img).astype(float), np.asarray(lt.filter(ImageFilter.GaussianBlur(10))).astype(float) * 1.4))
    pl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); pd = ImageDraw.Draw(pl)
    for (x, y, h, lean) in [(120, 1400, 1100, .08), (300, 1300, 700, -.05)]: palm(pd, x, y, h, (10, 6, 16, 255), lean, random.Random(int(x)))
    img = Image.alpha_composite(img.convert('RGBA'), pl).convert('RGB')
    img = bloom(img, 50, .5, 205)
    return grain(vignette(img, .5), 6)

import sys
for name, fn in (('vinewood', vinewood),):
    im = fn(); im.save(OUT + f'wall_{name}.webp', 'WEBP', quality=84)
    im.resize((360, 780)).save(f'/tmp/claude-0/-home-user-ZC/3eac5cd8-a0c6-5bdc-9017-57c8f915549a/scratchpad/pv_{name}.png'); print(name, os.path.getsize(OUT + f'wall_{name}.webp') // 1024)
