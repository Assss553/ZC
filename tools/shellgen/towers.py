# ROX Twin Towers for FiveM: dark glass + LED exterior, 4 walk-in floors (lobby, offices, executive, sky lounge)  (c) ROX Store
# Furniture inside = real GTA props spawned by the rox_towers resource.  Same layout as tools/blender/towers_interior.py
import math, random
import numpy as np
from kit import Shell, MATS, X, Y, Z

TXD = 'rox_towers_txd'
FH, Z0, NMID = 3.9, 14.6, 14
TOP_MID = Z0 + NMID * FH                     # 69.2
def chamfer(w, d, c, ox=0.0, oy=0.0):
    x, y = w / 2, d / 2
    return [(ox + a, oy + b) for a, b in [(-x + c, -y), (x - c, -y), (x, -y + c), (x, y - c), (x - c, y), (-x + c, y), (-x, y - c), (-x, -y + c)]]
POD, MID = chamfer(60, 50, 9), chamfer(48, 38, 8)
TL, TR = chamfer(18, 30, 4, -13, 0), chamfer(18, 28, 4, 13, 2)
TL_TOP, TR_TOP = 138.0, 118.0
NL = int((TL_TOP - TOP_MID - 0.3) / FH)
FLOORS = {   # walk-in floors: name -> (floor z, ceiling z, outline)
    'lobby': (0.0, 14.3, POD),
    'office': (Z0 + 3 * FH, Z0 + 4 * FH - 0.3, MID),
    'executive': (Z0 + 8 * FH, Z0 + 9 * FH - 0.3, MID),
    'skylounge': (TOP_MID + 0.3 + (NL - 1) * FH, TL_TOP - 0.3, TL),
}
CORE = (-5.0, 0.0, 5.0, 8.0)


def piece(name, label):
    s = Shell(name, label, label); s.hull = False; s.txd, s.lod = TXD, 1500
    return s


def poly(s, mat, pts, z, up=True, col=None, tile=None):
    tile = tile or MATS[mat]['tile']
    c = np.mean(np.array(pts), 0); P = [(c[0], c[1], z)] + [(x, y, z) for x, y in pts]; n = len(pts); I = []
    for i in range(n):
        a, b = 1 + i, 1 + (i + 1) % n
        I += [0, a, b] if up else [0, b, a]
    s._add(mat, '', P, np.tile((0, 0, 1 if up else -1), (n + 1, 1)), [(p[0] / tile, -p[1] / tile) for p in P], np.tile((1, 0, 0, 1), (n + 1, 1)), I)
    if col is not None:
        for k in range(0, len(I), 3): s.ctris.append((np.array(P[I[k]]), np.array(P[I[k + 1]]), np.array(P[I[k + 2]]), col))


def edges(pts):
    n = len(pts)
    for i in range(n):
        a, b = np.array(pts[i], float), np.array(pts[(i + 1) % n], float); d = b - a; L = float(np.linalg.norm(d))
        yield i, a, b, d / L, L


def facade(s, pts, z0, z1, rnd, lit=0.0, door=None, collide=True):
    """Outer dark glass skin, random lit panes, collision quads. door = (edge index, a0, a1, height)."""
    for i, a, b, U, L in edges(pts):
        U3 = np.array([U[0], U[1], 0.0]); O = np.array([a[0], a[1], z0])
        holes = [(door[1], 0.0, door[2], door[3])] if door and door[0] == i else []
        s.surf('tower_glass', O, U3, Z, L, z1 - z0, holes=holes, step=3.0)
        if lit:
            z = z0 + 0.4
            while z < z1 - 1:
                if rnd.random() < lit:
                    t0 = rnd.uniform(0, 0.6); t1 = min(1.0, t0 + rnd.uniform(0.2, 0.5)); nrm = np.array([U[1], -U[0], 0.0]) * 0.02
                    s.surf('tower_glass_lit', O + U3 * L * t0 + nrm + Z * (z - z0), U3, Z, L * (t1 - t0), 3.0, step=0)
                z += FH
        if collide:
            segs = [(0, L)] if not holes else [(0, holes[0][0]), (holes[0][2], L)]
            for (u0, u1) in segs:
                p0, p1 = O + U3 * u0, O + U3 * u1
                s.quad('tower_glass', p0, U3, Z, u1 - u0, z1 - z0, col=114) if False else None
                q = [p0, p1, p1 + Z * (z1 - z0), p0 + Z * (z1 - z0)]
                s.ctris += [(q[0], q[1], q[2], 114), (q[0], q[2], q[3], 114)]
            if holes:
                p0 = O + U3 * holes[0][0] + Z * holes[0][3]; p1 = O + U3 * holes[0][2] + Z * holes[0][3]; hh = z1 - z0 - holes[0][3]
                s.ctris += [(p0, p1, p1 + Z * hh, 114), (p0, p1 + Z * hh, p0 + Z * hh, 114)]


def led_ring(s, pts, z, w=0.14):
    for i, a, b, U, L in edges(pts):
        nrm = np.array([U[1], -U[0]]) * 0.1; c = (a + b) / 2 + nrm
        s.obox('led_white', c[0], c[1], z - w / 2, L + w, w, w, math.degrees(math.atan2(U[1], U[0])))


def led_corners(s, pts, z0, z1, w=0.12):
    for x, y in pts: s.box('led_white', x - w / 2, y - w / 2, z0, x + w / 2, y + w / 2, z1)


def slab_ring(s, pts, z, grow=1.04, h=0.6, mat='concrete_wall'):
    big = [(x * grow, y * grow) for x, y in pts]
    poly(s, mat, big, z + h, True, col=1); poly(s, mat, big, z, False)
    for i, a, b, U, L in edges(big):
        U3 = np.array([U[0], U[1], 0.0]); s.surf(mat, (a[0], a[1], z), U3, Z, L, h, step=0)
    led_ring(s, big, z + h + 0.07)


def interior(s, key, wall='paint_white', floor='tile_white', ceil='ceiling_tile'):
    z0, z1, pts = FLOORS[key]
    inner = [(x * 0.985, y * 0.985) for x, y in pts]
    poly(s, floor, inner, z0 + 0.02, True, col=81); poly(s, ceil, inner, z1, False)
    for i, a, b, U, L in edges(inner):        # window view out (night city) on the inside of the glass
        U3 = np.array([-U[0], -U[1], 0.0]); s.surf('city_view', (b[0], b[1], z0 + 0.02), U3, Z, L, z1 - z0 - 0.02, step=0, fit=True)
    cx0, cy0, cx1, cy1 = min(p[0] for p in inner), min(p[1] for p in inner), max(p[0] for p in inner), max(p[1] for p in inner)
    sp = 4.0; x = cx0 + 2
    while x < cx1 - 1:
        y = cy0 + 2
        while y < cy1 - 1:
            s.surf('light', (x - 0.6, y + 0.15, z1 - 0.01), X, -Y, 1.2, 0.3, step=0, fit=True)
            if int((x - cx0) / sp) % 2 == 0 and int((y - cy0) / sp) % 2 == 0: s.light(x, y, z1 - 0.5, color=(255, 244, 226), intensity=6 if key != 'lobby' else 9, falloff=11 if key != 'lobby' else 16)
            y += sp
        x += sp


def mlo_dress(s, key):
    # MLO look: black ceiling with linear LED lines, oak-clad core with black reveals, oak feature panels, glass-box offices
    z0, z1, pts = FLOORS[key]
    inner = [(x * 0.985, y * 0.985) for x, y in pts]
    cx0, cy0, cx1, cy1 = min(p[0] for p in inner), min(p[1] for p in inner), max(p[0] for p in inner), max(p[1] for p in inner)
    zc = z1 - 0.02
    poly(s, 'paint_black', [(x * 0.97, y * 0.97) for x, y in inner], zc, False)
    y = cy0 + 4
    while y < cy1 - 3:                                   # long LED lines across the ceiling
        s.box('led_white', cx0 + 4, y - 0.04, zc - 0.05, cx1 - 4, y + 0.04, zc); y += 5.0
    x0, y0, x1, y1 = CORE; d = 0.06; zt = min(z1, z0 + 3.4) if key != 'lobby' else z0 + 9.0
    s.box('oak_panel', x0 - d, y0 - d, z0, x1 + d, y1 + d, zt, faces='xXyY', step=1.2)
    for xx in np.arange(x0 + 1.2, x1, 1.2):             # black reveals between panels (front + back)
        for yy in (y0 - d - 0.01, y1 + d):
            s.box('paint_black', xx - 0.02, yy, z0, xx + 0.02, yy + 0.01, zt)
    s.box('led_white', x0 - d - 0.02, y0 - d - 0.03, zt - 0.06, x1 + d + 0.02, y1 + d + 0.03, zt)
    if key == 'office':                                  # four glass-box offices along the north side
        gy0, gy1 = 9.0, 15.5
        for i in range(5):
            xx = -18 + i * 8.0
            s.box('metal_dark', xx - 0.04, gy0, z0, xx + 0.04, gy1, z0 + 3.0); s.cbox(xx - 0.04, gy0, z0, xx + 0.04, gy1, z0 + 3.0, 56)
        for i in range(4):
            a = -18 + i * 8.0
            for xx in np.arange(a + 1.2, a + 8.0, 1.2):
                if abs(xx - (a + 4.0)) > 0.7: s.box('metal_dark', xx - 0.025, gy0 - 0.03, z0, xx + 0.025, gy0 + 0.03, z0 + 3.0)
            for zz in (z0 + 0.02, z0 + 2.95, z0 + 1.05):
                s.box('metal_dark', a, gy0 - 0.03, zz, a + 3.4, gy0 + 0.03, zz + 0.05); s.box('metal_dark', a + 4.6, gy0 - 0.03, zz, a + 8.0, gy0 + 0.03, zz + 0.05)
            s.cbox(a, gy0 - 0.03, z0, a + 3.4, gy0 + 0.03, z0 + 3.0, 56); s.cbox(a + 4.6, gy0 - 0.03, z0, a + 8.0, gy0 + 0.03, z0 + 3.0, 56)
            s.box('metal_dark', a, gy0 - 0.03, z0 + 2.95, a + 8.0, gy0 + 0.03, z0 + 3.0)
            s.box('oak_panel', a + 0.1, gy1 - 0.06, z0, a + 7.9, gy1, z0 + 3.0, faces='y', step=1.2)
        s.box('metal_dark', -18, gy0, z0 + 3.0, 14, gy1, z0 + 3.05)
    if key == 'lobby':                                   # oak reception wall + oak side walls behind the lounges
        for sx in (-1, 1):
            s.box('oak_panel', sx * 15 - 5, -24.0, z0, sx * 15 + 5, -23.8, z0 + 5.0, faces='y', step=1.2)
            s.box('led_white', sx * 15 - 5, -23.82, z0 + 5.0, sx * 15 + 5, -23.78, z0 + 5.06)
        s.box('oak_panel', -3.2, -7.6, z0, 3.2, -6.4, z0 + 1.1, faces='xXyYz', step=1.2); s.cbox(-3.2, -7.6, z0, 3.2, -6.4, z0 + 1.1, 70)
        s.box('led_white', -3.2, -7.62, z0 + 0.06, 3.2, -7.58, z0 + 0.1)


def core(s, z0, z1):
    x0, y0, x1, y1 = CORE
    s.box('concrete_wall', x0, y0, z0, x1, y1, z1, faces='xXyY', step=2.0); s.cbox(x0, y0, z0, x1, y1, z1, 1)


def base():
    s = piece('rox_towers_base', 'ROX Towers podium + offices'); rnd = random.Random(7)
    # podium / lobby (door in the middle of the south side, 4 m wide)
    facade(s, POD, 0.0, 14.6, rnd, lit=0.0, door=(0, 21 - 2.5, 21 + 2.5, 3.6))
    s.box('stone', -3.0, -25.6, 3.6, 3.0, -24.6, 4.0); s.box('led_white', -2.6, -25.62, 3.5, 2.6, -25.58, 3.6)
    interior(s, 'lobby', floor='tile_white'); mlo_dress(s, 'lobby')
    s.box('paint_charcoal', -7, -0.4, 0.02, 7, -0.05, 9.0)                  # dark marble logo wall in front of the core
    s.surf('sign_garage' if False else 'neon_hotel', (-3.5, -0.42, 6.5), X, Z, 7.0, 1.5, step=0, fit=True) if False else s.surf('sign_store', (-3.5, -0.42, 6.5), X, Z, 7.0, 1.4, step=0, fit=True)
    slab_ring(s, POD, 14.6, grow=1.03)
    led_corners(s, POD, 0.0, 15.2)
    core(s, 0.0, TOP_MID)
    # mid block: 14 floors, two of them walk-in
    facade(s, MID, Z0 + 0.6, TOP_MID, rnd, lit=0.22)
    for k in ('office', 'executive'): interior(s, k, floor='carpet'); mlo_dress(s, k)
    led_corners(s, MID, Z0 + 0.6, TOP_MID); slab_ring(s, MID, TOP_MID, grow=1.08, h=0.5)
    s.bb = (-32, -27, 0, 32, 27, TOP_MID + 1)
    return s


def twin():
    s = piece('rox_towers_twin', 'ROX Towers twins'); rnd = random.Random(11)
    for pts, top, nm in ((TL, TL_TOP, 'L'), (TR, TR_TOP, 'R')):
        facade(s, pts, TOP_MID + 0.6, top, rnd, lit=0.2)
        led_corners(s, pts, TOP_MID + 0.6, top)
        for z in (96.0, 110.0):
            if z < top: led_ring(s, pts, z)
        slab_ring(s, pts, top, grow=1.0, h=0.6)
        inner = [((x - (-13 if nm == 'L' else 13)) * 0.82 + (-13 if nm == 'L' else 13), (y - (0 if nm == 'L' else 2)) * 0.82 + (0 if nm == 'L' else 2)) for x, y in pts]
        facade(s, inner, top + 0.6, top + 4.6, rnd); poly(s, 'concrete_wall', inner, top + 4.6, True, col=1); led_ring(s, inner, top + 4.65); led_corners(s, inner, top + 0.6, top + 4.6)
        poly(s, 'concrete_wall', pts, TOP_MID + 0.6, False)
    interior(s, 'skylounge', floor='parquet')
    # sky bridge
    BR = [(-4.2, -1.5), (4.2, -1.5), (4.2, 3.5), (-4.2, 3.5)]
    facade(s, BR, 98, 102, rnd); poly(s, 'concrete_wall', BR, 102, True); poly(s, 'concrete_wall', BR, 98, False); led_ring(s, BR, 102.05); led_ring(s, BR, 97.95)
    # helipad + beacons
    s.cyl('floor_blue', -13, 0, TL_TOP + 4.6, 6.0, 0.15, seg=32); s.cyl('led_white', -13, 0, TL_TOP + 4.76, 5.6, 0.04, seg=32, caps=False)
    for (cx, cy, z) in ((-13, 0, TL_TOP + 4.6), (13, 2, TR_TOP + 4.6)):
        for k in range(4):
            a = k * math.pi / 2 + 0.8; x, y = cx + math.cos(a) * 5, cy + math.sin(a) * 9
            s.cyl('metal_dark', x, y, z, 0.12, 5, seg=8); s.cyl('neon_deli', x, y, z + 5, 0.3, 0.4, seg=10)
            s.light(x, y, z + 5.3, color=(255, 40, 30), intensity=3, falloff=5)
    s.bb = (-24, -18, TOP_MID, 24, 18, TL_TOP + 11)
    return s


def all_pieces():
    b, t = base(), twin()
    b.meta = dict(floors={k: dict(z=round(v[0], 2), ceil=round(v[1], 2)) for k, v in FLOORS.items()}, core=CORE)
    return [b, t]
