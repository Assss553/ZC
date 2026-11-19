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

# ---- weapon sling (shoulder strap) : 256x1024 webbing + buckle/QD swivel ----
def sling(name, cols):
    w, h = 256, 1024
    img = Image.new("RGB", (w, h), cols[0]); d = ImageDraw.Draw(img)
    for x in range(0, w, 6):  # webbing weave
        d.line((x, 0, x, h), fill=cols[1], width=2)
    d.rectangle((0, 0, 14, h), fill=cols[1]); d.rectangle((w-15, 0, w, h), fill=cols[1])  # stitched edges
    for y in range(0, h, 18):
        d.line((20, y, 20, y+9), fill=cols[2], width=2); d.line((w-21, y, w-21, y+9), fill=cols[2], width=2)
    metal = (45, 45, 48)
    # adjuster buckle
    d.rounded_rectangle((10, 300, w-10, 400), 10, fill=metal, outline=(90, 90, 95), width=4)
    d.rectangle((40, 330, w-40, 370), fill=cols[0])
    # QD swivel
    d.ellipse((78, 820, 178, 920), fill=metal, outline=(110, 110, 115), width=6)
    d.ellipse((113, 855, 143, 885), fill=(20, 20, 20))
    # reinforced box-X stitch
    d.rectangle((30, 560, w-30, 700), outline=cols[2], width=3)
    d.line((30, 560, w-30, 700), fill=cols[2], width=3); d.line((w-30, 560, 30, 700), fill=cols[2], width=3)
    return img

slings = []
for name, cols in VARIANTS.items():
    c = cols if name != "desert" else [cols[0], cols[1], (70, 55, 40)]
    s = sling(name, c); s.save(f"{OUT}/swat_sling_{name}_diff.png"); slings.append(s)
pv = Image.new("RGB", (3*150+40, 560), (90, 100, 115))
for i, s in enumerate(slings):
    pv.paste(s.resize((128, 512)), (20 + i*150, 24))
pv.save(f"{OUT}/_preview_sling.png")
