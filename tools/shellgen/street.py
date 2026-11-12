# ROX street district - exterior map pieces  (c) ROX Store
# Every piece is modelled in the same local space, so all of them are spawned at one origin.
import numpy as np, math, random
from kit import Shell, X, Y, Z

TXD = 'rox_street_txd'


def piece(name, label):
    s = Shell(name, label, label)
    s.txd, s.lod = TXD, 1200
    return s


def sphere(s, mat, cx, cy, cz, r, seg=14, rings=8, sq=1.0):
    """Smooth-shaded ellipsoid (centre cx,cy,cz)."""
    from kit import MATS
    tile = MATS[mat]['tile']; P, N, UV, T, I = [], [], [], [], []
    for i in range(rings + 1):
        v = math.pi * i / rings
        for k in range(seg + 1):
            u = 2 * math.pi * k / seg
            n = np.array([math.sin(v) * math.cos(u), math.sin(v) * math.sin(u), -math.cos(v)])
            P.append((cx + n[0] * r, cy + n[1] * r, cz + n[2] * r * sq)); nn = n * np.array([1, 1, 1 / sq]); N.append(nn / np.linalg.norm(nn))
            UV.append((u * r / tile, -v * r / tile)); T.append((-math.sin(u), math.cos(u), 0, 1))
    for i in range(rings):
        for k in range(seg):
            a, b = i * (seg + 1) + k, (i + 1) * (seg + 1) + k
            I += [a, a + 1, b + 1, a, b + 1, b]
    s._add(mat, '', P, N, UV, T, I)


def extrude(s, mat, prof, O, U, V, w, col=None, fan=0, skip=()):
    """Extrude a closed (a, z) profile lying in the U/Z plane along V. Used for ramps, steps, kerbs."""
    from kit import MATS
    O, U, V = np.asarray(O, float), np.asarray(U, float), np.asarray(V, float)
    n = len(prof); cen = np.mean(np.array(prof), 0)
    pt = lambda p, d=0.0: O + U * p[0] + Z * p[1] + V * d
    for i in range(n):
        if i in skip: continue
        p, q = prof[i], prof[(i + 1) % n]
        E = U * (q[0] - p[0]) + Z * (q[1] - p[1]); ln = float(np.linalg.norm(E))
        if ln < 1e-6: continue
        E = E / ln; nrm = np.cross(E, V)
        mid = np.array([(p[0] + q[0]) / 2 - cen[0], (p[1] + q[1]) / 2 - cen[1]])
        out = float(np.dot(nrm, U) * mid[0] + nrm[2] * mid[1])
        if out >= 0: s.quad(mat, pt(p), E, V, ln, w, col=col)
        else: s.quad(mat, pt(p, w), E, -V, ln, w, col=col)
    tile = MATS[mat]['tile']
    for (d, nv) in ((0.0, -V), (w, V)):
        P = [pt(p, d) for p in prof]; I = []
        for i in range(n):
            a, b = i, (i + 1) % n
            if a == fan or b == fan: continue
            tri = [fan, a, b]
            if np.dot(np.cross(P[a] - P[fan], P[b] - P[fan]), nv) < 0: tri = [fan, b, a]
            I += tri
        s._add(mat, '', P, np.tile(nv, (n, 1)), [(p[0] / tile, -p[1] / tile) for p in prof], np.tile(np.append(U, 1.0), (n, 1)), I)
        if col is not None:
            for k in range(0, len(I), 3): s.ctris.append((P[I[k]], P[I[k + 1]], P[I[k + 2]], col))


def ball_tree(s, x, y, z, h=3.2, r=1.5, planter=True):
    if planter:
        s.box('stone', x - 0.75, y - 0.75, z, x + 0.75, y + 0.75, z + 0.45, faces='xXyYZ', col=11)
        s.box('hedge', x - 0.62, y - 0.62, z + 0.45, x + 0.62, y + 0.62, z + 0.5, faces='Z')
    s.cyl('wood_dark', x, y, z + 0.4, 0.13, h - 0.4, seg=8, r2=0.09, caps=False)
    s.cbox(x - 0.15, y - 0.15, z, x + 0.15, y + 0.15, z + h, 46, occ=False)
    sphere(s, 'hedge', x, y, z + h + r * 0.55, r, sq=0.85)
    sphere(s, 'hedge', x + r * 0.45, y - r * 0.3, z + h + r * 0.25, r * 0.62)
    sphere(s, 'hedge', x - r * 0.4, y + r * 0.35, z + h + r * 0.35, r * 0.66)


def street_light(s, x, y, z, side):
    """side = +1 arm towards +y, -1 towards -y"""
    s.cyl('metal_dark', x, y, z, 0.16, 0.5, seg=10); s.cyl('metal_dark', x, y, z + 0.5, 0.085, 7.3, seg=10, r2=0.06)
    s.cbox(x - 0.16, y - 0.16, z, x + 0.16, y + 0.16, z + 7.8, 56, occ=False)
    y1 = y + side * 2.4
    s.box('metal_dark', x - 0.04, min(y, y1), z + 7.7, x + 0.04, max(y, y1), z + 7.78)
    s.box('metal_dark', x - 0.16, min(y1, y1 + side * 0.8), z + 7.62, x + 0.16, max(y1, y1 + side * 0.8), z + 7.8)
    s.box('light', x - 0.12, min(y1, y1 + side * 0.8) + 0.05, z + 7.6, x + 0.12, max(y1, y1 + side * 0.8) - 0.05, z + 7.62, faces='z')
    s.light(x, y1 + side * 0.4, z + 7.4, color=(255, 214, 160), intensity=9, falloff=18)


def bench(s, x, y, z, yaw):
    r = math.radians(yaw); U = np.array([math.cos(r), math.sin(r)]); V = np.array([-math.sin(r), math.cos(r)])
    at = lambda a, b: (x + U[0] * a + V[0] * b, y + U[1] * a + V[1] * b)
    for a in (-0.75, 0.75):
        cx, cy = at(a, 0.0); s.obox('metal_dark', cx, cy, z, 0.06, 0.5, 0.44, yaw)
        cx, cy = at(a, 0.24); s.obox('metal_dark', cx, cy, z + 0.44, 0.06, 0.05, 0.46, yaw)
    for b in (-0.17, -0.02, 0.13):
        cx, cy = at(0, b); s.obox('planks', cx, cy, z + 0.44, 1.8, 0.12, 0.035, yaw)
    for zz in (0.58, 0.74):
        cx, cy = at(0, 0.25); s.obox('planks', cx, cy, z + zz, 1.8, 0.035, 0.12, yaw)
    cx, cy = at(0, 0.04); s.cbox(cx - 0.6, cy - 0.6, z, cx + 0.6, cy + 0.6, z + 0.5, 70, occ=False)


def bin_(s, x, y, z):
    s.cyl('paint_green', x, y, z, 0.27, 0.85, seg=12); s.cyl('metal_dark', x, y, z + 0.85, 0.3, 0.07, seg=12); s.cyl('metal_dark', x, y, z + 0.92, 0.2, 0.01, seg=12)
    s.cbox(x - 0.27, y - 0.27, z, x + 0.27, y + 0.27, z + 0.9, 56, occ=False)


def bollard(s, x, y, z):
    s.cyl('metal_dark', x, y, z, 0.085, 0.85, seg=8); s.cyl('paint_yellow', x, y, z + 0.6, 0.09, 0.1, seg=8, caps=False); s.cyl('metal_dark', x, y, z + 0.85, 0.1, 0.05, seg=8, r2=0.04)
    s.cbox(x - 0.09, y - 0.09, z, x + 0.09, y + 0.09, z + 0.9, 56, occ=False)


def hydrant(s, x, y, z):
    s.cyl('paint_red', x, y, z, 0.13, 0.5, seg=10); s.cyl('paint_red', x, y, z + 0.5, 0.15, 0.06, seg=10); s.cyl('paint_red', x, y, z + 0.56, 0.11, 0.14, seg=10, r2=0.03)
    s.box('paint_red', x - 0.22, y - 0.05, z + 0.3, x + 0.22, y + 0.05, z + 0.4)
    s.cbox(x - 0.15, y - 0.15, z, x + 0.15, y + 0.15, z + 0.7, 56, occ=False)


def planter(s, x0, y0, x1, y1, z, h=0.55, hedge_h=0.6):
    s.box('stone', x0, y0, z, x1, y1, z + h, faces='xXyYZ', col=11)
    s.box('hedge', x0 + 0.12, y0 + 0.12, z + h, x1 - 0.12, y1 - 0.12, z + h + hedge_h, faces='xXyYZ', col=46)


def traffic_light(s, x, y, z, ax, ay):
    """Pole at x,y with an arm reaching (ax, ay) metres over the road, heads facing against the arm's left."""
    s.cyl('metal_dark', x, y, z, 0.18, 0.6, seg=10); s.cyl('metal_dark', x, y, z + 0.6, 0.1, 5.6, seg=10)
    s.cbox(x - 0.18, y - 0.18, z, x + 0.18, y + 0.18, z + 6.2, 56, occ=False)
    s.box('metal_dark', min(x, x + ax) - 0.05, min(y, y + ay) - 0.05, z + 5.9, max(x, x + ax) + 0.05, max(y, y + ay) + 0.05, z + 6.02)
    for t in (0.55, 1.0):
        hx, hy = x + ax * t, y + ay * t
        s.box('metal_dark', hx - 0.2, hy - 0.2, z + 4.75, hx + 0.2, hy + 0.2, z + 5.9)
        for k, m in enumerate(('paint_green', 'paint_yellow', 'paint_red')):
            zc = z + 4.95 + 0.36 * k
            if ax:   # arm along x -> faces look along +-y
                s.box(m, hx - 0.11, hy - 0.215, zc - 0.11, hx + 0.11, hy + 0.215, zc + 0.11, faces='yY')
            else:
                s.box(m, hx - 0.215, hy - 0.11, zc - 0.11, hx + 0.215, hy + 0.11, zc + 0.11, faces='xX')


def bus_shelter(s, x, y, z, face):
    """Shelter 4 m long along x, open towards face (+1 = +y, -1 = -y)."""
    yb = y - face * 0.75
    for px in (x - 2, x + 2):
        for py in (y - 0.75, y + 0.75):
            s.cyl('steel', px, py, z, 0.04, 2.5, seg=8)
    s.box('metal_dark', x - 2.2, y - 0.95, z + 2.5, x + 2.2, y + 0.95, z + 2.58)
    s.box('window_dark', x - 2, yb - 0.015, z + 0.25, x + 2, yb + 0.015, z + 2.3)
    s.box('window_dark', x - 2.015, y - 0.75, z + 0.25, x - 1.985, y + 0.75, z + 2.3)
    s.surf('sign_parking', (x + 2.02, y - 0.6, z + 0.5), Y, Z, 1.2, 1.7, step=0, fit=True); s.surf('sign_parking', (x + 1.98, y + 0.6, z + 0.5), -Y, Z, 1.2, 1.7, step=0, fit=True)
    s.box('metal_dark', x + 1.985, y - 0.65, z + 0.25, x + 2.015, y + 0.65, z + 2.3, faces='yY')
    s.box('planks', x - 1.6, yb + face * 0.1 - 0.2, z + 0.42, x + 1.3, yb + face * 0.1 + 0.2, z + 0.47)
    for px in (x - 1.4, x + 1.1):
        s.box('metal_dark', px - 0.03, yb + face * 0.1 - 0.18, z, px + 0.03, yb + face * 0.1 + 0.18, z + 0.42)
    s.cbox(x - 2, yb - 0.05, z, x + 2, yb + 0.05, z + 2.5, 114, occ=False); s.cbox(x - 2.2, y - 0.95, z + 2.5, x + 2.2, y + 0.95, z + 2.58, 56)
    s.light(x, y, z + 2.3, color=(220, 235, 255), intensity=4, falloff=6)


def barrier(s, x, y, z, along='y', n=1):
    """Concrete jersey barrier segments 2 m each."""
    for i in range(n):
        o = (i - (n - 1) / 2) * 2.05
        cx, cy = (x, y + o) if along == 'y' else (x + o, y)
        U, V = (X, Y) if along == 'y' else (Y, -X)
        O = np.array([cx, cy, z]) - V * 1.0
        extrude(s, 'concrete_wall', [(-0.3, 0), (0.3, 0), (0.3, 0.12), (0.1, 0.38), (0.08, 0.85), (-0.08, 0.85), (-0.1, 0.38), (-0.3, 0.12)], O, U, V, 2.0, fan=0, skip=(0,))
        if i % 2 == 0:
            extrude(s, 'paint_red', [(-0.085, 0.6), (0.085, 0.6), (0.085, 0.8), (-0.085, 0.8)], O + V * 0.3, U, V, 1.4, fan=0)
    L = n * 2.05 / 2
    if along == 'y': s.cbox(x - 0.3, y - L, z, x + 0.3, y + L, z + 0.85, 1, occ=False)
    else: s.cbox(x - L, y - 0.3, z, x + L, y + 0.3, z + 0.85, 1, occ=False)


class Face:
    """Outward facing facade plane. P(a, z, d) = O + U*a + N*d + Z*z"""
    def __init__(f, s, x0, y0, x1, y1, side, zb=0.0):
        f.s, f.zb = s, zb
        if side == 'S': f.O, f.N, f.L = np.array([x0, y0, zb]), -Y, x1 - x0
        elif side == 'N': f.O, f.N, f.L = np.array([x1, y1, zb]), Y, x1 - x0
        elif side == 'W': f.O, f.N, f.L = np.array([x0, y1, zb]), -X, y1 - y0
        else: f.O, f.N, f.L = np.array([x1, y0, zb]), X, y1 - y0
        f.U = np.cross(Z, f.N)

    def P(f, a, z, d=0.0):
        return f.O + f.U * a + f.N * d + Z * z

    def box(f, mat, a0, a1, z0, z1, d0, d1, **kw):
        p, q = f.P(a0, z0, d0), f.P(a1, z1, d1)
        f.s.box(mat, p[0], p[1], p[2], q[0], q[1], q[2], **kw)

    def wall(f, mat, z0, z1, holes=(), step=4.0):
        hs = [(h[0], h[1] - z0, h[2], h[3] - z0) for h in holes]
        f.s.surf(mat, f.P(0, z0), f.U, Z, f.L, z1 - z0, holes=hs, step=step)

    def recess(f, a0, a1, z0, z1, D, mat, back, fit=True):
        s, U, N = f.s, f.U, f.N
        s.surf(mat, f.P(a0, z0, 0), -N, Z, D, z1 - z0, step=0)
        s.surf(mat, f.P(a1, z0, -D), N, Z, D, z1 - z0, step=0)
        s.surf(mat, f.P(a0, z0, 0), U, -N, a1 - a0, D, step=0)
        s.surf(mat, f.P(a0, z1, -D), U, N, a1 - a0, D, step=0)
        s.surf(back, f.P(a0, z0, -D), U, Z, a1 - a0, z1 - z0, step=0, fit=fit)

    def window(f, a0, a1, z0, z1, wall, frame='trim', D=0.2, cols=2, rows=2, sill='stone', lintel=True, ac=False, glass='window_dark'):
        f.recess(a0, a1, z0, z1, D, wall, glass)
        b = 0.05
        for (p, q, r, t) in ((a0, a0 + b, z0, z1), (a1 - b, a1, z0, z1), (a0, a1, z0, z0 + b), (a0, a1, z1 - b, z1)):
            f.box(frame, p, q, r, t, -D + 0.005, -D + 0.06)
        for k in range(1, cols):
            a = a0 + (a1 - a0) * k / cols
            f.box(frame, a - b / 2, a + b / 2, z0, z1, -D + 0.005, -D + 0.06)
        for k in range(1, rows):
            z = z0 + (z1 - z0) * k / rows
            f.box(frame, a0, a1, z - b / 2, z + b / 2, -D + 0.005, -D + 0.06)
        if sill:
            f.box(sill, a0 - 0.1, a1 + 0.1, z0 - 0.09, z0, -0.02, 0.1)
        if lintel:
            f.box(sill or 'stone', a0 - 0.12, a1 + 0.12, z1, z1 + 0.16, -0.02, 0.06)
        if ac:
            f.box('appliance', a0 + 0.15, a0 + 0.85, z0 + 0.02, z0 + 0.5, -0.1, 0.42)
            f.box('metal_dark', a0 + 0.2, a0 + 0.8, z0 + 0.08, z0 + 0.44, 0.42, 0.43)


def roof_kit(s, x0, y0, x1, y1, zt, rnd, tank=True, parapet='stone'):
    s.surf('roof', (x0, y0, zt), X, Y, x1 - x0, y1 - y0, step=6)
    p = 0.3
    for (a, b, c, d) in ((x0, y0, x1, y0 + p), (x0, y1 - p, x1, y1), (x0, y0 + p, x0 + p, y1 - p), (x1 - p, y0 + p, x1, y1 - p)):
        s.box(parapet, a, b, zt, c, d, zt + 0.9, faces='xXyYZ')
        s.box('metal_dark', a - 0.03, b - 0.03, zt + 0.9, c + 0.03, d + 0.03, zt + 0.96)
    w, d = x1 - x0, y1 - y0
    bx, by = x0 + w * 0.3, y0 + d * 0.55
    s.box('concrete_wall', bx, by, zt, bx + 3.2, by + 4, zt + 2.6, faces='xXyYZ', col=1)        # stair bulkhead
    s.box('door_grey', bx + 1.0, by - 0.02, zt, bx + 2.0, by, zt + 2.05, faces='y')
    for k in range(3):
        ax, ay = x0 + w * (0.55 + 0.12 * k), y0 + d * rnd.uniform(0.2, 0.35)
        s.box('appliance', ax, ay, zt + 0.15, ax + 1.4, ay + 1.1, zt + 1.1, faces='xXyYZ')
        s.box('metal_dark', ax + 0.1, ay + 0.1, zt, ax + 1.3, ay + 1.0, zt + 0.15, faces='xXyY')
        s.cyl('metal_dark', ax + 0.7, ay + 0.55, zt + 1.1, 0.42, 0.06, seg=14)
    for k in range(4):
        vx, vy = x0 + w * rnd.uniform(0.1, 0.9), y0 + d * rnd.uniform(0.65, 0.9)
        s.cyl('steel', vx, vy, zt, 0.12, 0.7, seg=10)
        s.cyl('steel', vx, vy, zt + 0.7, 0.2, 0.12, seg=10)
    if tank:
        tx, ty = x0 + w * 0.78, y0 + d * 0.7
        for (lx, ly) in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)):
            s.box('metal_dark', tx + lx - 0.07, ty + ly - 0.07, zt, tx + lx + 0.07, ty + ly + 0.07, zt + 2.2, faces='xXyY')
        s.box('metal_dark', tx - 1.1, ty - 1.1, zt + 2.2, tx + 1.1, ty + 1.1, zt + 2.32)
        s.cyl('wood_door', tx, ty, zt + 2.32, 1.25, 2.6, seg=18)
        s.cyl('metal_dark', tx, ty, zt + 4.92, 1.3, 0.7, seg=18, r2=0.1)
        for hz in (2.9, 3.9):
            s.cyl('metal_dark', tx, ty, zt + hz, 1.27, 0.07, seg=18, caps=False)


def fire_escape(s, f, a0, a1, floors, fh, base):
    for k in range(1, floors):
        z = base + fh * k
        f.box('metal_dark', a0, a1, z - 0.06, z, 0.0, 1.1)
        for (p, q, d0, d1) in ((a0, a1, 1.06, 1.1), (a0, a0 + 0.04, 0.0, 1.1), (a1 - 0.04, a1, 0.0, 1.1)):
            f.box('metal_dark', p, q, z + 0.95, z + 1.0, d0, d1)
            f.box('metal_dark', p, q, z + 0.5, z + 0.53, d0, d1)
        n = int((a1 - a0) / 0.35)
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            f.box('metal_dark', a - 0.012, a + 0.012, z, z + 0.95, 1.07, 1.095)
        if k > 1:  # ladder down to the previous landing
            la = a0 + 0.5 if k % 2 else a1 - 0.9
            for dd in (0.0, 0.4):
                f.box('metal_dark', la + dd, la + dd + 0.03, z - fh, z, 0.75, 0.78)
            for r in range(int(fh / 0.3)):
                f.box('metal_dark', la, la + 0.43, z - fh + 0.3 * r, z - fh + 0.3 * r + 0.025, 0.755, 0.775)


SHOPS = ('shop_market', 'shop_fashion', 'shop_cafe')


def building(name, label, x0, y0, x1, y1, floors, wall='brick_red', base='stone', fh=3.4, gh=4.8, bay=3.4, win=(1.5, 1.9),
             shop_sides='S', sign=None, awning=None, escape=None, garage=False, pilasters=True, seed=1, tank=True, frame='trim', ac_rate=0.25,
             balconies='', blade=None, billboard=None, shops=SHOPS):
    s = piece(name, label)
    rnd = random.Random(seed)
    H = gh + fh * (floors - 1)
    s.cbox(x0, y0, 0, x1, y1, H + 0.9, 13)
    for side in 'SNWE':
        f = Face(s, x0, y0, x1, y1, side)
        n = max(1, int(round(f.L / bay)))
        bw = f.L / n
        shop = side in shop_sides
        # ---- upper floors
        holes = []
        for k in range(1, floors):
            zf = gh + fh * (k - 1)
            for b in range(n):
                c = bw * (b + 0.5)
                holes.append((c - win[0] / 2, zf + 0.95, c + win[0] / 2, zf + 0.95 + win[1], b, k))
        f.wall(wall, gh, H, [h[:4] for h in holes])
        for (a0, z0, a1, z1, b, k) in holes:
            balc = side in balconies and b % 3 == 1
            f.window(a0, a1, z0, z1, wall, frame=frame, ac=(not balc) and rnd.random() < ac_rate)
            if rnd.random() < 0.3:                                    # half drawn blind
                f.box('fabric' if rnd.random() < 0.5 else 'trim', a0 + 0.05, a1 - 0.05, z1 - rnd.uniform(0.4, 1.1), z1 - 0.05, -0.19, -0.185)
            if balc:
                c = (a0 + a1) / 2; zb = z0 - 0.35
                f.box('concrete_wall', c - 1.35, c + 1.35, zb - 0.14, zb, 0, 1.15)
                for (p, q, d0, d1) in ((c - 1.35, c + 1.35, 1.11, 1.15), (c - 1.35, c - 1.31, 0, 1.15), (c + 1.31, c + 1.35, 0, 1.15)):
                    f.box('metal_dark', p, q, zb + 0.98, zb + 1.03, d0, d1)
                for i in range(15):
                    a = c - 1.33 + 2.66 * i / 14
                    f.box('metal_dark', a - 0.012, a + 0.012, zb, zb + 0.98, 1.12, 1.145)
                for d in (0.38, 0.76):
                    for a in (c - 1.33, c + 1.33):
                        f.box('metal_dark', a - 0.012, a + 0.012, zb, zb + 0.98, d - 0.012, d + 0.012)
                if rnd.random() < 0.5:
                    f.box('hedge', c - 1.2, c - 0.75, zb, zb + 0.55, 0.7, 1.05)
        for k in range(1, floors):                      # string courses
            z = gh + fh * (k - 1)
            f.box(base, 0, f.L, z - 0.12, z + 0.12, 0, 0.09 if k > 1 else 0.2)
        if pilasters:
            for b in range(n + 1):
                a = min(max(bw * b, 0.3), f.L - 0.3)
                f.box(wall, a - 0.3, a + 0.3, gh, H - 0.4, 0, 0.12)
                f.box(base, a - 0.36, a + 0.36, H - 0.75, H - 0.4, 0, 0.2)
        # cornice
        f.box(base, -0.3, f.L + 0.3, H - 0.4, H - 0.15, 0, 0.3)
        f.box(base, -0.5, f.L + 0.5, H - 0.15, H + 0.12, 0, 0.5)
        for b in range(int(f.L / 0.9)):
            a = 0.45 + b * 0.9
            f.box(base, a - 0.12, a + 0.12, H - 0.62, H - 0.4, 0, 0.26)
        # drain pipes on plain sides
        if not shop:
            for a in (0.55, f.L - 0.55):
                f.box('metal_dark', a - 0.06, a + 0.06, 0, H - 0.75, 0.12, 0.24)
                for z in range(2, int(H) - 1, 3):
                    f.box('metal_dark', a - 0.09, a + 0.09, z, z + 0.06, 0.1, 0.26)
        # ---- ground floor
        gholes = []
        mid = n // 2
        if shop:
            for b in range(n):
                c = bw * (b + 0.5)
                gholes.append((c - bw / 2 + 0.45, 0.0 if (garage or b == mid) else 0.55, c + bw / 2 - 0.45, 3.2))
        else:
            for b in range(n):
                c = bw * (b + 0.5)
                gholes.append((c - 0.55, 0.0, c + 0.55, 2.15) if b == mid else (c - 0.7, 1.5, c + 0.7, 3.1))
        f.wall(base, 0, gh, gholes)
        f.box(base, 0, f.L, 0, 0.5, 0, 0.1)            # plinth (door bays cut it visually with frames)
        for i, (a0, z0, a1, z1) in enumerate(gholes):
            if shop and garage:
                up = rnd.random() < 0.34
                f.recess(a0, a1, z0, z1, 0.25, base, 'shutter', fit=False)
                f.box('metal_dark', a0 - 0.08, a0, 0, z1 + 0.25, 0, 0.06); f.box('metal_dark', a1, a1 + 0.08, 0, z1 + 0.25, 0, 0.06)
                f.box('metal_dark', a0 - 0.08, a1 + 0.08, z1, z1 + 0.3, 0, 0.12)
                f.box('paint_yellow', a0 - 0.2, a0 - 0.08, 0, 1.2, 0, 0.14); f.box('paint_yellow', a1 + 0.08, a1 + 0.2, 0, 1.2, 0, 0.14)
                s.surf('light', f.P((a0 + a1) / 2 - 0.5, z1 + 0.5, 0.02), f.U, Z, 1.0, 0.16, step=0)
            elif shop and z0 == 0.0:
                f.recess(a0, a1, z0, z1, 0.6, base, shops[i % len(shops)])
                m = (a0 + a1) / 2
                f.box('metal_dark', m - 1.0, m + 1.0, 0, 2.3, -0.58, -0.52)
                f.box('window_dark', m - 0.92, m - 0.03, 0.1, 2.22, -0.56, -0.5); f.box('window_dark', m + 0.03, m + 0.92, 0.1, 2.22, -0.56, -0.5)
                f.box('steel', m - 0.12, m - 0.08, 0.95, 1.35, -0.5, -0.44); f.box('steel', m + 0.08, m + 0.12, 0.95, 1.35, -0.5, -0.44)
                f.box('metal_dark', a0, a1, 2.3, 2.38, -0.58, -0.5)
                f.box('stone', a0, a1, 0, 0.03, -0.6, 0.15)
                s.light(*f.P(m, 2.9, -0.2), color=(255, 226, 180), intensity=5, falloff=7)
            elif shop:
                f.window(a0, a1, z0, z1, base, frame='metal_dark', D=0.25, cols=max(2, int((a1 - a0) / 1.4)), rows=1, sill='stone', lintel=False, glass=shops[i % len(shops)])
            elif z0 == 0.0:                                           # service door
                f.recess(a0, a1, z0, z1, 0.2, base, 'door_grey')
                f.box('stone', a0 - 0.3, a1 + 0.3, 0, 0.12, 0, 0.7)
                f.box('metal_dark', a0 - 0.2, a1 + 0.2, 2.5, 2.56, 0, 0.6)
                f.box('light', (a0 + a1) / 2 - 0.15, (a0 + a1) / 2 + 0.15, 2.42, 2.5, 0.1, 0.3)
            else:
                f.window(a0, a1, z0, z1, base, frame=frame, cols=2, rows=2)
                for k in range(5):                                    # security bars
                    a = a0 + (a1 - a0) * (k + 0.5) / 5
                    f.box('metal_dark', a - 0.012, a + 0.012, z0, z1, -0.06, -0.035)
            if shop and awning and not garage:
                aw = awning if not isinstance(awning, tuple) else awning[i % len(awning)]
                O = f.P(a0 - 0.1, 3.0, 1.45)
                extrude(s, aw, [(0, 0), (0, 0.22), (-1.45, 0.62), (-1.45, 0.5), (-0.04, 0.12)], O, f.N, f.U, a1 - a0 + 0.2, fan=1)
                for a in (a0, a1):
                    f.box('metal_dark', a - 0.02, a + 0.02, 3.02, 3.06, 0, 1.42)
        if shop and sign:
            sg = sign if not isinstance(sign, tuple) else sign[('SNWE'.index(side)) % len(sign)]
            w = min(f.L - 2, 8.8)
            f.box('metal_dark', (f.L - w) / 2 - 0.12, (f.L + w) / 2 + 0.12, 3.52, 4.68, 0, 0.18)
            s.surf(sg, f.P((f.L - w) / 2, 3.55, 0.19), f.U, Z, w, 1.1, step=0, fit=True)
            for t in (0.2, 0.5, 0.8):                                 # gooseneck sign lamps
                a = (f.L - w) / 2 + w * t
                f.box('metal_dark', a - 0.02, a + 0.02, 4.68, 4.9, 0.02, 0.06); f.box('metal_dark', a - 0.02, a + 0.02, 4.86, 4.9, 0.02, 0.6)
                f.box('metal_dark', a - 0.09, a + 0.09, 4.76, 4.88, 0.5, 0.7)
            s.light(*f.P(f.L / 2, 4.2, 1.6), color=(255, 226, 180), intensity=7, falloff=10)
        if blade and side == blade[1]:
            a = bw * 1.0; z = gh + fh * 0.6
            s.surf(blade[0], f.P(a - 0.07, z, 0.35), f.N, Z, 3.0, 0.75, step=0, fit=True)
            s.surf(blade[0], f.P(a + 0.07, z, 3.35), -f.N, Z, 3.0, 0.75, step=0, fit=True)
            f.box('metal_dark', a - 0.065, a + 0.065, z - 0.08, z + 0.83, 0.3, 3.4)
            f.box('metal_dark', a - 0.03, a + 0.03, z + 0.3, z + 0.36, 0, 0.3); f.box('metal_dark', a - 0.03, a + 0.03, z + 0.6, z + 0.66, 0, 0.3)
            s.light(*f.P(a + 1.2, z + 0.3, 1.8), color=(255, 90, 70), intensity=5, falloff=7)
        if escape == side:
            c = bw * (n - 1 + 0.5)
            fire_escape(s, f, c - 1.5, c + 1.5, floors, fh, gh + 0.9 - fh)
        if billboard == side:
            c, z0b = f.L / 2, H + 3.0
            s.surf('billboard', f.P(c - 5, z0b, -1.2), f.U, Z, 10, 5, step=0, fit=True)
            f.box('metal_dark', c - 5.1, c + 5.1, z0b - 0.1, z0b + 5.1, -1.42, -1.22)
            for a in (c - 3.4, c, c + 3.4):
                f.box('metal_dark', a - 0.1, a + 0.1, H, z0b + 5, -1.7, -1.42)
                f.box('metal_dark', a - 0.05, a + 0.05, H, H + 0.1, -4.2, -1.7); f.box('metal_dark', a - 0.05, a + 0.05, z0b + 3.0, z0b + 3.1, -1.9, -1.7)
            f.box('metal_dark', c - 5.1, c + 5.1, z0b - 0.5, z0b - 0.42, -1.2, -0.4)           # catwalk
            for a in (c - 4, c - 1.3, c + 1.3, c + 4):
                f.box('metal_dark', a - 0.1, a + 0.1, z0b - 0.42, z0b - 0.3, -0.75, -0.45)
                s.light(*f.P(a, z0b + 0.5, 0.6), color=(255, 240, 220), intensity=5, falloff=7)
        # wall lamps
        for b in range(0, n + 1, 2):
            a = min(max(bw * b, 0.4), f.L - 0.4)
            f.box('metal_dark', a - 0.06, a + 0.06, 2.95, 3.1, 0, 0.3)
            f.box('light', a - 0.1, a + 0.1, 2.75, 2.95, 0.18, 0.38)
    roof_kit(s, x0, y0, x1, y1, H, rnd, tank=tank, parapet=base)
    s.bb = (x0 - 1, y0 - 1, 0, x1 + 1, y1 + 1, H + 6)
    return s


def ground():
    s = piece('rox_street_ground', 'ROX street ground')
    s.cbox(-90, -55, -8.0, 90, 55, 0.0, 4)
    s.box('concrete_wall', -90, -55, -8, 90, 55, 0, faces='xXyY', step=6.0)          # platform skirt
    A = lambda x0, y0, x1, y1, m='asphalt', st=5.0: s.surf(m, (x0, y0, 0), X, Y, x1 - x0, y1 - y0, step=st)
    A(-90, -8, 90, 8); A(-6, 8, 6, 55)                                   # main road + side street
    A(-48, 38, -12, 53); A(-12, 42, -6, 49)                              # car park behind the tower
    A(14, 40, 46, 53); A(6, 42, 14, 49)                                  # garage yard
    def walk(x0, y0, x1, y1, mat='pavement'):
        s.box(mat, x0, y0, 0, x1, y1, 0.16, faces='xXyYZ', step=4.0)
        s.cboxes.append((x0, y0, 0, x1, y1, 0.16, 1)); s.occ.append((x0, y0, 0, x1, y1, 0.16))
    for r in ((-90, 8, -6, 38), (-90, 38, -48, 55), (-48, 53, -6, 55), (-12, 38, -6, 42), (-12, 49, -6, 53),
              (6, 8, 90, 40), (46, 40, 90, 55), (6, 53, 46, 55), (6, 40, 14, 42), (6, 49, 14, 53), (-90, -55, 90, -8)):
        walk(*r)
    for (x0, y0, x1, y1) in ((-90, 8, -6, 8.3), (6, 8, 90, 8.3), (-90, -8.3, 90, -8), (-6.3, 8.3, -6, 42), (-6.3, 49, -6, 55), (6, 8.3, 6.3, 42), (6, 49, 6.3, 55)):
        s.box('concrete_wall', x0, y0, 0.16, x1, y1, 0.172, faces='Z')    # kerb stones
    L = lambda x0, y0, x1, y1, m='paint_line': s.surf(m, (x0, y0, 0.012), X, Y, x1 - x0, y1 - y0, step=0)
    for (a, b) in ((-90, -14), (14, 90)):
        L(a, -0.28, b, -0.1, 'paint_yellow'); L(a, 0.1, b, 0.28, 'paint_yellow')
        x = a
        while x < b - 3:
            L(x, 3.92, x + 3, 4.08); L(x, -4.08, x + 3, -3.92); x += 9
    for cx in (-11.5, 11.5):                                             # zebra crossings on the main road
        for k in range(10):
            y = -7.4 + k * 1.55
            L(cx - 1.6, y, cx + 1.6, y + 0.8)
    for k in range(7):
        x = -5.2 + k * 1.55
        L(x, 9.2, x + 0.8, 12.4)
    L(-6, 12.9, 6, 13.3); L(-14.2, 0.3, -13.8, 8); L(13.8, -8, 14.2, -0.3)
    L(-0.14, 14, 0.14, 40, 'paint_yellow'); L(-0.14, 51, 0.14, 55, 'paint_yellow')
    for x in range(-84, 85, 6):                                          # parking bays along both kerbs
        if abs(x) > 16:
            L(x - 0.07, 5.6, x + 0.07, 8); L(x - 0.07, -8, x + 0.07, -5.6)
    for x in range(-45, -13, 3):                                         # car park bays
        L(x - 0.06, 38.4, x + 0.06, 43.4); L(x - 0.06, 47.6, x + 0.06, 52.6)
    for x in range(17, 46, 3):
        L(x - 0.06, 47.6, x + 0.06, 52.6)
    for k in range(8):                                                   # hatched keep-clear box in front of the garage doors
        L(15 + k * 4, 6.0, 16.6 + k * 4, 6.25, 'paint_yellow')
    for (x, y) in ((-40, 2), (30, -2.2), (0, 30), (62, 1.5), (-70, -3), (-30, 46), (30, 46)):
        s.surf('manhole', (x - 0.45, y - 0.45, 0.014), X, Y, 0.9, 0.9, step=0, fit=True)
    for x in range(-80, 81, 20):                                         # storm drains
        for y in (7.5, -7.95):
            s.box('metal_dark', x - 0.5, y, 0.0, x + 0.5, y + 0.45, 0.014, faces='Z')
    for x in (-89.4, 89.4):                                              # road ends
        barrier(s, x, 0, 0, 'y', n=8)
    barrier(s, 0, 54.4, 0, 'x', n=6)
    # perimeter wall with railing
    for (x0, y0, x1, y1) in ((-90, 54.6, -6.5, 55), (6.5, 54.6, 90, 55), (-90, -55, 90, -54.6), (-90, 8.6, -89.6, 54.6), (89.6, 8.6, 90, 54.6), (-90, -54.6, -89.6, -8.6), (89.6, -54.6, 90, -8.6)):
        s.box('stone', x0, y0, 0.16, x1, y1, 0.75, faces='xXyYZ', col=11)
        s.box('metal_dark', x0 + 0.15, y0 + 0.15, 1.25, x1 - 0.15, y1 - 0.15, 1.3)
        s.cbox(x0, y0, 0.75, x1, y1, 1.3, 56, occ=False)
        ln = max(x1 - x0, y1 - y0); k = int(ln / 1.5)
        for i in range(k + 1):
            px, py = (x0 + 0.2 + (ln - 0.4) * i / k, (y0 + y1) / 2) if x1 - x0 > y1 - y0 else ((x0 + x1) / 2, y0 + 0.2 + (ln - 0.4) * i / k)
            s.box('metal_dark', px - 0.02, py - 0.02, 0.75, px + 0.02, py + 0.02, 1.25, faces='xXyY')
    s.bb = (-90, -55, 0, 90, 55, 3)
    return s


def furniture():
    s = piece('rox_street_props', 'ROX street furniture')
    z = 0.16
    for x in range(-71, 80, 28):
        street_light(s, x, 8.7, z, -1); street_light(s, x + 14, -8.7, z, 1)
    for y in (24, 46):
        s.cyl('metal_dark', -6.7, y, z, 0.085, 6.0, seg=10); s.box('metal_dark', -6.9, y - 0.12, z + 5.9, -4.6, y + 0.12, z + 6.05)
        s.box('light', -5.4, y - 0.1, z + 5.88, -4.65, y + 0.1, z + 5.9, faces='z'); s.light(-5.0, y, z + 5.6, color=(255, 214, 160), intensity=8, falloff=15)
        s.cbox(-6.8, y - 0.1, z, -6.6, y + 0.1, z + 6, 56, occ=False)
    traffic_light(s, -7.0, 9.0, z, 0, -6.0); traffic_light(s, 7.0, -9.0, z, 0, 6.0); traffic_light(s, 7.0, 14.2, z, -6.0, 0)
    for x in (-66, -38, 24, 62):
        bench(s, x, 12.6, z, 180); bin_(s, x + 1.6, 12.7, z)
    for x in (-60, -20, 20, 46, 70):
        bench(s, x, -11.6, z, 0); bin_(s, x + 1.6, -11.7, z)
    for x in range(-78, 85, 14):                                         # trees in kerb planters, alternating with palms from the game
        if abs(x) > 9 and (x // 14) % 2 == 0:
            ball_tree(s, x, 9.7, z, h=3.0, r=1.35); ball_tree(s, x + 7, -9.7, z, h=3.0, r=1.35)
    for k in range(9):                                                   # bollards guarding the garage forecourt and corners
        bollard(s, 15 + k * 3.75, 8.7, z)
    for (x, y) in ((-7, 8.9), (-8.6, 8.9), (7, 8.9), (8.6, 8.9), (-7, -8.9), (7, -8.9)):
        bollard(s, x, y + (0.0 if abs(y) > 8.8 else 0), z)
    hydrant(s, 9.6, 10.2, z); hydrant(s, -52, -9.2, z); hydrant(s, 48, 9.2, z)
    bus_shelter(s, -30, 10.4, z, -1); bus_shelter(s, 30, -10.4, z, 1)
    for (x0, x1) in ((-80, -72), (-64, -57), (-44, -36), (-26, -18), (54, 60), (70, 78)):     # hedge planters against the facades
        planter(s, x0, 12.9, x1, 13.7, z)
    for (x0, x1) in ((10, 16), (34, 40), (52, 58), (70, 76)):
        planter(s, x0, -13.7, x1, -12.9, z)
    for i, x in enumerate((18.5, 19.2, 19.9)):                           # newspaper boxes
        s.obox(('paint_red', 'paint_dkblue', 'paint_yellow')[i], x, -12.4, z, 0.5, 0.45, 1.05, 0); s.obox('window_dark', x, -12.17, z + 0.5, 0.36, 0.02, 0.4, 0)
    s.cbox(18.2, -12.7, z, 20.2, -12.1, z + 1.05, 56, occ=False)
    for (x, y) in ((-10, 40), (-10, 51), (10, 41), (10, 51)):            # car park entrance signs
        s.cyl('steel', x, y, z, 0.035, 2.6, seg=8)
        s.surf('sign_parking', (x - 0.4, y - 0.03, z + 1.9), X, Z, 0.8, 0.6, step=0, fit=True); s.surf('sign_parking', (x + 0.4, y + 0.03, z + 1.9), -X, Z, 0.8, 0.6, step=0, fit=True)
    for (x, y) in ((-50, 16), (-50, 22), (48, 18), (48, 24), (16, 50.5), (-46, 40)):         # dumpsters in the alleys
        s.box('paint_green', x - 0.9, y - 1.4, 0.3 if abs(x) < 47 or y > 39 else z + 0.14, x + 0.9, y + 1.4, 1.45, faces='xXyYZ', col=56)
        s.box('metal_dark', x - 0.95, y - 1.45, 1.45, x + 0.95, y + 1.45, 1.52)
        for (ax, ay) in ((-0.7, -1.2), (0.7, -1.2), (-0.7, 1.2), (0.7, 1.2)):
            s.cyl('metal_dark', x + ax, y + ay, 0.0, 0.1, 0.3, seg=8)
    s.bb = (-90, -55, 0, 90, 55, 9)
    return s


def park():
    s = piece('rox_street_park', 'ROX street park')
    z = 0.16
    def G(x0, y0, x1, y1):
        s.box('grass', x0, y0, z, x1, y1, z + 0.1, faces='xXyYZ', step=4.0); s.cbox(x0, y0, z, x1, y1, z + 0.1, 46)
        for (a, b, c, d) in ((x0 - 0.2, y0 - 0.2, x1 + 0.2, y0), (x0 - 0.2, y1, x1 + 0.2, y1 + 0.2), (x0 - 0.2, y0, x0, y1), (x1, y0, x1 + 0.2, y1)):
            s.box('stone', a, b, z, c, d, z + 0.22, faces='xXyYZ', col=11)
    G(-84, -48, -56, -30); G(-84, -24, -56, -14); G(-42, -48, -30, -30); G(-42, -20, -30, -14)
    # hedges framing the lawns + trees
    for (x0, y0, x1, y1) in ((-84, -48.9, -30, -48.2), (-84.9, -48, -84.2, -14)):
        s.box('hedge', x0, y0, z, x1, y1, z + 1.2, faces='xXyYZ', step=3.0, col=46)
    for (x, y, h, r) in ((-78, -42, 3.6, 2.2), (-66, -36, 4.2, 2.5), (-76, -19, 3.4, 2.0), (-62, -18, 3.8, 2.2), (-36, -42, 3.8, 2.3), (-36, -17, 3.2, 1.8), (-80, -33, 3.0, 1.8), (-60, -45, 3.4, 2.0)):
        ball_tree(s, x, y, z + 0.1, h=h, r=r, planter=False)
    # fountain plaza
    cx, cy = -49, -27
    s.cyl('stone', cx, cy, z, 3.4, 0.55, seg=32); s.cyl('stone', cx, cy, z + 0.55, 3.4, 0.01, seg=32)
    s.cyl('floor_blue', cx, cy, z + 0.56, 3.0, 0.02, seg=32)
    s.cyl('stone', cx, cy, z + 0.56, 0.8, 0.9, seg=16, r2=0.45); s.cyl('stone', cx, cy, z + 1.46, 1.5, 0.16, seg=24, r2=1.6)
    s.cyl('floor_blue', cx, cy, z + 1.62, 1.45, 0.01, seg=24)
    s.cyl('stone', cx, cy, z + 1.62, 0.3, 0.8, seg=12, r2=0.2); s.cyl('stone', cx, cy, z + 2.42, 0.7, 0.12, seg=16, r2=0.8); sphere(s, 'stone', cx, cy, z + 2.8, 0.28, seg=10, rings=5)
    s.cbox(cx - 3.1, cy - 3.1, z, cx + 3.1, cy + 3.1, z + 0.55, 11)
    for a in range(0, 360, 60):
        r = math.radians(a + 30); bench(s, cx + math.cos(r) * 6.2, cy + math.sin(r) * 6.2, z, a + 30 - 90 + 180)
    for a in range(0, 360, 90):
        r = math.radians(a); px, py = cx + math.cos(r) * 5.2, cy + math.sin(r) * 5.2
        s.cyl('metal_dark', px, py, z, 0.07, 3.4, seg=8); sphere(s, 'light', px, py, z + 3.6, 0.24, seg=10, rings=5)
        s.light(px, py, z + 3.5, color=(255, 230, 190), intensity=6, falloff=11); s.cbox(px - 0.08, py - 0.08, z, px + 0.08, py + 0.08, z + 3.4, 56, occ=False)
    # basketball court with fence
    x0, y0, x1, y1 = -26, -47, 2, -31
    s.box('floor_blue', x0, y0, z, x1, y1, z + 0.02, faces='Z', step=4.0)
    Lc = lambda a, b, c, d: s.surf('paint_line', (a, b, z + 0.032), X, Y, c - a, d - b, step=0)
    Lc(x0 + 0.5, y0 + 0.5, x1 - 0.5, y0 + 0.6); Lc(x0 + 0.5, y1 - 0.6, x1 - 0.5, y1 - 0.5); Lc(x0 + 0.5, y0 + 0.5, x0 + 0.6, y1 - 0.5)
    Lc(x1 - 0.6, y0 + 0.5, x1 - 0.5, y1 - 0.5); Lc(-12.05, y0 + 0.5, -11.95, y1 - 0.5)
    for sx in (x0 + 0.6, x1 - 5.6):
        Lc(sx, -41.5, sx + 5, -41.4); Lc(sx, -36.6, sx + 5, -36.5); Lc(sx + (4.9 if sx < -12 else 0), -41.5, sx + (5 if sx < -12 else 0.1), -36.5)
    cyc = -39
    for hx, sg in ((x0 + 1.2, 1), (x1 - 1.2, -1)):
        s.cyl('metal_dark', hx, cyc, z, 0.09, 3.2, seg=10)
        s.box('metal_dark', min(hx, hx + sg * 1.0), cyc - 0.05, z + 3.1, max(hx, hx + sg * 1.0), cyc + 0.05, z + 3.2)
        s.box('trim', hx + sg * 1.0 - 0.03, cyc - 0.9, z + 2.75, hx + sg * 1.0 + 0.03, cyc + 0.9, z + 3.85)
        s.cyl('paint_red', hx + sg * 1.3, cyc, z + 3.02, 0.23, 0.03, seg=14, caps=False)
        s.cbox(hx - 0.1, cyc - 0.1, z, hx + 0.1, cyc + 0.1, z + 3.2, 56, occ=False)
    for (a, b, c, d) in ((x0, y0, x1, y0), (x0, y1, -15, y1), (-9, y1, x1, y1), (x0, y0, x0, y1), (x1, y0, x1, y1)):
        ln = max(abs(c - a), abs(d - b)); k = max(1, int(ln / 2.8))
        for i in range(k + 1):
            px, py = a + (c - a) * i / k, b + (d - b) * i / k
            s.cyl('steel', px, py, z, 0.04, 3.4, seg=8)
        for hz in (0.1, 1.7, 3.35):
            s.box('steel', min(a, c) - 0.02, min(b, d) - 0.02, z + hz, max(a, c) + 0.02, max(b, d) + 0.02, z + hz + 0.04)
        # chain-link mesh as thin wires
        if a != c:
            for i in range(int(ln / 0.35)):
                px = min(a, c) + 0.35 * i; s.box('steel', px - 0.006, b - 0.006, z + 0.1, px + 0.006, b + 0.006, z + 3.35, faces='yY')
        else:
            for i in range(int(ln / 0.35)):
                py = min(b, d) + 0.35 * i; s.box('steel', a - 0.006, py - 0.006, z + 0.1, a + 0.006, py + 0.006, z + 3.35, faces='xX')
        s.cbox(min(a, c) - 0.05, min(b, d) - 0.05, z, max(a, c) + 0.05, max(b, d) + 0.05, z + 3.4, 56, occ=False)
    for px in (x0 + 0.3, x1 - 0.3):
        for py in (y0 + 0.3, y1 - 0.3):
            s.cyl('metal_dark', px, py, z, 0.1, 8.0, seg=8); s.box('metal_dark', px - 0.5, py - 0.15, z + 7.8, px + 0.5, py + 0.15, z + 8.1)
            s.light(px + (1.5 if px < -12 else -1.5), py + (1.5 if py < -39 else -1.5), z + 7.5, color=(235, 240, 255), intensity=10, falloff=20)
    # ---- skate park
    sx0, sy0, sx1, sy1 = -24, -27, 4, -13
    s.box('concrete_floor', sx0, sy0, z, sx1, sy1, z + 0.04, faces='xXyYZ', step=4.0); s.cbox(sx0, sy0, z, sx1, sy1, z + 0.04, 1)
    zz = z + 0.04
    R = 2.4
    curve = [(R * math.sin(math.radians(a)), R - R * math.cos(math.radians(a))) for a in (0, 12, 24, 36, 48, 60, 70)]
    top = curve[-1][1]
    prof = curve + [(curve[-1][0] + 1.4, top), (curve[-1][0] + 1.4, 0)]
    extrude(s, 'concrete_floor', prof, (sx0 + 4.2, sy0 + 0.6, zz), -X, Y, 8.0, col=1, fan=len(prof) - 1, skip=(len(prof) - 1,))       # west quarter pipe
    extrude(s, 'concrete_floor', prof, (sx1 - 4.2, sy0 + 5.4, zz), X, Y, 8.0, col=1, fan=len(prof) - 1, skip=(len(prof) - 1,))        # east quarter pipe
    for (ox, U) in ((sx0 + 4.2 - curve[-1][0] - 0.02, X), (sx1 - 4.2 + curve[-1][0] + 0.02, X)):                                     # coping rails
        oy = sy0 + 0.6 if ox < -10 else sy0 + 5.4
        s.box('steel', ox - 0.04, oy, zz + top - 0.02, ox + 0.04, oy + 8.0, zz + top + 0.05)
    fb = [(0, 0), (2.2, 0.75), (5.0, 0.75), (7.2, 0)]                                                                                # fun box
    extrude(s, 'concrete_floor', fb, (-13.6, -22.5, zz), X, Y, 3.4, col=1, fan=0, skip=(3,))
    s.box('steel', -11.2, -20.85, zz + 0.75, -8.8, -20.75, zz + 1.1, faces='xXyYZ'); s.cbox(-11.2, -20.85, zz + 0.75, -8.8, -20.75, zz + 1.1, 56, occ=False)
    st = [(0, 0), (0, 0.6), (1.2, 0.6), (1.2, 0.4), (1.6, 0.4), (1.6, 0.2), (2.0, 0.2), (2.0, 0)]                                    # stair set + ledge
    extrude(s, 'concrete_floor', [(0, 0), (3.2, 0.6), (3.2, 0)], (-18.5, -17.6, zz), X, Y, 2.6, col=1, fan=2, skip=(2,))
    extrude(s, 'concrete_floor', [(q[0] + 3.2, q[1]) for q in st], (-18.5, -17.6, zz), X, Y, 2.6, col=1, fan=7, skip=(7,))
    s.box('stone', -15.3, -14.9, zz, -11.5, -14.5, zz + 0.95, faces='xXyYZ', col=11)
    for (ax, ay, ln) in ((-6.5, -16.5, 5.0), (-4.0, -24.8, 4.0)):                                                                    # grind rails
        s.box('steel', ax, ay - 0.03, zz + 0.42, ax + ln, ay + 0.03, zz + 0.48); s.cbox(ax, ay - 0.03, zz + 0.42, ax + ln, ay + 0.03, zz + 0.48, 56, occ=False)
        for t in (0.15, ln / 2, ln - 0.15):
            s.box('steel', ax + t - 0.025, ay - 0.025, zz, ax + t + 0.025, ay + 0.025, zz + 0.42, faces='xXyY')
    extrude(s, 'concrete_floor', [(0, 0), (1.8, 0.5), (3.6, 0)], (-2.6, -20.5, zz), X, Y, 2.4, col=1, fan=0, skip=(2,))               # pyramid kicker
    for (x, y) in ((sx0 - 0.6, sy1 - 2), (sx1 + 0.6, sy0 + 2)):
        s.cyl('metal_dark', x, y, z, 0.09, 7.0, seg=8); s.box('metal_dark', x - 0.4, y - 0.15, z + 6.9, x + 0.4, y + 0.15, z + 7.15)
        s.light(x + (2 if x < -10 else -2), y, z + 6.6, color=(235, 240, 255), intensity=10, falloff=20); s.cbox(x - 0.1, y - 0.1, z, x + 0.1, y + 0.1, z + 7, 56, occ=False)
    bench(s, -20, -13.6, z, 0); bench(s, 0, -13.6, z, 0); bin_(s, -17.8, -13.6, z)
    s.bb = (-85, -49, 0, 5, -13, 9)
    return s


def all_pieces():
    P = [ground(), furniture(), park()]
    P.append(building('rox_street_b1', 'Brick block', -82, 14, -54, 38, 6, wall='brick_red', sign='sign_store', awning=('awning_green', 'awning_red'), escape='E', balconies='S', seed=1))
    P.append(building('rox_street_b2', 'Hotel tower', -48, 14, -14, 36, 9, wall='brick_white', base='stone', sign=('sign_market', 'sign_cafe'), awning='awning_red', escape='W',
                      seed=2, win=(1.4, 2.0), shop_sides='SE', blade=('sign_hotel', 'S')))
    P.append(building('rox_street_b3', 'ROX Garage', 14, 14, 46, 38, 3, wall='brick_dark', base='concrete_wall', sign='sign_garage', garage=True, pilasters=False,
                      seed=3, fh=3.8, gh=5.2, bay=5.3, win=(2.6, 2.0), frame='metal_dark', tank=False, ac_rate=0.0))
    P.append(building('rox_street_b4', 'Corner apartments', 52, 14, 80, 34, 5, wall='paint_ochre', base='brick_red', sign='sign_cafe', awning='awning_green', escape='E', seed=4,
                      shop_sides='S', balconies='SW', shops=('shop_cafe', 'shop_fashion')))
    P.append(building('rox_street_b5', 'Shops', 8, -40, 42, -14, 2, wall='paint_cream', base='stone', sign='sign_store', awning=('awning_red', 'awning_green'), shop_sides='N', pilasters=False,
                      seed=5, tank=False, billboard='N', shops=('shop_fashion', 'shop_market', 'shop_cafe')))
    P.append(building('rox_street_b6', 'Brick tower', 50, -44, 78, -14, 11, wall='brick_dark', base='stone', sign='sign_market', awning='awning_green', shop_sides='N', escape='W', balconies='E', seed=6))
    return P


# GTA props placed by the client script (model, x, y, heading) - z is found on the ground
def props():
    out = []
    for x in range(-78, 85, 14):
        if abs(x) > 9 and (x // 14) % 2 != 0:
            out.append(('prop_palm_fan_03_c', x, 9.7, (x * 37) % 360)); out.append(('prop_palm_med_01b', x + 7, -9.7, (x * 53) % 360))
    out += [('prop_tree_birch_02', -70, -30, 0), ('prop_tree_olive_01', -60, -40, 40), ('prop_tree_birch_02', -74, -45, 90), ('prop_tree_olive_01', -40, -36, 10),
            ('prop_pallet_pile_01', 20, 44, 20), ('prop_rub_tyre_01', 26, 41, 0), ('prop_rub_tyre_01', 26.6, 41.3, 40), ('prop_toolchest_05', 40, 41, 180),
            ('prop_news_disp_02a', -24, 12.6, 180), ('prop_postbox_01a', 54, 12.4, 180), ('prop_phonebox_01a', -52.5, 12.4, 180), ('prop_vend_soda_01', 44.5, -13.2, 0),
            ('prop_vend_snak_01', 45.6, -13.2, 0), ('prop_table_03', 60, 11.2, 0), ('prop_table_03', 64, 11.2, 0), ('prop_chair_01a', 61, 11.2, 90), ('prop_chair_01a', 65, 11.2, 90),
            ('prop_parasol_01', 60, 11.2, 0), ('prop_parasol_01', 64, 11.2, 0), ('prop_bikerack_1a', -3, -12.2, 0), ('prop_skate_flatramp', 1.5, -15.5, 90)]
    return out
