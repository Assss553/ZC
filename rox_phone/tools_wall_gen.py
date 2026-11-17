# ROX Store - procedural wallpapers (original artwork), 1080x2340
import numpy as np, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops
W, H = 1080, 2340
OUT = '/home/user/ZC/rox_phone/html/img/'
import os; os.makedirs(OUT, exist_ok=True)

def grad(stops, h=H, w=W):
    ys = np.linspace(0, 1, h)[:, None]
    img = np.zeros((h, w, 3))
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        m = (ys >= p0) & (ys <= p1)
        t = np.clip((ys - p0) / max(1e-6, p1 - p0), 0, 1)
        t = t * t * (3 - 2 * t)
        col = np.array(c0)[None, None, :] * (1 - t[..., None]) + np.array(c1)[None, None, :] * t[..., None]
        img = np.where(m[..., None], np.broadcast_to(col, (h, w, 3)), img)
    return img

def radial(cx, cy, r, col, power=2.0):
    y, x = np.mgrid[0:H, 0:W]
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** power
    return a[..., None] * np.array(col)[None, None, :]

def to_img(a): return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
def screen(base, add): return 255 - (255 - base) * (255 - add) / 255

def palm(draw, x, y, h, col, lean=0.0, rng=None):
    rng = rng or random.Random(1)
    # trunk: segmented, slightly curved
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((x + lean * h * t * t + math.sin(t * 3) * 6, y - h * t))
    for i in range(40):
        w0 = 15 - 9 * (i / 40)
        draw.line([pts[i], pts[i + 1]], fill=col, width=int(w0 * h / 600) + 3)
    tx, ty = pts[-1]
    draw.ellipse([tx - 18 * h / 600, ty - 14 * h / 600, tx + 18 * h / 600, ty + 14 * h / 600], fill=col)
    # fronds: arched rachis + drooping tapered leaflets
    for k in range(11):
        ang = -math.pi / 2 + (k - 5) * 0.5 + rng.uniform(-.1, .1)
        L = h * rng.uniform(.30, .40)
        droop = rng.uniform(.7, 1.0) * (1 + abs(k - 5) * .15)
        prev = (tx, ty); pts = []
        for s in range(0, 31):
            t = s / 30
            pts.append((tx + math.cos(ang) * L * t, ty + math.sin(ang) * L * t + droop * (L * .5) * t * t))
        for s in range(1, 31):
            t = s / 30; (ax, ay), (px, py) = pts[s - 1], pts[s]
            draw.line([(ax, ay), (px, py)], fill=col, width=max(2, int(5 * h / 600 * (1 - t) + 1)))
            pass
            ll = L * .2 * math.sin(math.pi * min(1, t * 1.05)) + 2
            dx, dy = px - ax, py - ay; n = math.hypot(dx, dy) or 1; dx /= n; dy /= n
            for sgn in (1, -1):
                nx, ny = -dy * sgn, dx * sgn
                ex, ey = px + nx * ll * .7 + dx * ll * .5, py + ny * ll * .7 + ll * .9
                draw.polygon([(px, py), (px + dx * 3, py + dy * 3), (ex, ey)], fill=col)
                draw.line([(px, py), (ex, ey)], fill=col, width=max(2, int(4 * h / 600)))

def skyline(draw, base, maxh, col, rng, win=None, wd=None, minw=40, maxw=120, gap=4):
    x = -20
    while x < W + 20:
        w = rng.randint(minw, maxw); h = rng.uniform(.25, 1) * maxh
        if rng.random() < .12: h = maxh * rng.uniform(1.1, 1.5)
        top = base - h
        draw.rectangle([x, top, x + w, base + 10], fill=col)
        if rng.random() < .3: draw.rectangle([x + w * .3, top - h * .08, x + w * .7, top], fill=col)
        if rng.random() < .15: draw.line([(x + w / 2, top), (x + w / 2, top - 60)], fill=col, width=3)
        if win and wd:
            for yy in range(int(top + 12), int(base - 8), 14):
                for xx in range(int(x + 8), int(x + w - 8), 11):
                    if rng.random() < .28:
                        c = win[rng.randint(0, len(win) - 1)]
                        wd.rectangle([xx, yy, xx + 5, yy + 7], fill=c)
        x += w + gap

def grain(img, amt=10, seed=3):
    rs = np.random.RandomState(seed)
    a = np.asarray(img).astype(float) + rs.normal(0, amt, (H, W, 1))
    return to_img(a)

def vignette(img, s=.55):
    y, x = np.mgrid[0:H, 0:W]
    d = np.sqrt(((x - W / 2) / (W * .75)) ** 2 + ((y - H / 2) / (H * .7)) ** 2)
    m = 1 - np.clip(d - .3, 0, 1) * s
    return to_img(np.asarray(img).astype(float) * m[..., None])

def bloom(img, r=40, k=.6, thr=180):
    a = np.asarray(img).astype(float)
    br = np.clip((a.max(axis=2, keepdims=True) - thr) / (255 - thr), 0, 1) * a
    b = np.asarray(to_img(br).filter(ImageFilter.GaussianBlur(r))).astype(float)
    return to_img(screen(a, b * k))

# ============ 1. GOLDEN HOUR — Los Santos boulevard ============
def golden():
    rng = random.Random(42)
    sky = grad([(0, (34, 18, 74)), (.22, (120, 40, 110)), (.42, (240, 92, 90)), (.55, (255, 160, 90)), (.62, (255, 205, 140)), (1, (255, 205, 140))])
    sun_y = 1330
    sky = screen(sky, radial(W / 2, sun_y, 900, (255, 120, 60), 1.6))
    sky = screen(sky, radial(W / 2, sun_y, 380, (255, 230, 170), 1.3))
    img = to_img(sky)
    d = ImageDraw.Draw(img)
    # sun disc with stripes
    sun = Image.new('L', (W, H), 0); sd = ImageDraw.Draw(sun); sd.ellipse([W / 2 - 230, sun_y - 230, W / 2 + 230, sun_y + 230], fill=255)
    for i in range(7): sd.rectangle([0, sun_y + 30 + i * 30, W, sun_y + 30 + i * 30 + 4 + i * 2.2], fill=0)
    img = Image.composite(to_img(np.full((H, W, 3), (255, 236, 190))), img, sun.filter(ImageFilter.GaussianBlur(1.5)))
    # thin clouds
    cl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); cd = ImageDraw.Draw(cl)
    for i in range(14):
        y = rng.randint(380, 1150); x = rng.randint(-200, W); w = rng.randint(250, 700)
        cd.ellipse([x, y, x + w, y + rng.randint(10, 26)], fill=(255, 190, 170, rng.randint(40, 110)))
    img.paste(cl.filter(ImageFilter.GaussianBlur(6)), (0, 0), cl.filter(ImageFilter.GaussianBlur(6)))
    # far hills + haze layers
    for layer, (col, base, mh, alpha) in enumerate([((170, 70, 110), 1480, 160, 160), ((110, 40, 90), 1530, 260, 220), ((55, 20, 55), 1585, 360, 255)]):
        L = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ld = ImageDraw.Draw(L)
        if layer == 0:
            pts = [(0, base)] + [(x, base - mh * (.5 + .5 * math.sin(x / 140 + 1.3) * math.cos(x / 310))) for x in range(0, W + 20, 20)] + [(W, H), (0, H)]
            ld.polygon(pts, fill=col + (alpha,))
        else:
            wl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); wd = ImageDraw.Draw(wl)
            skyline(ld, base, mh, col + (alpha,), rng, win=[(255, 200, 120, 200), (255, 160, 90, 160)] if layer == 2 else None, wd=wd, minw=30 + layer * 10, maxw=80 + layer * 20)
            L = Image.alpha_composite(L, wl)
        img = Image.alpha_composite(img.convert('RGBA'), L).convert('RGB')
    # road (perspective) + sidewalks
    road = Image.new('RGBA', (W, H), (0, 0, 0, 0)); rd = ImageDraw.Draw(road)
    vp = (W / 2, 1600)
    rd.polygon([(0, 1600), (W, 1600), (W, H), (0, H)], fill=(28, 14, 30, 255))
    rd.polygon([(vp[0] - 18, 1600), (vp[0] + 18, 1600), (W + 500, H), (-500, H)], fill=(44, 26, 44, 255))
    # sun reflection on asphalt
    img = Image.alpha_composite(img.convert('RGBA'), road).convert('RGB')
    a = np.asarray(img).astype(float)
    a = screen(a, radial(W / 2, 1640, 520, (150, 70, 60), 1.8) * (np.mgrid[0:H, 0:W][0] > 1600)[..., None])
    img = to_img(a); d = ImageDraw.Draw(img)
    # lane dashes
    for i in range(14):
        t0 = (i / 14) ** 2.2; t1 = ((i + .45) / 14) ** 2.2
        y0 = 1600 + (H - 1600) * t0; y1 = 1600 + (H - 1600) * t1
        w0 = 2 + 40 * t0; w1 = 2 + 40 * t1
        d.polygon([(W / 2 - w0 / 2, y0), (W / 2 + w0 / 2, y0), (W / 2 + w1 / 2, y1), (W / 2 - w1 / 2, y1)], fill=(255, 210, 120))
    # light trails (long exposure)
    tr = Image.new('RGB', (W, H), (0, 0, 0)); td = ImageDraw.Draw(tr)
    for side, col in ((-1, (255, 60, 60)), (1, (255, 230, 180))):
        for k in range(4):
            off = 80 + k * 26
            pts = []
            for i in range(60):
                t = (i / 59) ** 2.1
                pts.append((W / 2 + side * (off * t * 6 + 8 + k * 2), 1600 + (H - 1600) * t))
            td.line(pts, fill=col, width=3 + k)
    tr = tr.filter(ImageFilter.GaussianBlur(2))
    img = to_img(screen(np.asarray(img).astype(float), np.asarray(tr).astype(float)))
    # street lamps
    d = ImageDraw.Draw(img)
    for side in (-1, 1):
        for i in range(6):
            t = (i + 1) / 7; t = t ** 1.8
            x = W / 2 + side * (60 + 900 * t); y = 1600 + (H - 1600) * t * .2
            h = 40 + 900 * t
            d.line([(x, y + 10), (x, y - h)], fill=(25, 10, 25), width=int(2 + 10 * t))
            d.line([(x, y - h), (x - side * 60 * t, y - h - 10 * t)], fill=(25, 10, 25), width=int(2 + 8 * t))
    # palms (big foreground + mid)
    pl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); pd = ImageDraw.Draw(pl)
    for (x, y, h, lean, c) in [(250, 1640, 520, -.05, (70, 25, 60, 255)), (830, 1640, 560, .05, (70, 25, 60, 255)),                                 (80, 2000, 1500, .1, (16, 6, 18, 255)), (1010, 2050, 1650, -.12, (16, 6, 18, 255))]:
        palm(pd, x, y, h, c, lean, random.Random(int(x)))
    img = Image.alpha_composite(img.convert('RGBA'), pl).convert('RGB')
    # sports car silhouette w/ rim light
    car = Image.new('RGBA', (W, H), (0, 0, 0, 0)); kd = ImageDraw.Draw(car)
    cx, cy, s = 270, 2050, 2.1
    body = [(0, 44), (14, 28), (52, 18), (96, 4), (150, 0), (196, 10), (238, 26), (262, 34), (268, 48), (268, 58), (0, 58)]
    kd.polygon([(cx + px * s, cy + py * s) for px, py in body], fill=(10, 4, 12, 255))
    kd.polygon([(cx + px * s, cy + py * s) for px, py in [(100, 6), (150, 2), (190, 12), (210, 22), (88, 22)]], fill=(40, 20, 40, 255))
    for wx in (56, 214):
        kd.ellipse([cx + (wx - 21) * s, cy + 37 * s, cx + (wx + 21) * s, cy + 79 * s], fill=(5, 2, 6, 255))
        kd.ellipse([cx + (wx - 11) * s, cy + 47 * s, cx + (wx + 11) * s, cy + 69 * s], fill=(70, 50, 60, 255))
    kd.line([(cx + 14 * s, cy + 28 * s), (cx + 96 * s, cy + 4 * s), (cx + 150 * s, cy), (cx + 238 * s, cy + 26 * s)], fill=(255, 170, 110, 255), width=4)
    kd.polygon([(cx, cy + 40 * s), (cx + 10 * s, cy + 40 * s), (cx + 8 * s, cy + 48 * s), (cx, cy + 48 * s)], fill=(255, 40, 60, 255))
    img = Image.alpha_composite(img.convert('RGBA'), car).convert('RGB')
    # car shadow/reflection glow
    img = to_img(screen(np.asarray(img).astype(float), radial(cx - 10, cy + 90 * s, 120, (255, 40, 60), 2)))
    img = bloom(img, 50, .55, 200)
    img = vignette(img, .6)
    return grain(img, 6)

# ============ 2. NEON RAIN — downtown at night ============
def neon():
    rng = random.Random(7)
    sky = grad([(0, (6, 6, 20)), (.35, (20, 14, 48)), (.55, (60, 20, 70)), (.62, (110, 30, 80)), (1, (12, 8, 22))])
    sky = screen(sky, radial(W * .7, 1100, 900, (90, 30, 120), 1.5))
    img = to_img(sky).convert('RGBA')
    # 3 depth layers of towers with lit windows
    for li, (col, base, mh, wins) in enumerate([((30, 22, 60), 1400, 700, [(120, 120, 200, 120)]), ((18, 12, 38), 1450, 900, [(255, 190, 120, 160), (140, 200, 255, 140)]), ((8, 6, 18), 1500, 1150, [(255, 210, 140, 230), (120, 220, 255, 200), (255, 90, 160, 200)])]):
        L = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ld = ImageDraw.Draw(L)
        wl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); wd = ImageDraw.Draw(wl)
        skyline(ld, base, mh, col + (255,), random.Random(li * 13 + 5), win=wins, wd=wd, minw=60 + li * 20, maxw=140 + li * 30, gap=6 + li * 4)
        if li < 2: L = L.filter(ImageFilter.GaussianBlur(2 - li))
        img = Image.alpha_composite(img, L); img = Image.alpha_composite(img, wl)
    img = img.convert('RGB')
    # neon signs
    sg = Image.new('RGB', (W, H), (0, 0, 0)); gd = ImageDraw.Draw(sg)
    signs = [((90, 820, 290, 870), (255, 45, 140)), ((760, 700, 980, 740), (40, 230, 255)), ((640, 1040, 700, 1340), (255, 140, 40)), ((150, 1120, 200, 1380), (120, 255, 160)), ((420, 980, 600, 1015), (255, 60, 80))]
    for box, c in signs: gd.rounded_rectangle(box, 10, outline=c, width=7)
    gd.text((110, 828), 'ROX', fill=(255, 45, 140))
    glow = sg.filter(ImageFilter.GaussianBlur(18))
    a = screen(np.asarray(img).astype(float), np.asarray(glow).astype(float) * 1.6)
    a = screen(a, np.asarray(sg).astype(float))
    img = to_img(a)
    # wet street with reflections (mirror city, blurred, stretched)
    top = img.crop((0, 600, W, 1500)).transpose(Image.FLIP_TOP_BOTTOM).resize((W, H - 1500)).filter(ImageFilter.GaussianBlur(6))
    refl = np.asarray(top).astype(float) * .55
    ys = np.linspace(1, .25, H - 1500)[:, None, None]
    street = np.asarray(img).astype(float); street[1500:] = street[1500:] * .15 + refl * ys
    img = to_img(street); d = ImageDraw.Draw(img)
    # streaks of light on wet road
    for i in range(70):
        x = rng.randint(0, W); y = rng.randint(1520, H); l = rng.randint(30, 160)
        c = rng.choice([(255, 60, 150), (60, 220, 255), (255, 170, 80)])
        d.line([(x, y), (x, y + l)], fill=tuple(int(v * .5) for v in c), width=2)
    # rain
    rn = Image.new('RGBA', (W, H), (0, 0, 0, 0)); nd = ImageDraw.Draw(rn)
    for i in range(1300):
        x = rng.randint(-100, W); y = rng.randint(-100, H); l = rng.randint(18, 60)
        nd.line([(x, y), (x + l * .18, y + l)], fill=(200, 210, 255, rng.randint(25, 80)), width=1)
    img = Image.alpha_composite(img.convert('RGBA'), rn).convert('RGB')
    # foreground bokeh
    bk = Image.new('RGB', (W, H), (0, 0, 0)); bd = ImageDraw.Draw(bk)
    for i in range(26):
        r = rng.randint(30, 110); x = rng.randint(-50, W + 50); y = rng.choice([rng.randint(1700, H), rng.randint(0, 500)])
        c = rng.choice([(255, 60, 150), (60, 200, 255), (255, 150, 60), (180, 90, 255)])
        bd.ellipse([x - r, y - r, x + r, y + r], fill=tuple(int(v * .35) for v in c))
    img = to_img(screen(np.asarray(img).astype(float), np.asarray(bk.filter(ImageFilter.GaussianBlur(14))).astype(float)))
    img = bloom(img, 40, .5, 190)
    return grain(vignette(img, .7), 7)

# ============ 3. OCEAN DRIVE — coast highway at dusk ============
def ocean():
    rng = random.Random(21)
    sky = grad([(0, (12, 22, 70)), (.3, (60, 60, 140)), (.45, (230, 120, 140)), (.52, (255, 180, 130)), (.55, (255, 210, 160)), (1, (20, 30, 70))])
    img = to_img(screen(sky, radial(W * .62, 1270, 700, (255, 150, 90), 1.6)))
    d = ImageDraw.Draw(img)
    d.ellipse([W * .62 - 110, 1160, W * .62 + 110, 1380], fill=(255, 238, 200))
    # sea
    sea = grad([(0, (40, 40, 100)), (1, (6, 12, 34))], h=H - 1290)
    a = np.asarray(img).astype(float); a[1290:] = sea
    img = to_img(a); d = ImageDraw.Draw(img)
    # sun glitter path
    for i in range(900):
        t = rng.random() ** 1.5; y = 1295 + t * 900; spread = 30 + t * 380
        x = W * .62 + rng.gauss(0, spread * .45); l = 6 + t * 40
        c = (255, 210 + rng.randint(0, 40), 150 + rng.randint(0, 60))
        d.line([(x, y), (x + l, y)], fill=c, width=1 + int(t * 2))
    # cliffs left
    cl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); cd = ImageDraw.Draw(cl)
    cd.polygon([(0, 900), (120, 1000), (210, 1150), (300, 1290), (420, 1500), (520, 1750), (600, 2100), (640, H), (0, H)], fill=(24, 18, 40, 255))
    cd.polygon([(0, 1100), (80, 1180), (160, 1300), (260, 1520), (340, 1800), (380, H), (0, H)], fill=(12, 9, 22, 255))
    img = Image.alpha_composite(img.convert('RGBA'), cl).convert('RGB'); d = ImageDraw.Draw(img)
    # winding road on cliff with trails
    pts = []
    for i in range(80):
        t = i / 79; y = 1240 + (H - 1240) * t ** 1.4; x = 170 + 380 * t ** 1.2 + math.sin(t * 5) * 40 * t
        pts.append((x, y))
    d.line(pts, fill=(40, 30, 55), width=60)
    tr = Image.new('RGB', (W, H), (0, 0, 0)); td = ImageDraw.Draw(tr)
    td.line([(x - 12, y) for x, y in pts], fill=(255, 50, 60), width=5); td.line([(x + 12, y) for x, y in pts], fill=(255, 235, 190), width=5)
    img = to_img(screen(np.asarray(img).astype(float), np.asarray(tr.filter(ImageFilter.GaussianBlur(3))).astype(float) * 1.4))
    # palms on the cliff
    pl = Image.new('RGBA', (W, H), (0, 0, 0, 0)); pd = ImageDraw.Draw(pl)
    for (x, y, h, lean) in [(110, 1180, 520, .08), (220, 1300, 420, -.05), (960, 2340, 1700, -.14)]:
        palm(pd, x, y, h, (8, 6, 16, 255), lean, random.Random(int(x)))
    img = Image.alpha_composite(img.convert('RGBA'), pl).convert('RGB')
    # stars
    d = ImageDraw.Draw(img)
    for i in range(160):
        x = rng.randint(0, W); y = rng.randint(0, 700); r = rng.random() * 1.8
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255))
    img = bloom(img, 45, .55, 200)
    return grain(vignette(img, .55), 6)

for name, fn in (('golden', golden), ('neon', neon), ('ocean', ocean)):
    im = fn(); im.save(OUT + f'wall_{name}.webp', 'WEBP', quality=86)
    im.resize((360, 780)).save(f'/tmp/claude-0/-home-user-ZC/3eac5cd8-a0c6-5bdc-9017-57c8f915549a/scratchpad/pv_{name}.png')
    print(name, os.path.getsize(OUT + f'wall_{name}.webp') // 1024, 'KB')
