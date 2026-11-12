# ROX build pieces: walls, floors, upper-floor slabs, stairs, doors, bathroom, kitchen ...  (c) ROX Store
# Small placeable models (with collision) sold in the furniture shop, used to build the inside of the
# empty ROX open houses. Origin = centre of the piece at floor level.
import math
import numpy as np
from kit import Shell, MATS, X, Y, Z
from street import extrude, sphere

TXD = 'rox_build_txd'
CAT = []      # catalogue rows: (model, label, labelAr, cat, price)
PIECES = []


def new(model, label, label_ar, cat, price):
    s = Shell('rox_b_' + model, label, label_ar)
    s.txd, s.lod = TXD, 120
    s.cat = (s.name, label, label_ar, cat, int(price))
    PIECES.append(s)
    return s


def done(s, x0, y0, x1, y1, h):
    s.bb = (x0, y0, 0, x1, y1, h)
    return s


WALLS = [  # key, material, English, Arabic
    ('white', 'paint_white', 'White', 'أبيض'), ('cream', 'paint_cream', 'Cream', 'كريمي'), ('grey', 'paint_grey', 'Grey', 'رمادي'),
    ('sand', 'paint_sand', 'Sand', 'رملي'), ('sage', 'paint_sage', 'Sage', 'أخضر فاتح'), ('sky', 'paint_sky', 'Sky Blue', 'سماوي'),
    ('blush', 'paint_blush', 'Blush', 'وردي فاتح'), ('navy', 'paint_navy', 'Navy', 'كحلي'), ('dkblue', 'paint_dkblue', 'Slate Blue', 'أزرق غامق'),
    ('maroon', 'paint_maroon', 'Maroon', 'عنابي'), ('red', 'paint_red', 'Red', 'أحمر'), ('green', 'paint_green', 'Green', 'أخضر'),
    ('ochre', 'paint_ochre', 'Ochre', 'أصفر ترابي'), ('black', 'paint_black', 'Black', 'أسود'), ('charcoal', 'paint_charcoal', 'Charcoal', 'فحمي'),
    ('teal', 'paint_teal', 'Teal', 'تركوازي'), ('mint', 'paint_mint', 'Mint', 'نعناعي'), ('purple', 'paint_purple', 'Purple', 'بنفسجي'),
    ('pink', 'paint_pink', 'Pink', 'وردي'), ('orange', 'paint_orange', 'Orange', 'برتقالي'), ('yellow', 'paint_yellow2', 'Yellow', 'أصفر'),
    ('olive', 'paint_olive', 'Olive', 'زيتي'), ('brown', 'paint_brown', 'Brown', 'بني'), ('lilac', 'paint_lilac', 'Lilac', 'بنفسجي فاتح'),
    ('wallpaper', 'wallpaper', 'Wallpaper', 'ورق جدران'), ('brick', 'brick_red', 'Red Brick', 'طوب أحمر'), ('brickw', 'brick_white', 'White Brick', 'طوب أبيض'),
    ('brickd', 'brick_dark', 'Dark Brick', 'طوب غامق'), ('concrete', 'concrete_wall', 'Concrete', 'خرسانة'), ('stone', 'stone', 'Stone', 'حجر'),
    ('tilew', 'tile_white', 'White Tile', 'بلاط أبيض'), ('tileb', 'tile_beige', 'Beige Tile', 'بلاط بيج'), ('wood', 'planks', 'Wood', 'خشب'),
]
MATS['paint_yellow2'] = dict(tex='rox_paint_yellow', sh='n', tile=2.0, spec=0.06, col=101)

FLOORS = [
    ('planks', 'planks', 'Wood Planks', 'خشب'), ('parquet', 'parquet', 'Parquet', 'باركيه'), ('dark', 'wood_dark', 'Dark Wood', 'خشب غامق'),
    ('carpet', 'carpet', 'Grey Carpet', 'موكيت رمادي'), ('terra', 'tile_terra', 'Terracotta Tile', 'بلاط تيراكوتا'), ('beige', 'tile_beige', 'Beige Tile', 'بلاط بيج'),
    ('white', 'tile_white', 'White Tile', 'بلاط أبيض'), ('concrete', 'concrete_floor', 'Polished Concrete', 'خرسانة مصقولة'), ('blue', 'floor_blue', 'Blue Epoxy', 'إيبوكسي أزرق'),
    ('stone', 'stone', 'Stone Slabs', 'حجر'), ('granite', 'countertop', 'Granite', 'جرانيت'), ('pavement', 'pavement', 'Paving', 'رصيف'),
    ('grass', 'grass', 'Grass', 'عشب'), ('rugred', 'rug_red', 'Red Carpet', 'موكيت أحمر'), ('rugblue', 'rug_blue', 'Blue Carpet', 'موكيت أزرق'),
    ('rugcream', 'rug_cream', 'Cream Carpet', 'موكيت كريمي'),
]
WOODS = [('oak', 'wood_door', 'Oak', 'بلوط'), ('walnut', 'wood_dark', 'Walnut', 'جوز'), ('white', 'trim', 'White', 'أبيض'), ('black', 'metal_dark', 'Black', 'أسود')]
DOORS = [('wood', 'door_wood', 'Wood', 'خشبي'), ('maroon', 'door_maroon', 'Maroon', 'عنابي'), ('grey', 'door_grey', 'Grey', 'رمادي'), ('blue', 'door_blue', 'Blue', 'أزرق'),
         ('green', 'door_green', 'Green', 'أخضر'), ('black', 'door_black', 'Black', 'أسود'), ('white', 'door_white', 'White', 'أبيض'), ('red', 'door_red', 'Red', 'أحمر'),
         ('yellow', 'door_yellow', 'Yellow', 'أصفر')]
TH = 0.12


def wall(s, mat, L, H, holes=(), th=TH, frame='trim'):
    """Two-sided wall centred on the origin, along X. holes: (a0, z0, a1, z1) measured from the left end."""
    s.surf(mat, (-L / 2, -th / 2, 0), X, Z, L, H, holes=list(holes), step=1.0)
    s.surf(mat, (L / 2, th / 2, 0), -X, Z, L, H, holes=[(L - h[2], h[1], L - h[0], h[3]) for h in holes], step=1.0)
    s.box(mat, -L / 2, -th / 2, 0, L / 2, th / 2, H, faces='xXZ')
    xs = sorted({0.0, L} | {h[0] for h in holes} | {h[2] for h in holes})
    col = MATS[mat]['col']
    for i in range(len(xs) - 1):
        a, b = xs[i], xs[i + 1]
        hs = [h for h in holes if h[0] <= a + 1e-6 and h[2] >= b - 1e-6]
        if not hs: s.cbox(a - L / 2, -th / 2, 0, b - L / 2, th / 2, H, col)
        else:
            h = hs[0]
            if h[1] > 0.01: s.cbox(a - L / 2, -th / 2, 0, b - L / 2, th / 2, h[1], col)
            if h[3] < H - 0.01: s.cbox(a - L / 2, -th / 2, h[3], b - L / 2, th / 2, H, col)
    for (a0, z0, a1, z1) in holes:                      # lining of the opening
        x0, x1 = a0 - L / 2, a1 - L / 2
        s.box(frame, x0, -th / 2 - 0.015, z0, x0 + 0.03, th / 2 + 0.015, z1)
        s.box(frame, x1 - 0.03, -th / 2 - 0.015, z0, x1, th / 2 + 0.015, z1)
        s.box(frame, x0, -th / 2 - 0.015, z1 - 0.03, x1, th / 2 + 0.015, z1)
        if z0 > 0.01: s.box(frame, x0 - 0.03, -th / 2 - 0.04, z0 - 0.03, x1 + 0.03, th / 2 + 0.04, z0)


def glazing(s, L, a0, z0, a1, z1, cols=2):
    x0, x1 = a0 - L / 2, a1 - L / 2
    for k in range(1, cols):
        x = x0 + (x1 - x0) * k / cols
        s.box('trim', x - 0.02, -0.02, z0, x + 0.02, 0.02, z1)
    s.box('window_dark', x0 + 0.03, -0.006, z0, x1 - 0.03, 0.006, z1 - 0.03, faces='yY')
    s.cbox(x0, -0.02, z0, x1, 0.02, z1, 114, occ=False)


def build_walls():
    H = 2.9
    for (k, m, en, ar) in WALLS:
        for L in (1, 2, 3, 4, 6):
            s = new(f'wall_{k}_{L}m', f'Wall {L}m · {en}', f'جدار {L}م · {ar}', 'walls', 60 + 45 * L)
            wall(s, m, L, H); done(s, -L / 2, -TH, L / 2, TH, H)
        s = new(f'wall_{k}_tall4', f'Tall Wall 4m (2 floors) · {en}', f'جدار عالي 4م (دورين) · {ar}', 'walls', 420)
        wall(s, m, 4, 5.8); done(s, -2, -TH, 2, TH, 5.8)
        s = new(f'wall_{k}_half2', f'Half Wall 2m · {en}', f'نصف جدار 2م · {ar}', 'walls', 90)
        wall(s, m, 2, 1.1); s.box('trim', -1.02, -0.09, 1.1, 1.02, 0.09, 1.14); done(s, -1, -TH, 1, TH, 1.14)
        s = new(f'wall_{k}_door', f'Door Wall 2m · {en}', f'جدار بفتحة باب 2م · {ar}', 'walls', 190)
        wall(s, m, 2, H, [(0.5, 0, 1.5, 2.1)]); done(s, -1, -TH, 1, TH, H)
        s = new(f'wall_{k}_arch', f'Wide Opening Wall 4m · {en}', f'جدار بفتحة واسعة 4م · {ar}', 'walls', 320)
        wall(s, m, 4, H, [(0.7, 0, 3.3, 2.3)]); done(s, -2, -TH, 2, TH, H)
        s = new(f'wall_{k}_win2', f'Window Wall 2m · {en}', f'جدار بشباك 2م · {ar}', 'walls', 240)
        wall(s, m, 2, H, [(0.4, 0.9, 1.6, 2.15)]); glazing(s, 2, 0.4, 0.9, 1.6, 2.15); done(s, -1, -TH, 1, TH, H)
        s = new(f'wall_{k}_win4', f'Window Wall 4m · {en}', f'جدار بشباك 4م · {ar}', 'walls', 380)
        wall(s, m, 4, H, [(0.8, 0.9, 3.2, 2.15)]); glazing(s, 4, 0.8, 0.9, 3.2, 2.15, cols=3); done(s, -2, -TH, 2, TH, H)
        s = new(f'pillar_{k}', f'Square Pillar · {en}', f'عمود مربع · {ar}', 'walls', 150)
        s.box(m, -0.2, -0.2, 0, 0.2, 0.2, H, faces='xXyYZ', col=True, occ=True); s.box('trim', -0.23, -0.23, 0, 0.23, 0.23, 0.12, faces='xXyYZ'); done(s, -0.23, -0.23, 0.23, 0.23, H)


def build_floors():
    for (k, m, en, ar) in FLOORS:
        for (a, b) in ((1, 1), (2, 2), (4, 4), (2, 4)):
            s = new(f'floor_{k}_{a}x{b}', f'Floor {a}x{b}m · {en}', f'أرضية {a}×{b}م · {ar}', 'floors', 18 * a * b + 20)
            s.box(m, -a / 2, -b / 2, 0, a / 2, b / 2, 0.025, faces='xXyYZ', step=1.0); s.cbox(-a / 2, -b / 2, 0, a / 2, b / 2, 0.025, MATS[m]['col'])
            done(s, -a / 2, -b / 2, a / 2, b / 2, 0.03)
    # upper floor slabs: the top is 3.0 m above the floor you place them on (matches the 3 m stairs)
    for (k, m, en, ar) in FLOORS[:10]:
        for (a, b) in ((2, 2), (4, 4), (2, 4), (4, 6)):
            s = new(f'slab_{k}_{a}x{b}', f'Upper Floor {a}x{b}m · {en}', f'أرضية دور ثاني {a}×{b}م · {ar}', 'levels', 60 * a * b + 80)
            s.box(m, -a / 2, -b / 2, 2.8, a / 2, b / 2, 3.0, faces='Z', step=1.0)
            s.box('paint_white', -a / 2, -b / 2, 2.8, a / 2, b / 2, 3.0, faces='xXyYz', step=1.0)
            s.cbox(-a / 2, -b / 2, 2.8, a / 2, b / 2, 3.0, MATS[m]['col'])
            done(s, -a / 2, -b / 2, a / 2, b / 2, 3.0)
    for (a, b) in ((2, 2), (4, 4), (4, 6)):
        for (k, m, en, ar) in (('white', 'paint_white', 'White', 'أبيض'), ('tile', 'ceiling_tile', 'Tiles', 'بلاطات'), ('wood', 'planks', 'Wood', 'خشب')):
            s = new(f'ceiling_{k}_{a}x{b}', f'Ceiling {a}x{b}m · {en}', f'سقف {a}×{b}م · {ar}', 'levels', 30 * a * b)
            s.box(m, -a / 2, -b / 2, 2.9, a / 2, b / 2, 2.96, faces='xXyYzZ', step=1.0); s.cbox(-a / 2, -b / 2, 2.9, a / 2, b / 2, 2.96, 101)
            done(s, -a / 2, -b / 2, a / 2, b / 2, 2.96)


def stair(s, mat, w, rise_total, n, run=0.27, rail='wood_dark'):
    r = rise_total / n
    prof = [(0, 0)]
    for i in range(n):
        prof += [(i * run, (i + 1) * r), ((i + 1) * run, (i + 1) * r)]
    prof.append((n * run, 0))
    Ln = n * run
    extrude(s, mat, prof, (-w / 2, -Ln / 2, 0), Y, X, w, fan=len(prof) - 1, skip=(len(prof) - 1,))
    for i in range(n):                                   # white risers
        y = -Ln / 2 + i * run
        s.box('trim', -w / 2, y - 0.004, i * r, w / 2, y, (i + 1) * r - 0.03, faces='y')
    a, b = np.array([-w / 2, -Ln / 2, 0.0]), np.array([w / 2, -Ln / 2, 0.0])
    c, d = np.array([w / 2, Ln / 2, rise_total]), np.array([-w / 2, Ln / 2, rise_total])
    s.ctris += [(a, b, c, 72), (a, c, d, 72)]
    for k in range(0, n, 3):                             # solid underneath (stays below the ramp)
        y0, y1 = -Ln / 2 + k * run, -Ln / 2 + min(n, k + 3) * run
        if k: s.cbox(-w / 2, y0, 0, w / 2, y1, k * r, 72, occ=False)
    if rail:
        for sx in (-w / 2 + 0.03, w / 2 - 0.03):
            for i in range(0, n + 1, 2):
                y, z = -Ln / 2 + min(i, n - 0.2) * run + 0.1, min(i + 1, n) * r
                s.box(rail, sx - 0.02, y - 0.02, z, sx + 0.02, y + 0.02, z + 0.9)
            O = np.array([sx - 0.025, -Ln / 2 + 0.1, r + 0.9]); E = np.array([0, Ln - 0.2, rise_total - r])
            ln = float(np.linalg.norm(E)); E /= ln; up = np.cross(X, E)
            s.quad(rail, O, E, X, ln, 0.05); s.quad(rail, O + X * 0.05 - up * 0.05, E, -X, ln, 0.05)
            s.quad(rail, O - up * 0.05, E, up, ln, 0.05); s.quad(rail, O + X * 0.05, E, -up, ln, 0.05) if False else s.quad(rail, O + X * 0.05 - up * 0.05, E, up, ln, 0.05)
        s.cbox(-w / 2, -Ln / 2, 0, -w / 2 + 0.05, Ln / 2, 0.01, 72, occ=False)
    return Ln


def build_stairs():
    mats = [('oak', 'wood_door', 'Oak', 'بلوط'), ('walnut', 'wood_dark', 'Walnut', 'جوز'), ('planks', 'planks', 'Pine', 'صنوبر'), ('concrete', 'concrete_floor', 'Concrete', 'خرسانة'),
            ('white', 'tile_white', 'White Tile', 'بلاط أبيض'), ('beige', 'tile_beige', 'Beige Tile', 'بلاط بيج'), ('stone', 'stone', 'Stone', 'حجر'), ('carpet', 'carpet', 'Carpet', 'موكيت')]
    for (k, m, en, ar) in mats:
        for (w, wn) in ((1.0, '1m'), (1.5, '1.5m')):
            s = new(f'stairs_{k}_{wn}', f'Stairs to Upper Floor ({wn} wide) · {en}', f'درج للدور الثاني (عرض {wn}) · {ar}', 'levels', 900 + 400 * w)
            Ln = stair(s, m, w, 3.0, 16); done(s, -w / 2, -Ln / 2, w / 2, Ln / 2, 3.9)
            s = new(f'stairs_{k}_{wn}_norail', f'Stairs, no rail ({wn} wide) · {en}', f'درج بدون درابزين (عرض {wn}) · {ar}', 'levels', 800 + 400 * w)
            Ln = stair(s, m, w, 3.0, 16, rail=None); done(s, -w / 2, -Ln / 2, w / 2, Ln / 2, 3.0)
        s = new(f'stairs_{k}_half', f'Half Stairs (1.5m high) · {en}', f'نصف درج (ارتفاع 1.5م) · {ar}', 'levels', 600)
        Ln = stair(s, m, 1.2, 1.5, 8, rail=None); done(s, -0.6, -Ln / 2, 0.6, Ln / 2, 1.5)
        s = new(f'steps_{k}', f'Steps (3 steps) · {en}', f'عتبات (3 درجات) · {ar}', 'levels', 220)
        Ln = stair(s, m, 1.6, 0.54, 3, run=0.3, rail=None); done(s, -0.8, -Ln / 2, 0.8, Ln / 2, 0.54)
        s = new(f'landing_{k}', f'Landing 1.5x1.5m (1.5m high) · {en}', f'بسطة درج 1.5×1.5م (ارتفاع 1.5م) · {ar}', 'levels', 350)
        s.box(m, -0.75, -0.75, 1.35, 0.75, 0.75, 1.5, faces='xXyYzZ', col=True)
        for (x, y) in ((-0.68, -0.68), (0.68, -0.68), (-0.68, 0.68), (0.68, 0.68)): s.box('trim', x - 0.05, y - 0.05, 0, x + 0.05, y + 0.05, 1.35, faces='xXyY')
        done(s, -0.75, -0.75, 0.75, 0.75, 1.5)
    rails = [('wood', 'wood_dark', 'Wood', 'خشب'), ('white', 'trim', 'White', 'أبيض'), ('black', 'metal_dark', 'Black Metal', 'معدن أسود'), ('steel', 'steel', 'Steel', 'ستيل')]
    for (k, m, en, ar) in rails:
        for L in (1, 2, 4):
            s = new(f'rail_{k}_{L}m', f'Railing {L}m · {en}', f'درابزين {L}م · {ar}', 'levels', 60 + 50 * L)
            s.box(m, -L / 2, -0.03, 0.9, L / 2, 0.03, 0.96); s.box(m, -L / 2, -0.015, 0.08, L / 2, 0.015, 0.11)
            n = int(L / 0.14)
            for i in range(n + 1):
                x = -L / 2 + 0.02 + (L - 0.04) * i / n
                s.box(m, x - 0.012, -0.012, 0.11, x + 0.012, 0.012, 0.9, faces='xXyY')
            s.cbox(-L / 2, -0.04, 0, L / 2, 0.04, 0.96, 56, occ=False); done(s, -L / 2, -0.05, L / 2, 0.05, 0.96)
        s = new(f'rail_{k}_glass2m', f'Glass Railing 2m · {en} posts', f'درابزين زجاج 2م · أعمدة {ar}', 'levels', 260)
        for x in (-0.97, 0.97): s.box(m, x - 0.03, -0.03, 0, x + 0.03, 0.03, 1.0)
        s.box(m, -1, -0.03, 0.98, 1, 0.03, 1.02); s.box('window_dark', -0.94, -0.006, 0.08, 0.94, 0.006, 0.95, faces='yY')
        s.cbox(-1, -0.04, 0, 1, 0.04, 1.02, 114, occ=False); done(s, -1, -0.05, 1, 0.05, 1.02)


def build_doors():
    for (k, m, en, ar) in DOORS:
        s = new(f'door_{k}_closed', f'Door with Frame (closed) · {en}', f'باب بإطار (مقفل) · {ar}', 'doors', 380)
        for x in (-0.5, 0.45): s.box('trim', x, -0.07, 0, x + 0.05, 0.07, 2.15)
        s.box('trim', -0.5, -0.07, 2.1, 0.5, 0.07, 2.15)
        s.surf(m, (-0.45, -0.022, 0), X, Z, 0.9, 2.1, step=0, fit=True); s.surf(m, (0.45, 0.022, 0), -X, Z, 0.9, 2.1, step=0, fit=True)
        s.box('steel', 0.3, -0.07, 1.0, 0.4, 0.07, 1.03); s.cbox(-0.5, -0.05, 0, 0.5, 0.05, 2.15, 70); done(s, -0.5, -0.07, 0.5, 0.07, 2.15)
        s = new(f'door_{k}_open', f'Door with Frame (open) · {en}', f'باب بإطار (مفتوح) · {ar}', 'doors', 380)
        for x in (-0.5, 0.45):
            s.box('trim', x, -0.07, 0, x + 0.05, 0.07, 2.15); s.cbox(x, -0.07, 0, x + 0.05, 0.07, 2.15, 70, occ=False)
        s.box('trim', -0.5, -0.07, 2.1, 0.5, 0.07, 2.15); s.cbox(-0.5, -0.07, 2.1, 0.5, 0.07, 2.15, 70, occ=False)
        s.obox(m, -0.45 + 0.04, 0.45, 0, 0.9, 0.04, 2.1, 95, fit=True); s.cbox(-0.47, 0, 0, -0.38, 0.9, 2.1, 70, occ=False)
        done(s, -0.5, -0.07, 0.5, 0.9, 2.15)
        s = new(f'door_{k}_double', f'Double Door (closed) · {en}', f'باب دبل (مقفل) · {ar}', 'doors', 640)
        for x in (-0.95, 0.9): s.box('trim', x, -0.07, 0, x + 0.05, 0.07, 2.15)
        s.box('trim', -0.95, -0.07, 2.1, 0.95, 0.07, 2.15)
        for x0 in (-0.9, 0.0):
            s.surf(m, (x0, -0.022, 0), X, Z, 0.9, 2.1, step=0, fit=True); s.surf(m, (x0 + 0.9, 0.022, 0), -X, Z, 0.9, 2.1, step=0, fit=True)
        s.box('steel', -0.12, -0.07, 1.0, 0.12, 0.07, 1.03); s.cbox(-0.95, -0.05, 0, 0.95, 0.05, 2.15, 70); done(s, -0.95, -0.07, 0.95, 0.07, 2.15)
    for (k, m, en, ar) in WOODS:
        for (w, wn) in ((1.2, '1.2m'), (2.4, '2.4m')):
            s = new(f'window_{k}_{wn}', f'Window Frame {wn} · {en}', f'إطار شباك {wn} · {ar}', 'doors', 180 + 80 * w)
            for x in (-w / 2, w / 2 - 0.05): s.box(m, x, -0.04, 0.9, x + 0.05, 0.04, 2.15)
            for z in (0.9, 2.1): s.box(m, -w / 2, -0.04, z, w / 2, 0.04, z + 0.05)
            for i in range(1, int(w / 0.6)):
                x = -w / 2 + w * i / int(w / 0.6); s.box(m, x - 0.02, -0.03, 0.95, x + 0.02, 0.03, 2.1)
            s.box('window_dark', -w / 2 + 0.05, -0.006, 0.95, w / 2 - 0.05, 0.006, 2.1, faces='yY'); s.cbox(-w / 2, -0.04, 0.9, w / 2, 0.04, 2.15, 114, occ=False)
            done(s, -w / 2, -0.05, w / 2, 0.05, 2.15)
        s = new(f'glasswall_{k}', f'Glass Partition 2m · {en}', f'قاطع زجاج 2م · {ar}', 'doors', 420)
        for x in (-1, 0.95): s.box(m, x, -0.03, 0, x + 0.05, 0.03, 2.9)
        for z in (0, 2.85): s.box(m, -1, -0.03, z, 1, 0.03, z + 0.05)
        s.box('window_dark', -0.95, -0.006, 0.05, 0.95, 0.006, 2.85, faces='yY'); s.cbox(-1, -0.03, 0, 1, 0.03, 2.9, 114); done(s, -1, -0.05, 1, 0.05, 2.9)


def build_bath():
    tiles = [('white', 'tile_white', 'White', 'أبيض'), ('beige', 'tile_beige', 'Beige', 'بيج'), ('terra', 'tile_terra', 'Terracotta', 'تيراكوتا'), ('stone', 'stone', 'Stone', 'حجر'), ('black', 'paint_black', 'Black', 'أسود')]
    for (k, m, en, ar) in tiles:
        s = new(f'bathtub_{k}', f'Bathtub · {en}', f'بانيو · {ar}', 'bathroom', 1400)
        s.box(m, -0.85, -0.4, 0, 0.85, 0.4, 0.56, faces='xXyY', col=True, occ=True); s.box(m, -0.85, -0.4, 0.52, 0.85, 0.4, 0.56, faces='Z')
        s.box('appliance', -0.76, -0.31, 0.2, 0.76, 0.31, 0.565, faces='Z'); s.box('appliance', -0.76, -0.31, 0.2, 0.76, 0.31, 0.56, faces='xXyY') if False else None
        s.box('steel', -0.8, -0.03, 0.56, -0.74, 0.03, 0.8); s.box('steel', -0.8, -0.02, 0.76, -0.6, 0.02, 0.8); done(s, -0.85, -0.4, 0.85, 0.4, 0.8)
        s = new(f'shower_{k}', f'Shower Cabin · {en}', f'كابينة دش · {ar}', 'bathroom', 1700)
        s.box(m, -0.5, -0.5, 0, 0.5, 0.5, 0.1, faces='xXyYZ', col=True); s.box(m, -0.5, 0.44, 0.1, 0.5, 0.5, 2.2, faces='xXyYZ', col=True)
        for x in (-0.5, 0.47): s.box('steel', x, -0.5, 0.1, x + 0.03, -0.47, 2.1)
        s.box('window_dark', -0.5, -0.49, 0.1, -0.49, 0.44, 2.1, faces='xX'); s.box('window_dark', 0.49, -0.49, 0.1, 0.5, 0.44, 2.1, faces='xX')
        s.box('window_dark', -0.47, -0.5, 0.1, 0.0, -0.49, 2.1, faces='yY'); s.cbox(-0.5, -0.5, 0.1, -0.48, 0.44, 2.1, 114, occ=False); s.cbox(0.48, -0.5, 0.1, 0.5, 0.44, 2.1, 114, occ=False)
        s.box('steel', -0.02, 0.38, 1.0, 0.02, 0.44, 2.05); s.cyl('steel', 0, 0.3, 2.0, 0.11, 0.03, seg=12); done(s, -0.5, -0.5, 0.5, 0.5, 2.2)
        for L in (2, 4):
            s = new(f'bathwall_{k}_{L}m', f'Half-tiled Wall {L}m · {en}', f'جدار نصفه بلاط {L}م · {ar}', 'bathroom', 120 * L)
            s.surf(m, (-L / 2, -TH / 2, 0), X, Z, L, 1.5, step=1.0); s.surf(m, (L / 2, TH / 2, 0), -X, Z, L, 1.5, step=1.0)
            s.surf('paint_white', (-L / 2, -TH / 2, 1.5), X, Z, L, 1.4, step=1.0); s.surf('paint_white', (L / 2, TH / 2, 1.5), -X, Z, L, 1.4, step=1.0)
            s.box('trim', -L / 2, -TH / 2 - 0.01, 1.48, L / 2, TH / 2 + 0.01, 1.52, faces='yYzZ'); s.box('paint_white', -L / 2, -TH / 2, 0, L / 2, TH / 2, 2.9, faces='xXZ')
            s.cbox(-L / 2, -TH / 2, 0, L / 2, TH / 2, 2.9, 81); done(s, -L / 2, -TH, L / 2, TH, 2.9)
    for (k, m, en, ar) in WOODS:
        for (w, wn) in ((0.8, 'Single'), (1.4, 'Double')):
            s = new(f'vanity_{k}_{wn.lower()}', f'{wn} Vanity with Mirror · {en}', f'مغسلة {"مفردة" if w < 1 else "دبل"} بمراية · {ar}', 'bathroom', 500 + 500 * w)
            s.box(m, -w / 2, -0.25, 0.1, w / 2, 0.25, 0.8, faces='xXyY', col=True, occ=True); s.box('metal_dark', -w / 2 + 0.03, -0.22, 0, w / 2 - 0.03, 0.22, 0.1, faces='xXyY')
            s.box('countertop', -w / 2 - 0.02, -0.27, 0.8, w / 2 + 0.02, 0.25, 0.84)
            for c in ((0,) if w < 1 else (-0.35, 0.35)):
                s.box('appliance', c - 0.22, -0.18, 0.84, c + 0.22, 0.16, 0.9); s.box('steel', c - 0.015, 0.17, 0.84, c + 0.015, 0.2, 1.02); s.box('steel', c - 0.015, 0.06, 0.99, c + 0.015, 0.2, 1.02)
            s.box('window_dark', -w / 2 + 0.05, 0.23, 1.15, w / 2 - 0.05, 0.25, 1.95, faces='y'); s.box(m, -w / 2, 0.235, 1.1, w / 2, 0.25, 2.0, faces='xXzZ')
            done(s, -w / 2, -0.27, w / 2, 0.25, 2.0)
    for (k, m, en, ar) in (('white', 'appliance', 'White', 'أبيض'), ('black', 'black_glass', 'Black', 'أسود')):
        s = new(f'toilet_{k}', f'Toilet · {en}', f'مرحاض · {ar}', 'bathroom', 420)
        s.box(m, -0.2, 0.12, 0, 0.2, 0.32, 0.85, col=True, occ=True); s.box(m, -0.19, -0.33, 0, 0.19, 0.12, 0.4, col=True, occ=True)
        s.box('trim', -0.2, -0.34, 0.4, 0.2, 0.12, 0.43); s.box('steel', -0.05, 0.16, 0.85, 0.05, 0.22, 0.87); done(s, -0.2, -0.34, 0.2, 0.32, 0.87)
        s = new(f'towelrail_{k}', f'Heated Towel Rail · {en}', f'حامل مناشف · {ar}', 'bathroom', 160)
        for x in (-0.25, 0.23): s.box('steel', x, -0.02, 0.6, x + 0.02, 0.02, 1.6)
        for i in range(6): s.box('steel', -0.25, -0.012, 0.68 + i * 0.17, 0.25, 0.012, 0.7 + i * 0.17)
        s.box(m, -0.22, -0.04, 0.9, 0.22, -0.012, 1.4, faces='xXyzZ'); s.cbox(-0.25, -0.03, 0.6, 0.25, 0.03, 1.6, 56, occ=False); done(s, -0.25, -0.05, 0.25, 0.03, 1.6)


def build_kitchen():
    for (k, m, en, ar) in WOODS + [('grey', 'paint_grey', 'Grey', 'رمادي'), ('navy', 'paint_navy', 'Navy', 'كحلي'), ('sage', 'paint_sage', 'Sage', 'أخضر فاتح'), ('red', 'paint_red', 'Red', 'أحمر')]:
        def base(s, w, top=True):
            s.box(m, -w / 2, -0.3, 0.1, w / 2, 0.3, 0.88, faces='xXyY', col=True, occ=True); s.box('metal_dark', -w / 2 + 0.02, -0.26, 0, w / 2 - 0.02, 0.3, 0.1, faces='xXyY')
            if top: s.box('countertop', -w / 2, -0.32, 0.88, w / 2, 0.3, 0.92)
            n = max(1, round(w / 0.6))
            for i in range(n):
                x = -w / 2 + w * (i + 0.5) / n
                s.box('steel', x - 0.07, -0.325, 0.74, x + 0.07, -0.3, 0.76)
                if i: s.box('metal_dark', -w / 2 + w * i / n - 0.004, -0.302, 0.1, -w / 2 + w * i / n + 0.004, -0.3, 0.88, faces='y')
        for (w, wn) in ((1.2, '1.2m'), (2.4, '2.4m')):
            s = new(f'kbase_{k}_{wn}', f'Kitchen Base Unit {wn} · {en}', f'خزانة مطبخ سفلية {wn} · {ar}', 'kitchen', 380 * w); base(s, w); done(s, -w / 2, -0.33, w / 2, 0.3, 0.92)
        s = new(f'ksink_{k}', f'Kitchen Sink Unit · {en}', f'وحدة مغسلة مطبخ · {ar}', 'kitchen', 720); base(s, 1.2)
        s.box('steel', -0.4, -0.22, 0.921, 0.4, 0.2, 0.926, faces='Z'); s.box('metal_dark', -0.34, -0.17, 0.922, 0.34, 0.15, 0.93, faces='Z')
        s.box('steel', -0.015, 0.2, 0.92, 0.015, 0.23, 1.2); s.box('steel', -0.015, 0.02, 1.17, 0.015, 0.23, 1.2); done(s, -0.6, -0.33, 0.6, 0.3, 1.2)
        s = new(f'khob_{k}', f'Kitchen Hob + Oven · {en}', f'موقد وفرن · {ar}', 'kitchen', 950); base(s, 0.9)
        s.box('black_glass', -0.3, -0.25, 0.921, 0.3, 0.25, 0.926, faces='Z'); s.box('black_glass', -0.3, -0.303, 0.2, 0.3, -0.3, 0.8, faces='y')
        for (x, y) in ((-0.15, -0.1), (0.15, -0.1), (-0.15, 0.12), (0.15, 0.12)): s.cyl('metal_dark', x, y, 0.926, 0.09, 0.008, seg=14)
        done(s, -0.45, -0.33, 0.45, 0.3, 0.94)
        s = new(f'kwall_{k}', f'Kitchen Wall Cabinet 1.2m · {en}', f'خزانة مطبخ علوية 1.2م · {ar}', 'kitchen', 340)
        s.box(m, -0.6, -0.02, 1.45, 0.6, 0.33, 2.15, col=True); s.box('metal_dark', -0.004, -0.022, 1.45, 0.004, -0.02, 2.15, faces='y')
        for x in (-0.07, 0.05): s.box('steel', x, -0.04, 1.5, x + 0.02, -0.02, 1.62)
        done(s, -0.6, -0.04, 0.6, 0.33, 2.15)
        s = new(f'kisland_{k}', f'Kitchen Island 2m · {en}', f'جزيرة مطبخ 2م · {ar}', 'kitchen', 1300)
        s.box(m, -1, -0.45, 0.1, 1, 0.45, 0.88, faces='xXyY', col=True, occ=True); s.box('metal_dark', -0.96, -0.41, 0, 0.96, 0.41, 0.1, faces='xXyY')
        s.box('countertop', -1.08, -0.55, 0.88, 1.08, 0.55, 0.93); done(s, -1.08, -0.55, 1.08, 0.55, 0.93)
        s = new(f'ktall_{k}', f'Tall Pantry Cabinet · {en}', f'خزانة مؤن طويلة · {ar}', 'kitchen', 620)
        s.box(m, -0.3, -0.3, 0.1, 0.3, 0.3, 2.15, col=True, occ=True); s.box('metal_dark', -0.28, -0.26, 0, 0.28, 0.3, 0.1, faces='xXyY')
        s.box('steel', 0.2, -0.325, 0.9, 0.22, -0.3, 1.3); s.box('metal_dark', -0.3, -0.302, 1.2, 0.3, -0.3, 1.208, faces='y'); done(s, -0.3, -0.33, 0.3, 0.3, 2.15)
    for (k, m, en, ar) in (('white', 'appliance', 'White', 'أبيض'), ('steel', 'steel', 'Steel', 'ستيل'), ('black', 'black_glass', 'Black', 'أسود')):
        s = new(f'fridge_{k}', f'Fridge Freezer · {en}', f'ثلاجة · {ar}', 'kitchen', 1600)
        s.box(m, -0.36, -0.34, 0.03, 0.36, 0.34, 1.85, col=True, occ=True); s.box('metal_dark', -0.36, -0.342, 1.18, 0.36, -0.34, 1.19, faces='y')
        s.box('steel', 0.27, -0.37, 0.5, 0.29, -0.34, 1.1); s.box('steel', 0.27, -0.37, 1.28, 0.29, -0.34, 1.7); done(s, -0.36, -0.37, 0.36, 0.34, 1.85)


def build_furniture():
    for (k, m, en, ar) in WOODS:
        s = new(f'wardrobe_{k}', f'Wardrobe 2m · {en}', f'دولاب ملابس 2م · {ar}', 'storage', 1100)
        s.box(m, -1, -0.3, 0.06, 1, 0.3, 2.3, col=True, occ=True); s.box('metal_dark', -0.98, -0.28, 0, 0.98, 0.3, 0.06, faces='xXyY')
        for x in (-0.5, 0.0, 0.5): s.box('metal_dark', x - 0.004, -0.302, 0.06, x + 0.004, -0.3, 2.3, faces='y')
        for x in (-0.56, -0.06, 0.04, 0.54): s.box('steel', x, -0.325, 1.0, x + 0.02, -0.3, 1.3)
        done(s, -1, -0.33, 1, 0.3, 2.3)
        s = new(f'bookshelf_{k}', f'Bookshelf · {en}', f'مكتبة · {ar}', 'storage', 520)
        for x in (-0.6, 0.57): s.box(m, x, -0.15, 0, x + 0.03, 0.15, 2.0)
        for i in range(6): s.box(m, -0.57, -0.15, 0.05 + i * 0.385, 0.57, 0.15, 0.08 + i * 0.385)
        s.box(m, -0.6, 0.14, 0, 0.6, 0.15, 2.0, faces='yY'); s.cbox(-0.6, -0.15, 0, 0.6, 0.15, 2.0, 70); done(s, -0.6, -0.15, 0.6, 0.15, 2.0)
        s = new(f'sideboard_{k}', f'Sideboard · {en}', f'بوفيه · {ar}', 'storage', 640)
        s.box(m, -0.9, -0.22, 0.15, 0.9, 0.22, 0.8, col=True, occ=True)
        for (x, y) in ((-0.82, -0.16), (0.82, -0.16), (-0.82, 0.16), (0.82, 0.16)): s.box('metal_dark', x - 0.02, y - 0.02, 0, x + 0.02, y + 0.02, 0.15, faces='xXyY')
        for x in (-0.3, 0.3): s.box('metal_dark', x - 0.004, -0.222, 0.15, x + 0.004, -0.22, 0.8, faces='y')
        done(s, -0.9, -0.23, 0.9, 0.22, 0.8)
        s = new(f'shelf_{k}', f'Wall Shelf 1.2m · {en}', f'رف جداري 1.2م · {ar}', 'storage', 110)
        s.box(m, -0.6, -0.11, 1.5, 0.6, 0.11, 1.54, col=True); done(s, -0.6, -0.11, 0.6, 0.11, 1.54)
        s = new(f'tvunit_{k}', f'TV Unit · {en}', f'طاولة تلفزيون · {ar}', 'storage', 480)
        s.box(m, -0.8, -0.2, 0.08, 0.8, 0.2, 0.5, col=True, occ=True); s.box('metal_dark', -0.76, -0.17, 0, 0.76, 0.17, 0.08, faces='xXyY'); s.box('black_glass', -0.78, -0.202, 0.3, 0.78, -0.2, 0.46, faces='y')
        done(s, -0.8, -0.21, 0.8, 0.2, 0.5)

        def table(s, w, d, h, th=0.04, leg=0.06):
            s.box(m, -w / 2, -d / 2, h - th, w / 2, d / 2, h)
            for (x, y) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                s.box(m, x * (w / 2 - 0.08) - leg / 2, y * (d / 2 - 0.08) - leg / 2, 0, x * (w / 2 - 0.08) + leg / 2, y * (d / 2 - 0.08) + leg / 2, h - th, faces='xXyY')
            s.cbox(-w / 2, -d / 2, h - 0.1, w / 2, d / 2, h, 70); done(s, -w / 2, -d / 2, w / 2, d / 2, h)
        table(new(f'dining_{k}', f'Dining Table · {en}', f'طاولة طعام · {ar}', 'table', 780), 1.8, 0.9, 0.76)
        table(new(f'coffee_{k}', f'Coffee Table · {en}', f'طاولة قهوة · {ar}', 'table', 340), 1.1, 0.6, 0.42)
        table(new(f'desk_{k}', f'Desk · {en}', f'مكتب · {ar}', 'table', 520), 1.4, 0.65, 0.75)
        table(new(f'sidetable_{k}', f'Side Table · {en}', f'طاولة جانبية · {ar}', 'table', 180), 0.45, 0.45, 0.52, leg=0.04)
        table(new(f'bench_{k}', f'Bench · {en}', f'مقعد خشبي · {ar}', 'chair', 260), 1.4, 0.38, 0.45)
        s = new(f'bar_{k}', f'Bar Counter 2m · {en}', f'كاونتر بار 2م · {ar}', 'table', 980)
        s.box(m, -1, -0.25, 0, 1, 0.25, 1.05, faces='xXyY', col=True, occ=True); s.box('countertop', -1.05, -0.35, 1.05, 1.05, 0.3, 1.1); done(s, -1.05, -0.35, 1.05, 0.3, 1.1)
        s = new(f'bedframe_{k}', f'Bed Frame (double) · {en}', f'سرير دبل · {ar}', 'bed', 1500)
        s.box(m, -0.85, -1.05, 0.12, 0.85, 1.05, 0.3, col=True); s.box(m, -0.85, 1.0, 0.12, 0.85, 1.06, 1.05)
        s.box('trim', -0.8, -1.0, 0.3, 0.8, 0.98, 0.5, col=97); s.box('fabric', -0.8, -1.0, 0.5, 0.8, 0.35, 0.53, faces='xXyYZ')
        for x in (-0.42, 0.42): s.box('trim', x - 0.3, 0.5, 0.5, x + 0.3, 0.92, 0.6)
        done(s, -0.85, -1.05, 0.85, 1.06, 1.05)
    rugs = [('red', 'rug_red', 'Red', 'أحمر'), ('blue', 'rug_blue', 'Blue', 'أزرق'), ('cream', 'rug_cream', 'Cream', 'كريمي'), ('green', 'rug_green', 'Green', 'أخضر'), ('black', 'rug_black', 'Black', 'أسود'), ('grey', 'carpet', 'Grey', 'رمادي')]
    for (k, m, en, ar) in rugs:
        for (a, b) in ((1.6, 2.4), (2.5, 3.5)):
            s = new(f'rug_{k}_{int(a * 10)}', f'Rug {a}x{b}m · {en}', f'سجادة {a}×{b}م · {ar}', 'decorations', 120 * a)
            s.box(m, -a / 2, -b / 2, 0, a / 2, b / 2, 0.015, faces='xXyYZ'); s.box('trim', -a / 2, -b / 2, 0.015, a / 2, -b / 2 + 0.05, 0.016, faces='Z'); s.box('trim', -a / 2, b / 2 - 0.05, 0.015, a / 2, b / 2, 0.016, faces='Z')
            s.cbox(-a / 2, -b / 2, 0, a / 2, b / 2, 0.015, 97); done(s, -a / 2, -b / 2, a / 2, b / 2, 0.02)
        s = new(f'rug_{k}_round', f'Round Rug · {en}', f'سجادة دائرية · {ar}', 'decorations', 190)
        s.cyl(m, 0, 0, 0, 1.0, 0.015, seg=28); s.cbox(-0.7, -0.7, 0, 0.7, 0.7, 0.015, 97); done(s, -1, -1, 1, 1, 0.02)
    for (k, m, en, ar) in (('cream', 'fabric', 'Terracotta', 'تيراكوتا'), ('white', 'trim', 'White', 'أبيض'), ('grey', 'carpet', 'Grey', 'رمادي'), ('blue', 'rug_blue', 'Blue', 'أزرق'), ('red', 'rug_red', 'Red', 'أحمر')):
        s = new(f'curtain_{k}', f'Curtains 2m · {en}', f'ستارة 2م · {ar}', 'decorations', 210)
        s.box('metal_dark', -1.05, -0.02, 2.3, 1.05, 0.02, 2.34)
        for (x0, x1) in ((-1.0, -0.45), (0.45, 1.0)):
            for i in range(6):
                a = x0 + (x1 - x0) * i / 6; s.box(m, a, -0.03 - 0.02 * (i % 2), 0.05, a + (x1 - x0) / 6, 0.03 + 0.02 * (i % 2), 2.3)
        s.cbox(-1.05, -0.05, 0.05, 1.05, 0.05, 2.34, 97, occ=False); done(s, -1.05, -0.06, 1.05, 0.06, 2.34)
        s = new(f'sofa_{k}', f'Sofa (3 seats) · {en}', f'كنبة ثلاثية · {ar}', 'chair', 1250)
        s.box(m, -1.05, -0.42, 0.1, 1.05, 0.42, 0.42, col=True, occ=True); s.box(m, -1.05, 0.22, 0.42, 1.05, 0.42, 0.85, col=True)
        for x in (-1.05, 0.87): s.box(m, x, -0.42, 0.42, x + 0.18, 0.22, 0.62, col=True)
        for i in range(3): s.box(m, -0.85 + i * 0.58, -0.4, 0.42, -0.31 + i * 0.58, 0.2, 0.5)
        for (x, y) in ((-0.98, -0.36), (0.98, -0.36), (-0.98, 0.36), (0.98, 0.36)): s.box('metal_dark', x - 0.025, y - 0.025, 0, x + 0.025, y + 0.025, 0.1, faces='xXyY')
        done(s, -1.05, -0.42, 1.05, 0.42, 0.85)
        s = new(f'armchair_{k}', f'Armchair · {en}', f'كرسي مريح · {ar}', 'chair', 620)
        s.box(m, -0.42, -0.4, 0.1, 0.42, 0.4, 0.42, col=True, occ=True); s.box(m, -0.42, 0.22, 0.42, 0.42, 0.4, 0.85, col=True)
        for x in (-0.42, 0.28): s.box(m, x, -0.4, 0.42, x + 0.14, 0.22, 0.6)
        done(s, -0.42, -0.4, 0.42, 0.4, 0.85)
    for (sz, szn, inten, fall) in ((0.6, 'Small', 5, 7), (1.2, 'Large', 8, 10)):
        s = new(f'light_panel_{szn.lower()}', f'Ceiling Light Panel · {szn}', f'لوحة إضاءة سقف · {"صغيرة" if sz < 1 else "كبيرة"}', 'light', 180 * sz + 100)
        s.box('trim', -sz / 2, -sz / 2, 2.84, sz / 2, sz / 2, 2.9, faces='xXyYZ'); s.surf('light', (-sz / 2 + 0.03, sz / 2 - 0.03, 2.838), X, -Y, sz - 0.06, sz - 0.06, step=0, fit=True)
        s.light(0, 0, 2.6, intensity=inten, falloff=fall); s.cbox(-sz / 2, -sz / 2, 2.84, sz / 2, sz / 2, 2.9, 114, occ=False); done(s, -sz / 2, -sz / 2, sz / 2, sz / 2, 2.9)
    for (k, c, en, ar) in (('warm', (255, 214, 160), 'Warm', 'دافئ'), ('white', (240, 244, 255), 'White', 'أبيض'), ('red', (255, 70, 60), 'Red', 'أحمر'), ('blue', (80, 130, 255), 'Blue', 'أزرق'), ('green', (90, 255, 130), 'Green', 'أخضر'), ('purple', (190, 90, 255), 'Purple', 'بنفسجي')):
        s = new(f'light_pendant_{k}', f'Pendant Light · {en}', f'ثريا معلقة · {ar}', 'light', 240)
        s.box('metal_dark', -0.01, -0.01, 2.2, 0.01, 0.01, 2.9); s.cyl('metal_dark', 0, 0, 1.95, 0.22, 0.25, seg=14, r2=0.05); s.cyl('light', 0, 0, 1.94, 0.2, 0.012, seg=14)
        s.light(0, 0, 1.8, color=c, intensity=6, falloff=8); s.cbox(-0.2, -0.2, 1.95, 0.2, 0.2, 2.2, 56, occ=False); done(s, -0.22, -0.22, 0.22, 0.22, 2.9)
        s = new(f'light_floor_{k}', f'Floor Lamp · {en}', f'أباجورة أرضية · {ar}', 'light', 200)
        s.cyl('metal_dark', 0, 0, 0, 0.16, 0.03, seg=14); s.cyl('metal_dark', 0, 0, 0.03, 0.015, 1.45, seg=8); s.cyl('trim', 0, 0, 1.45, 0.2, 0.3, seg=14, r2=0.14, caps=False); s.cyl('light', 0, 0, 1.5, 0.05, 0.15, seg=8)
        s.light(0, 0, 1.6, color=c, intensity=4, falloff=6); s.cbox(-0.15, -0.15, 0, 0.15, 0.15, 1.75, 56, occ=False); done(s, -0.2, -0.2, 0.2, 0.2, 1.75)
        s = new(f'light_strip_{k}', f'LED Strip 2m · {en}', f'شريط LED 2م · {ar}', 'light', 150)
        s.box('metal_dark', -1, -0.02, 2.86, 1, 0.02, 2.9); s.box('light', -0.98, -0.015, 2.85, 0.98, 0.015, 2.86, faces='xXyYz')
        s.light(-0.5, 0, 2.6, color=c, intensity=4, falloff=6); s.light(0.5, 0, 2.6, color=c, intensity=4, falloff=6); s.cbox(-1, -0.02, 2.85, 1, 0.02, 2.9, 56, occ=False); done(s, -1, -0.03, 1, 0.03, 2.9)
    for (k, m, en, ar) in (('stone', 'stone', 'Stone', 'حجر'), ('white', 'trim', 'White', 'أبيض'), ('black', 'paint_black', 'Black', 'أسود'), ('terra', 'tile_terra', 'Terracotta', 'تيراكوتا')):
        s = new(f'planter_{k}', f'Planter with Hedge · {en}', f'حوض نباتات · {ar}', 'decorations', 260)
        s.box(m, -0.6, -0.25, 0, 0.6, 0.25, 0.5, faces='xXyYZ', col=True, occ=True); s.box('hedge', -0.54, -0.19, 0.5, 0.54, 0.19, 0.95, faces='xXyYZ'); done(s, -0.6, -0.25, 0.6, 0.25, 0.95)
        s = new(f'plant_{k}', f'Potted Tree · {en} pot', f'شجرة زينة · حوض {ar}', 'decorations', 320)
        s.cyl(m, 0, 0, 0, 0.22, 0.4, seg=14, r2=0.28); s.cyl('wood_dark', 0, 0, 0.4, 0.035, 0.8, seg=8, caps=False); sphere(s, 'hedge', 0, 0, 1.55, 0.45, sq=0.9)
        s.cbox(-0.25, -0.25, 0, 0.25, 0.25, 1.2, 46, occ=False); done(s, -0.45, -0.45, 0.45, 0.45, 2.0)


def all_pieces():
    if not PIECES:
        build_walls(); build_floors(); build_stairs(); build_doors(); build_bath(); build_kitchen(); build_furniture()
    return PIECES
