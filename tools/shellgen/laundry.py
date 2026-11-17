# ROX Laundry: a complete walk-in laundromat building (exterior + interior)  (c) ROX Store
# Origin = centre of the building at street level, shop front on the -Y side.
import math, json
import numpy as np
from kit import Shell, X, Y, Z
from street import sphere

W, D, H, T = 16.0, 10.0, 3.6, 0.3
X0, Y0, X1, Y1 = -W / 2, -D / 2, W / 2, D / 2
MACHINES = []


def heading(dx, dy):
    return (math.degrees(math.atan2(-dx, dy)) + 360) % 360


def ring(s, mat, C, n, r0, r1, depth, seg=28, inner=True):
    """Ring (porthole bezel) standing on a vertical plane with outward normal n."""
    C, n = np.asarray(C, float), np.asarray(n, float); u = np.cross(Z, n)
    P, N, UV, T, I = [], [], [], [], []
    def q(a, b, c, d, nn):
        o = len(P); P.extend([a, b, c, d]); N.extend([nn] * 4); UV.extend([(0, 0), (1, 0), (1, 1), (0, 1)]); T.extend([list(u) + [1.0]] * 4); I.extend([o, o + 1, o + 2, o, o + 2, o + 3])
    for k in range(seg):
        a0, a1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        d0, d1 = u * math.cos(a0) + Z * math.sin(a0), u * math.cos(a1) + Z * math.sin(a1)
        f = C + n * depth
        q(f + d0 * r1, f + d1 * r1, f + d1 * r0, f + d0 * r0, n)                          # front annulus
        q(C + d0 * r1, C + d1 * r1, f + d1 * r1, f + d0 * r1, (d0 + d1) / np.linalg.norm(d0 + d1))   # outer wall
        if inner: q(f + d0 * r0, f + d1 * r0, C + d1 * r0, C + d0 * r0, -(d0 + d1) / np.linalg.norm(d0 + d1))
    s._add(mat, '', P, N, UV, T, I)


def disc(s, mat, C, n, r, seg=28):
    C, n = np.asarray(C, float), np.asarray(n, float); u = np.cross(Z, n)
    P = [C] + [C + (u * math.cos(2 * math.pi * k / seg) + Z * math.sin(2 * math.pi * k / seg)) * r for k in range(seg)]
    I = []
    for k in range(seg): I += [0, 1 + k, 1 + (k + 1) % seg]
    UV = [(0.5, 0.5)] + [(0.5 + 0.5 * math.cos(2 * math.pi * k / seg), 0.5 - 0.5 * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    s._add(mat, '', P, [n] * len(P), UV, [list(u) + [1.0]] * len(P), I)


def machine(s, kind, x, y, face, z0=0.0, h=0.95, w=0.7, d=0.72):
    """Front loader. face = 'N','S','E','W' (direction the door looks at). (x, y) = centre of the footprint."""
    fx, fy = {'N': (0, 1), 'S': (0, -1), 'E': (1, 0), 'W': (-1, 0)}[face]
    hx, hy = (w / 2, d / 2) if face in 'NS' else (d / 2, w / 2)
    body = 'appliance' if kind == 'washer' else 'paint_charcoal'
    if z0 == 0.0:
        s.box('metal_dark', x - hx + 0.03, y - hy + 0.03, 0, x + hx - 0.03, y + hy - 0.03, 0.12, faces='xXyY')
        z0 = 0.12
    s.box(body, x - hx, y - hy, z0, x + hx, y + hy, z0 + h, faces='xXyYZ', occ=True)
    s.cbox(x - hx, y - hy, 0, x + hx, y + hy, z0 + h, 56, occ=False)
    tex = 'washer_front' if kind == 'washer' else 'dryer_front'
    e = 0.004
    if face == 'S': s.surf(tex, (x - hx + 0.01, y - hy - e, z0 + 0.01), X, Z, 2 * hx - 0.02, h - 0.02, step=0, fit=True)
    if face == 'N': s.surf(tex, (x + hx - 0.01, y + hy + e, z0 + 0.01), -X, Z, 2 * hx - 0.02, h - 0.02, step=0, fit=True)
    if face == 'E': s.surf(tex, (x + hx + e, y - hy + 0.01, z0 + 0.01), Y, Z, 2 * hy - 0.02, h - 0.02, step=0, fit=True)
    if face == 'W': s.surf(tex, (x - hx - e, y + hy - 0.01, z0 + 0.01), -Y, Z, 2 * hy - 0.02, h - 0.02, step=0, fit=True)
    # real 3D porthole: chrome bezel, tinted glass dome, lit drum, control strip with dial
    n = np.array([fx, fy, 0.0]); front = max(hx, hy) if face in 'EW' else hy
    front = hx if face in 'EW' else hy
    zc = z0 + h * 0.42
    C = np.array([x + fx * front, y + fy * front, zc])
    ring(s, 'steel', C, n, 0.2, 0.25, 0.05)
    ring(s, 'metal_dark', C + n * 0.05, n, 0.165, 0.2, 0.012, inner=False)
    disc(s, 'black_glass', C + n * 0.035, n, 0.2)
    disc(s, 'light' if kind == 'washer' else 'window_dark', C - n * 0.15, n, 0.17) if False else None
    u = np.cross(Z, n)
    ph = C + Z * (h * 0.58 - 0.08)
    a, b = ph - u * (hx if face in 'NS' else hy) * 0.92, ph + u * (hx if face in 'NS' else hy) * 0.92
    s.box('metal_dark' if kind == 'washer' else 'steel', min(a[0], b[0]) - (0.012 if face in 'EW' else 0), min(a[1], b[1]) - (0.012 if face in 'NS' else 0), ph[2] - 0.07,
          max(a[0], b[0]) + (0.012 if face in 'EW' else 0) + (fx * 0.015 if fx > 0 else 0), max(a[1], b[1]) + (0.012 if face in 'NS' else 0) + (fy * 0.015 if fy > 0 else 0), ph[2] + 0.07) if False else None
    ring(s, 'appliance', ph + u * 0.18, n, 0.0, 0.035, 0.03, seg=14, inner=False)
    px, py = x + fx * (max(hx, hy) + 0.55), y + fy * (max(hx, hy) + 0.55)
    MACHINES.append(dict(kind=kind, x=round(px, 3), y=round(py, 3), z=round(z0 + h * 0.5, 3), h=round(heading(-fx, -fy), 1)))


def building():
    s = Shell('rox_laundromat', 'ROX Laundry', 'مغسلة ROX', H=H, wall_t=T)
    s.hull = False; s.txd, s.lod = 'rox_laundry_txd', 400
    s.room('main', X0, Y0, X1, Y1, floor='tile_check', wall='paint_white', ceil='concrete_wall', H=H,
           wains=('tile_mint', 1.45), base=None, crown=True)
    # ---- shop front: double door + two big windows (open frames you can see through)
    s.door('main', 'S', -0.8, 1.0, h=2.5, casing='metal_dark')
    s.door_leaf('main', 'S', (-0.8, Y0), 0.9, 2.45, 'l', 'black_glass', 100)
    s.door_leaf('main', 'S', (1.0, Y0), 0.9, 2.45, 'r', 'black_glass', 100)
    s.window('main', 'S', -7.4, -1.6, sill=0.55, head=2.85, glass=None, frame='metal_dark', cols=4, depth=0.3)
    s.window('main', 'S', 1.8, 7.4, sill=0.55, head=2.85, glass=None, frame='metal_dark', cols=4, depth=0.3)
    s.window('main', 'E', -3.5, -0.5, sill=1.6, head=2.8, glass=None, frame='metal_dark', cols=3, depth=0.3)
    s.entry = (0.1, Y0 - 1.5, 1.0, 0.0)
    s.build_rooms()
    exterior(s)
    interior(s)
    s.bb = (X0 - 1.6, Y0 - 3.2, -0.1, X1 + 0.6, Y1 + 0.6, H + 4.0)
    s.meta = dict(model='rox_laundromat', machines=MACHINES)
    return s


def exterior(s):
    Hx = H + 3.6
    for side in 'SNWE':
        O, U, Nn, L = s.frame('main', side)
        holes = [(L + T - h[2], h[1], L + T - h[0], h[3]) for h in s.holes[('main', side)]]
        mat = 'brick_red' if side == 'S' else 'brick_dark'
        Oo = O + U * (L + T) - Nn * T
        s.surf(mat, Oo, -U, Z, L + 2 * T, Hx, holes=holes, step=2.0)
        for h in s.holes[('main', side)]:     # reveal through the full wall thickness
            s._reveal('main', side, h[0], h[2], h[1], h[3], T, 'stone', back=None)
        s.cbox(*(lambda p, q: (min(p[0], q[0]), min(p[1], q[1]), H, max(p[0], q[0]), max(p[1], q[1]), Hx))(Oo, O - Nn * 0.0 + U * 0), 13, occ=False) if False else None
    # roof + parapet
    s.box('roof', X0 - T, Y0 - T, H + 3.35, X1 + T, Y1 + T, H + 3.4, faces='Z', tag='ceil')
    s.box('stone', X0 - T - 0.05, Y0 - T - 0.05, H + 3.6, X1 + T + 0.05, Y1 + T + 0.05, H + 3.75, faces='xXyYZ')
    s.box('stone', X0 - T - 0.2, Y0 - T - 0.35, H + 3.3, X1 + T + 0.2, Y0 - T, H + 3.6, faces='xXyzZ')
    for k in range(int((X1 - X0 + 2 * T) / 0.6)):
        x = X0 - T + 0.3 + k * 0.6; s.box('stone', x - 0.1, Y0 - T - 0.28, H + 3.05, x + 0.1, Y0 - T, H + 3.3)
    # upper storey: dark windows with stone sills / lintels (apartments above the shop)
    for x in (-6.2, -3.1, 3.1, 6.2):
        for (sd, yy, nn) in (('S', Y0 - T, -1),):
            s.box('stone', x - 0.75, yy - 0.12, H + 1.0, x + 0.75, yy, H + 1.1); s.box('stone', x - 0.75, yy - 0.08, H + 2.6, x + 0.75, yy, H + 2.75)
            s.box('black_glass', x - 0.6, yy - 0.012, H + 1.1, x + 0.6, yy, H + 2.6, faces='y')
            s.box('trim', x - 0.025, yy - 0.04, H + 1.1, x + 0.025, yy, H + 2.6); s.box('trim', x - 0.6, yy - 0.04, H + 1.83, x + 0.6, yy, H + 1.88)
            s.box('metal_dark', x - 0.75, yy - 0.45, H + 1.1, x + 0.75, yy - 0.4, H + 1.14); s.box('metal_dark', x - 0.75, yy - 0.45, H + 1.9, x + 0.75, yy - 0.42, H + 1.93)
            for i in range(9): s.box('metal_dark', x - 0.72 + i * 0.18, yy - 0.44, H + 1.14, x - 0.7 + i * 0.18, yy - 0.42, H + 1.9)
            s.box('metal_dark', x - 0.75, yy - 0.45, H + 1.1, x - 0.72, yy, H + 1.93); s.box('metal_dark', x + 0.72, yy - 0.45, H + 1.1, x + 0.75, yy, H + 1.93)
    s.cbox(X0 - T, Y0 - T, H, X1 + T, Y1 + T, H + 3.6, 13, occ=False)
    # projecting blade sign on the corner
    s.box('metal_dark', X1 - 0.2, Y0 - T - 1.25, 2.95, X1 - 0.1, Y0 - T, 3.05); s.box('metal_dark', X1 - 0.2, Y0 - T - 1.25, 5.55, X1 - 0.1, Y0 - T, 5.65)
    s.box('metal_dark', X1 - 0.21, Y0 - T - 1.2, 3.05, X1 - 0.09, Y0 - T - 0.1, 5.55)
    s.surf('blade_laundry', (X1 - 0.215, Y0 - T - 0.12, 3.12), -Y, Z, 1.06, 2.36, step=0, fit=True)
    s.surf('blade_laundry', (X1 - 0.085, Y0 - T - 1.18, 3.12), Y, Z, 1.06, 2.36, step=0, fit=True)
    s.light(X1 - 0.8, Y0 - T - 0.65, 4.2, color=(255, 120, 60), intensity=4, falloff=5)
    s.cbox(X0 - T, Y0 - T, H + 3.2, X1 + T, Y1 + T, H + 3.4, 1)
    # stone plinth + cornice on the front
    s.box('stone', X0 - T - 0.04, Y0 - T - 0.06, 0, X1 + T + 0.04, Y0 - T, 0.45, faces='xXyZ')
    s.box('stone', X0 - T - 0.1, Y0 - T - 0.25, 3.05, X1 + T + 0.1, Y0 - T, 3.2, faces='xXyzZ')
    # big lit sign
    s.box('metal_dark', -4.6, Y0 - T - 0.22, 3.3, 4.6, Y0 - T, 4.4)
    s.surf('sign_laundry', (-4.5, Y0 - T - 0.225, 3.38), X, Z, 9.0, 0.95, step=0, fit=True)
    for x in (-3.5, 0.0, 3.5):
        s.box('metal_dark', x - 0.02, Y0 - T - 0.8, 4.45, x + 0.02, Y0 - T - 0.2, 4.5); s.box('metal_dark', x - 0.09, Y0 - T - 0.92, 4.3, x + 0.09, Y0 - T - 0.72, 4.45)
    s.light(0, Y0 - 1.6, 3.9, color=(255, 200, 160), intensity=8, falloff=9)
    # striped awnings over the windows
    from street import extrude
    for (a, b) in ((-7.5, -1.5), (1.7, 7.5)):
        extrude(s, 'awning_red', [(0, 0), (0, 0.25), (-1.3, 0.7), (-1.3, 0.55), (-0.04, 0.13)], (a, Y0 - T - 1.3, 2.9), -Y, X, b - a, fan=1)
    # neon OPEN sign hanging in the right window
    s.box('metal_dark', 4.0, Y0 + 0.05, 2.2, 5.6, Y0 + 0.1, 2.62); s.surf('sign_open', (4.05, Y0 + 0.045, 2.24), X, Z, 1.5, 0.36, step=0, fit=True)
    s.light(4.8, Y0 - 0.6, 2.4, color=(255, 60, 60), intensity=3, falloff=4)
    # pavement in front + wall lamps
    s.box('pavement', X0 - 1.0, Y0 - 3.2, -0.15, X1 + 1.0, Y0 - T, 0.0, faces='xXyZ', step=3.0); s.cbox(X0 - 1.0, Y0 - 3.2, -0.15, X1 + 1.0, Y0 - T, 0, 1)
    for x in (-7.8, 7.8):
        s.box('metal_dark', x - 0.08, Y0 - T - 0.35, 2.6, x + 0.08, Y0 - T, 2.8); s.box('light', x - 0.12, Y0 - T - 0.45, 2.45, x + 0.12, Y0 - T - 0.25, 2.62)
        s.light(x, Y0 - 1.0, 2.4, color=(255, 214, 160), intensity=4, falloff=6)
    # plants by the door are GTA props (rox_laundry shared/props.lua)


def interior(s):
    # furniture, machines, plants and chairs are real GTA props placed by rox_laundry (shared/props.lua)
    # posters + clock
    s.surf('poster_laundry', (X1 - 0.01, -1.6, 1.55), Y, Z, 1.2, 1.6, step=0, fit=True) if False else None
    s.surf('poster_laundry', (2.4, Y1 - 0.01, 1.6), -X, Z, 1.15, 1.5, step=0, fit=True)
    s.surf('poster_laundry', (X0 + 0.01, -4.6 + 0.0, 2.0), Y, Z, 0.0001, 0.0001, step=0, fit=True) if False else None
    s.cyl('appliance', 4.6, Y1 - 0.02, 2.6, 0.25, 0.02, seg=24) if False else None
    s.box('appliance', 4.35, Y1 - 0.04, 2.35, 4.85, Y1, 2.85); s.box('metal_dark', 4.59, Y1 - 0.05, 2.6, 4.61, Y1 - 0.04, 2.8); s.box('metal_dark', 4.6, Y1 - 0.05, 2.59, 4.75, Y1 - 0.04, 2.61)
    # restroom / staff door on the north wall
    s.box('trim', 3.3, Y1 - 0.05, 0, 4.3, Y1, 2.15, faces='y'); s.surf('door_grey', (3.35, Y1 - 0.055, 0), X, Z, 0.9, 2.1, step=0, fit=True)
    # ceiling: exposed concrete, black track rails with spots, long LED bars, pendants over the folding tables
    for y in (-3.4, 3.0):
        s.box('metal_dark', X0 + 0.6, y - 0.03, H - 0.06, X1 - 0.6, y + 0.03, H)
        for k in range(9):
            x = X0 + 1.2 + k * 1.7
            s.box('metal_dark', x - 0.05, y - 0.05, H - 0.2, x + 0.05, y + 0.05, H - 0.06); s.cyl('metal_dark', x, y, H - 0.38, 0.06, 0.18, seg=12)
            s.cyl('light', x, y, H - 0.385, 0.05, 0.004, seg=12)
            if k % 2 == 0: s.light(x, y, H - 0.6, color=(255, 228, 190), intensity=5, falloff=7)
    for x in (-4.0, 0.0):
        s.box('metal_dark', x - 1.4, -0.05, H - 0.7, x + 1.4, 0.05, H - 0.62); s.box('light', x - 1.35, -0.04, H - 0.705, x + 1.35, 0.04, H - 0.7, faces='z')
        for k in range(4): s.box('metal_dark', x - 1.3 + k * 0.86, -0.006, H - 0.62, x - 1.29 + k * 0.86, 0.006, H)
        s.light(x, 0, H - 1.0, color=(240, 244, 255), intensity=6, falloff=8)
    for (a, b) in ((2.6, -1.0), (2.6, 1.6)):
        for k in range(3):
            x = a + 0.5 + k * 0.9
            s.box('metal_dark', x - 0.004, b - 0.004, 1.9, x + 0.004, b + 0.004, H); s.cyl('brass', x, b, 1.62, 0.2, 0.28, seg=16, r2=0.05, caps=False)
            s.cyl('light', x, b, 1.615, 0.17, 0.006, seg=16); s.light(x, b, 1.45, color=(255, 210, 150), intensity=3.5, falloff=4.5)
    # neon signs on the walls
    s.box('paint_black', 2.0, Y1 - 0.06, 2.35, 5.0, Y1 - 0.02, 2.9); s.surf('neon_wash', (2.05, Y1 - 0.065, 2.38), X, Z, 2.9, 0.48, step=0, fit=True)
    s.light(3.5, Y1 - 0.7, 2.6, color=(255, 90, 200), intensity=3, falloff=4)
    s.box('paint_black', X0 + 0.02, -4.4, 2.3, X0 + 0.06, -2.0, 2.85); s.surf('neon_heart', (X0 + 0.065, -4.35, 2.33), Y, Z, 2.3, 0.48, step=0, fit=True)
    s.light(X0 + 0.8, -3.2, 2.5, color=(90, 230, 255), intensity=3, falloff=4)
    # oak slat feature wall behind the cashier + LED shelf strips
    for k in range(24):
        x = 5.0 + k * 0.12
        if x < X1 - 0.05: s.box('wood_door', x, Y1 - 0.06, 0, x + 0.07, Y1 - 0.02, 2.25 if False else 1.25)



def all_pieces():
    MACHINES.clear()
    return [building()]
