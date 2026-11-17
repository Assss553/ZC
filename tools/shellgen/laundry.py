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
    px, py = x + fx * (max(hx, hy) + 0.55), y + fy * (max(hx, hy) + 0.55)
    MACHINES.append(dict(kind=kind, x=round(px, 3), y=round(py, 3), z=round(z0 + h * 0.5, 3), h=round(heading(-fx, -fy), 1)))


def building():
    s = Shell('rox_laundromat', 'ROX Laundry', 'مغسلة ROX', H=H, wall_t=T)
    s.hull = False; s.txd, s.lod = 'rox_laundry_txd', 400
    s.room('main', X0, Y0, X1, Y1, floor='tile_check', wall='paint_white', ceil='ceiling_tile', H=H,
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
    s.bb = (X0 - 1.6, Y0 - 3.2, -0.1, X1 + 0.6, Y1 + 0.6, H + 1.6)
    s.meta = dict(model='rox_laundromat', machines=MACHINES)
    return s


def exterior(s):
    Hx = H + 1.0
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
    s.box('roof', X0 - T, Y0 - T, H + 0.2, X1 + T, Y1 + T, H + 0.25, faces='Z', tag='ceil')
    s.box('stone', X0 - T - 0.05, Y0 - T - 0.05, H + 1.0, X1 + T + 0.05, Y1 + T + 0.05, H + 1.12, faces='xXyYZ')
    s.cbox(X0 - T, Y0 - T, H, X1 + T, Y1 + T, H + 0.25, 1)
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
    for x in (-6.0, 6.0):   # planters by the door
        s.box('stone', x - 0.45, Y0 - 1.1, 0, x + 0.45, Y0 - 0.4, 0.55, col=11); s.box('hedge', x - 0.38, Y0 - 1.03, 0.55, x + 0.38, Y0 - 0.47, 0.95)


def interior(s):
    # west wall: 11 washers facing east
    for k in range(11): machine(s, 'washer', X0 + 0.36, -4.0 + k * 0.76, 'E')
    # north wall: stacked dryers (2 high) facing south
    for k in range(10):
        x = -6.6 + k * 0.82
        machine(s, 'dryer', x, Y1 - 0.4, 'S', w=0.8, d=0.78, h=0.88)
        machine(s, 'dryer', x, Y1 - 0.4, 'S', z0=1.0, w=0.8, d=0.78, h=0.88)
    s.box('paint_charcoal', -7.05, Y1 - 0.8, 1.88, 1.6, Y1, 2.05)
    s.box('paint_white', -7.05, Y1 - 0.8, 2.05, 1.6, Y1, H, faces='yZ')
    # centre island: back-to-back washers with a spine and detergent shelf
    for k in range(8):
        x = -4.6 + k * 0.76
        machine(s, 'washer', x, -0.42, 'S'); machine(s, 'washer', x, 0.42, 'N')
    s.box('countertop', -5.0, -0.8, 1.07, 1.1, 0.8, 1.12)
    s.box('paint_charcoal', -5.0, -0.06, 1.12, 1.1, 0.06, 1.75, col=1)
    s.box('countertop', -5.05, -0.22, 1.75, 1.15, 0.22, 1.8)
    s.cbox(-5.0, -0.8, 1.07, 1.1, 0.8, 1.12, 14)
    rng = np.random.default_rng(5)
    for k in range(18):   # detergent bottles on the shelf
        x = -4.9 + k * 0.33 + rng.uniform(-0.05, 0.05); y = 0.1 * (-1) ** k
        m = ('paint_orange', 'paint_teal', 'paint_navy', 'paint_yellow2' if False else 'paint_ochre', 'paint_pink')[k % 5]
        s.box(m, x - 0.06, y - 0.05, 1.8, x + 0.06, y + 0.05, 2.06); s.box('appliance', x - 0.025, y - 0.025, 2.06, x + 0.025, y + 0.025, 2.12)
    # folding tables
    for (a, b) in ((2.6, -1.0), (2.6, 1.6)):
        s.box('countertop', a, b - 0.5, 0.9, a + 2.8, b + 0.5, 0.95, col=14)
        for (lx, ly) in ((0.1, 0.1), (2.7, 0.1), (0.1, 0.9), (2.7, 0.9)): s.box('steel', a + lx - 0.03, b - 0.5 + ly - 0.03, 0, a + lx + 0.03, b - 0.5 + ly + 0.03, 0.9, faces='xXyY')
        s.box('steel', a + 0.1, b - 0.45, 0.25, a + 2.7, b + 0.45, 0.28)
        for k in range(3):   # folded towels
            s.box(('paint_white', 'paint_sky', 'paint_blush')[k], a + 0.4 + k * 0.8, b - 0.2, 0.95, a + 0.85 + k * 0.8, b + 0.15, 1.05 + 0.03 * k)
    MACHINES.append(dict(kind='fold', x=4.0, y=-2.0, z=1.0, h=0.0))
    # cashier counter (L) with register
    s.box('wood_dark', 5.4, 2.4, 0, 5.9, Y1 - 0.9, 1.05, col=70, occ=True); s.box('wood_dark', 5.4, 2.4, 0, X1 - 0.1, 2.9, 1.05, col=70, occ=True)
    s.box('countertop', 5.35, 2.35, 1.05, 5.95, Y1 - 0.85, 1.1); s.box('countertop', 5.35, 2.35, 1.05, X1 - 0.05, 2.95, 1.1)
    s.box('black_glass', 6.4, 2.55, 1.1, 6.85, 2.85, 1.22); s.box('black_glass', 6.5, 2.75, 1.22, 6.8, 2.8, 1.5); s.box('paint_charcoal', 6.35, 2.5, 1.1, 6.9, 2.9, 1.14)
    s.surf('poster_laundry', (X1 - 0.02, 3.2, 1.3), -Y if False else Y, Z, 1.2, 1.6, step=0, fit=True) if False else None
    MACHINES.append(dict(kind='cashier', x=6.6, y=1.9, z=1.0, h=0.0))
    # shelves behind the counter
    for z in (1.3, 1.75, 2.2):
        s.box('wood_door', 6.2, Y1 - 0.35, z, X1 - 0.05, Y1 - 0.05, z + 0.04)
        for k in range(5): s.box(('paint_orange', 'paint_teal', 'paint_navy', 'paint_ochre', 'paint_pink')[(k + int(z * 3)) % 5], 6.3 + k * 0.32, Y1 - 0.3, z + 0.04, 6.5 + k * 0.32, Y1 - 0.12, z + 0.32)
    # change machine + vending machine on the east wall
    s.box('steel', X1 - 0.45, -4.4, 0, X1 - 0.02, -3.75, 1.7, col=56, occ=True); s.box('black_glass', X1 - 0.46, -4.3, 0.95, X1 - 0.45, -3.85, 1.45, faces='x')
    s.box('paint_red', X1 - 0.8, -3.5, 0, X1 - 0.02, -2.55, 1.95, col=56, occ=True); s.box('black_glass', X1 - 0.81, -3.4, 0.6, X1 - 0.8, -2.85, 1.8, faces='x')
    s.box('light', X1 - 0.82, -2.82, 0.6, X1 - 0.8, -2.65, 1.8, faces='x'); s.light(X1 - 1.4, -3.0, 1.3, color=(220, 235, 255), intensity=2, falloff=3)
    # waiting area by the windows: chairs + magazine table + plants
    for k in range(6):
        x = -6.8 + k * 0.62
        s.box('paint_orange', x - 0.24, Y0 + 0.35, 0.42, x + 0.24, Y0 + 0.82, 0.48, col=70); s.box('paint_orange', x - 0.24, Y0 + 0.3, 0.48, x + 0.24, Y0 + 0.36, 0.95)
        for lx in (-0.2, 0.2): s.box('steel', x + lx - 0.015, Y0 + 0.4, 0, x + lx + 0.015, Y0 + 0.77, 0.42, faces='xXyY')
    s.box('steel', -6.95, Y0 + 0.36, 0.02, -3.35, Y0 + 0.78, 0.06)
    for x in (-7.5, 1.5, 7.4):
        s.cyl('paint_charcoal', x, Y0 + 0.5 if x != 7.4 else 4.6, 0, 0.22, 0.45, seg=14, r2=0.26); sphere(s, 'hedge', x, Y0 + 0.5 if x != 7.4 else 4.6, 1.05, 0.42, sq=1.3)
    # laundry carts
    for (x, y) in ((-2.0, 2.0), (1.4, 2.4), (-2.6, -2.6)):
        for (lx, ly) in ((-0.3, -0.22), (0.3, -0.22), (-0.3, 0.22), (0.3, 0.22)):
            s.box('steel', x + lx - 0.012, y + ly - 0.012, 0.06, x + lx + 0.012, y + ly + 0.012, 0.95, faces='xXyY'); s.cyl('metal_dark', x + lx, y + ly, 0, 0.04, 0.06, seg=8)
        s.box('steel', x - 0.32, y - 0.24, 0.92, x + 0.32, y + 0.24, 0.95); s.box('fabric', x - 0.28, y - 0.2, 0.45, x + 0.28, y + 0.2, 0.92, faces='xXyYz')
        s.box('steel', x - 0.32, y - 0.012, 1.0, x + 0.32, y + 0.012, 1.85); s.box('steel', x - 0.34, y - 0.03, 1.8, x + 0.34, y + 0.03, 1.84)
        s.cbox(x - 0.33, y - 0.25, 0, x + 0.33, y + 0.25, 0.95, 56, occ=False)
    # posters + clock
    s.surf('poster_laundry', (X1 - 0.01, -1.6, 1.55), Y, Z, 1.2, 1.6, step=0, fit=True) if False else None
    s.surf('poster_laundry', (2.4, Y1 - 0.01, 1.6), -X, Z, 1.15, 1.5, step=0, fit=True)
    s.surf('poster_laundry', (X0 + 0.01, -4.6 + 0.0, 2.0), Y, Z, 0.0001, 0.0001, step=0, fit=True) if False else None
    s.cyl('appliance', 4.6, Y1 - 0.02, 2.6, 0.25, 0.02, seg=24) if False else None
    s.box('appliance', 4.35, Y1 - 0.04, 2.35, 4.85, Y1, 2.85); s.box('metal_dark', 4.59, Y1 - 0.05, 2.6, 4.61, Y1 - 0.04, 2.8); s.box('metal_dark', 4.6, Y1 - 0.05, 2.59, 4.75, Y1 - 0.04, 2.61)
    # restroom / staff door on the north wall
    s.box('trim', 3.3, Y1 - 0.05, 0, 4.3, Y1, 2.15, faces='y'); s.surf('door_grey', (3.35, Y1 - 0.055, 0), X, Z, 0.9, 2.1, step=0, fit=True)
    # ceiling: linear lights + fans
    for y in (-3.2, -1.2, 1.0, 3.2):
        for x in (-5.5, -1.5, 2.5, 6.0):
            s.linear_light(x, y, H, 1.6, 'x', drop=0.02, intensity=4.5, falloff=7)
    s.fan(-2.0, -2.0, H); s.fan(3.8, 0.3, H)


def all_pieces():
    MACHINES.clear()
    return [building()]
