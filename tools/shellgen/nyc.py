# ROX NYC block: a New York style crossroads at night (exteriors only)  (c) ROX Store
# Generated: roads, pavements, crossings, subway entrance and 20 building exteriors.
# Street furniture (lights, traffic lights, hydrants, trees, benches, cars ...) are real GTA props (rox_nyc/shared/props.lua).
import random, math, json
import numpy as np
import street
from street import piece, building, barrier
from kit import MATS, X, Y, Z

street.LIT_RATE = 0.42
TXD = 'rox_nyc_txd'
AV, ST = 9.0, 7.0        # half widths of the avenue (along Y) and the street (along X)
SW = 6.0                 # pavement width
E = 80.0                 # half size of the whole map
NEON = ('neon_deli', 'neon_pizza', 'neon_bar', 'neon_hotel', 'neon_pharmacy', 'neon_cafe')
INSIDE = {'neon_deli': 'shopr_deli', 'neon_pizza': 'shopr_pizza', 'neon_bar': 'shopr_bar', 'neon_hotel': 'shopr_boutique',
          'neon_pharmacy': 'shopr_deli', 'neon_cafe': 'shopr_cafe', 'neon_burger': 'shopr_burger', 'neon_slice': 'shopr_pizza'}
# small restaurants: (name, neon sign, awning)
RESTAURANTS = [('ROX Pizza', 'neon_slice', 'awning_pizza'), ('ROX Burger', 'neon_burger', 'awning_navy'),
               ('ROX Coffee', 'neon_cafe', 'awning_cafe'), ("Joe's Pizza", 'neon_pizza', 'awning_pizza'),
               ('Corner Deli', 'neon_deli', 'awning_green'), ('Night Bar', 'neon_bar', 'awning_navy'),
               ('ROX Burger 2', 'neon_burger', 'awning_pizza'), ('Bean Cafe', 'neon_cafe', 'awning_cafe')]
POINTS = dict(steam=[], parking=[], trees=[], lamps=[], corners=[], dining=[])
SHOPLIST = []   # enterable shops: building, type, interior box, doors
MATS['shop_black'] = dict(MATS['win_night'])
KIND = {'neon_deli': 'deli', 'neon_pizza': 'pizza', 'neon_slice': 'pizza', 'neon_burger': 'burger', 'neon_cafe': 'cafe', 'neon_bar': 'bar', 'neon_pharmacy': 'pharmacy', 'neon_hotel': 'deli'}


def nyc_piece(name, label):
    s = piece(name, label); s.txd, s.lod = TXD, 1500
    return s


def ground():
    s = nyc_piece('rox_nyc_ground', 'ROX NYC crossroads')
    s.cbox(-E, -E, -6.0, E, E, 0.0, 4)
    s.box('concrete_wall', -E, -E, -6, E, E, 0, faces='xXyY', step=8.0)
    A = lambda x0, y0, x1, y1: s.surf('asphalt', (x0, y0, 0), X, Y, x1 - x0, y1 - y0, step=6.0)
    A(-AV, -E, AV, E); A(-E, -ST, -AV, ST); A(AV, -ST, E, ST)
    P0, P1 = AV + SW, ST + SW
    def walk(x0, y0, x1, y1):
        s.box('pavement', x0, y0, 0, x1, y1, 0.16, faces='xXyYZ', step=4.0); s.cboxes.append((x0, y0, 0, x1, y1, 0.16, 1)); s.occ.append((x0, y0, 0, x1, y1, 0.16))
    for sx in (-1, 1):
        for sy in (-1, 1):
            # L shaped corner pavement + the block floor behind it
            xa, xb = sorted((sx * AV, sx * E)); ya, yb = sorted((sy * ST, sy * E))
            walk(xa, ya, xb, yb)
            for (a, b, c, d) in ((sx * AV - 0.15 * sx, ya if sy > 0 else yb - 0, sx * AV, yb if sy > 0 else ya),):
                pass
            # granite kerb along both road edges
            ky = sy * ST; kx = sx * AV
            s.box('stone', min(xa, xb), ky - 0.15 * (sy > 0) + (0 if sy > 0 else 0), 0, max(xa, xb), ky + (0.15 if sy > 0 else -0.15), 0.17, faces='Z') if False else None
            s.box('stone', xa, min(ky, ky + sy * 0.25), 0.16, xb, max(ky, ky + sy * 0.25), 0.175, faces='Z')
            s.box('stone', min(kx, kx + sx * 0.25), ya, 0.16, max(kx, kx + sx * 0.25), yb, 0.175, faces='Z')
            POINTS['corners'].append((sx * (AV + 0.8), sy * (ST + 0.8)))
    L = lambda x0, y0, x1, y1, m='paint_line': s.surf(m, (x0, y0, 0.012), X, Y, x1 - x0, y1 - y0, step=0)
    # avenue: double yellow, lane dashes, parking lanes
    for (a, b) in ((-E, -ST - 4.0), (ST + 4.0, E)):
        L(-0.25, a, -0.1, b, 'paint_yellow'); L(0.1, a, 0.25, b, 'paint_yellow')
        y = a
        while y < b - 3:
            for x in (-4.5, 4.5): L(x - 0.08, y, x + 0.08, y + 3)
            y += 9
        for x in (-AV + 2.4, AV - 2.4):
            L(x - 0.07, a, x + 0.07, b)
        for y in np.arange(a + 3, b - 3, 6.5):
            for x in (-AV, AV - 2.4):
                if abs(y) > 16: POINTS['parking'].append((x + 1.2 if x < 0 else x + 1.2, float(y + 3.25), 0.0 if x < 0 else 180.0))
    # street: single dashed white centre, parking both sides
    for (a, b) in ((-E, -AV - 4.0), (AV + 4.0, E)):
        x = a
        while x < b - 3: L(x, -0.08, x + 3, 0.08); x += 7
        for y in (-ST + 2.4, ST - 2.4): L(a, y - 0.07, b, y + 0.07)
        for x in np.arange(a + 3, b - 3, 6.5):
            for y in (-ST + 1.2, ST - 1.2):
                if abs(x) > 18: POINTS['parking'].append((float(x + 3.25), y, 90.0 if y < 0 else 270.0))
    # ladder crossings + stop bars on the four approaches
    for sy in (-1, 1):
        y0 = sy * (ST + 1.0)
        for k in range(int(2 * AV / 1.2)):
            x = -AV + 0.3 + k * 1.2
            L(x, min(y0, y0 + sy * 3.2), x + 0.6, max(y0, y0 + sy * 3.2))
        L(-AV, min(y0, y0) + sy * 3.6 - 0.2 if sy > 0 else y0 - 3.8, AV, (y0 + 3.8) if sy > 0 else y0 - 3.4)
    for sx in (-1, 1):
        x0 = sx * (AV + 1.0)
        for k in range(int(2 * ST / 1.2)):
            y = -ST + 0.3 + k * 1.2
            L(min(x0, x0 + sx * 3.2), y, max(x0, x0 + sx * 3.2), y + 0.6)
        L((x0 + 3.4) if sx > 0 else x0 - 3.8, -ST, (x0 + 3.8) if sx > 0 else x0 - 3.4, ST)
    # manholes (steam comes out of some) + storm drains
    rng = random.Random(7)
    for (x, y) in ((-3.0, 22.0), (3.5, -30.0), (-2.5, -55.0), (2.0, 48.0), (26.0, 2.0), (-34.0, -2.5), (55.0, -1.5), (-60.0, 2.0), (0.0, 0.0)):
        s.surf('manhole', (x - 0.45, y - 0.45, 0.014), X, Y, 0.9, 0.9, step=0, fit=True)
        if rng.random() < 0.7: POINTS['steam'].append((x, y))
    for y in np.arange(-E + 10, E - 5, 18):
        for x in (-AV + 0.05, AV - 0.5):
            if abs(y) > ST + 5: s.box('metal_dark', x, y, 0.0, x + 0.45, y + 1.0, 0.014, faces='Z')
    # tree pits + lamp positions on the pavements
    for sx in (-1, 1):
        for y in np.arange(ST + SW + 6, E - 4, 12):
            for sy in (-1, 1):
                x = sx * (AV + 1.4)
                s.box('metal_dark', x - 0.7, sy * y - 0.7, 0.16, x + 0.7, sy * y + 0.7, 0.172, faces='Z')
                POINTS['trees'].append((x, float(sy * y)))
                POINTS['lamps'].append((sx * (AV + 0.6), float(sy * (y - 6)), 90.0 if sx > 0 else 270.0))
    for sy in (-1, 1):
        for x in np.arange(AV + SW + 6, E - 4, 12):
            for sx in (-1, 1):
                y = sy * (ST + 1.4)
                s.box('metal_dark', sx * x - 0.7, y - 0.7, 0.16, sx * x + 0.7, y + 0.7, 0.172, faces='Z')
                POINTS['trees'].append((float(sx * x), y))
                POINTS['lamps'].append((float(sx * (x - 6)), sy * (ST + 0.6), 0.0 if sy > 0 else 180.0))
    subway(s, AV + 2.4, ST + 3.2)
    for sx in (-1, 1):
        barrier(s, sx * (E - 0.6), 0, 0, 'y', n=7)
    for sy in (-1, 1):
        barrier(s, 0, sy * (E - 0.6), 0, 'x', n=9)
    s.bb = (-E, -E, 0, E, E, 4)
    return s


def subway(s, x, y):
    """NYC subway entrance on the NE corner: stair well with railings, green globe lamps, sign."""
    w, l = 2.2, 5.0
    x0, y0, x1, y1 = x, y, x + w, y + l
    s.box('concrete_wall', x0, y0, -3.0, x1, y0 + 0.15, 0.16, faces='Y')
    s.box('concrete_wall', x0, y1 - 0.15, -3.0, x1, y1, 0.16, faces='y')
    s.box('concrete_wall', x0, y0, -3.0, x0 + 0.15, y1, 0.16, faces='X'); s.box('concrete_wall', x1 - 0.15, y0, -3.0, x1, y1, 0.16, faces='x')
    for i in range(14):   # steps going down (south to north)
        z = 0.16 - (i + 1) * 0.2; yy = y0 + 0.15 + i * 0.33
        s.box('stone', x0 + 0.15, yy, z, x1 - 0.15, yy + 0.33, z + 0.2, faces='yZ')
    s.box('black_glass', x0 + 0.15, y1 - 0.2, -3.0, x1 - 0.15, y1 - 0.15, -0.6, faces='y')
    for (a, b, c, d) in ((x0, y0, x1, y0 + 0.06), (x0, y0, x0 + 0.06, y1), (x1 - 0.06, y0, x1, y1)):
        s.box('paint_green', a, b, 0.16, c, d, 1.15); s.cbox(a, b, 0.16, c, d, 1.15, 56, occ=False)
    for i in range(12):
        yy = y0 + 0.2 + i * 0.4
        s.box('paint_green', x0 + 0.01, yy, 0.25, x0 + 0.05, yy + 0.03, 1.1); s.box('paint_green', x1 - 0.05, yy, 0.25, x1 - 0.01, yy + 0.03, 1.1)
    for (gx, gy) in ((x0, y0), (x1, y0)):
        s.cyl('paint_green', gx, gy, 0.16, 0.06, 2.4, seg=10); s.cyl('light', gx, gy, 2.56, 0.17, 0.3, seg=14, r2=0.17)
        s.light(gx, gy, 2.7, color=(140, 255, 160), intensity=4, falloff=6)
    s.box('metal_dark', x0 - 0.05, y0 - 0.06, 1.15, x1 + 0.05, y0 + 0.02, 1.65)
    s.surf('sign_subway', (x0, y0 - 0.065, 1.2), X, Z, w, 0.4, step=0, fit=True)


def blocks():
    out = []
    styles = [dict(wall='brick_red', base='stone'), dict(wall='brick_dark', base='stone'), dict(wall='brownstone', base='brownstone'),
              dict(wall='brick_white', base='stone'), dict(wall='stone', base='stone'), dict(wall='brick_red', base='brick_dark')]
    rng = random.Random(42); n = 0
    for sx in (-1, 1):
        for sy in (-1, 1):
            fx, fy = AV + SW, ST + SW          # building line
            lots = [  # (x0, y0, x1, y1) in the quadrant's positive frame: x along street, y along avenue
                (fx, fy, fx + 22, fy + 22, 'corner'),
                (fx + 23.5, fy, fx + 33, fy + 14, 'resto'), (fx + 34.5, fy, fx + 44, fy + 14, 'resto'), (fx + 46, fy, E - 4, fy + 20, 'street'),
                (fx, fy + 24, fx + 18, fy + 42, 'avenue'), (fx, fy + 44, fx + 20, E - 4, 'avenue'),
            ]
            for (a, b, c, d, kind) in lots:
                if kind == 'resto':
                    x0, x1 = sorted((sx * a, sx * c)); y0, y1 = sorted((sy * b, sy * d))
                    name, sg, aw = RESTAURANTS[len([o for o in out if getattr(o, 'resto', False)]) % len(RESTAURANTS)]
                    n += 1; face_y = 'S' if sy > 0 else 'N'
                    st = styles[rng.randrange(len(styles))]
                    r = building('rox_nyc_b%02d' % n, name, x0, y0, x1, y1, rng.choice((2, 3, 3, 4)), wall=st['wall'], base='stone', gh=4.4, bay=3.0,
                                 shop_sides=face_y, sign=(sg,), awning=aw, pilasters=False, seed=100 + n, tank=False, shops=(INSIDE[sg],), ac_rate=0.4, enter=True,
                                 blade=(sg, 'W' if sx > 0 else 'E') if False else None)
                    r.txd, r.lod, r.resto = TXD, 1500, True
                    out.append(r); SHOPLIST.append(dict(name=r.name, label=name, kind=KIND[sg], **r.shop))
                    # pavement terrace in front (GTA tables, chairs, parasols spawned by rox_nyc)
                    yy = sy * (ST + 3.4); xc = (x0 + x1) / 2
                    for dx in (-2.4, 2.4): POINTS['dining'].append((xc + dx, yy, 0.0))
                    continue
                x0, x1 = sorted((sx * a, sx * c)); y0, y1 = sorted((sy * b, sy * d))
                face_x = 'W' if sx > 0 else 'E'; face_y = 'S' if sy > 0 else 'N'
                sides = face_x + face_y if kind == 'corner' else (face_y if kind == 'street' else face_x)
                st = styles[rng.randrange(len(styles))]
                floors = rng.choice((4, 5, 6, 6, 7, 8, 9, 11)) if kind != 'corner' else rng.choice((8, 10, 12, 14))
                sg = NEON[rng.randrange(len(NEON))]
                if kind == 'corner': sg = ('neon_deli', 'neon_pharmacy', 'neon_deli', 'neon_bar')[len([o for o in out if getattr(o, 'corner', False)]) % 4]
                n += 1
                b_ = building('rox_nyc_b%02d' % n, 'ROX NYC building %d' % n, x0, y0, x1, y1, floors, wall=st['wall'], base=st['base'],
                              shop_sides=sides, sign=(sg, NEON[(NEON.index(sg) + 2) % len(NEON)]), awning=('awning_red', 'awning_green')[n % 2],
                              escape=(face_y if kind == 'avenue' else face_x) if floors >= 5 and rng.random() < 0.7 else None,
                              pilasters=st['wall'] != 'brownstone', seed=100 + n, tank=floors >= 7 and rng.random() < 0.7,
                              balconies=(face_x if kind == 'street' else '') if rng.random() < 0.3 else '', shops=(INSIDE[sg],) if kind == 'corner' else ('shop_black',), enter=kind == 'corner',
                              blade=('neon_hotel', face_y if sy > 0 else face_y) if kind == 'corner' and rng.random() < 0.5 else None,
                              billboard=face_y if kind == 'corner' and floors <= 10 and rng.random() < 0.5 else None)
                b_.txd, b_.lod = TXD, 1500
                if kind == 'corner':
                    b_.corner = True; SHOPLIST.append(dict(name=b_.name, label={'neon_deli': 'Deli 24H', 'neon_pharmacy': 'Pharmacy', 'neon_bar': 'Night Bar'}[sg], kind=KIND[sg], **b_.shop))
                out.append(b_)
    return out


def all_pieces():
    for k in POINTS: POINTS[k].clear()
    SHOPLIST.clear()
    g = ground()
    pieces = [g] + blocks()
    g.meta = dict(points=POINTS, shops=SHOPLIST)
    return pieces
