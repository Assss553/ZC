"""Generate SWAT uniform textures (camo bases + patches) for FiveM. Run: python3 generate_textures.py"""
import os, random, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
S = 1024
VARIANTS = {
    "olive":  [(62, 68, 46), (52, 58, 38), (74, 80, 56)],
    "black":  [(22, 22, 24), (16, 16, 18), (30, 30, 33)],
    "desert": [(150, 118, 82), (120, 92, 62), (40, 32, 26)],
}
def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()

def fabric(img):
    """Add woven fabric noise."""
    px = img.load(); rnd = random.Random(1)
    for y in range(S):
        for x in range(S):
            n = rnd.randint(-6, 6) + (4 if (x + y) % 4 < 2 else -4) // 2
            r, g, b = px[x, y][:3]
            px[x, y] = (max(0, min(255, r+n)), max(0, min(255, g+n)), max(0, min(255, b+n)))
    return img

def camo(name, cols, blobs):
    rnd = random.Random(name)
    img = Image.new("RGB", (S, S), cols[0]); d = ImageDraw.Draw(img)
    if blobs:
        for c in cols[1:]:
            for _ in range(28):
                cx, cy, r = rnd.randint(0, S), rnd.randint(0, S), rnd.randint(40, 110)
                pts = [(cx + math.cos(a)*r*rnd.uniform(.5, 1.4), cy + math.sin(a)*r*rnd.uniform(.5, 1.4))
                       for a in [i*2*math.pi/10 for i in range(10)]]
                d.polygon(pts, fill=c)
        img = img.filter(ImageFilter.GaussianBlur(1.5))
    return fabric(img)

def arm_patch():
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    d.ellipse((16, 16, 496, 496), fill=(18, 18, 18), outline=(220, 220, 220), width=12)
    d.ellipse((60, 60, 452, 452), outline=(200, 200, 200), width=4)
    d.text((256, 110), "S.W.A.T", font=font(70), fill="white", anchor="mm")
    # stylised eagle wings
    for side in (-1, 1):
        for i in range(5):
            x0 = 256 + side*20; x1 = 256 + side*(150 - i*18); y = 230 + i*28
            d.polygon([(x0, y), (x1, y - 30), (x1 - side*10, y + 14)], fill="white")
    d.ellipse((236, 200, 276, 240), fill="white")
    d.polygon([(236, 360), (276, 360), (256, 400)], fill="white")
    d.text((256, 420), "SPECIAL WEAPONS & TACTICS", font=font(20), fill="white", anchor="mm")
    return img

def rect_patch(text, w=600, h=180, fs=110):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    d.rounded_rectangle((4, 4, w-4, h-4), 18, fill=(15, 15, 15), outline=(200, 200, 200), width=6)
    d.text((w//2, h//2), text, font=font(fs), fill="white", anchor="mm")
    return img

os.makedirs(OUT, exist_ok=True)
for name, cols in VARIANTS.items():
    base = camo(name, cols, blobs=(name == "desert"))
    base.save(f"{OUT}/swat_shirt_{name}_diff.png")
    vest = base.copy()
    vest.paste(p := rect_patch("S.W.A.T"), (212, 420), p)
    vest.paste(p := rect_patch("D-1", 300, 140, 90), (362, 250), p)
    vest.save(f"{OUT}/swat_vest_{name}_diff.png")
arm_patch().save(f"{OUT}/patch_arm_swat.png")
rect_patch("S.W.A.T").save(f"{OUT}/patch_chest_swat.png")
rect_patch("D-1", 300, 140, 90).save(f"{OUT}/patch_d1.png")

# preview sheet
files = sorted(f for f in os.listdir(OUT) if f.endswith("_diff.png"))
sheet = Image.new("RGB", (3*340+20, 2*340+20), (90, 100, 115))
for i, f in enumerate(files):
    t = Image.open(f"{OUT}/{f}").resize((320, 320))
    sheet.paste(t, (20 + (i % 3)*340, 20 + (i // 3)*340))
sheet.save(f"{OUT}/_preview.png")
print("done:", os.listdir(OUT))

# ---- weapon sling v2 : smooth padded shoulder strap, 512x2048 ----
def _shade(c, k): return tuple(max(0, min(255, int(v*k))) for v in c)

def sling(name, cols):
    W, H = 512, 2048
    base, dark, thread = cols
    img = Image.new("RGB", (W, H), base); px = img.load()
    rnd = random.Random(name + "sling")
    # cylindrical shading across width + fine twill weave + soft noise
    for y in range(H):
        for x in range(W):
            u = (x / (W - 1)) * 2 - 1
            k = 0.72 + 0.38 * math.cos(u * math.pi / 2) ** 0.8
            k += 0.05 * math.sin((x + y) * 0.9) + rnd.uniform(-0.025, 0.025)
            px[x, y] = _shade(base, k)
    d = ImageDraw.Draw(img, "RGBA")
    # padded shoulder section with raised quilting
    pad = (60, 520, W - 60, 1180)
    d.rounded_rectangle(pad, 70, fill=_shade(dark, 1.05) + (255,))
    for y in range(pad[1] + 40, pad[3] - 30, 60):
        d.rounded_rectangle((pad[0] + 30, y, pad[2] - 30, y + 40), 20, fill=_shade(base, 1.1) + (110,))
    d.rounded_rectangle(pad, 70, outline=thread + (255,), width=3)
    # rolled edges + double stitch lines
    for e in (0, W):
        for t in range(26):
            a = int(120 * (1 - t / 26))
            x = t if e == 0 else W - 1 - t
            d.line((x, 0, x, H), fill=(0, 0, 0, a // 3))
    for off in (34, 46):
        for x in (off, W - off):
            for y in range(0, H, 22):
                d.line((x, y, x, y + 12), fill=thread + (230,), width=2)
    # metal hardware with gradient
    def metal(box, r):
        x0, y0, x1, y1 = box
        for i in range(y1 - y0):
            k = 0.55 + 0.6 * math.sin(math.pi * i / (y1 - y0))
            d.line((x0 + r // 3, y0 + i, x1 - r // 3, y0 + i), fill=_shade((70, 72, 76), k))
        d.rounded_rectangle(box, r, outline=(30, 30, 32), width=5)
    metal((24, 200, W - 24, 330), 30); d.rounded_rectangle((90, 240, W - 90, 290), 16, fill=_shade(base, .6))
    # box-X reinforcement (smooth)
    bx = (90, 1350, W - 90, 1560)
    d.rectangle(bx, outline=thread, width=4)
    d.line((bx[0], bx[1], bx[2], bx[3]), fill=thread, width=4); d.line((bx[2], bx[1], bx[0], bx[3]), fill=thread, width=4)
    # QD swivel ring
    cx, cy = W // 2, 1800
    for r in range(110, 60, -1):
        k = 0.5 + 0.7 * (1 - abs(r - 85) / 25)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=_shade((80, 82, 86), k), width=2)
    d.ellipse((cx - 30, cy - 30, cx + 30, cy + 30), fill=(18, 18, 20))
    return img.filter(ImageFilter.SMOOTH)

slings = []
for name, cols in VARIANTS.items():
    c = {"olive": [(68, 74, 50), (50, 55, 36), (95, 100, 72)],
         "black": [(30, 30, 33), (18, 18, 20), (70, 70, 74)],
         "desert": [(160, 130, 92), (128, 102, 70), (90, 72, 50)]}[name]
    s = sling(name, c); s.save(f"{OUT}/swat_sling_{name}_diff.png"); slings.append(s)
pv = Image.new("RGB", (3 * 170 + 30, 700), (90, 100, 115))
for i, s in enumerate(slings):
    pv.paste(s.resize((160, 640), Image.LANCZOS), (20 + i * 170, 30))
pv.save(f"{OUT}/_preview_sling.png")
