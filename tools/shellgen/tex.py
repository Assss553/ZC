# ROX shell generator - procedural tileable textures  (c) ROX Store
import numpy as np, struct, os
from PIL import Image

N = 512

def fbm(beta=2.0, seed=0, n=N, ax=1.0, ay=1.0):
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)[:, None] * ay
    g = np.fft.fftfreq(n)[None, :] * ax
    r = np.sqrt(f * f + g * g); r[0, 0] = 1
    amp = r ** (-beta / 2.0); amp[0, 0] = 0
    a = np.fft.ifft2(amp * np.exp(2j * np.pi * rng.random((n, n)))).real
    return (a - a.min()) / (a.max() - a.min() + 1e-9)

def blur(a, sigma):
    n = a.shape[0]
    f = np.fft.fftfreq(n)[:, None]; g = np.fft.fftfreq(a.shape[1])[None, :]
    k = np.exp(-2 * (np.pi * sigma) ** 2 * (f * f + g * g))
    return np.fft.ifft2(np.fft.fft2(a) * k).real

def white(seed, n=N):
    return np.random.default_rng(seed).random((n, n))

def col(c):
    return np.array(c, dtype=np.float64)[None, None, :]

def shade(base, m):
    """base rgb (0-255), m multiplier map -> uint8 image"""
    return np.clip(col(base) * m[:, :, None], 0, 255).astype(np.uint8)

def mix(a, b, t):
    return a * (1 - t[:, :, None]) + b * t[:, :, None]

def normal_map(h, strength=2.0):
    """DirectX-style tangent normal map from a tileable height map (0..1)."""
    n = h.shape[0]
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * n / 512.0 * strength * 40
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * n / 512.0 * strength * 40
    nx, ny, nz = -dx, -dy, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    out = np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5
    return np.clip(out * 255, 0, 255).astype(np.uint8)

def spec_map(intensity, gloss=None):
    g = intensity if gloss is None else gloss
    return np.clip(np.stack([intensity, g, np.full_like(intensity, 0.5)], -1) * 255, 0, 255).astype(np.uint8)

# ---------------------------------------------------------------- materials
def paint(color, seed, mottle=0.05, dirt=0.0):
    m = 1 + mottle * (fbm(2.6, seed) - 0.5) + 0.012 * (white(seed + 1) - 0.5)
    if dirt:
        d = np.clip(fbm(2.2, seed + 5) * 1.6 - 0.7, 0, 1)
        m = m * (1 - dirt * d)
    h = fbm(1.0, seed + 2) * 0.25 + fbm(2.4, seed + 3) * 0.2
    return dict(d=shade(color, m), n=normal_map(h, 0.07))

def wallpaper(color, seed):
    y, x = np.mgrid[0:N, 0:N] / N
    weave = 0.5 + 0.25 * np.sin(x * 2 * np.pi * 128) * 1.0 + 0.25 * np.sin(y * 2 * np.pi * 96)
    weave = weave * (0.7 + 0.6 * fbm(1.0, seed, ax=6))
    m = 0.94 + 0.08 * weave + 0.07 * (fbm(2.8, seed + 1) - 0.5)
    # faint damask-like blotches
    b = np.clip(fbm(3.2, seed + 2) * 2 - 0.9, 0, 1)
    m = m * (1 - 0.04 * b)
    return dict(d=shade(color, m), n=normal_map(weave, 0.08))

def beadboard(color, seed, grooves=6):
    y, x = np.mgrid[0:N, 0:N] / N
    g = np.abs(((x * grooves) % 1.0) - 0.5) * 2          # 0 at centre of board, 1 at groove
    groove = np.clip((g - 0.9) / 0.1, 0, 1)
    h = 1 - groove ** 2
    m = (1 - 0.35 * groove) * (1 + 0.03 * (fbm(2.0, seed, ax=0.2) - 0.5))
    return dict(d=shade(color, m), n=normal_map(h, 0.9))

def concrete(color, seed, stains=0.18, cracks=3, gloss=0.25):
    base = 0.55 * fbm(2.4, seed) + 0.3 * fbm(1.4, seed + 1) + 0.15 * white(seed + 2)
    m = 0.86 + 0.28 * base
    st = np.clip(fbm(3.0, seed + 3) * 1.8 - 0.75, 0, 1)
    m = m * (1 - stains * st)
    h = base.copy()
    rng = np.random.default_rng(seed + 9)
    ck = np.zeros((N, N))
    for _ in range(cracks):
        p = rng.random(2) * N; a = rng.random() * 6.28
        for _ in range(int(N * 0.9)):
            ck[int(p[1]) % N, int(p[0]) % N] = 1
            a += (rng.random() - 0.5) * 0.5
            p += np.array([np.cos(a), np.sin(a)])
    ck = np.clip(blur(ck, 0.7) * 3.0, 0, 1)
    m = m * (1 - 0.22 * ck); h = h - 0.5 * ck
    pores = (white(seed + 4) > 0.9965).astype(float); pores = np.clip(blur(pores, 0.8) * 6, 0, 1)
    m = m * (1 - 0.25 * pores); h = h - 0.4 * pores
    sp = np.clip(gloss * (0.6 + 0.8 * fbm(2.6, seed + 6)) * (1 - 0.6 * st), 0, 1)
    return dict(d=shade(color, m), n=normal_map(h, 0.09), s=spec_map(sp, np.clip(sp * 1.4, 0, 1)))

def tiles(color, grout, seed, nx=4, ny=4, gap=0.012, var=0.07, gloss=0.6, bevel=0.03, speckle=0.0):
    y, x = np.mgrid[0:N, 0:N] / N
    fx, fy = (x * nx) % 1.0, (y * ny) % 1.0
    ix, iy = np.floor(x * nx).astype(int), np.floor(y * ny).astype(int)
    ex = np.minimum(fx, 1 - fx) / nx; ey = np.minimum(fy, 1 - fy) / ny   # distance to tile edge (in texture units)
    e = np.minimum(ex, ey)
    g = (e < gap / 2).astype(float)
    g = np.clip(blur(g, 0.6), 0, 1)
    rng = np.random.default_rng(seed)
    tint = (1 + var * (rng.random((ny, nx)) - 0.5) * 2)[iy % ny, ix % nx]
    m = tint * (0.95 + 0.1 * fbm(2.4, seed + 1)) * (1 + 0.02 * (white(seed + 2) - 0.5))
    if speckle:
        sp_ = (white(seed + 7) > 0.985).astype(float); m = m * (1 - speckle * np.clip(blur(sp_, 0.7) * 5, 0, 1))
    d = mix(col(color) * m[:, :, None], col(grout) * (0.9 + 0.2 * white(seed + 3))[:, :, None], g)
    h = np.clip((e - gap / 2) / bevel, 0, 1) ** 0.5 * (1 - g) + 0.02 * fbm(2.0, seed + 4)
    sp = gloss * (1 - g) * (0.85 + 0.3 * fbm(2.5, seed + 5))
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), n=normal_map(h, 0.22), s=spec_map(np.clip(sp, 0, 1)))

def wood_grain(seed, n=N, vertical=True, rings=7.0):
    a = fbm(1.6, seed, n, ax=1.0, ay=14.0) if vertical else fbm(1.6, seed, n, ax=14.0, ay=1.0)
    y, x = np.mgrid[0:n, 0:n] / n
    c = x if vertical else y
    warp = fbm(2.6, seed + 1, n) * 1.2
    r = 0.5 + 0.5 * np.sin((c * rings + warp * 3.0) * 2 * np.pi)
    return np.clip(0.55 * a + 0.3 * r + 0.15 * fbm(1.0, seed + 2, n, ax=1 if vertical else 30, ay=30 if vertical else 1), 0, 1)

def wood(c_dark, c_light, seed, vertical=True, gloss=0.3):
    g = wood_grain(seed, vertical=vertical)
    d = mix(col(c_dark) * np.ones((N, N, 1)), col(c_light) * np.ones((N, N, 1)), g)
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), n=normal_map(g, 0.08), s=spec_map(np.clip(gloss * (0.7 + 0.5 * g), 0, 1)))

def planks(c_dark, c_light, seed, rows=10, n=N, gloss=0.35):
    """planks running along x (u); `rows` planks across v."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / n
    row = np.floor(y * rows).astype(int) % rows
    off = rng.random(rows)[row]
    seg = np.floor((x + off) * 2.0).astype(int) % 2            # two boards per row
    pid = row * 2 + seg
    tone = rng.random(rows * 2)[pid]
    shift = rng.random(rows * 2)[pid]
    g = wood_grain(seed + 3, n, vertical=False, rings=9.0)
    g = np.take_along_axis(g, ((np.arange(n)[None, :] + (shift * n).astype(int)) % n), axis=1)
    fy = (y * rows) % 1.0
    fxs = ((x + off) * 2.0) % 1.0
    edge = np.minimum(np.minimum(fy, 1 - fy) / rows, np.minimum(fxs, 1 - fxs) / 2.0)
    gapm = np.clip(1 - edge / 0.0022, 0, 1)
    t = np.clip(0.25 + 0.5 * g + 0.45 * (tone - 0.5), 0, 1)
    d = mix(col(c_dark) * np.ones((n, n, 1)), col(c_light) * np.ones((n, n, 1)), t) * (1 - 0.6 * gapm)[:, :, None]
    h = g * 0.25 + (1 - gapm)
    sp = gloss * (1 - gapm) * (0.75 + 0.4 * g)
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), n=normal_map(h, 0.2), s=spec_map(np.clip(sp, 0, 1)))

def herringbone(c_dark, c_light, seed, n=1024, cells=20, ratio=5, gloss=0.4):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] * (cells / n)
    cx, cy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - cx, y - cy
    d_ = (cx - cy) % (2 * ratio)
    horiz = d_ < ratio
    sx = np.where(horiz, cx - d_, cx); sy = np.where(horiz, cy, cy - (2 * ratio - 1 - d_))
    pid = ((sx % cells) * 131 + (sy % cells) * 17 + horiz * 7919) % 4096
    tone = rng.random(4096)[pid]; shift = rng.random(4096)[pid]
    along = np.where(horiz, d_ + fx, (2 * ratio - 1 - d_) + fy) / ratio      # 0..1 along plank
    across = np.where(horiz, fy, fx)
    gbase = wood_grain(seed + 3, 512, vertical=False, rings=5.0)
    gi = ((along + shift) * 511).astype(int) % 512; gj = ((across * 0.18 + shift) * 511).astype(int) % 512
    g = gbase[gj, gi]
    edge = np.minimum(np.minimum(across, 1 - across), np.minimum(along, 1 - along) * ratio)
    gapm = np.clip(1 - edge / 0.035, 0, 1)
    t = np.clip(0.2 + 0.5 * g + 0.55 * (tone - 0.5), 0, 1)
    d = mix(col(c_dark) * np.ones((n, n, 1)), col(c_light) * np.ones((n, n, 1)), t) * (1 - 0.55 * gapm)[:, :, None]
    h = g * 0.2 + (1 - gapm)
    sp = gloss * (1 - gapm) * (0.75 + 0.4 * g)
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), n=normal_map(h, 0.2), s=spec_map(np.clip(sp, 0, 1)))

def carpet(color, seed):
    f = 0.5 * white(seed) + 0.5 * blur(white(seed + 1), 0.8)
    m = 0.82 + 0.3 * f + 0.08 * (fbm(2.6, seed + 2) - 0.5)
    return dict(d=shade(color, m), n=normal_map(blur(white(seed + 3), 0.6), 0.12))

def ceiling_tile(seed):
    y, x = np.mgrid[0:N, 0:N] / N
    e = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))
    bar = (e < 0.02).astype(float)
    fis = (blur(white(seed), 1.0) > 0.535).astype(float) * (fbm(1.5, seed + 1, ax=4) > 0.5)
    fis = np.clip(blur(fis, 0.6) * 1.4, 0, 1) * (1 - bar)
    m = 0.97 - 0.2 * fis - 0.05 * bar * 0 + 0.02 * (white(seed + 2) - 0.5)
    d = mix(col((236, 235, 230)) * m[:, :, None], col((214, 214, 212)) * np.ones((N, N, 1)), bar)
    h = 0.6 - 0.5 * fis + 0.4 * bar - 0.3 * np.clip(1 - np.abs(e - 0.02) / 0.006, 0, 1)
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), n=normal_map(h, 0.2))

def metal(color, seed, brushed=False, gloss=0.5):
    if brushed:
        a = fbm(1.4, seed, ax=1.0, ay=40.0)
        m = 0.9 + 0.2 * a
        return dict(d=shade(color, m), n=normal_map(a, 0.15), s=spec_map(np.clip(gloss * (0.8 + 0.4 * a), 0, 1), np.full((N, N), 0.8)))
    m = 0.93 + 0.1 * fbm(2.4, seed) + 0.03 * (white(seed + 1) - 0.5)
    return dict(d=shade(color, m), s=spec_map(np.clip(gloss * (0.7 + 0.5 * fbm(2.0, seed + 2)), 0, 1)))

def shutter(color, seed, slats=8):
    y, x = np.mgrid[0:N, 0:N] / N
    f = (y * slats) % 1.0
    prof = np.sin(f * np.pi) ** 0.6
    lip = np.clip(1 - f / 0.07, 0, 1)
    streak = fbm(2.0, seed, ax=30.0, ay=1.0)
    m = (0.78 + 0.22 * prof) * (1 - 0.35 * lip) * (0.93 + 0.12 * streak) * (1 - 0.1 * np.clip(fbm(2.8, seed + 1) * 2 - 1.0, 0, 1))
    return dict(d=shade(color, m), n=normal_map(prof * 0.8 - lip * 0.5, 1.6), s=spec_map(np.clip(0.35 * prof, 0, 1)))

def window_day(seed):
    y, x = np.mgrid[0:N, 0:N] / N
    sky = mix(col((250, 248, 240)) * np.ones((N, N, 1)), col((196, 216, 236)) * np.ones((N, N, 1)), np.clip(y * 1.2, 0, 1))
    b = blur((fbm(2.2, seed) > 0.58).astype(float) * (y > 0.45), 14)
    d = sky * (1 - 0.35 * np.clip(b * 1.6, 0, 1))[:, :, None]
    d = d * (0.97 + 0.06 * blur(white(seed + 1), 3))[:, :, None]
    return dict(d=np.clip(d, 0, 255).astype(np.uint8))

def window_dark(seed):
    y, x = np.mgrid[0:N, 0:N] / N
    m = 0.75 + 0.5 * fbm(3.0, seed) - 0.2 * y
    refl = np.clip(blur((fbm(2.4, seed + 1) > 0.62).astype(float), 10) * 1.2, 0, 1)
    d = col((36, 42, 48)) * m[:, :, None] + col((70, 82, 92)) * refl[:, :, None]
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), s=spec_map(np.full((N, N), 0.9), np.full((N, N), 0.95)))

def light_panel(seed):
    y, x = np.mgrid[0:N, 0:N] / N
    e = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))
    v = 0.86 + 0.14 * np.clip(e / 0.18, 0, 1)
    pr = 0.985 + 0.015 * np.sin(x * 2 * np.pi * 64) * np.sin(y * 2 * np.pi * 64)
    return dict(d=shade((255, 250, 240), v * pr))

def fabric(color, seed, folds=4):
    y, x = np.mgrid[0:N, 0:N] / N
    f = (y * folds) % 1.0
    fold = 0.5 + 0.5 * np.cos(f * 2 * np.pi)
    weave = 0.5 + 0.5 * np.sin(x * 2 * np.pi * 150) * np.sin(y * 2 * np.pi * 150)
    m = (0.74 + 0.3 * fold) * (0.95 + 0.07 * weave) * (0.96 + 0.08 * fbm(2.4, seed))
    return dict(d=shade(color, m), n=normal_map(fold * 0.8 + weave * 0.04, 1.0))

def cardboard(seed):
    y, x = np.mgrid[0:N, 0:N] / N
    corr = 0.5 + 0.5 * np.sin(x * 2 * np.pi * 90)
    m = 0.9 + 0.06 * corr + 0.14 * (fbm(2.6, seed) - 0.5)
    d = col((168, 132, 88)) * m[:, :, None]
    rng = np.random.default_rng(seed)
    # newspaper sheets + tape
    for _ in range(3):
        x0, y0 = rng.random() * 0.6, rng.random() * 0.6; w, h = 0.25 + rng.random() * 0.2, 0.3 + rng.random() * 0.2
        mk = ((x > x0) & (x < x0 + w) & (y > y0) & (y < y0 + h))
        txt = (blur(white(int(rng.integers(1e6))), 0.5) > 0.52) & ((y * 70 % 1.0) > 0.35) & ((x * 5 % 1.0) > 0.08)
        paper = col((206, 198, 170)) * (0.92 + 0.1 * fbm(2.5, seed + 4))[:, :, None] * (1 - 0.45 * txt)[:, :, None]
        d = np.where(mk[:, :, None], paper, d)
    for _ in range(4):
        y0 = rng.random(); mk = (np.abs(y - y0) < 0.018)
        d = np.where(mk[:, :, None], col((196, 170, 110)) * np.ones((N, N, 1)), d)
    st = np.clip(fbm(3.0, seed + 8) * 2 - 1.1, 0, 1)
    d = d * (1 - 0.35 * st)[:, :, None]
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), n=normal_map(corr * 0.2 + fbm(2.0, seed + 9) * 0.5, 0.4))

def granite(color, seed, gloss=0.7):
    a = blur(white(seed), 1.2); b = blur(white(seed + 1), 2.5)
    sp1 = np.clip((a - 0.5) * 9, -1, 1); sp2 = np.clip((b - 0.5) * 14, -1, 1)
    m = 0.9 + 0.12 * sp1 + 0.1 * sp2 + 0.08 * (fbm(2.5, seed + 2) - 0.5)
    dark = (white(seed + 3) > 0.975).astype(float); dark = np.clip(blur(dark, 0.9) * 5, 0, 1)
    d = col(color) * m[:, :, None] * (1 - 0.5 * dark)[:, :, None]
    return dict(d=np.clip(d, 0, 255).astype(np.uint8), s=spec_map(np.full((N, N), gloss), np.full((N, N), 0.9)))

def door_panel(color, seed, panels=True, gloss=0.3):
    y, x = np.mgrid[0:N, 0:N] / N
    m = 0.94 + 0.1 * fbm(2.4, seed, ax=6) + 0.02 * (white(seed + 1) - 0.5)
    h = np.zeros((N, N))
    if panels:
        for (x0, y0, x1, y1) in [(0.14, 0.06, 0.86, 0.40), (0.14, 0.47, 0.86, 0.60), (0.14, 0.67, 0.86, 0.95)]:
            dx = np.minimum(x - x0, x1 - x); dy = np.minimum(y - y0, y1 - y); e = np.minimum(dx, dy)
            inside = e > 0
            rim = np.clip(1 - np.abs(e - 0.012) / 0.012, 0, 1) * inside
            h += inside * 0.5 - rim * 0.6
            m = m * (1 - 0.22 * rim)
    return dict(d=shade(color, m), n=normal_map(blur(h, 1.0) + 0.02 * fbm(2, seed + 2, ax=8), 0.6), s=spec_map(np.full((N, N), gloss)))

def build_all():
    T = {}
    T['rox_paint_white'] = paint((232, 230, 224), 1)
    T['rox_paint_cream'] = paint((222, 208, 180), 2)
    T['rox_paint_grey'] = paint((176, 178, 178), 3)
    T['rox_paint_dkblue'] = paint((62, 68, 82), 4, mottle=0.12, dirt=0.25)
    T['rox_paint_maroon'] = paint((92, 26, 30), 5, mottle=0.06)
    T['rox_wallpaper_beige'] = wallpaper((186, 160, 118), 6)
    T['rox_wainscot_white'] = beadboard((222, 218, 208), 7)
    T['rox_concrete_floor'] = concrete((150, 146, 140), 8, cracks=1, gloss=0.3)
    T['rox_concrete_wall'] = concrete((172, 168, 160), 9, stains=0.25, cracks=1, gloss=0.08)
    T['rox_floor_bluegrey'] = concrete((108, 124, 146), 10, stains=0.1, cracks=0, gloss=0.55)
    T['rox_parquet_herringbone'] = herringbone((120, 72, 38), (186, 128, 76), 11)
    T['rox_wood_planks'] = planks((112, 78, 48), (178, 136, 92), 12)
    T['rox_tile_terracotta'] = tiles((150, 112, 78), (86, 74, 62), 13, 4, 4, var=0.09, gloss=0.45)
    T['rox_tile_beige'] = tiles((214, 198, 170), (150, 142, 128), 14, 4, 4, var=0.05, gloss=0.6)
    T['rox_tile_white'] = tiles((236, 236, 232), (170, 172, 172), 15, 4, 6, var=0.02, gloss=0.8)
    T['rox_carpet_grey'] = carpet((120, 118, 114), 16)
    T['rox_ceiling_tile'] = ceiling_tile(17)
    T['rox_wood_dark'] = wood((38, 24, 16), (84, 54, 34), 18)
    T['rox_wood_door'] = wood((122, 70, 34), (176, 112, 62), 19)
    T['rox_trim_white'] = paint((238, 236, 230), 20, mottle=0.02)
    T['rox_metal_dark'] = metal((34, 35, 38), 21, gloss=0.4)
    T['rox_metal_steel'] = metal((176, 180, 184), 22, brushed=True, gloss=0.75)
    T['rox_metal_brass'] = metal((150, 112, 58), 23, gloss=0.7)
    T['rox_shutter'] = shutter((188, 186, 176), 24)
    T['rox_door_grey'] = door_panel((98, 100, 102), 25, panels=False, gloss=0.35)
    T['rox_door_maroon'] = door_panel((86, 22, 26), 26, panels=True)
    T['rox_door_wood'] = door_panel((150, 92, 48), 27, panels=True)
    T['rox_window_day'] = window_day(28)
    T['rox_window_dark'] = window_dark(29)
    T['rox_light_panel'] = light_panel(30)
    T['rox_blind_fabric'] = fabric((176, 106, 72), 31)
    T['rox_cardboard'] = cardboard(32)
    T['rox_countertop'] = granite((176, 150, 112), 33)
    T['rox_appliance_white'] = metal((228, 228, 226), 34, gloss=0.6)
    T['rox_black_glass'] = metal((14, 14, 16), 35, gloss=0.95)
    return T

# ---------------------------------------------------------------- DDS (BC1) writer
def _bc1_blocks(img):
    h, w, _ = img.shape
    b = img.reshape(h // 4, 4, w // 4, 4, 3).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 3).astype(np.float64)
    mean = b.mean(1, keepdims=True); c = b - mean
    axis = (c.max(1) - c.min(1))                     # rough principal axis
    cov = np.einsum('bij,bik->bjk', c, c)
    for _ in range(4):
        axis = np.einsum('bjk,bk->bj', cov, axis); axis /= (np.linalg.norm(axis, axis=1, keepdims=True) + 1e-9)
    t = np.einsum('bij,bj->bi', c, axis)
    hi = mean[:, 0] + axis * t.max(1, keepdims=True); lo = mean[:, 0] + axis * t.min(1, keepdims=True)
    def q565(cc):
        cc = np.clip(cc, 0, 255)
        r = np.round(cc[:, 0] * 31 / 255).astype(np.uint32); g = np.round(cc[:, 1] * 63 / 255).astype(np.uint32); bl = np.round(cc[:, 2] * 31 / 255).astype(np.uint32)
        return (r << 11) | (g << 5) | bl
    def un565(v):
        return np.stack([((v >> 11) & 31) * 255 / 31, ((v >> 5) & 63) * 255 / 63, (v & 31) * 255 / 31], -1)
    c0, c1 = q565(hi), q565(lo)
    sw = c0 < c1; c0, c1 = np.where(sw, c1, c0), np.where(sw, c0, c1)
    p0, p1 = un565(c0), un565(c1)
    pal = np.stack([p0, p1, (2 * p0 + p1) / 3, (p0 + 2 * p1) / 3], 1)        # (B,4,3)
    dist = ((b[:, :, None, :] - pal[:, None, :, :]) ** 2).sum(-1)             # (B,16,4)
    idx = dist.argmin(-1).astype(np.uint32)
    idx = np.where((c0 == c1)[:, None], 0, idx)
    bits = (idx << (2 * np.arange(16, dtype=np.uint32))[None, :]).sum(1).astype(np.uint32)
    out = np.zeros(len(b), dtype=[('c0', '<u2'), ('c1', '<u2'), ('i', '<u4')])
    out['c0'], out['c1'], out['i'] = c0, c1, bits
    return out.tobytes()

def mips(img):
    out = [img]
    while out[-1].shape[0] > 4:
        a = out[-1].astype(np.float64)
        a = (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4
        out.append(np.clip(a + 0.5, 0, 255).astype(np.uint8))
    return out

def write_dds(path, img):
    ml = mips(img[:, :, :3])
    h, w = img.shape[:2]
    data = b''.join(_bc1_blocks(m) for m in ml)
    DDSD = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000
    hdr = struct.pack('<4sIIIIIII44x', b'DDS ', 124, DDSD, h, w, max(1, w // 4) * max(1, h // 4) * 8, 0, len(ml))
    pf = struct.pack('<II4sIIIII', 32, 0x4, b'DXT1', 0, 0, 0, 0, 0)
    caps = struct.pack('<IIIII', 0x1000 | 0x8 | 0x400000, 0, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(hdr + pf + caps + data)
    return len(ml)

if __name__ == '__main__':
    import sys
    out = sys.argv[1]
    os.makedirs(out + '/dds', exist_ok=True); os.makedirs(out + '/png', exist_ok=True)
    T = build_all()
    index = {}
    for name, t in T.items():
        for k, suf in (('d', ''), ('n', '_n'), ('s', '_s')):
            if k in t:
                nm = name + suf
                lv = write_dds(f'{out}/dds/{nm}.dds', t[k])
                Image.fromarray(t[k]).save(f'{out}/png/{nm}.png')
                index[nm] = [int(t[k].shape[1]), int(t[k].shape[0]), lv]
    import json; json.dump(index, open(out + '/textures.json', 'w'), indent=1)
    print(len(index), 'textures', sum(os.path.getsize(f'{out}/dds/{f}') for f in os.listdir(out + '/dds')) // 1024, 'KB')
