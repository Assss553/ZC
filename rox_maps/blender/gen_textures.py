# ROX Store | All rights reserved
# Procedural tileable PBR textures (diffuse + normal), original work. Run: python gen_textures.py <out_dir>
import sys, os
import numpy as np
from PIL import Image

N = 1024
OUT = sys.argv[-1] if len(sys.argv) > 1 else "textures"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def fbm(oct=6, base=4, seed=0):
    """Tileable fractal noise in [0,1]."""
    r = np.random.default_rng(seed); acc = np.zeros((N, N)); amp = 1.0; tot = 0
    for o in range(oct):
        f = base * 2 ** o
        g = r.random((f, f))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
        # wrap: tile 3x3 then crop center to keep seamless edges
        big = np.tile(g, (3, 3)); bi = Image.fromarray((big * 255).astype(np.uint8)).resize((N * 3, N * 3), Image.BICUBIC)
        acc += amp * (np.asarray(bi, float)[N:2 * N, N:2 * N] / 255); tot += amp; amp *= 0.5
    a = acc / tot; return (a - a.min()) / (np.ptp(a) + 1e-9)

def colorize(t, c0, c1):
    c0, c1 = np.array(c0, float), np.array(c1, float)
    return (c0 + (c1 - c0) * t[..., None]).clip(0, 255)

def save(name, rgb, height):
    Image.fromarray(rgb.astype(np.uint8)).save(os.path.join(OUT, f"rox_{name}.png"))
    h = height.astype(float)
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 4; dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 4
    n = np.dstack([-dx, dy, np.ones_like(h)]); n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(os.path.join(OUT, f"rox_{name}_n.png"))

y, x = np.mgrid[0:N, 0:N] / N

# Brick (running bond, per-brick tint, mortar recess)
rows, cols = 16, 8
ry = (y * rows); row = ry.astype(int); bx = x * cols + (row % 2) * 0.5; col = bx.astype(int)
fy, fx = ry % 1, bx % 1
mortar = ((fy < 0.07) | (fx < 0.035)).astype(float)
tint = np.random.default_rng(1).random((rows, cols + 1))[row, col % (cols + 1)]
n1 = fbm(5, 8, 2)
brick = colorize(tint * 0.5 + n1 * 0.5, (95, 38, 26), (160, 70, 45))
brick = brick * (1 - mortar[..., None]) + colorize(n1, (150, 145, 135), (195, 190, 180)) * mortar[..., None]
save("brick", brick, (1 - mortar) * 0.8 + n1 * 0.2)

# Wood planks
pl = 6; prow = (y * pl).astype(int); off = np.random.default_rng(3).random(pl)[prow]
grain = np.sin((x * 40 + fbm(4, 4, 4) * 6 + off * 20) * np.pi) * 0.5 + 0.5
seam = (((y * pl) % 1) < 0.02) | ((((x + off) * 2) % 1) < 0.006)
wood = colorize(grain * 0.6 + fbm(5, 16, 5) * 0.4, (70, 38, 18), (140, 85, 45)) * (1 - 0.6 * seam[..., None])
save("wood", wood, grain * 0.3 + (1 - seam) * 0.7)

# Marble (bar top / tables)
v = np.abs(np.sin((x * 3 + y * 2 + fbm(6, 3, 6) * 4) * np.pi)) ** 0.25
save("marble", colorize(v, (40, 40, 44), (235, 232, 228)), v * 0.2)

# Checker floor tiles (kitchen / toilets)
t = ((x * 8).astype(int) + (y * 8).astype(int)) % 2
gr = (((x * 8) % 1) < 0.03) | (((y * 8) % 1) < 0.03)
n2 = fbm(4, 16, 8)
tile = np.where(t[..., None], colorize(n2, (215, 210, 200), (240, 236, 228)), colorize(n2, (25, 25, 28), (45, 45, 50)))
tile = tile * (1 - gr[..., None]) + 110 * gr[..., None]
save("tiles", tile, 1 - gr)

# Concrete / plaster / asphalt
c = fbm(7, 4, 9); save("concrete", colorize(c, (85, 85, 88), (140, 140, 142)), c)
p = fbm(6, 8, 10); save("plaster", colorize(p, (205, 198, 184), (232, 226, 214)), p * 0.3)
a = fbm(7, 32, 11) * 0.7 + rng.random((N, N)) * 0.3; save("asphalt", colorize(a, (18, 18, 20), (58, 58, 60)), a)

# Brushed metal, leather, fabric
m = fbm(3, 2, 12) * 0.3 + np.repeat(rng.random((N, 1)), N, 1) * 0.7
save("metal", colorize(m, (120, 122, 126), (185, 188, 192)), m * 0.2)
l = fbm(6, 24, 13); save("leather", colorize(l, (30, 14, 8), (70, 36, 20)), l)
f = (np.sin(x * N * np.pi / 2) * np.sin(y * N * np.pi / 2) * 0.5 + 0.5) * 0.4 + fbm(4, 8, 14) * 0.6
save("fabric", colorize(f, (90, 15, 20), (140, 30, 35)), f)

# Dark wall panel for HQ (graffiti-like color splotches over concrete)
g = fbm(5, 3, 15)
hq = colorize(fbm(7, 4, 16), (45, 45, 50), (80, 80, 85))
hq[..., 0] += (g > 0.7) * 70; hq[..., 2] += (g < 0.25) * 60
save("hqwall", hq.clip(0, 255), fbm(7, 4, 16))

# ROX sign
sign = np.zeros((256, 1024, 3), np.uint8)
from PIL import ImageDraw, ImageFont
im = Image.fromarray(sign); d = ImageDraw.Draw(im)
try:
    fnt = ImageFont.truetype("DejaVuSans-Bold.ttf", 170)
except OSError:
    fnt = ImageFont.load_default()
d.text((512, 128), "ROX DINER", fill=(255, 60, 140), font=fnt, anchor="mm")
im.save(os.path.join(OUT, "rox_sign.png"))
print("textures ->", OUT, len(os.listdir(OUT)))
