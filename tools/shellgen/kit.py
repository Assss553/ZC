# ROX shell generator - modelling kit  (c) ROX Store
# Builds interior shells as GTA V drawables (CodeWalker XML) from a room description.
import numpy as np, math, json, os

Z = np.array([0.0, 0.0, 1.0])
X = np.array([1.0, 0.0, 0.0])
Y = np.array([0.0, 1.0, 0.0])

# shader kinds: ns = normal_spec, n = normal, s = spec, d = default, e = emissive
# tile = metres covered by one texture repeat; col = collision material index
MATS = {
    'paint_white':   dict(tex='rox_paint_white', sh='n', tile=2.0, spec=0.06, col=101),
    'paint_cream':   dict(tex='rox_paint_cream', sh='n', tile=2.0, spec=0.06, col=101),
    'paint_grey':    dict(tex='rox_paint_grey', sh='n', tile=2.0, spec=0.06, col=101),
    'paint_dkblue':  dict(tex='rox_paint_dkblue', sh='n', tile=2.5, spec=0.12, col=101),
    'paint_maroon':  dict(tex='rox_paint_maroon', sh='n', tile=2.0, spec=0.15, col=101),
    'wallpaper':     dict(tex='rox_wallpaper_beige', sh='n', tile=1.2, spec=0.04, col=101),
    'wainscot':      dict(tex='rox_wainscot_white', sh='n', tile=0.6, spec=0.2, col=70),
    'concrete_floor':dict(tex='rox_concrete_floor', sh='ns', tile=3.0, spec=0.5, fall=60, col=1),
    'concrete_wall': dict(tex='rox_concrete_wall', sh='ns', tile=3.0, spec=0.15, fall=30, col=1),
    'floor_blue':    dict(tex='rox_floor_bluegrey', sh='ns', tile=3.0, spec=0.8, fall=110, col=1),
    'parquet':       dict(tex='rox_parquet_herringbone', sh='ns', tile=2.0, spec=0.6, fall=90, col=72),
    'planks':        dict(tex='rox_wood_planks', sh='ns', tile=1.6, spec=0.5, fall=80, col=72),
    'tile_terra':    dict(tex='rox_tile_terracotta', sh='ns', tile=1.32, spec=0.6, fall=90, col=81),
    'tile_beige':    dict(tex='rox_tile_beige', sh='ns', tile=1.2, spec=0.7, fall=110, col=81),
    'tile_white':    dict(tex='rox_tile_white', sh='ns', tile=0.8, spec=0.8, fall=130, col=81),
    'carpet':        dict(tex='rox_carpet_grey', sh='n', tile=1.0, spec=0.01, col=97),
    'ceiling_tile':  dict(tex='rox_ceiling_tile', sh='n', tile=0.6, spec=0.03, col=101),
    'wood_dark':     dict(tex='rox_wood_dark', sh='ns', tile=1.2, spec=0.5, fall=70, col=70),
    'wood_door':     dict(tex='rox_wood_door', sh='ns', tile=1.2, spec=0.4, fall=60, col=70),
    'trim':          dict(tex='rox_trim_white', sh='n', tile=1.5, spec=0.3, col=70),
    'metal_dark':    dict(tex='rox_metal_dark', sh='s', tile=1.0, spec=0.6, fall=80, col=56),
    'steel':         dict(tex='rox_metal_steel', sh='ns', tile=1.0, spec=0.9, fall=140, col=56),
    'brass':         dict(tex='rox_metal_brass', sh='s', tile=1.0, spec=0.9, fall=120, col=56),
    'shutter':       dict(tex='rox_shutter', sh='ns', tile=0.64, spec=0.5, fall=60, col=67),
    'door_grey':     dict(tex='rox_door_grey', sh='ns', tile=1.0, spec=0.5, fall=60, col=56),
    'door_maroon':   dict(tex='rox_door_maroon', sh='ns', tile=1.0, spec=0.5, fall=60, col=70),
    'door_wood':     dict(tex='rox_door_wood', sh='ns', tile=1.0, spec=0.4, fall=60, col=70),
    'window_day':    dict(tex='rox_window_day', sh='e', tile=1.0, emis=2.2, col=114),
    'window_dark':   dict(tex='rox_window_dark', sh='s', tile=2.0, spec=1.0, fall=200, col=114),
    'light':         dict(tex='rox_light_panel', sh='e', tile=1.0, emis=6.0, col=114),
    'fabric':        dict(tex='rox_blind_fabric', sh='n', tile=0.6, spec=0.02, col=97),
    'cardboard':     dict(tex='rox_cardboard', sh='n', tile=1.4, spec=0.02, col=86),
    'countertop':    dict(tex='rox_countertop', sh='s', tile=0.8, spec=0.9, fall=140, col=14),
    'appliance':     dict(tex='rox_appliance_white', sh='s', tile=1.0, spec=0.7, fall=100, col=56),
    'brick_red':     dict(tex='rox_brick_red', sh='n', tile=1.5, spec=0.05, col=13),
    'brick_dark':    dict(tex='rox_brick_dark', sh='n', tile=1.5, spec=0.05, col=13),
    'brick_white':   dict(tex='rox_brick_white', sh='n', tile=1.5, spec=0.05, col=13),
    'asphalt':       dict(tex='rox_asphalt', sh='ns', tile=6.0, spec=0.25, fall=40, col=4),
    'pavement':      dict(tex='rox_pavement', sh='n', tile=2.4, spec=0.05, col=1),
    'grass':         dict(tex='rox_grass', sh='n', tile=4.0, spec=0.01, col=46),
    'stone':         dict(tex='rox_stone', sh='n', tile=2.4, spec=0.08, col=11),
    'roof':          dict(tex='rox_roof', sh='n', tile=3.0, spec=0.02, col=1),
    'paint_yellow':  dict(tex='rox_paint_yellow', sh='n', tile=3.0, spec=0.1, col=4),
    'paint_line':    dict(tex='rox_paint_line', sh='n', tile=3.0, spec=0.1, col=4),
    'awning_green':  dict(tex='rox_awning_green', sh='n', tile=1.2, spec=0.02, col=97),
    'awning_red':    dict(tex='rox_awning_red', sh='n', tile=1.2, spec=0.02, col=97),
    'sign_garage':   dict(tex='rox_sign_garage', sh='e', tile=1.0, emis=3.0, col=56),
    'sign_store':    dict(tex='rox_sign_store', sh='e', tile=1.0, emis=2.5, col=56),
    'sign_market':   dict(tex='rox_sign_market', sh='e', tile=1.0, emis=2.5, col=56),
    'sign_cafe':     dict(tex='rox_sign_cafe', sh='e', tile=1.0, emis=2.5, col=56),
    'sign_hotel':    dict(tex='rox_sign_hotel', sh='e', tile=1.0, emis=3.5, col=56),
    'sign_parking':  dict(tex='rox_sign_parking', sh='e', tile=1.0, emis=2.0, col=56),
    'shop_market':   dict(tex='rox_shop_market', sh='s', tile=1.0, spec=1.0, fall=200, col=114),
    'shop_fashion':  dict(tex='rox_shop_fashion', sh='s', tile=1.0, spec=1.0, fall=200, col=114),
    'shop_cafe':     dict(tex='rox_shop_cafe', sh='s', tile=1.0, spec=1.0, fall=200, col=114),
    'hedge':         dict(tex='rox_hedge', sh='n', tile=1.2, spec=0.02, col=46),
    'billboard':     dict(tex='rox_billboard', sh='d', tile=1.0, spec=0.05, col=56),
    'manhole':       dict(tex='rox_manhole', sh='n', tile=1.0, spec=0.3, col=56),
    'paint_green':   dict(tex='rox_paint_green', sh='n', tile=2.0, spec=0.2, col=56),
    'paint_red':     dict(tex='rox_paint_red', sh='n', tile=2.0, spec=0.2, col=56),
    'paint_ochre':   dict(tex='rox_paint_ochre', sh='n', tile=2.0, spec=0.06, col=13),
    'rooftile':      dict(tex='rox_rooftile', sh='n', tile=2.0, spec=0.05, col=13),
    'black_glass':   dict(tex='rox_black_glass', sh='s', tile=1.0, spec=1.0, fall=220, col=114),
}

FLOOR_COL = {'concrete_floor': 1, 'floor_blue': 1, 'parquet': 72, 'planks': 72, 'tile_terra': 81, 'tile_beige': 81,
             'tile_white': 81, 'carpet': 97}


def _breaks(length, edges, step):
    pts = {0.0, float(length)}
    for e in edges:
        if 1e-4 < e < length - 1e-4:
            pts.add(float(e))
    pts = sorted(pts)
    out = [pts[0]]
    for p in pts[1:]:
        if p - out[-1] < 1e-4:
            continue
        gap = p - out[-1]
        n = max(1, int(math.ceil(gap / step - 1e-6))) if step else 1
        for k in range(1, n + 1):
            out.append(out[-1] + (p - out[-1]) / (n - k + 1))
    return out


class Shell:
    def __init__(s, name, label, label_ar, H=2.7, wall_t=0.2):
        s.name, s.label, s.label_ar = name, label, label_ar
        s.H, s.t = H, wall_t
        s.b = {}            # bucket key -> lists
        s.cboxes = []       # collision boxes (x0,y0,z0,x1,y1,z1,colmat)
        s.occ = []          # AO occluder boxes
        s.lights = []
        s.rooms = {}
        s.holes = {}        # (room, side) -> list of (a0,z0,a1,z1,kind)
        s.entry = (0, 0, 1.0, 0.0)
        s.script_lights = []
        s.txd = 'rox_shells_txd'
        s.lod = 300
        s.ctris = []        # extra collision triangles (p0, p1, p2, colmat) for slopes

    # ------------------------------------------------------------ low level
    def _bucket(s, mat, tag=''):
        k = mat + '|' + tag
        if k not in s.b:
            s.b[k] = dict(P=[], N=[], UV=[], T=[], I=[], n=0)
        return s.b[k]

    def _add(s, mat, tag, P, N, UV, T, I):
        b = s._bucket(mat, tag)
        b['P'].append(np.asarray(P, float)); b['N'].append(np.asarray(N, float))
        b['UV'].append(np.asarray(UV, float)); b['T'].append(np.asarray(T, float))
        b['I'].append(np.asarray(I, np.int64) + b['n']); b['n'] += len(P)

    def surf(s, mat, O, U, V, w, h, holes=(), step=0.6, tag='', rot=0.0, uvo=None, fit=False):
        """Rectangular surface (O + U*a + V*b), normal = U x V, with rectangular holes, tessellated for vertex AO."""
        O, U, V = np.asarray(O, float), np.asarray(U, float), np.asarray(V, float)
        if w < 1e-4 or h < 1e-4:
            return
        Nn = np.cross(U, V)
        us = _breaks(w, [e for hl in holes for e in (hl[0], hl[2])], step)
        vs = _breaks(h, [e for hl in holes for e in (hl[1], hl[3])], step)
        tile = MATS[mat]['tile']
        c, sn = math.cos(rot), math.sin(rot)
        Ut, Vt = U * c + V * sn, -U * sn + V * c
        idx, P, UV, I = {}, [], [], []
        def vid(i, j):
            k = (i, j)
            if k not in idx:
                p = O + U * us[i] + V * vs[j]
                idx[k] = len(P); P.append(p)
                q = p if uvo is None else p - np.asarray(uvo, float)
                UV.append((us[i] / w, 1.0 - vs[j] / h) if fit else (float(np.dot(q, Ut)) / tile, -float(np.dot(q, Vt)) / tile))
            return idx[k]
        for i in range(len(us) - 1):
            for j in range(len(vs) - 1):
                cu, cv = (us[i] + us[i + 1]) / 2, (vs[j] + vs[j + 1]) / 2
                if any(hl[0] - 1e-5 < cu < hl[2] + 1e-5 and hl[1] - 1e-5 < cv < hl[3] + 1e-5 for hl in holes):
                    continue
                a, b_, c_, d = vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)
                I += [a, b_, c_, a, c_, d]
        if not P:
            return
        n = len(P)
        s._add(mat, tag, P, np.tile(Nn, (n, 1)), UV, np.tile(np.append(Ut, 1.0), (n, 1)), I)

    def box(s, mat, x0, y0, z0, x1, y1, z1, faces='xXyYzZ', tag='', col=None, occ=False, step=0):
        x0, x1 = min(x0, x1), max(x0, x1); y0, y1 = min(y0, y1), max(y0, y1); z0, z1 = min(z0, z1), max(z0, z1)
        w, d, h = x1 - x0, y1 - y0, z1 - z0
        if 'x' in faces: s.surf(mat, (x0, y1, z0), -Y, Z, d, h, step=step, tag=tag)
        if 'X' in faces: s.surf(mat, (x1, y0, z0), Y, Z, d, h, step=step, tag=tag)
        if 'y' in faces: s.surf(mat, (x0, y0, z0), X, Z, w, h, step=step, tag=tag)
        if 'Y' in faces: s.surf(mat, (x1, y1, z0), -X, Z, w, h, step=step, tag=tag)
        if 'z' in faces: s.surf(mat, (x0, y1, z0), X, -Y, w, d, step=step, tag=tag)
        if 'Z' in faces: s.surf(mat, (x0, y0, z1), X, Y, w, d, step=step, tag=tag)
        if col is not None:
            s.cboxes.append((x0, y0, z0, x1, y1, z1, MATS[mat]['col'] if col is True else col))
        if occ:
            s.occ.append((x0, y0, z0, x1, y1, z1))

    def quad(s, mat, O, U, V, w, h, col=None, step=0, fit=False, tag=''):
        """Free rectangle (any orientation) with optional two-sided collision."""
        O, U, V = np.asarray(O, float), np.asarray(U, float), np.asarray(V, float)
        U = U / np.linalg.norm(U); V = V / np.linalg.norm(V)
        s.surf(mat, O, U, V, w, h, step=step, fit=fit, tag=tag)
        if col is not None:
            a, b_, c, d = O, O + U * w, O + U * w + V * h, O + V * h
            s.ctris += [(a, b_, c, col), (a, c, d, col)]

    def obox(s, mat, cx, cy, z0, lx, ly, h, yaw, tag='', fit=False):
        """Box rotated around Z (yaw in degrees), centred at cx,cy."""
        r = math.radians(yaw)
        U = np.array([math.cos(r), math.sin(r), 0.0]); V = np.array([-math.sin(r), math.cos(r), 0.0])
        C = np.array([cx, cy, z0])
        a, b_ = lx / 2, ly / 2
        s.surf(mat, C - U * a - V * b_, U, Z, lx, h, step=0, tag=tag, fit=fit)          # -V side
        s.surf(mat, C + U * a + V * b_, -U, Z, lx, h, step=0, tag=tag, fit=fit)         # +V side
        s.surf(mat, C + U * a - V * b_, V, Z, ly, h, step=0, tag=tag)          # +U side
        s.surf(mat, C - U * a + V * b_, -V, Z, ly, h, step=0, tag=tag)         # -U side
        s.surf(mat, C - U * a - V * b_ + Z * h, U, V, lx, ly, step=0, tag=tag)  # top
        s.surf(mat, C - U * a + V * b_, U, -V, lx, ly, step=0, tag=tag)         # bottom

    def cyl(s, mat, cx, cy, z0, r, h, seg=14, tag='', r2=None, caps=True):
        r2 = r if r2 is None else r2
        P, N, UV, T, I = [], [], [], [], []
        tile = MATS[mat]['tile']
        for k in range(seg + 1):
            a = 2 * math.pi * k / seg
            ca, sa = math.cos(a), math.sin(a)
            n = np.array([ca, sa, (r - r2) / max(h, 1e-6)]); n /= np.linalg.norm(n)
            for (rr, zz) in ((r, z0), (r2, z0 + h)):
                P.append((cx + ca * rr, cy + sa * rr, zz)); N.append(n)
                UV.append((a * r / tile, -zz / tile)); T.append((-sa, ca, 0, 1))
        for k in range(seg):
            a, b_, c_, d = 2 * k, 2 * k + 2, 2 * k + 3, 2 * k + 1
            I += [a, b_, c_, a, c_, d]
        s._add(mat, tag, P, N, UV, T, I)
        if caps:
            for (zz, rr, nz) in ((z0 + h, r2, 1.0), (z0, r, -1.0)):
                P = [(cx, cy, zz)] + [(cx + math.cos(2 * math.pi * k / seg) * rr, cy + math.sin(2 * math.pi * k / seg) * rr, zz) for k in range(seg)]
                I = []
                for k in range(seg):
                    a, b_ = 1 + k, 1 + (k + 1) % seg
                    I += [0, a, b_] if nz > 0 else [0, b_, a]
                s._add(mat, tag, P, np.tile((0, 0, nz), (len(P), 1)), [(p[0] / tile, -p[1] / tile) for p in P],
                       np.tile((1, 0, 0, 1), (len(P), 1)), I)

    def cbox(s, x0, y0, z0, x1, y1, z1, col=101, occ=True):
        b = (min(x0, x1), min(y0, y1), min(z0, z1), max(x0, x1), max(y0, y1), max(z0, z1))
        s.cboxes.append(b + (col,))
        if occ:
            s.occ.append(b)

    def light(s, x, y, z, color=(255, 236, 210), intensity=4.0, falloff=6.0, shadow=False):
        s.lights.append(dict(p=(x, y, z), c=color, i=intensity, f=falloff, sh=shadow))

    # ------------------------------------------------------------ rooms
    def room(s, name, x0, y0, x1, y1, floor='planks', wall='paint_white', ceil='paint_white', H=None,
             wains=None, base='trim', floor_rot=0.0, crown=False, light=True, rail=True):
        s.rooms[name] = dict(rail=rail, x0=x0, y0=y0, x1=x1, y1=y1, floor=floor, wall=wall, ceil=ceil, H=H or s.H, wains=wains,
                             base=base, rot=floor_rot, crown=crown, light=light)
        for sd in 'NSEW':
            s.holes[(name, sd)] = []
        return name

    def frame(s, room, side):
        """(origin, U, inward normal, length) of a wall side. P = O + U*a + N*d + Z*z"""
        r = s.rooms[room]
        if side == 'S': return np.array([r['x1'], r['y0'], 0.0]), -X, Y, r['x1'] - r['x0']
        if side == 'N': return np.array([r['x0'], r['y1'], 0.0]), X, -Y, r['x1'] - r['x0']
        if side == 'W': return np.array([r['x0'], r['y0'], 0.0]), Y, X, r['y1'] - r['y0']
        return np.array([r['x1'], r['y1'], 0.0]), -Y, -X, r['y1'] - r['y0']

    def local(s, room, side, c0, c1):
        """world coordinate range along the wall -> local (a0, a1)"""
        r = s.rooms[room]
        if side == 'S': a = (r['x1'] - c1, r['x1'] - c0)
        elif side == 'N': a = (c0 - r['x0'], c1 - r['x0'])
        elif side == 'W': a = (c0 - r['y0'], c1 - r['y0'])
        else: a = (r['y1'] - c1, r['y1'] - c0)
        return a

    def wbox(s, mat, room, side, a0, a1, z0, z1, d0, d1, **kw):
        O, U, Nn, L = s.frame(room, side)
        p = O + U * a0 + Nn * d0; q = O + U * a1 + Nn * d1
        s.box(mat, p[0], p[1], z0, q[0], q[1], z1, **kw)

    def wpoint(s, room, side, a, z, d=0.0):
        O, U, Nn, L = s.frame(room, side)
        return O + U * a + Nn * d + Z * z

    def _cut(s, room, side, c0, c1, z0, z1, kind):
        a0, a1 = s.local(room, side, c0, c1)
        s.holes[(room, side)].append((a0, z0, a1, z1, kind))
        return a0, a1

    def _casing(s, room, side, a0, a1, h, mat='trim', wdt=0.07, th=0.018):
        s.wbox(mat, room, side, a0 - wdt, a0, 0, h + wdt, 0, th)
        s.wbox(mat, room, side, a1, a1 + wdt, 0, h + wdt, 0, th)
        s.wbox(mat, room, side, a0, a1, h, h + wdt, 0, th)

    def door(s, room, side, c0, c1, to=None, h=2.05, kind='door', casing='trim', thresh='wood_dark', leaf=None,
             leaf_mat='door_wood', leaf_angle=100):
        """Opening between `room` and `to` (the room on the other side of the wall). kind: door | open (full height)."""
        r = s.rooms[room]
        if kind == 'open':
            h = r['H']
        a0, a1 = s._cut(room, side, c0, c1, 0, h, kind)
        if kind == 'door' and casing:
            s._casing(room, side, a0, a1, h, casing)
        if to is None:
            return
        o = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}[side]
        r2 = s.rooms[to]
        h2 = r2['H'] if kind == 'open' else h
        b0, b1 = s._cut(to, o, c0, c1, 0, min(h, h2), kind)
        if kind == 'door' and casing:
            s._casing(to, o, b0, b1, h, casing)
        hh = min(h, h2)
        wm = r['wall'] if kind == 'open' else (casing or r['wall'])
        cm = r['ceil'] if kind == 'open' else (casing or r['wall'])
        if side in 'NS':
            ya = r['y1'] if side == 'N' else r['y0']; yb = r2['y0'] if side == 'N' else r2['y1']
            lo, hi = min(ya, yb), max(ya, yb); g = hi - lo
            if g > 1e-4:
                s.surf(wm, (c0, lo, 0), Y, Z, g, hh, step=0.5)
                s.surf(wm, (c1, hi, 0), -Y, Z, g, hh, step=0.5)
                s.surf(cm, (c0, hi, hh), X, -Y, c1 - c0, g, step=0.5, tag='ceil' if kind == 'open' else '')
                s.surf(thresh if kind == 'door' else r['floor'], (c0, lo, 0), X, Y, c1 - c0, g, step=0.5)
            hinge = (c0 if (leaf or 'l')[0] == 'l' else c1, ya)
        else:
            xa = r['x1'] if side == 'E' else r['x0']; xb = r2['x0'] if side == 'E' else r2['x1']
            lo, hi = min(xa, xb), max(xa, xb); g = hi - lo
            if g > 1e-4:
                s.surf(wm, (hi, c0, 0), -X, Z, g, hh, step=0.5)
                s.surf(wm, (lo, c1, 0), X, Z, g, hh, step=0.5)
                s.surf(cm, (lo, c1, hh), X, -Y, g, c1 - c0, step=0.5, tag='ceil' if kind == 'open' else '')
                s.surf(thresh if kind == 'door' else r['floor'], (lo, c0, 0), X, Y, g, c1 - c0, step=0.5)
            hinge = (xa, c0 if (leaf or 'l')[0] == 'l' else c1)
        if leaf:
            s.door_leaf(room, side, hinge, c1 - c0, h, leaf, leaf_mat, leaf_angle)

    def door_leaf(s, room, side, hinge, width, h, leaf, mat, angle):
        """Static door leaf swung open into `room`."""
        base = {'N': 90.0, 'S': -90.0, 'E': 0.0, 'W': 180.0}[side]   # direction along the wall for a closed leaf
        along = {'N': 0.0, 'S': 0.0, 'E': 90.0, 'W': 90.0}[side]
        sgn = 1 if leaf[0] == 'l' else -1
        inward = {'N': -90.0, 'S': 90.0, 'E': 180.0, 'W': 0.0}[side]
        closed = along if sgn > 0 else along + 180.0
        # rotate from closed direction towards the room interior
        d = ((inward - closed + 540) % 360) - 180
        yaw = closed + math.copysign(min(abs(angle), 170), d)
        r = math.radians(yaw)
        cx, cy = hinge[0] + math.cos(r) * width / 2, hinge[1] + math.sin(r) * width / 2
        s.obox(mat, cx, cy, 0.01, width - 0.02, 0.04, h - 0.03, yaw, fit=True)
        hx, hy = hinge[0] + math.cos(r) * (width - 0.1), hinge[1] + math.sin(r) * (width - 0.1)
        s.obox('steel', hx, hy, 1.0, 0.12, 0.09, 0.03, yaw)
        x0, x1 = sorted((hinge[0], hinge[0] + math.cos(r) * width)); y0, y1 = sorted((hinge[1], hinge[1] + math.sin(r) * width))
        s.cbox(x0 - 0.03, y0 - 0.03, 0, x1 + 0.03, y1 + 0.03, h, 70, occ=False)

    def entry_door(s, room, side, c0, c1, h=2.08, mat='door_maroon', frame='trim'):
        """Closed front door on an outside wall (the exit point)."""
        a0, a1 = s._cut(room, side, c0, c1, 0, h, 'window')
        D = 0.1
        s._reveal(room, side, a0, a1, 0, h, D, frame, back=None)
        O, U, Nn, L = s.frame(room, side)
        s.surf(mat, O + U * a0 - Nn * (D - 0.02), U, Z, a1 - a0, h, step=0, fit=True)
        s._casing(room, side, a0, a1, h, frame)
        s.wbox('steel', room, side, a1 - 0.14, a1 - 0.08, 0.98, 1.02, -D + 0.02, -D + 0.09)
        s.wbox('steel', room, side, a1 - 0.16, a1 - 0.06, 0.9, 1.1, -D + 0.02, -D + 0.035)
        p = O + U * (a0 + a1) / 2 + Nn * 1.0
        yaw = {'N': 180.0, 'S': 0.0, 'E': 90.0, 'W': 270.0}[side]
        s.entry = (float(p[0]), float(p[1]), 1.0, yaw)

    def panel(s, mat, room, side, c0, c1, z0, z1, th=0.03, fit=False):
        a0, a1 = s.local(room, side, c0, c1)
        s.wbox(mat, room, side, a0, a1, z0, z1, 0, th)

    def _reveal(s, room, side, a0, a1, z0, z1, D, mat, back='window_day', sill=None, tag=''):
        O, U, Nn, L = s.frame(room, side)
        P = lambda a, z, d=0.0: O + U * a + Nn * d + Z * z
        s.surf(mat, P(a0, z0, 0), -Nn, Z, D, z1 - z0, step=0.4)
        s.surf(mat, P(a1, z0, -D), Nn, Z, D, z1 - z0, step=0.4)
        s.surf(sill or mat, P(a0, z0, 0), U, -Nn, a1 - a0, D, step=0.4)
        s.surf(mat, P(a0, z1, -D), U, Nn, a1 - a0, D, step=0.4)
        if back:
            s.surf(back, P(a0, z0, -D), U, Z, a1 - a0, z1 - z0, step=0, fit=True, tag=tag)

    def window(s, room, side, c0, c1, sill=0.9, head=2.1, glass='window_day', frame='trim', cols=2, rows=1,
               cover=None, depth=0.14, sillboard=True, bar=0.045):
        """Window in an outside wall. cover: None | 'shade' | 'boards' | 'blind'."""
        a0, a1 = s._cut(room, side, c0, c1, sill, head, 'window')
        D = depth
        s._reveal(room, side, a0, a1, sill, head, D, s.rooms[room]['wall'], back=glass)
        f0, f1 = -D + 0.005, -D + 0.05
        s.wbox(frame, room, side, a0, a0 + bar, sill, head, f0, f1)
        s.wbox(frame, room, side, a1 - bar, a1, sill, head, f0, f1)
        s.wbox(frame, room, side, a0, a1, sill, sill + bar, f0, f1)
        s.wbox(frame, room, side, a0, a1, head - bar, head, f0, f1)
        for k in range(1, cols):
            a = a0 + (a1 - a0) * k / cols
            s.wbox(frame, room, side, a - bar / 2, a + bar / 2, sill, head, f0, f1)
        for k in range(1, rows):
            z = sill + (head - sill) * k / rows
            s.wbox(frame, room, side, a0, a1, z - bar / 2, z + bar / 2, f0, f1)
        if sillboard:
            s.wbox('trim' if frame != 'metal_dark' else 'metal_dark', room, side, a0 - 0.04, a1 + 0.04, sill - 0.03, sill, -D, 0.04)
        if cover == 'shade':
            s.wbox('fabric', room, side, a0 + 0.02, a1 - 0.02, sill + (head - sill) * 0.45, head - 0.02, -D + 0.07, -D + 0.085)
            s.wbox('wood_dark', room, side, a0 + 0.01, a1 - 0.01, head - 0.06, head, -D + 0.06, -D + 0.1)
        elif cover == 'boards':
            s.wbox('cardboard', room, side, a0 + 0.01, a1 - 0.01, sill + 0.01, head - 0.01, -D + 0.055, -D + 0.065)
        elif cover == 'blind':
            n = int((head - sill - 0.1) / 0.06)
            for k in range(n):
                z = head - 0.06 - k * 0.06
                s.wbox('trim', room, side, a0 + 0.02, a1 - 0.02, z - 0.004, z + 0.004, -D + 0.06, -D + 0.1)

    # ------------------------------------------------------------ build rooms
    def _segments(s, room, side, z):
        O, U, Nn, L = s.frame(room, side)
        cuts = sorted((h[0], h[2]) for h in s.holes[(room, side)] if h[1] - 1e-4 <= z <= h[3] + 1e-4 and h[4] != 'window' or (h[4] == 'window' and h[1] < z < h[3]))
        out, a = [], 0.0
        for c0, c1 in cuts:
            if c0 > a + 1e-3: out.append((a, c0))
            a = max(a, c1)
        if L > a + 1e-3: out.append((a, L))
        return out

    def build_rooms(s):
        t = s.t
        xs = [r['x0'] for r in s.rooms.values()] + [r['x1'] for r in s.rooms.values()]
        ys = [r['y0'] for r in s.rooms.values()] + [r['y1'] for r in s.rooms.values()]
        Hm = max(r['H'] for r in s.rooms.values())
        s.bb = (min(xs) - t, min(ys) - t, -0.25, max(xs) + t, max(ys) + t, Hm + 0.25)
        for name, r in s.rooms.items():
            x0, y0, x1, y1, H = r['x0'], r['y0'], r['x1'], r['y1'], r['H']
            s.surf(r['floor'], (x0, y0, 0), X, Y, x1 - x0, y1 - y0, rot=r['rot'], step=0.6)
            s.surf(r['ceil'], (x0, y1, H), X, -Y, x1 - x0, y1 - y0, step=0.6, tag='ceil')
            s.cbox(x0 - t, y0 - t, H, x1 + t, y1 + t, H + 0.2, 101)
            s.cbox(x0 - t, y0 - t, -0.2, x1 + t, y1 + t, 0, FLOOR_COL.get(r['floor'], 1))
            for sd in 'NSEW':
                O, U, Nn, L = s.frame(name, sd)
                holes = [(h[0], h[1], h[2], h[3]) for h in s.holes[(name, sd)]]
                wn = r['wains']
                if wn:
                    wm, wh = wn
                    s.surf(wm, O, U, Z, L, wh, holes=holes, step=0.5)
                    hs = [(h[0], h[1] - wh, h[2], h[3] - wh) for h in holes]
                    s.surf(r['wall'], O + Z * wh, U, Z, L, H - wh, holes=hs, step=0.6)
                    for a0, a1 in (s._segments(name, sd, wh) if r['rail'] else ()):
                        s.wbox('trim', name, sd, a0, a1, wh - 0.03, wh + 0.03, 0, 0.022)
                else:
                    s.surf(r['wall'], O, U, Z, L, H, holes=holes, step=0.6)
                if r['base']:
                    for a0, a1 in s._segments(name, sd, 0.02):
                        s.wbox(r['base'], name, sd, a0, a1, 0, 0.09, 0, 0.014, faces='xXyYZ')
                if r['crown']:
                    for a0, a1 in s._segments(name, sd, H - 0.02):
                        s.wbox('trim', name, sd, a0, a1, H - 0.07, H, 0, 0.05)
                # collision: wall cells that are not door openings
                dh = [(h[0], h[1], h[2], h[3]) for h in s.holes[(name, sd)] if h[4] != 'window']
                us = _breaks(L, [e for h in dh for e in (h[0], h[2])], 0)
                vs = _breaks(H, [e for h in dh for e in (h[1], h[3])], 0)
                for i in range(len(us) - 1):
                    for j in range(len(vs) - 1):
                        cu, cv = (us[i] + us[i + 1]) / 2, (vs[j] + vs[j + 1]) / 2
                        if any(h[0] < cu < h[2] and h[1] < cv < h[3] for h in dh):
                            continue
                        p = O + U * us[i]; q = O + U * us[i + 1] - Nn * t
                        s.cbox(p[0], p[1], vs[j], q[0], q[1], vs[j + 1], MATS[r['wall']]['col'])
        # outer hull (casts sun shadows, never seen from inside)
        x0, y0, z0, x1, y1, z1 = s.bb
        s.box('concrete_wall', x0, y0, 0, x1, y1, z1 - 0.05, faces='xXyYZ', tag='hull')

    # ------------------------------------------------------------ fixtures
    def led_panel(s, x, y, z, size=0.6, intensity=4.0, falloff=None, light=True):
        h = size / 2
        s.surf('light', (x - h, y + h, z - 0.012), X, -Y, size, size, step=0, fit=True, tag='fix')
        for (a, b, c, d) in ((x - h - 0.02, y - h - 0.02, x + h + 0.02, y - h), (x - h - 0.02, y + h, x + h + 0.02, y + h + 0.02),
                             (x - h - 0.02, y - h, x - h, y + h), (x + h, y - h, x + h + 0.02, y + h)):
            s.box('trim', a, b, z - 0.02, c, d, z, faces='xXyYz', tag='fix')
        if light:
            s.light(x, y, z - 0.25, intensity=intensity, falloff=falloff or 6.0)

    def linear_light(s, x, y, z, length=1.4, along='x', drop=0.25, mat='metal_dark', intensity=5.0, falloff=8.0):
        lx, ly = (length, 0.14) if along == 'x' else (0.14, length)
        zz = z - drop
        s.box(mat, x - lx / 2, y - ly / 2, zz, x + lx / 2, y + ly / 2, zz + 0.07, faces='xXyYZ', tag='fix')
        s.surf('light', (x - lx / 2 + 0.01, y + ly / 2 - 0.01, zz - 0.002), X, -Y, lx - 0.02, ly - 0.02, step=0, fit=True, tag='fix')
        if drop > 0.05:
            for k in (-0.4, 0.4):
                px, py = (x + k * length, y) if along == 'x' else (x, y + k * length)
                s.box(mat, px - 0.006, py - 0.006, zz + 0.07, px + 0.006, py + 0.006, z, faces='xXyY', tag='fix')
        s.light(x, y, zz - 0.2, color=(255, 244, 228), intensity=intensity, falloff=falloff)

    def fan(s, x, y, z, light=True):
        s.cyl('brass', x, y, z - 0.22, 0.02, 0.22, seg=8, tag='fix')
        s.cyl('wood_dark', x, y, z - 0.34, 0.11, 0.12, seg=14, tag='fix')
        for k in range(5):
            a = 72 * k + 12
            r = math.radians(a)
            s.obox('wood_dark', x + math.cos(r) * 0.42, y + math.sin(r) * 0.42, z - 0.29, 0.62, 0.13, 0.012, a, tag='fix')
        s.cyl('light', x, y, z - 0.47, 0.06, 0.13, seg=12, r2=0.11, tag='fix')
        if light:
            s.light(x, y, z - 0.6, color=(255, 222, 180), intensity=4.0, falloff=6.5)

    def pillar(s, mat, x0, y0, x1, y1, z0=0, z1=None, col=1):
        z1 = z1 or s.H
        s.box(mat, x0, y0, z0, x1, y1, z1, faces='xXyY' + ('z' if z0 > 0 else ''), step=0.6)
        s.cbox(x0, y0, z0, x1, y1, z1, col)

    def outlet(s, room, side, c, z=0.3, sw=False):
        a, _ = s.local(room, side, c, c)
        s.wbox('trim', room, side, a - 0.04, a + 0.04, z - (0.06 if not sw else 0.04), z + (0.06 if not sw else 0.04), 0, 0.008)

    def shutter(s, room, side, c0, c1, h, mat='shutter'):
        """Roller shutter door on an outside wall (closed)."""
        a0, a1 = s.local(room, side, c0, c1)
        O, U, Nn, L = s.frame(room, side)
        s.surf(mat, O + U * a0 + Nn * 0.03, U, Z, a1 - a0, h, step=0.6, uvo=O + U * a0)
        s.wbox('metal_dark', room, side, a0 - 0.08, a0, 0, h + 0.3, 0, 0.07)
        s.wbox('metal_dark', room, side, a1, a1 + 0.08, 0, h + 0.3, 0, 0.07)
        s.wbox('metal_dark', room, side, a0 - 0.08, a1 + 0.08, h, h + 0.32, 0, 0.3)
        s.wbox('metal_dark', room, side, a1 + 0.1, a1 + 0.2, 1.1, 1.45, 0, 0.09)
        p0 = O + U * a0; p1 = O + U * a1 + Nn * 0.06
        s.cbox(p0[0], p0[1], 0, p1[0], p1[1], h, 67, occ=False)

    def kitchen(s, room, side, c0, c1, fridge=True, upper=True, hob_at=0.55, sink_at=0.25):
        """Kitchen run along a wall: base units, worktop, sink, hob, wall units, fridge at the end."""
        a0, a1 = s.local(room, side, c0, c1)
        O, U, Nn, L = s.frame(room, side)
        fe = a1
        if fridge:
            fe = a1 - 0.72
            s.wbox('appliance', room, side, fe + 0.02, a1 - 0.02, 0.02, 1.85, 0.01, 0.68)
            s.wbox('steel', room, side, fe + 0.06, fe + 0.085, 0.75, 1.55, 0.68, 0.72)
            s.wbox('metal_dark', room, side, fe + 0.02, a1 - 0.02, 1.18, 1.19, 0.6, 0.685)
            p, q = O + U * fe, O + U * a1 + Nn * 0.68
            s.cbox(p[0], p[1], 0, q[0], q[1], 1.85, 56)
        s.wbox('metal_dark', room, side, a0, fe, 0, 0.1, 0, 0.54)                       # plinth
        s.wbox('wood_dark', room, side, a0, fe, 0.1, 0.87, 0, 0.6)                       # carcass
        s.wbox('countertop', room, side, a0 - 0.01, fe + 0.01, 0.87, 0.91, 0, 0.63)       # worktop
        n = max(1, int(round((fe - a0) / 0.6)))
        for k in range(n):
            x = a0 + (fe - a0) * k / n
            if k: s.wbox('metal_dark', room, side, x - 0.004, x + 0.004, 0.11, 0.86, 0.6, 0.603)
            xm = a0 + (fe - a0) * (k + 0.5) / n
            s.wbox('steel', room, side, xm - 0.08, xm + 0.08, 0.78, 0.795, 0.6, 0.63)
        sx = a0 + (fe - a0) * sink_at
        s.wbox('steel', room, side, sx - 0.3, sx + 0.3, 0.9, 0.915, 0.08, 0.55)
        s.wbox('metal_dark', room, side, sx - 0.24, sx + 0.24, 0.905, 0.92, 0.14, 0.5)
        fp = O + U * sx + Nn * 0.1
        s.cyl('steel', fp[0], fp[1], 0.91, 0.018, 0.26, seg=8)
        fq = O + U * sx + Nn * 0.19
        s.box('steel', min(fp[0], fq[0]) - 0.012, min(fp[1], fq[1]) - 0.012, 1.15, max(fp[0], fq[0]) + 0.012, max(fp[1], fq[1]) + 0.012, 1.175)
        hx = a0 + (fe - a0) * hob_at
        if hx + 0.3 < fe:
            s.wbox('black_glass', room, side, hx - 0.29, hx + 0.29, 0.91, 0.918, 0.06, 0.56)
            for (da, dd) in ((-0.14, 0.2), (0.14, 0.2), (-0.14, 0.43), (0.14, 0.43)):
                c = O + U * (hx + da) + Nn * dd
                s.cyl('steel', c[0], c[1], 0.918, 0.085, 0.004, seg=14)
                s.cyl('metal_dark', c[0], c[1], 0.922, 0.065, 0.002, seg=14)
            s.wbox('black_glass', room, side, hx - 0.28, hx + 0.28, 0.2, 0.8, 0.6, 0.612)
            s.wbox('steel', room, side, hx - 0.24, hx + 0.24, 0.74, 0.76, 0.612, 0.645)
            if upper:
                s.wbox('steel', room, side, hx - 0.3, hx + 0.3, 1.55, 1.63, 0, 0.5)
        s.surf('tile_white', O + U * a0 + Nn * 0.006 + Z * 0.91, U, Z, fe - a0, 0.55, step=0.5)
        if upper:
            for (u0, u1) in ((a0, hx - 0.32), (hx + 0.32, fe)) if hx + 0.3 < fe else ((a0, fe),):
                if u1 - u0 > 0.2:
                    s.wbox('wood_dark', room, side, u0, u1, 1.5, 2.2, 0, 0.34)
                    m = max(1, int(round((u1 - u0) / 0.6)))
                    for k in range(1, m):
                        x = u0 + (u1 - u0) * k / m
                        s.wbox('metal_dark', room, side, x - 0.004, x + 0.004, 1.51, 2.19, 0.34, 0.343)
        p, q = O + U * a0, O + U * fe + Nn * 0.63
        s.cbox(p[0], p[1], 0, q[0], q[1], 0.91, 70)

    def wardrobe(s, room, side, c0, c1, h=2.3, depth=0.6, mat='wood_door'):
        a0, a1 = s.local(room, side, c0, c1)
        O, U, Nn, L = s.frame(room, side)
        s.wbox(mat, room, side, a0, a1, 0.06, h, 0, depth)
        s.wbox('metal_dark', room, side, a0, a1, 0, 0.06, 0, depth - 0.04)
        n = max(2, int(round((a1 - a0) / 0.55)))
        for k in range(1, n):
            x = a0 + (a1 - a0) * k / n
            s.wbox('metal_dark', room, side, x - 0.004, x + 0.004, 0.07, h - 0.01, depth, depth + 0.003)
            s.wbox('steel', room, side, x + 0.03, x + 0.045, 0.95, 1.2, depth, depth + 0.03)
        p, q = O + U * a0, O + U * a1 + Nn * depth
        s.cbox(p[0], p[1], 0, q[0], q[1], h, 70)

    # ------------------------------------------------------------ finalize
    def finalize(s):
        out = {}
        for k, b in s.b.items():
            if not b['n']:
                continue
            out[k] = dict(P=np.concatenate(b['P']), N=np.concatenate(b['N']), UV=np.concatenate(b['UV']),
                          T=np.concatenate(b['T']), I=np.concatenate(b['I']))
        s.geo = out
        s._ao()
        return out

    def _ao(s, rays=18, dist=1.3, strength=0.72):
        occ = np.array(s.occ, float) if s.occ else np.zeros((0, 6))
        rng = np.random.default_rng(3)
        # cosine weighted hemisphere directions (local z up)
        u1, u2 = (np.arange(rays) + rng.random(rays)) / rays, rng.random(rays)
        rr, th = np.sqrt(u1), 2 * np.pi * u2
        loc = np.stack([rr * np.cos(th), rr * np.sin(th), np.sqrt(1 - u1)], -1)
        for k, g in s.geo.items():
            P, Nn = g['P'], g['N']
            n = len(P)
            ao = np.ones(n)
            if k.endswith('|hull') or MATS[k.split('|')[0]]['sh'] == 'e' or not len(occ):
                g['AO'] = ao; continue
            for c0 in range(0, n, 6000):
                p, nn = P[c0:c0 + 6000], Nn[c0:c0 + 6000]
                up = np.where(np.abs(nn[:, 2:3]) < 0.9, Z[None, :], X[None, :])
                tx = np.cross(up, nn); tx /= np.linalg.norm(tx, axis=1, keepdims=True)
                ty = np.cross(nn, tx)
                d = loc[None, :, 0:1] * tx[:, None, :] + loc[None, :, 1:2] * ty[:, None, :] + loc[None, :, 2:3] * nn[:, None, :]
                o = (p + nn * 0.015)[:, None, :]
                lo, hi = p.min(0) - dist, p.max(0) + dist
                sel = occ[(occ[:, 3] > lo[0]) & (occ[:, 0] < hi[0]) & (occ[:, 4] > lo[1]) & (occ[:, 1] < hi[1]) & (occ[:, 5] > lo[2]) & (occ[:, 2] < hi[2])]
                hit = np.zeros(d.shape[:2], bool)
                inv = 1.0 / np.where(np.abs(d) < 1e-9, 1e-9, d)
                for bx in sel:
                    t0 = (bx[None, None, 0:3] - o) * inv; t1 = (bx[None, None, 3:6] - o) * inv
                    tn = np.minimum(t0, t1).max(-1); tf = np.maximum(t0, t1).min(-1)
                    hit |= (tf >= tn) & (tn > 1e-4) & (tn < dist)
                ao[c0:c0 + 6000] = 1.0 - strength * hit.mean(1)
            g['AO'] = np.clip(ao, 0.3, 1.0)

    # ------------------------------------------------------------ export
    def write_xml(s, outdir, embed=None):
        geo = s.geo
        keys = sorted(geo.keys())
        mats = sorted({k.split('|')[0] for k in keys})
        allP = np.concatenate([geo[k]['P'] for k in keys])
        mn, mx = allP.min(0), allP.max(0)
        ctr = (mn + mx) / 2; rad = float(np.linalg.norm(mx - ctr))
        f = lambda v: ('%.6f' % v).rstrip('0').rstrip('.') if abs(v) > 5e-7 else '0'
        L = ['<?xml version="1.0" encoding="UTF-8"?>', '<Drawable>', f' <Name>{s.name}</Name>',
             f' <BoundingSphereCenter x="{f(ctr[0])}" y="{f(ctr[1])}" z="{f(ctr[2])}" />', f' <BoundingSphereRadius value="{f(rad)}" />',
             f' <BoundingBoxMin x="{f(mn[0])}" y="{f(mn[1])}" z="{f(mn[2])}" />', f' <BoundingBoxMax x="{f(mx[0])}" y="{f(mx[1])}" z="{f(mx[2])}" />',
             ' <LodDistHigh value="9998" />', ' <LodDistMed value="9998" />', ' <LodDistLow value="9998" />', ' <LodDistVlow value="9998" />',
             ' <FlagsHigh value="0" />', ' <FlagsMed value="0" />', ' <FlagsLow value="0" />', ' <FlagsVlow value="0" />', ' <ShaderGroup>', '  <Shaders>']
        vec = lambda n, x, y=0, z=0, w=0: f'     <Item name="{n}" type="Vector" x="{f(x)}" y="{f(y)}" z="{f(z)}" w="{f(w)}" />'
        tex = lambda n, t: f'     <Item name="{n}" type="Texture">\n      <Name>{t}</Name>\n     </Item>'
        for m in mats:
            M = MATS[m]; sh = M['sh']; t = M['tex']
            name, fn = {'ns': ('normal_spec', 'normal_spec.sps'), 'n': ('normal', 'normal.sps'), 's': ('spec', 'spec.sps'),
                        'd': ('default', 'default.sps'), 'e': ('emissive', 'emissive.sps')}[sh]
            L += ['   <Item>', f'    <Name>{name}</Name>', f'    <FileName>{fn}</FileName>', '    <RenderBucket value="0" />', '    <Parameters>']
            sp, fl = M.get('spec', 0.1), M.get('fall', 40)
            if sh == 'ns':
                L += [tex('DiffuseSampler', t), tex('BumpSampler', t + '_n'), tex('SpecSampler', t + '_s'), vec('HardAlphaBlend', 1), vec('useTessellation', 0),
                      vec('wetnessMultiplier', 0), vec('bumpiness', 1), vec('specMapIntMask', 1, 0, 0), vec('specularIntensityMult', sp),
                      vec('specularFalloffMult', fl), vec('specularFresnel', 0.75)]
            elif sh == 'n':
                L += [tex('DiffuseSampler', t), tex('BumpSampler', t + '_n'), vec('HardAlphaBlend', 1), vec('useTessellation', 0), vec('wetnessMultiplier', 0),
                      vec('bumpiness', 1), vec('specularIntensityMult', sp), vec('specularFalloffMult', fl), vec('specularFresnel', 0.75),
                      vec('globalAnimUV1', 0, 1, 0), vec('globalAnimUV0', 1, 0, 0)]
            elif sh == 's':
                L += [tex('DiffuseSampler', t), tex('SpecSampler', t + '_s'), vec('HardAlphaBlend', 1), vec('useTessellation', 0), vec('wetnessMultiplier', 0),
                      vec('specMapIntMask', 1, 0, 0), vec('specularIntensityMult', sp), vec('specularFalloffMult', fl), vec('specularFresnel', 0.97),
                      vec('globalAnimUV1', 0, 1, 0), vec('globalAnimUV0', 1, 0, 0)]
            elif sh == 'e':
                L += [tex('DiffuseSampler', t), vec('matMaterialColorScale', 1, 0, 0, 1), vec('HardAlphaBlend', 1), vec('useTessellation', 0),
                      vec('emissiveMultiplier', M.get('emis', 4)), vec('globalAnimUV1', 0, 1, 0), vec('globalAnimUV0', 1, 0, 0)]
            else:
                L += [tex('DiffuseSampler', t), vec('matMaterialColorScale', 1, 0, 0, 1), vec('HardAlphaBlend', 1), vec('useTessellation', 0),
                      vec('wetnessMultiplier', 0), vec('globalAnimUV1', 0, 1, 0), vec('globalAnimUV0', 1, 0, 0)]
            L += ['    </Parameters>', '   </Item>']
        L += ['  </Shaders>', ' </ShaderGroup>', ' <DrawableModelsHigh>', '  <Item>', '   <RenderMask value="255" />', '   <Flags value="0" />',
              '   <HasSkin value="0" />', '   <BoneIndex value="0" />', '   <Unknown1 value="0" />', '   <Geometries>']
        nv = nt = 0
        for m in mats:
            tang = MATS[m]['sh'] in ('ns', 'n')
            P = np.concatenate([geo[k]['P'] for k in keys if k.split('|')[0] == m])
            Nn = np.concatenate([geo[k]['N'] for k in keys if k.split('|')[0] == m])
            UV = np.concatenate([geo[k]['UV'] for k in keys if k.split('|')[0] == m])
            T = np.concatenate([geo[k]['T'] for k in keys if k.split('|')[0] == m])
            AO = np.concatenate([geo[k]['AO'] for k in keys if k.split('|')[0] == m])
            I, off = [], 0
            for k in keys:
                if k.split('|')[0] == m:
                    I.append(geo[k]['I'] + off); off += len(geo[k]['P'])
            I = np.concatenate(I)
            # split so every geometry stays below the 16 bit index limit
            tris = I.reshape(-1, 3)
            start = 0
            while start < len(tris):
                used, remap, sel = {}, [], []
                end = start
                while end < len(tris) and len(used) <= 64000:
                    for v in tris[end]:
                        if v not in used:
                            used[int(v)] = len(remap); remap.append(int(v))
                    end += 1
                idx = np.array([[used[int(v)] for v in tri] for tri in tris[start:end]]).reshape(-1)
                rm = np.array(remap)
                p, n_, uv, tg, ao = P[rm], Nn[rm], UV[rm], T[rm], AO[rm]
                gmn, gmx = p.min(0), p.max(0)
                L += ['    <Item>', f'     <ShaderIndex value="{mats.index(m)}" />',
                      f'     <BoundingBoxMin x="{f(gmn[0])}" y="{f(gmn[1])}" z="{f(gmn[2])}" w="0" />',
                      f'     <BoundingBoxMax x="{f(gmx[0])}" y="{f(gmx[1])}" z="{f(gmx[2])}" w="0" />',
                      '     <VertexBuffer>', '      <Flags value="0" />', '      <Layout type="GTAV1">', '       <Position />', '       <Normal />',
                      '       <Colour0 />', '       <TexCoord0 />'] + (['       <Tangent />'] if tang else []) + ['      </Layout>', '      <Data>']
                c = np.clip(np.round(ao * 255), 0, 255).astype(int)
                rows = []
                for i in range(len(p)):
                    r = '       %.5f %.5f %.5f   %.4f %.4f %.4f   %d %d %d 255   %.5f %.5f' % (p[i, 0], p[i, 1], p[i, 2], n_[i, 0], n_[i, 1], n_[i, 2], c[i], c[i], c[i], uv[i, 0], uv[i, 1])
                    if tang:
                        r += '   %.4f %.4f %.4f %.0f' % (tg[i, 0], tg[i, 1], tg[i, 2], tg[i, 3])
                    rows.append(r)
                L += rows + ['      </Data>', '     </VertexBuffer>', '     <IndexBuffer>', '      <Data>']
                for i in range(0, len(idx), 24):
                    L.append('       ' + ' '.join(str(int(v)) for v in idx[i:i + 24]))
                L += ['      </Data>', '     </IndexBuffer>', '    </Item>']
                nv += len(p); nt += len(idx) // 3
                start = end
        L += ['   </Geometries>', '  </Item>', ' </DrawableModelsHigh>']
        L += s._bounds_xml(f)
        L += [' <Lights>']
        for lt in s.lights:
            fl = 448 if lt['sh'] else 0
            L += ['  <Item>', f'   <Position x="{f(lt["p"][0])}" y="{f(lt["p"][1])}" z="{f(lt["p"][2])}" />',
                  f'   <Colour r="{lt["c"][0]}" g="{lt["c"][1]}" b="{lt["c"][2]}" />', '   <Flashiness value="0" />', f'   <Intensity value="{f(lt["i"])}" />',
                  f'   <Flags value="{fl}" />', '   <BoneId value="0" />', '   <Type>Point</Type>', '   <GroupId value="0" />', '   <TimeFlags value="16777215" />',
                  f'   <Falloff value="{f(lt["f"])}" />', '   <FalloffExponent value="8" />', '   <CullingPlaneNormal x="0" y="0" z="-1" />',
                  f'   <CullingPlaneOffset value="{f(lt["f"])}" />', '   <Unknown45 value="0" />', '   <Unknown46 value="0" />', '   <VolumeIntensity value="0" />',
                  '   <VolumeSizeScale value="1" />', '   <VolumeOuterColour r="255" g="255" b="255" />', '   <LightHash value="0" />', '   <VolumeOuterIntensity value="1" />',
                  '   <CoronaSize value="0" />', '   <VolumeOuterExponent value="1" />', '   <LightFadeDistance value="0" />', '   <ShadowBlur value="12" />',
                  '   <ShadowFadeDistance value="0" />', '   <SpecularFadeDistance value="0" />', '   <VolumetricFadeDistance value="0" />', '   <ShadowNearClip value="0.05" />',
                  '   <CoronaIntensity value="0" />', '   <CoronaZBias value="0.1" />', '   <Direction x="0" y="0" z="-1" />', '   <Tangent x="1" y="0" z="0" />',
                  '   <ConeInnerAngle value="0" />', '   <ConeOuterAngle value="0" />', '   <Extent x="1" y="1" z="1" />', '   <ProjectedTextureHash />', '  </Item>']
        L += [' </Lights>', '</Drawable>']
        open(os.path.join(outdir, s.name + '.ydr.xml'), 'w').write('\n'.join(L) + '\n')
        s.stats = dict(verts=nv, tris=nt, mats=len(mats), lights=len(s.lights), cboxes=len(s.cboxes), bbmin=[float(v) for v in mn], bbmax=[float(v) for v in mx],
                       center=[float(v) for v in ctr], radius=rad)
        return s.stats

    def _bounds_xml(s, f):
        boxes = s.cboxes
        cols = sorted({b[6] for b in boxes} | {t[3] for t in s.ctris})
        V, T = [], []
        for b in boxes:
            x0, y0, z0, x1, y1, z1, cm = b
            o = len(V)
            V += [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
            m = cols.index(cm)
            for (a, b_, c) in ((0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4), (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6), (3, 0, 4), (3, 4, 7)):
                T.append((m, o + a, o + b_, o + c))
        for (p0, p1, p2, cm) in s.ctris:
            o = len(V); V += [tuple(p0), tuple(p1), tuple(p2)]; T.append((cols.index(cm), o, o + 1, o + 2))
        Va = np.array(V); mn, mx = Va.min(0), Va.max(0); ctr = (mn + mx) / 2; rad = float(np.linalg.norm(mx - ctr))
        v3 = lambda n, p: f'<{n} x="{f(p[0])}" y="{f(p[1])}" z="{f(p[2])}" />'
        def common(ind, margin, utype):
            return [ind + v3('BoxMin', mn), ind + v3('BoxMax', mx), ind + v3('BoxCenter', ctr), ind + v3('SphereCenter', ctr), ind + f'<SphereRadius value="{f(rad)}" />',
                    ind + f'<Margin value="{margin}" />', ind + '<Volume value="1" />', ind + '<Inertia x="1" y="1" z="1" />', ind + '<MaterialIndex value="0" />',
                    ind + '<MaterialColourIndex value="0" />', ind + '<ProceduralID value="0" />', ind + '<RoomID value="0" />', ind + '<PedDensity value="0" />',
                    ind + '<UnkFlags value="0" />', ind + '<PolyFlags value="0" />', ind + f'<UnkType value="{utype}" />']
        L = [' <Bounds type="Composite">'] + common('  ', '0.04', 1) + ['  <Children>', '   <Item type="GeometryBVH">'] + common('    ', '0.04', 1)
        L += ['    <CompositeTransform>', '     1 0 0 0', '     0 1 0 0', '     0 0 1 0', '     0 0 0 1', '    </CompositeTransform>',
              '    <CompositeFlags1>MAP_WEAPON, MAP_DYNAMIC, MAP_ANIMAL, MAP_COVER, MAP_VEHICLE</CompositeFlags1>',
              '    <CompositeFlags2>VEHICLE_NOT_BVH, VEHICLE_BVH, PED, RAGDOLL, ANIMAL, ANIMAL_RAGDOLL, OBJECT, PLANT, PROJECTILE, EXPLOSION, FORKLIFT_FORKS, TEST_WEAPON, TEST_CAMERA, TEST_AI, TEST_SCRIPT, TEST_VEHICLE_WHEEL, GLASS</CompositeFlags2>',
              '    ' + v3('GeometryCenter', ctr), '    <UnkFloat1 value="0" />', '    <UnkFloat2 value="0" />', '    <Materials>']
        for cm in cols:
            L += ['     <Item>', f'      <Type value="{cm}" />', '      <ProceduralID value="0" />', '      <RoomID value="0" />', '      <PedDensity value="0" />',
                  '      <Flags>NONE</Flags>', '      <MaterialColourIndex value="0" />', '      <Unk value="0" />', '     </Item>']
        L += ['    </Materials>', '    <Vertices>'] + ['     %s, %s, %s' % (f(p[0]), f(p[1]), f(p[2])) for p in V] + ['    </Vertices>', '    <Polygons>']
        L += [f'     <Triangle m="{t[0]}" v1="{t[1]}" v2="{t[2]}" v3="{t[3]}" f1="0" f2="0" f3="0" />' for t in T]
        L += ['    </Polygons>', '   </Item>', '  </Children>', ' </Bounds>']
        return L

    def write_preview(s, path):
        out = {'name': s.name, 'label': s.label, 'meshes': [], 'lights': [dict(p=l['p'], c=l['c'], i=l['i'], f=l['f']) for l in s.lights],
               'bb': [float(v) for v in s.bb], 'entry': s.entry}
        for k, g in s.geo.items():
            m, tag = k.split('|')
            out['meshes'].append(dict(mat=m, tag=tag, tex=MATS[m]['tex'], sh=MATS[m]['sh'], spec=MATS[m].get('spec', 0.1),
                                      P=np.round(g['P'], 4).reshape(-1).tolist(), N=np.round(g['N'], 3).reshape(-1).tolist(),
                                      UV=np.round(g['UV'], 4).reshape(-1).tolist(), C=np.round(g['AO'], 3).tolist(), I=g['I'].tolist()))
        json.dump(out, open(path, 'w'))
