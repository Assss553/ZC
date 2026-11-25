# ROX Towers - full interior fit-out as a police headquarters (inside only; the exterior pieces in towers.py are untouched).
# One model per floor type, spawned by rox_towers at every floor level that uses it.  (c) ROX Store
#
#   lobby (ground, double height): glass vestibule, marble hall, waiting lounges, security line (detectors, bag scanners,
#                                  staff gates), reception, info screens, elevator hall, restrooms, security office, interview
#   mid-block floor types (48 x 38 chamfered plate, core x -5..5 / y 0..8, floor-to-floor 3.9):
#       svc  security + services     ops  operations centre      adm  administration offices
#       cnf  conference floor        inv  investigations          cmd  command / chief of police
#   twin floor (18 x 30 plate): tower offices
# Every floor: elevator hall in front of the core, south corridor with a perimeter gallery along the glass, side corridors,
# north corridor, restrooms, emergency stairs. Doors are openings sized for real GTA door props (spawned + door system).
import math, json, os
import numpy as np
from kit import Shell, MATS, X, Y, Z
import towers as T

FH = T.FH
CH = 3.4                        # room ceiling height on office floors (plenum above)
DOORW = 1.2
DOORS, FURN = {}, {}            # floor type -> list, exported to the resource


def piece(name, label):
    s = Shell(name, label, label, H=CH); s.hull = False; s.txd, s.lod = T.TXD, 120
    return s


def outer(s, zt, top=False, mat='paint_white'):
    """outside faces of every room wall (seen from galleries / the lobby hall), with the same openings; 9 cm out so they stay inside the gaps"""
    for name, r in s.rooms.items():
        for sd in 'NSEW':
            O, U, Nn, L = s.frame(name, sd)
            hl = [(L - h[2], h[1], L - h[0], h[3]) for h in s.holes[(name, sd)]]
            s.surf(mat, O + U * L - Nn * 0.09, -U, Z, L, zt, holes=hl, step=1.0)
        if top: s.surf('paint_black', (r['x0'] - 0.09, r['y0'] - 0.09, zt), X, Y, r['x1'] - r['x0'] + 0.18, r['y1'] - r['y0'] + 0.18, step=1.0)


def plate(s, pts, floor_mat, ceil_z, ceil_mat='paint_black'):
    """floor + ceiling of the whole plate (under / over the rooms) and the city view on the inside of the glass"""
    inner = [(x * 0.985, y * 0.985) for x, y in pts]
    T.poly(s, floor_mat, inner, -0.01, True, col=MATS[floor_mat]['col'])
    T.poly(s, ceil_mat, inner, ceil_z, False)
    for i, a, b, U, L in T.edges(inner):
        U3 = np.array([-U[0], -U[1], 0.0]); s.surf('city_view', (b[0], b[1], 0.0), U3, Z, L, ceil_z, step=0, fit=True)


def door(s, room, side, c, to=None, kind='std', w=DOORW, h=2.3, key='', casing='metal_dark'):
    """opening + record for a GTA door prop. kind: std | glass | sec (locked, keypad) | open (no leaf)"""
    c0, c1 = c - w / 2, c + w / 2
    s.door(room, side, c0, c1, to=to, h=h, casing=casing)
    if kind == 'open': return
    r = s.rooms[room]
    if side in 'NS':
        y = r['y1'] if side == 'N' else r['y0']
        if to is not None: y = (y + (s.rooms[to]['y0'] if side == 'N' else s.rooms[to]['y1'])) / 2
        hinge, head = (c0, y), 0.0
    else:
        x = r['x1'] if side == 'E' else r['x0']
        if to is not None: x = (x + (s.rooms[to]['x0'] if side == 'E' else s.rooms[to]['x1'])) / 2
        hinge, head = (x, c0), 90.0
    DOORS.setdefault(s.name, []).append(dict(x=round(hinge[0], 3), y=round(hinge[1], 3), h=head, w=w, kind=kind, key=key))


def F(s, model, x, y, h=0.0, z=0.0, **kw):
    d = dict(m=model, x=round(x, 3), y=round(y, 3), h=h)
    if z: d['z'] = z
    d.update(kw); FURN.setdefault(s.name, []).append(d)


def led_lines(s, rm, sp=2.4, along='x', z=None):
    r = s.rooms[rm]; z = z or r['H']
    if along == 'x':
        y = r['y0'] + sp / 2
        while y < r['y1'] - 0.3: s.box('led_white', r['x0'] + 0.6, y - 0.03, z - 0.04, r['x1'] - 0.6, y + 0.03, z - 0.002); y += sp
    else:
        x = r['x0'] + sp / 2
        while x < r['x1'] - 0.3: s.box('led_white', x - 0.03, r['y0'] + 0.6, z - 0.04, x + 0.03, r['y1'] - 0.6, z - 0.002); x += sp


def lights(s, rm, n=None, I=5.0, fo=8.0):
    r = s.rooms[rm]; w, d = r['x1'] - r['x0'], r['y1'] - r['y0']
    nx = max(1, round(w / 6)); ny = max(1, round(d / 6))
    for i in range(nx):
        for j in range(ny):
            s.light(r['x0'] + (i + 0.5) * w / nx, r['y0'] + (j + 0.5) * d / ny, r['H'] - 0.25, color=(255, 246, 232), intensity=I, falloff=fo)


def sign(s, mat, x, y, z, face, w=1.2):
    """wayfinding sign: face = 'N','S','E','W' (side the sign is read from)"""
    h = w / 6
    if face == 'S': s.surf(mat, (x - w / 2, y - 0.01, z), X, Z, w, h, step=0, fit=True)
    if face == 'N': s.surf(mat, (x + w / 2, y + 0.01, z), -X, Z, w, h, step=0, fit=True)
    if face == 'E': s.surf(mat, (x + 0.01, y - w / 2, z), Y, Z, w, h, step=0, fit=True)
    if face == 'W': s.surf(mat, (x - 0.01, y + w / 2, z), -Y, Z, w, h, step=0, fit=True)


def oak(s, x0, y0, x1, y1, z1, faces):
    s.box('oak_panel', x0, y0, 0, x1, y1, z1, faces=faces, step=1.2)


# ------------------------------------------------------------------------------------------------ mid-block floors
XA, XB, YA, YB = -20.0, 20.0, -14.5, 14.5
g = 0.1
STAIR = (8.0 + g, 11.0 + g, 12.0, YB)                # emergency stair room (north-east of the north corridor)


def skeleton(s):
    """corridors common to every mid floor; returns nothing, rooms are added by the floor type"""
    R = dict(base='metal_dark', H=CH)
    s.room('corr_s', XA, -3.9, XB, -0.1, floor='marble_white', wall='paint_white', ceil='paint_black', **R)
    s.room('corr_w', -7.9, 0.1, -5.1, 7.9, floor='marble_white', wall='paint_white', ceil='paint_black', **R)
    s.room('corr_e', 5.1, 0.1, 7.9, 7.9, floor='marble_white', wall='paint_white', ceil='paint_black', **R)
    s.room('corr_n', -7.9, 8.1, 7.9, 10.9, floor='marble_white', wall='paint_white', ceil='paint_black', **R)
    s.room('wc_m', -7.9, 11.1, -2.1, YB, floor='tile_white', wall='tile_white', ceil='paint_white', **R)
    s.room('wc_w', -1.9, 11.1, 3.9, YB, floor='tile_white', wall='tile_white', ceil='paint_white', **R)
    s.room('stairs', 4.1, 11.1, 7.9, YB, floor='concrete_floor', wall='paint_grey', ceil='paint_grey', **R)


def skeleton_links(s):
    s.door('corr_s', 'N', -7.9, -5.1, to='corr_w', kind='open')
    s.door('corr_s', 'N', 5.1, 7.9, to='corr_e', kind='open')
    s.door('corr_w', 'N', -7.9, -5.1, to='corr_n', kind='open')
    s.door('corr_e', 'N', 5.1, 7.9, to='corr_n', kind='open')
    s.door('corr_s', 'W', -3.5, -0.5, kind='open'); s.door('corr_s', 'E', -3.5, -0.5, kind='open')      # to the perimeter gallery
    door(s, 'corr_n', 'N', -5.0, to='wc_m'); door(s, 'corr_n', 'N', 1.0, to='wc_w')
    door(s, 'corr_n', 'N', 6.0, to='stairs', kind='sec', key='stairs')


def skeleton_dress(s, signmat):
    # elevator hall: 4 steel elevator doors on the core front, oak frames, LED, floor sign
    for k, x in enumerate((-3.6, -1.2, 1.2, 3.6)):
        s.box('steel', x - 0.8, -0.12, 0, x + 0.8, -0.1, 2.5, faces='y'); s.box('metal_dark', x - 0.005, -0.125, 0, x + 0.005, -0.12, 2.5)
        s.box('oak_panel', x - 0.95, -0.14, 0, x - 0.8, -0.1, 2.75, faces='xXy'); s.box('oak_panel', x + 0.8, -0.14, 0, x + 0.95, -0.1, 2.75, faces='xXy')
        s.box('oak_panel', x - 0.95, -0.14, 2.5, x + 0.95, -0.1, 2.75, faces='yz'); s.box('led_white', x - 0.1, -0.15, 2.58, x + 0.1, -0.14, 2.66, faces='y')
    sign(s, signmat, 0.0, -0.11, 2.85, 'S', w=2.4); sign(s, 'sg_elevators', -9.0, -0.11, 2.4, 'S', w=1.5)
    sign(s, 'sg_emergency_exit', 6.5, 10.89, 2.5, 'S', w=1.2); sign(s, 'sg_restrooms', -2.0, 10.89, 2.5, 'S', w=1.2)
    # oak wainscot on the corridors + LED strips
    oak(s, XA + 0.5, -3.88, XB - 0.5, -3.86, 1.1, 'Y'); oak(s, -4.9, -0.14, 4.9, -0.12, 0.0001, '')
    for rm, al, sp in (('corr_s', 'x', 1.2), ('corr_w', 'y', 1.4), ('corr_e', 'y', 1.4), ('corr_n', 'x', 1.4)): led_lines(s, rm, sp, al)
    for rm in ('corr_s', 'corr_w', 'corr_e', 'corr_n', 'wc_m', 'wc_w', 'stairs'): lights(s, rm, I=4.0, fo=7.0)
    # restrooms: stalls (solid partitions) along the north wall, vanity counter
    for rm in ('wc_m', 'wc_w'):
        r = s.rooms[rm]
        for k in range(4):
            x = r['x0'] + 0.3 + k * 1.3
            s.box('paint_charcoal', x, YB - 1.6, 0.15, x + 0.04, YB, 2.2); s.cbox(x, YB - 1.6, 0, x + 0.04, YB, 2.2, 56)
            F(s, 'prop_toilet_01', x + 0.65, YB - 0.45, 180.0)
        s.box('marble_black', r['x0'] + 0.2, r['y0'] + 0.05, 0.85, r['x1'] - 0.2, r['y0'] + 0.65, 0.9); s.cbox(r['x0'] + 0.2, r['y0'] + 0.05, 0, r['x1'] - 0.2, r['y0'] + 0.65, 0.9, 81)
        s.box('black_glass', r['x0'] + 0.3, r['y0'] + 0.01, 1.1, r['x1'] - 0.3, r['y0'] + 0.03, 2.2, faces='Y')
        for k in range(3): F(s, 'prop_sink_02', r['x0'] + 1.2 + k * 1.6, r['y0'] + 0.35, 0.0, z=0.9 - 0.85 if False else 0.0)
        F(s, 'prop_handdry_01', r['x1'] - 0.4, r['y0'] + 0.05, 0.0, z=1.2)
    # emergency stairs: flights rendered as steps along the east wall (teleport point for up / down)
    r = s.rooms['stairs']
    for k in range(10):
        s.box('concrete_wall', r['x1'] - 1.4, r['y0'] + 0.4 + k * 0.28, 0, r['x1'] - 0.1, r['y0'] + 0.68 + k * 0.28, 0.18 * (k + 1), faces='xXyYZ')
    s.box('steel', r['x1'] - 1.45, r['y0'] + 0.4, 0.9, r['x1'] - 1.42, r['y0'] + 3.2, 0.95)
    # perimeter gallery (between rooms and glass): waiting benches + plants
    for x in (-21.5, 21.5):
        for y in (-10.0, -6.0, 4.0, 10.0): F(s, 'apa_mp_h_acc_plant_tall_01', x, y, 0.0)
    F(s, 'prop_vend_coffe_01', -9.5, -0.6, 180.0); F(s, 'prop_vend_soda_01', 9.5, -0.6, 180.0); F(s, 'prop_watercooler', -10.6, -0.6, 180.0)
    for x in (-15.0, 15.0): F(s, 'ba_prop_battle_cctv_cam_01a', x, -3.8, 0.0, z=3.2)


# room helpers ---------------------------------------------------------------------------------------------------
def south_rooms(s, cuts, names, floor='carpet', wall='paint_white'):
    """south band (y -14.5..-4.1) split at x cuts; each room gets a door to corr_s and windows onto the gallery"""
    xs = [XA] + cuts + [XB]
    for i, nm in enumerate(names):
        x0, x1 = xs[i] + (g if i else 0), xs[i + 1] - (g if i < len(names) - 1 else 0)
        s.room(nm, x0, YA, x1, -4.1, floor=floor, wall=wall, ceil='paint_black', base='metal_dark', H=CH)
    return [(nm, s.rooms[nm]) for nm in names]


def side_rooms(s, side, names, floor='carpet', wall='paint_white'):
    """west / east block, 3 rooms stacked: A y 0.1..3.9, B 4.1..7.9, C 8.1..14.5"""
    x0, x1 = (XA, -8.1) if side == 'W' else (8.1, XB)
    for nm, (y0, y1) in zip(names, ((0.1, 3.9), (4.1, 7.9), (8.1, YB))):
        s.room(nm, x0, y0, x1, y1, floor=floor, wall=wall, ceil='paint_black', base='metal_dark', H=CH)


def side_doors(s, side, names, kinds=('std', 'std', 'std')):
    face = 'E' if side == 'W' else 'W'
    door(s, names[0], 'S', (-9.5 if side == 'W' else 9.5), to='corr_s', kind=kinds[0])
    door(s, names[1], face, 6.0, to='corr_w' if side == 'W' else 'corr_e', kind=kinds[1])
    door(s, names[2], face, 9.5, to='corr_n', kind=kinds[2])


def south_doors(s, rooms, kinds=None):
    for i, (nm, r) in enumerate(rooms):
        c = (r['x0'] + r['x1']) / 2
        if -8.2 < c < 8.2 and abs(c) > 3.0: c = c   # keep
        door(s, nm, 'N', c, to='corr_s', kind=(kinds or {}).get(nm, 'std'))


def gallery_windows(s, rooms, side):
    for nm, r in rooms:
        if side == 'S':
            a, b = r['x0'] + 0.8, r['x1'] - 0.8
            if b - a > 1.5: s.window(nm, 'S', a, b, sill=0.8, head=2.9, glass=None, frame='metal_dark', cols=max(2, int((b - a) / 1.6)), depth=0.2)
        else:
            a, b = r['y0'] + 0.8, r['y1'] - 0.8
            if b - a > 1.5: s.window(nm, side, a, b, sill=0.8, head=2.9, glass=None, frame='metal_dark', cols=max(2, int((b - a) / 1.6)), depth=0.2)


def office_kit(s, rm, face='N', boss=False):
    """private office: desk + PC + monitor, exec chair, 2 guest chairs, filing cabinet, shelf, plant, art"""
    r = s.rooms[rm]; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
    # desk faces the door; for south rooms the door is N, so the desk sits near the window looking north
    if face == 'N':
        dy = r['y0'] + 2.0
        F(s, 'h4_prop_office_desk_01', cx, dy, 180.0, name=rm + 'd'); F(s, 'prop_monitor_01a', cx - 0.3, dy, 180.0, on=rm + 'd'); F(s, 'prop_keyboard_01b', cx - 0.3, dy - 0.2, 180.0, on=rm + 'd')
        F(s, 'ex_prop_offchair_exec_01', cx, dy - 0.9, 180.0); F(s, 'prop_off_chair_01', cx - 0.5, dy + 1.0, 0.0); F(s, 'prop_off_chair_01', cx + 0.5, dy + 1.0, 0.0)
        F(s, 'v_med_cor_filingcab', r['x0'] + 0.35, r['y1'] - 0.4, 0.0); F(s, 'apa_mp_h_str_shelffloorm_02', r['x1'] - 0.4, cy, 270.0)
        F(s, 'apa_mp_h_acc_plant_tall_01', r['x1'] - 0.5, r['y0'] + 0.5, 0.0)
    else:   # door on E / W wall -> desk against the far wall looking at the door
        sgn = 1 if face == 'E' else -1; dx = (r['x0'] + 2.0) if face == 'E' else (r['x1'] - 2.0)
        hd = 270.0 if face == 'E' else 90.0
        F(s, 'h4_prop_office_desk_01', dx, cy, hd, name=rm + 'd'); F(s, 'prop_monitor_01a', dx, cy - 0.3, hd, on=rm + 'd')
        F(s, 'ex_prop_offchair_exec_01', dx - sgn * 0.9, cy, (hd + 180) % 360); F(s, 'prop_off_chair_01', dx + sgn * 1.0, cy - 0.5, hd); F(s, 'prop_off_chair_01', dx + sgn * 1.0, cy + 0.5, hd)
        F(s, 'v_med_cor_filingcab', (r['x0'] + 0.35) if face == 'E' else (r['x1'] - 0.35), r['y1'] - 0.4, 180.0)
        F(s, 'apa_mp_h_str_shelffloorm_02', cx, r['y1'] - 0.35, 180.0); F(s, 'apa_mp_h_acc_plant_tall_01', (r['x0'] + 0.5) if face == 'E' else (r['x1'] - 0.5), r['y0'] + 0.5, 0.0)
    if boss:
        F(s, 'ex_mp_h_off_sofa_01', cx + (1.5 if face == 'N' else 0), r['y1'] - 0.7, 180.0); F(s, 'apa_mp_h_tab_coffee_07', cx + (1.5 if face == 'N' else 0), r['y1'] - 1.9, 0.0)
        F(s, 'prop_flag_us', r['x0'] + 0.5, r['y0'] + 0.5, 0.0)
    led_lines(s, rm, 2.0); lights(s, rm)


def open_office(s, rm, rows, cols, x0, y0, dx=3.2, dy=3.0):
    for i in range(cols):
        for j in range(rows):
            x, y = x0 + i * dx, y0 + j * dy; n = f'{rm}{i}{j}'
            F(s, 'h4_prop_office_desk_01', x, y, 0.0, name=n); F(s, 'prop_monitor_01a', x - 0.3, y + 0.1, 0.0, on=n); F(s, 'prop_monitor_01a', x + 0.3, y + 0.1, 0.0, on=n)
            F(s, 'prop_keyboard_01b', x, y - 0.15, 0.0, on=n); F(s, 'prop_off_chair_01', x, y - 0.9, 180.0)
    led_lines(s, rm, 2.4); lights(s, rm)


def meeting(s, rm, big=False):
    r = s.rooms[rm]; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
    w, d = r['x1'] - r['x0'], r['y1'] - r['y0']
    along_x = w >= d
    if big:
        L = (w if along_x else d) - 3.0; n = int(L / 1.1)
        if along_x:
            s.box('marble_black', cx - L / 2, cy - 0.8, 0.72, cx + L / 2, cy + 0.8, 0.78); s.box('wood_dark', cx - L / 2 + 0.6, cy - 0.35, 0, cx + L / 2 - 0.6, cy + 0.35, 0.72)
            s.cbox(cx - L / 2, cy - 0.8, 0, cx + L / 2, cy + 0.8, 0.78, 70)
            for k in range(n):
                x = cx - L / 2 + 0.55 + k * 1.1
                F(s, 'ex_prop_offchair_exec_01', x, cy - 1.25, 180.0); F(s, 'ex_prop_offchair_exec_01', x, cy + 1.25, 0.0)
            s.surf('ops_map', (r['x0'] + 0.02, cy + 1.6, 0.9), -Y * -1 if False else Y, Z, 3.2, 1.8, step=0, fit=True) if False else None
            F(s, 'prop_tv_flat_01', r['x0'] + 0.15, cy, 270.0, z=1.5); F(s, 'prop_tv_flat_01', r['x1'] - 0.15, cy, 90.0, z=1.5)
        else:
            s.box('marble_black', cx - 0.8, cy - L / 2, 0.72, cx + 0.8, cy + L / 2, 0.78); s.box('wood_dark', cx - 0.35, cy - L / 2 + 0.6, 0, cx + 0.35, cy + L / 2 - 0.6, 0.72)
            s.cbox(cx - 0.8, cy - L / 2, 0, cx + 0.8, cy + L / 2, 0.78, 70)
            for k in range(n):
                y = cy - L / 2 + 0.55 + k * 1.1
                F(s, 'ex_prop_offchair_exec_01', cx - 1.25, y, 90.0); F(s, 'ex_prop_offchair_exec_01', cx + 1.25, y, 270.0)
            F(s, 'prop_tv_flat_01', cx, r['y1'] - 0.15, 180.0, z=1.5)
        s.box('led_white', cx - 2.5, cy - 0.04, CH - 0.5, cx + 2.5, cy + 0.04, CH - 0.46)            # pendant LED bar
        s.box('metal_dark', cx - 2.5, cy - 0.01, CH - 0.46, cx - 2.49, cy + 0.01, CH); s.box('metal_dark', cx + 2.49, cy - 0.01, CH - 0.46, cx + 2.5, cy + 0.01, CH)
    else:
        F(s, 'v_corp_conftable', cx, cy, 0.0 if along_x else 90.0)
        for k in (-1, 1):
            if along_x: F(s, 'prop_off_chair_01', cx - 0.7, cy + k * 1.1, 0.0 if k > 0 else 180.0); F(s, 'prop_off_chair_01', cx + 0.7, cy + k * 1.1, 0.0 if k > 0 else 180.0)
            else: F(s, 'prop_off_chair_01', cx + k * 1.1, cy - 0.7, 90.0 if k < 0 else 270.0); F(s, 'prop_off_chair_01', cx + k * 1.1, cy + 0.7, 90.0 if k < 0 else 270.0)
        F(s, 'prop_tv_flat_02', cx, r['y1'] - 0.12, 180.0, z=1.4)
    F(s, 'apa_mp_h_acc_plant_tall_01', r['x0'] + 0.5, r['y1'] - 0.5, 0.0); F(s, 'apa_mp_h_acc_plant_tall_01', r['x1'] - 0.5, r['y1'] - 0.5, 0.0)
    oak(s, r['x0'] + 0.01, r['y0'] + 0.3, r['x0'] + 0.05, r['y1'] - 0.3, CH, 'X')
    led_lines(s, rm, 1.8); lights(s, rm)


# ------------------------------------------------------------------------------------------------ floor types
def mid_floor(kind):
    s = piece(f'rox_towers_f_{kind}', f'ROX Towers floor {kind}')
    skeleton(s)
    if kind == 'svc':
        S = south_rooms(s, [-8.0, 0.0, 8.0], ['sec_office', 'cctv', 'breakroom', 'lockers'])
        side_rooms(s, 'W', ['storage', 'electrical', 'servers']); side_rooms(s, 'E', ['staff1', 'staff2', 'janitor'])
        skeleton_links(s); south_doors(s, S, {'sec_office': 'sec', 'cctv': 'sec'})
        side_doors(s, 'W', ['storage', 'electrical', 'servers'], ('std', 'sec', 'sec')); side_doors(s, 'E', ['staff1', 'staff2', 'janitor'])
        gallery_windows(s, S, 'S')
        r = s.rooms['sec_office']; open_office(s, 'sec_office', 2, 3, r['x0'] + 2.5, r['y0'] + 2.5, dx=3.4, dy=3.2)
        r = s.rooms['cctv']; s.surf('cctv_wall', (r['x0'] + 7.7, r['y0'] + 0.02, 0.9), -X, Z, 7.4, 2.2, step=0, fit=True)
        for k in range(3): F(s, 'ch_prop_ch_security_monitor_01a', r['x0'] + 1.6 + k * 2.4, r['y0'] + 1.6, 180.0); F(s, 'prop_off_chair_01', r['x0'] + 1.6 + k * 2.4, r['y0'] + 2.5, 0.0)
        led_lines(s, 'cctv', 2.0); lights(s, 'cctv', I=3.0)
        r = s.rooms['breakroom']
        for k in range(2):
            F(s, 'apa_mp_h_din_table_04', r['x0'] + 2.2 + k * 3.4, r['y0'] + 3.0, 0.0)
            for a in range(4): F(s, 'apa_mp_h_din_chair_04', r['x0'] + 2.2 + k * 3.4 + (0.75 if a % 2 else -0.75), r['y0'] + 3.0 + (0.6 if a < 2 else -0.6), 180.0 if a >= 2 else 0.0)
        F(s, 'ex_mp_h_off_sofa_01', r['x0'] + 4.0, r['y1'] - 0.7, 180.0); F(s, 'prop_vend_coffe_01', r['x1'] - 0.5, r['y1'] - 0.5, 180.0); F(s, 'v_ret_ml_fridge', r['x1'] - 1.4, r['y1'] - 0.45, 180.0)
        F(s, 'prop_tv_flat_01', r['x0'] + 4.0, r['y0'] + 0.12, 0.0, z=1.5); led_lines(s, 'breakroom', 2.0); lights(s, 'breakroom')
        r = s.rooms['lockers']
        for k in range(10): F(s, 'p_cs_locker_01_s', r['x0'] + 0.5 + k * 0.7, r['y0'] + 0.35, 0.0); F(s, 'p_cs_locker_01_s', r['x0'] + 0.5 + k * 0.7, r['y1'] - 0.35, 180.0)
        F(s, 'v_ilev_ph_bench', r['x0'] + 4.0, (r['y0'] + r['y1']) / 2, 0.0); led_lines(s, 'lockers', 2.0); lights(s, 'lockers')
        for rm in ('storage', 'janitor'):
            r = s.rooms[rm]
            for k in range(4): F(s, 'prop_box_wood02a', r['x0'] + 0.8 + k * 1.2, r['y1'] - 0.6, 0.0); F(s, 'v_ind_cs_box01', r['x0'] + 0.8 + k * 1.2, r['y0'] + 0.6, 0.0)
            lights(s, rm, I=3.0)
        r = s.rooms['servers']
        for row in range(3):
            for k in range(6): F(s, 'v_corp_servercln', r['x0'] + 1.5 + k * 1.3, r['y0'] + 1.5 + row * 1.8, 0.0 if row % 2 else 180.0)
        s.box('led_white', r['x0'] + 0.5, r['y0'] + 0.5, CH - 0.04, r['x1'] - 0.5, r['y0'] + 0.56, CH); lights(s, 'servers', I=3.0)
        r = s.rooms['electrical']
        for k in range(5): F(s, 'prop_elecbox_01a', r['x0'] + 1.0 + k * 1.6, r['y1'] - 0.3, 180.0)
        lights(s, 'electrical', I=3.0)
        for rm in ('staff1', 'staff2'): office_kit(s, rm, 'W')
        sm = 'sg_staff_only'
    elif kind == 'ops':
        s.room('ops', XA, YA, XB, -4.1, floor='carpet', wall='paint_charcoal', ceil='paint_black', base='metal_dark', H=CH)
        side_rooms(s, 'W', ['dispatch', 'radio', 'briefing_s']); side_rooms(s, 'E', ['ops_chief', 'ops_meet', 'ops_rest'])
        skeleton_links(s)
        door(s, 'ops', 'N', -10.0, to='corr_s', kind='sec', w=1.6, key='ops'); door(s, 'ops', 'N', 10.0, to='corr_s', kind='sec', w=1.6, key='ops')
        side_doors(s, 'W', ['dispatch', 'radio', 'briefing_s'], ('sec', 'std', 'std')); side_doors(s, 'E', ['ops_chief', 'ops_meet', 'ops_rest'])
        r = s.rooms['ops']
        # video wall across the south wall: city map in the middle, CCTV grids on both sides
        s.box('metal_dark', -15.5, YA + 0.02, 0.6, 15.5, YA + 0.2, 3.2, faces='Y'); s.cbox(-15.5, YA, 0, 15.5, YA + 0.2, 3.2, 56)
        s.surf('ops_map', (6.0, YA + 0.21, 0.8), -X, Z, 12.0, 2.3, step=0, fit=True)
        s.surf('cctv_wall', (-6.4, YA + 0.21, 0.8), -X, Z, 8.6, 2.3, step=0, fit=True); s.surf('cctv_wall', (15.0, YA + 0.21, 0.8), -X, Z, 8.6, 2.3, step=0, fit=True)
        # tiered operator rows (3 curved-ish rows, 2nd and 3rd raised)
        for row, (y, z) in enumerate(((-11.0, 0.0), (-8.6, 0.3), (-6.2, 0.6))):
            if z: s.box('marble_black', -15.0, y - 1.3, 0, 15.0, y + 1.1, z, faces='xXyYZ'); s.cbox(-15.0, y - 1.3, 0, 15.0, y + 1.1, z, 81); s.box('led_white', -15.0, y - 1.32, z - 0.05, 15.0, y - 1.3, z - 0.01, faces='y')
            for k in range(8):
                x = -13.1 + k * 3.75; n = f'op{row}{k}'
                F(s, 'h4_prop_office_desk_01', x, y, 180.0, z=z, name=n)
                for m in (-0.45, 0.0, 0.45): F(s, 'hei_prop_hei_monitor_police_01' if m == 0 else 'prop_monitor_01a', x + m, y - 0.1, 180.0, on=n)
                F(s, 'prop_phone_ing', x + 0.6, y + 0.15, 180.0, on=n); F(s, 'ex_prop_offchair_exec_01', x, y + 0.9, 0.0, z=z)
        F(s, 'xm_prop_x17_tv_ceiling_01', 0.0, -9.0, 180.0, z=CH - 0.05)
        s.box('led_white', XA + 0.6, YA + 0.6, CH - 0.04, XB - 0.6, YA + 0.66, CH); led_lines(s, 'ops', 3.0); lights(s, 'ops', I=3.5)
        sign(s, 'sg_operations', -10.0, -3.89, 2.5, 'S', w=1.6); sign(s, 'sg_operations', 10.0, -3.89, 2.5, 'S', w=1.6)
        r = s.rooms['dispatch']; open_office(s, 'dispatch', 1, 3, r['x0'] + 2.2, r['y0'] + 1.6, dx=3.6)
        r = s.rooms['radio']; open_office(s, 'radio', 1, 3, r['x0'] + 2.2, r['y0'] + 1.6, dx=3.6)
        meeting(s, 'briefing_s', big=True); office_kit(s, 'ops_chief', 'W', boss=True); meeting(s, 'ops_meet')
        r = s.rooms['ops_rest']; F(s, 'ex_mp_h_off_sofa_01', r['x0'] + 3.0, r['y1'] - 0.7, 180.0); F(s, 'prop_vend_coffe_01', r['x1'] - 0.5, r['y1'] - 0.5, 180.0); F(s, 'apa_mp_h_tab_coffee_07', r['x0'] + 3.0, r['y1'] - 1.9, 0.0)
        lights(s, 'ops_rest'); led_lines(s, 'ops_rest', 2.0); sm = 'sg_operations'
    elif kind in ('adm', 'cnf', 'inv', 'cmd'):
        if kind == 'adm':
            S = south_rooms(s, [-12.0, -4.0, 4.0, 12.0], ['sup1', 'sup2', 'open_s', 'sup3', 'sup4'])
            side_rooms(s, 'W', ['adm1', 'adm2', 'open_w']); side_rooms(s, 'E', ['adm3', 'adm4', 'records'])
            skeleton_links(s); south_doors(s, S); side_doors(s, 'W', ['adm1', 'adm2', 'open_w']); side_doors(s, 'E', ['adm3', 'adm4', 'records'])
            gallery_windows(s, S, 'S')
            for rm in ('sup1', 'sup2', 'sup3', 'sup4'): office_kit(s, rm, 'N')
            for rm in ('adm1', 'adm2', 'adm3', 'adm4'): office_kit(s, rm, 'E' if rm in ('adm1', 'adm2') else 'W')
            r = s.rooms['open_s']; open_office(s, 'open_s', 3, 2, r['x0'] + 2.3, r['y0'] + 2.4, dx=3.4)
            r = s.rooms['open_w']; open_office(s, 'open_w', 2, 3, r['x0'] + 2.2, r['y0'] + 1.6, dx=3.6, dy=2.8)
            r = s.rooms['records']
            for row in range(3):
                for k in range(6): F(s, 'v_med_cor_filingcab', r['x0'] + 1.0 + k * 1.6, r['y0'] + 1.2 + row * 2.0, 0.0)
            lights(s, 'records'); led_lines(s, 'records', 2.0); sm = 'sg_administration'
        elif kind == 'cnf':
            S = south_rooms(s, [-6.0, 6.0], ['board', 'conf_c', 'conf_e'])
            side_rooms(s, 'W', ['meet1', 'meet2', 'auditorium']); side_rooms(s, 'E', ['meet3', 'meet4', 'catering'])
            skeleton_links(s); south_doors(s, S); side_doors(s, 'W', ['meet1', 'meet2', 'auditorium']); side_doors(s, 'E', ['meet3', 'meet4', 'catering'])
            gallery_windows(s, S, 'S')
            meeting(s, 'board', big=True); meeting(s, 'conf_c', big=True); meeting(s, 'conf_e', big=True)
            for rm in ('meet1', 'meet2', 'meet3', 'meet4'): meeting(s, rm)
            r = s.rooms['auditorium']
            for row in range(4):
                for k in range(7): F(s, 'prop_off_chair_04', r['x0'] + 2.0 + k * 1.3, r['y0'] + 1.6 + row * 1.2, 180.0)
            F(s, 'v_ilev_cd_lampal', (r['x0'] + r['x1']) / 2, r['y1'] - 0.9, 0.0); F(s, 'prop_tv_flat_michael', (r['x0'] + r['x1']) / 2, r['y1'] - 0.12, 180.0, z=1.6)
            s.surf('police_badge', (r['x0'] + 1.0, r['y1'] - 0.02, 1.2), -X * -1 if False else X, Z, 1.6, 1.6, step=0, fit=True) if False else None
            led_lines(s, 'auditorium', 2.0); lights(s, 'auditorium')
            r = s.rooms['catering']; F(s, 'prop_vend_coffe_01', r['x1'] - 0.5, r['y1'] - 0.5, 180.0); F(s, 'v_ret_ml_fridge', r['x1'] - 1.4, r['y1'] - 0.45, 180.0)
            for k in range(3): F(s, 'apa_mp_h_din_table_04', r['x0'] + 2.0 + k * 3.2, r['y0'] + 2.5, 0.0)
            lights(s, 'catering'); led_lines(s, 'catering', 2.0); sm = 'sg_conference'
        elif kind == 'inv':
            S = south_rooms(s, [-12.0, -4.0, 4.0, 12.0], ['interview1', 'interview2', 'detectives', 'interrog1', 'interrog2'], wall='paint_grey')
            side_rooms(s, 'W', ['observe1', 'observe2', 'evidence'], wall='paint_grey'); side_rooms(s, 'E', ['inv_lead', 'lab', 'archive'], wall='paint_grey')
            skeleton_links(s)
            south_doors(s, S, {'interrog1': 'sec', 'interrog2': 'sec'})
            side_doors(s, 'W', ['observe1', 'observe2', 'evidence'], ('std', 'std', 'sec')); side_doors(s, 'E', ['inv_lead', 'lab', 'archive'], ('std', 'std', 'sec'))
            for rm in ('interview1', 'interview2'):
                r = s.rooms[rm]; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
                F(s, 'v_corp_conftable', cx, cy, 0.0); F(s, 'prop_off_chair_01', cx, cy - 1.0, 180.0); F(s, 'prop_off_chair_01', cx - 0.5, cy + 1.0, 0.0); F(s, 'prop_off_chair_01', cx + 0.5, cy + 1.0, 0.0)
                F(s, 'apa_mp_h_acc_plant_tall_01', r['x1'] - 0.5, r['y0'] + 0.5, 0.0); lights(s, rm); led_lines(s, rm, 2.0)
            for rm in ('interrog1', 'interrog2'):
                r = s.rooms[rm]; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
                s.box('black_glass', r['x0'] + 0.01, r['y0'] + 1.5, 1.0, r['x0'] + 0.03, r['y1'] - 1.5, 2.4, faces='X')     # one-way mirror
                s.box('steel', cx - 0.9, cy - 0.5, 0.74, cx + 0.9, cy + 0.5, 0.78); s.box('steel', cx - 0.05, cy - 0.05, 0, cx + 0.05, cy + 0.05, 0.74); s.cbox(cx - 0.9, cy - 0.5, 0, cx + 0.9, cy + 0.5, 0.78, 56)
                F(s, 'prop_off_chair_04', cx, cy - 1.0, 180.0); F(s, 'prop_off_chair_04', cx, cy + 1.0, 0.0); F(s, 'prop_cctv_cam_06a', r['x1'] - 0.3, r['y1'] - 0.3, 135.0, z=3.0)
                s.light(cx, cy, CH - 0.3, color=(255, 240, 220), intensity=7.0, falloff=5.0)
            r = s.rooms['detectives']; open_office(s, 'detectives', 3, 2, r['x0'] + 2.3, r['y0'] + 2.4, dx=3.4)
            for rm in ('observe1', 'observe2'):
                r = s.rooms[rm]; F(s, 'h4_prop_office_desk_01', r['x0'] + 2.0, (r['y0'] + r['y1']) / 2, 270.0, name=rm); F(s, 'ch_prop_ch_security_monitor_01a', r['x0'] + 2.0, (r['y0'] + r['y1']) / 2, 270.0, on=rm)
                F(s, 'prop_off_chair_01', r['x0'] + 3.0, (r['y0'] + r['y1']) / 2, 270.0); lights(s, rm, I=3.0)
            r = s.rooms['evidence']
            s.box('steel', r['x1'] - 3.0, r['y0'] + 0.2, 0, r['x1'] - 2.9, r['y1'] - 1.6, CH, faces='xX'); s.cbox(r['x1'] - 3.0, r['y0'] + 0.2, 0, r['x1'] - 2.9, r['y1'] - 1.6, CH, 56)   # cage
            for row in range(2):
                for k in range(5): F(s, 'prop_box_wood02a' if (k + row) % 2 else 'v_ind_cs_box01', r['x0'] + 1.0 + k * 1.4, r['y0'] + 1.0 + row * 3.0, 0.0)
            F(s, 'h4_prop_office_desk_01', r['x1'] - 1.5, r['y1'] - 1.0, 90.0, name='evd'); F(s, 'prop_monitor_01a', r['x1'] - 1.5, r['y1'] - 1.0, 90.0, on='evd')
            sign(s, 'sg_evidence', r['x1'] + 0.11, 9.5, 2.4, 'E', w=1.2) if False else None
            lights(s, 'evidence', I=3.5)
            office_kit(s, 'inv_lead', 'W', boss=True)
            r = s.rooms['lab']
            for k in range(3): F(s, 'h4_prop_office_desk_01', r['x0'] + 2.0 + k * 3.0, r['y0'] + 1.5, 180.0, name=f'lab{k}'); F(s, 'prop_monitor_01a', r['x0'] + 2.0 + k * 3.0, r['y0'] + 1.5, 180.0, on=f'lab{k}')
            lights(s, 'lab'); led_lines(s, 'lab', 2.0)
            r = s.rooms['archive']
            for row in range(3):
                for k in range(6): F(s, 'v_med_cor_filingcab', r['x0'] + 1.0 + k * 1.6, r['y0'] + 1.2 + row * 2.0, 0.0)
            lights(s, 'archive', I=3.0); sm = 'sg_investigations'
        else:  # cmd
            S = south_rooms(s, [-6.0, 6.0], ['chief', 'cmd_reception', 'deputy'])
            side_rooms(s, 'W', ['cmd_meet', 'aide1', 'war_room']); side_rooms(s, 'E', ['aide2', 'cmd_lounge', 'cmd_archive'])
            skeleton_links(s); south_doors(s, S, {'chief': 'sec', 'deputy': 'sec'})
            side_doors(s, 'W', ['cmd_meet', 'aide1', 'war_room']); side_doors(s, 'E', ['aide2', 'cmd_lounge', 'cmd_archive'], ('std', 'std', 'sec'))
            gallery_windows(s, S, 'S')
            for rm in ('chief', 'deputy'):
                r = s.rooms[rm]; oak(s, r['x0'] + 0.3, r['y1'] - 0.06, r['x1'] - 0.3, r['y1'] - 0.02, CH, 'y'); office_kit(s, rm, 'N', boss=True)
                s.surf('police_badge', ((r['x0'] + r['x1']) / 2 - 0.8, r['y1'] - 0.07, 1.4), X, Z, 1.6, 1.6, step=0, fit=True)
                F(s, 'prop_flag_lsservices', r['x1'] - 0.5, r['y0'] + 0.5, 0.0)
            r = s.rooms['cmd_reception']; cx = (r['x0'] + r['x1']) / 2
            oak(s, cx - 3.0, -9.0, cx + 3.0, -8.4, 1.1, 'xXyYZ'); s.cbox(cx - 3.0, -9.0, 0, cx + 3.0, -8.4, 1.1, 70); s.box('marble_black', cx - 3.1, -9.1, 1.1, cx + 3.1, -8.3, 1.15)
            F(s, 'prop_off_chair_01', cx - 1.0, -10.0, 180.0); F(s, 'prop_monitor_01a', cx - 1.0, -8.7, 0.0, z=1.15)
            for k in range(3): F(s, 'apa_mp_h_stn_chairarm_12', cx - 3.5 + k * 3.5, -5.2, 0.0)
            for x in (cx - 5.0, cx + 5.0): F(s, 'apa_mp_h_acc_plant_tall_01', x, YA + 0.6, 0.0)
            led_lines(s, 'cmd_reception', 2.0); lights(s, 'cmd_reception')
            meeting(s, 'cmd_meet'); office_kit(s, 'aide1', 'E'); office_kit(s, 'aide2', 'W')
            meeting(s, 'war_room', big=True)
            r = s.rooms['war_room']; s.surf('ops_map', (r['x0'] + 0.03, r['y0'] + 1.0, 0.9), Y, Z, 4.4, 2.0, step=0, fit=True)
            r = s.rooms['cmd_lounge']; F(s, 'ex_mp_h_off_sofa_01', r['x0'] + 3.0, r['y1'] - 0.7, 180.0); F(s, 'ex_mp_h_off_easychair_01', r['x0'] + 1.2, r['y1'] - 2.0, 90.0); F(s, 'apa_mp_h_tab_coffee_07', r['x0'] + 3.0, r['y1'] - 2.0, 0.0)
            F(s, 'ba_prop_battle_bar_fridge_01', r['x1'] - 0.5, r['y1'] - 0.5, 180.0); lights(s, 'cmd_lounge'); led_lines(s, 'cmd_lounge', 2.0)
            r = s.rooms['cmd_archive']
            for row in range(2):
                for k in range(6): F(s, 'v_med_cor_filingcab', r['x0'] + 1.0 + k * 1.6, r['y0'] + 1.5 + row * 2.5, 0.0)
            lights(s, 'cmd_archive', I=3.0); sm = 'sg_command'
    s.build_rooms()
    skeleton_dress(s, sm)
    outer(s, FH - 0.3)
    plate(s, T.MID, 'carpet', FH - 0.3)
    # gallery ceiling LED ring + lights along the glass
    for x in (-21.6, 21.6):
        s.box('led_white', x - 0.03, -12.0, FH - 0.34, x + 0.03, 12.0, FH - 0.3)
        for y in (-10.0, 0.0, 10.0): s.light(x, y, FH - 0.6, color=(255, 244, 226), intensity=4.0, falloff=7.0)
    for x in (-12.0, 0.0, 12.0): s.light(x, -16.2, FH - 0.6, color=(255, 244, 226), intensity=4.0, falloff=7.0)
    s.box('led_white', -16.0, -16.6, FH - 0.34, 16.0, -16.54, FH - 0.3)
    s.bb = (-25, -20, -0.1, 25, 20, FH)
    s.meta = dict(kind=kind)
    return s


# ------------------------------------------------------------------------------------------------ twin tower floor
def twin_floor(side):
    pts = T.TL if side == 'L' else T.TR
    ox = -13.0 if side == 'L' else 13.0; oy = 0.0 if side == 'L' else 2.0
    s = piece(f'rox_towers_t{side.lower()}', f'ROX Towers twin floor {side}')
    x0, x1 = ox - 7.0, ox + 7.0; y0, y1 = oy - 11.0, oy + 11.0
    R = dict(ceil='paint_black', base='metal_dark', H=CH)
    s.room('t_hall', ox - 1.4, y0, ox + 1.4, y1, floor='marble_white', wall='paint_white', **R)
    s.room('t_open', x0, y0, ox - 1.6, oy + 3.9, floor='carpet', wall='paint_white', **R)
    s.room('t_meet', x0, oy + 4.1, ox - 1.6, y1, floor='carpet', wall='paint_white', **R)
    s.room('t_off1', ox + 1.6, y0, x1, oy - 3.1, floor='carpet', wall='paint_white', **R)
    s.room('t_off2', ox + 1.6, oy - 2.9, x1, oy + 3.9, floor='carpet', wall='paint_white', **R)
    s.room('t_break', ox + 1.6, oy + 4.1, x1, y1, floor='tile_white', wall='paint_white', **R)
    door(s, 't_open', 'E', oy - 4.0, to='t_hall', kind='glass'); door(s, 't_meet', 'E', oy + 7.0, to='t_hall')
    door(s, 't_off1', 'W', oy - 7.0, to='t_hall'); door(s, 't_off2', 'W', oy + 0.5, to='t_hall'); door(s, 't_break', 'W', oy + 7.0, to='t_hall')
    s.door('t_hall', 'S', ox - 1.0, ox + 1.0, kind='open')
    s.build_rooms()
    r = s.rooms['t_open']; open_office(s, 't_open', 4, 1, r['x0'] + 2.4, r['y0'] + 2.2, dx=3.0, dy=3.2)
    meeting(s, 't_meet'); office_kit(s, 't_off1', 'W'); office_kit(s, 't_off2', 'W', boss=True)
    r = s.rooms['t_break']; F(s, 'apa_mp_h_din_table_04', (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2, 0.0); F(s, 'prop_vend_coffe_01', r['x1'] - 0.5, r['y1'] - 0.5, 180.0)
    lights(s, 't_break'); lights(s, 't_hall', I=4.0); led_lines(s, 't_hall', 1.4, 'y')
    # elevator spot at the hall's south end: elevator doors on a steel panel
    s.box('steel', ox - 0.8, y0 - 0.02, 0, ox + 0.8, y0, 2.5, faces='Y') if False else None
    outer(s, FH - 0.3)
    plate(s, pts, 'carpet', FH - 0.3)
    s.bb = (ox - 10, oy - 16, -0.1, ox + 10, oy + 16, FH)
    s.meta = dict(kind='twin' + side, elevator=(ox, y0 - 1.0))
    return s


# ------------------------------------------------------------------------------------------------ lobby (ground)
def lobby():
    s = piece('rox_towers_lobby', 'ROX Towers lobby')
    s.H = 4.2; R = dict(ceil='paint_black', base='metal_dark', H=4.2)
    # side facilities in the north-west / north-east of the podium
    s.room('l_wc_m', -26.0, 6.0, -20.1, 13.0, floor='tile_white', wall='tile_white', **R)
    s.room('l_wc_w', -19.9, 6.0, -14.0, 13.0, floor='tile_white', wall='tile_white', **R)
    s.room('l_secoff', -26.0, 13.2, -14.0, 19.0, floor='carpet', wall='paint_white', **R)
    s.room('l_interview', 14.0, 6.0, 26.0, 12.4, floor='carpet', wall='paint_white', **R)
    s.room('l_mail', 14.0, 12.6, 26.0, 19.0, floor='carpet', wall='paint_white', **R)
    door(s, 'l_wc_m', 'S', -23.0); door(s, 'l_wc_w', 'S', -17.0)
    door(s, 'l_secoff', 'E', 16.0, kind='sec', key='security')
    door(s, 'l_interview', 'W', 9.0); door(s, 'l_mail', 'W', 16.0)
    s.door('l_wc_m', 'E', 7.0, 7.01, to='l_wc_w') if False else None
    s.build_rooms()
    outer(s, 4.2, top=True, mat='oak_panel')
    for rm in ('l_wc_m', 'l_wc_w', 'l_secoff', 'l_interview', 'l_mail'): lights(s, rm, I=4.0); led_lines(s, rm, 1.8)
    for rm in ('l_wc_m', 'l_wc_w'):
        r = s.rooms[rm]
        for k in range(3):
            x = r['x0'] + 0.3 + k * 1.6; s.box('paint_charcoal', x, r['y1'] - 1.6, 0.15, x + 0.04, r['y1'], 2.2); s.cbox(x, r['y1'] - 1.6, 0, x + 0.04, r['y1'], 2.2, 56)
            F(s, 'prop_toilet_01', x + 0.8, r['y1'] - 0.45, 180.0)
        s.box('marble_black', r['x0'] + 0.2, r['y0'] + 0.05, 0.85, r['x1'] - 0.2, r['y0'] + 0.65, 0.9); s.cbox(r['x0'] + 0.2, r['y0'] + 0.05, 0, r['x1'] - 0.2, r['y0'] + 0.65, 0.9, 81)
        s.box('black_glass', r['x0'] + 0.3, r['y0'] + 0.01, 1.1, r['x1'] - 0.3, r['y0'] + 0.03, 2.4, faces='Y')
        for k in range(2): F(s, 'prop_sink_02', r['x0'] + 1.6 + k * 2.4, r['y0'] + 0.35, 0.0)
    r = s.rooms['l_secoff']; s.surf('cctv_wall', (r['x1'] - 6.5, r['y1'] - 0.02, 0.9), X, Z, 6.0, 2.4, step=0, fit=True)
    for k in range(3): F(s, 'h4_prop_office_desk_01', r['x0'] + 3.0 + k * 3.0, r['y0'] + 3.0, 180.0, name=f'ls{k}'); F(s, 'ch_prop_ch_security_monitor_01a', r['x0'] + 3.0 + k * 3.0, r['y0'] + 3.0, 0.0, on=f'ls{k}'); F(s, 'prop_off_chair_01', r['x0'] + 3.0 + k * 3.0, r['y0'] + 2.1, 180.0)
    r = s.rooms['l_interview']; F(s, 'v_corp_conftable', 20.0, 9.2, 0.0); F(s, 'prop_off_chair_01', 20.0, 8.2, 180.0); F(s, 'prop_off_chair_01', 20.0, 10.2, 0.0)
    r = s.rooms['l_mail']
    for k in range(5): F(s, 'v_med_cor_filingcab', 15.0 + k * 1.6, r['y1'] - 0.4, 180.0)
    F(s, 'h4_prop_office_desk_01', 20.0, 14.5, 0.0)
    # floor: white marble hall with black marble border and inlay path from the door to reception
    s.box('marble_black', -3.0, -24.4, 0.0, 3.0, -6.0, 0.012, faces='Z')
    s.box('marble_black', -14.0, -14.0, 0.0, 14.0, -12.8, 0.012, faces='Z')
    # glass vestibule behind the entrance: steel + glass frames, two openings
    for x in (-4.0, 4.0):
        s.box('metal_dark', x - 0.06, -24.6, 0, x + 0.06, -21.0, 3.6); s.cbox(x - 0.06, -24.6, 0, x + 0.06, -21.0, 3.6, 56)
        s.box('black_glass', x - 0.02, -24.4, 0.1, x + 0.02, -21.2, 3.4, faces='xX')
    s.box('metal_dark', -4.0, -21.06, 3.4, 4.0, -20.94, 3.6); s.box('led_white', -4.0, -21.08, 3.36, 4.0, -21.04, 3.4)
    for x in (-3.7, -2.4, 2.4, 3.7): s.box('metal_dark', x - 0.04, -21.04, 0, x + 0.04, -20.96, 3.4); s.cbox(x - 0.04, -21.04, 0, x + 0.04, -20.96, 3.4, 56)
    s.box('black_glass', -3.7, -21.0, 0.05, -2.4, -20.99, 3.35, faces='yY'); s.box('black_glass', 2.4, -21.0, 0.05, 3.7, -20.99, 3.35, faces='yY')
    s.cbox(-3.7, -21.03, 0, -2.4, -20.97, 3.4, 114); s.cbox(2.4, -21.03, 0, 3.7, -20.97, 3.4, 114)
    DOORS.setdefault('rox_towers_lobby', []).extend([dict(x=-2.4, y=-21.0, h=0.0, w=1.2, kind='glass', key=''), dict(x=0.0, y=-21.0, h=180.0, w=1.2, kind='glass', key=''), dict(x=0.0, y=-21.0, h=0.0, w=1.2, kind='glass', key=''), dict(x=2.4, y=-21.0, h=180.0, w=1.2, kind='glass', key='')])
    s.box('paint_black', -4.0, -24.6, 3.6, 4.0, -21.0, 3.62, faces='z'); s.box('led_white', -3.0, -23.0, 3.56, 3.0, -22.9, 3.6)
    sign(s, 'sg_security_check', 0.0, -20.94, 3.7, 'S', w=2.4)
    # security line at y -13.4: low glass barriers (collision) with 4 detector lanes + staff gates
    lanes = (-6.0, -2.0, 2.0, 6.0); gates = (-10.0, 10.0)
    xs = sorted([a for x in lanes for a in (x - 0.55, x + 0.55)] + [a for x in gates for a in (x - 0.5, x + 0.5)] + [-14.0, 14.0])
    for a, b in zip(xs[0::2], xs[1::2]):
        s.box('steel', a, -13.45, 0, b, -13.35, 1.1); s.cbox(a, -13.45, 0, b, -13.35, 1.1, 56); s.box('led_white', a, -13.47, 1.08, b, -13.33, 1.1)
    for x in lanes:
        F(s, 'ch_prop_ch_metal_detector_01a', x, -13.4, 0.0); F(s, 'ch_prop_baggage_scanner_01a', x + 1.6, -14.6, 90.0) if x in (-6.0, 2.0) else None
    for x in gates: F(s, 'prop_sec_barier_01a', x - 0.5, -13.4, 0.0); F(s, 'ch_prop_fingerprint_scanner_01a', x + 0.6, -13.4, 180.0, z=1.1)
    for x in (-12.0, 12.0):
        s.box('oak_panel', x - 1.2, -12.2, 0, x + 1.2, -11.6, 1.1, faces='xXyYZ'); s.cbox(x - 1.2, -12.2, 0, x + 1.2, -11.6, 1.1, 70); s.box('marble_black', x - 1.25, -12.25, 1.1, x + 1.25, -11.55, 1.14)
        F(s, 'prop_off_chair_01', x, -11.0, 0.0); F(s, 'ch_prop_ch_security_monitor_01a', x, -11.9, 0.0, z=1.14)
    for x in (-14.0, 14.0): F(s, 'prop_cctv_cam_06a', x, -13.4, 180.0, z=4.0)
    # reception: long oak + black marble counter with LED, staff behind, ROX badge wall on the core
    s.box('oak_panel', -6.0, -7.6, 0, 6.0, -6.6, 1.1, faces='xXyYZ', step=1.2); s.cbox(-6.0, -7.6, 0, 6.0, -6.6, 1.1, 70)
    s.box('marble_black', -6.1, -7.7, 1.1, 6.1, -6.5, 1.16); s.box('led_white', -6.0, -7.62, 0.05, 6.0, -7.6, 0.09)
    for x in (-4.0, -1.3, 1.3, 4.0):
        F(s, 'prop_off_chair_01', x, -5.8, 180.0 + 180.0 if False else 0.0); F(s, 'prop_monitor_01a', x, -6.8, 0.0, z=1.16)
    s.box('oak_panel', -7.0, -0.42, 0.0, 7.0, -0.08, 9.0, faces='yxX', step=1.2)
    s.surf('police_badge', (-1.5, -0.43, 3.6), X, Z, 3.0, 3.0, step=0, fit=True); s.surf('sign_police', (-4.0, -0.43, 7.0), X, Z, 8.0, 1.0, step=0, fit=True)
    s.box('led_white', -7.0, -0.44, 8.98, 7.0, -0.42, 9.02, faces='y')
    # elevator hall on the core sides (core x -5..5): 2 elevators each side behind the reception
    for sx in (-1, 1):
        for k, y in enumerate((2.0, 5.5)):
            xw = sx * 5.0
            s.box('steel', xw + sx * 0.0, y - 0.8, 0, xw + sx * 0.02, y + 0.8, 2.6, faces='X' if sx > 0 else 'x')
            s.box('oak_panel', xw, y - 0.95, 2.6, xw + sx * 0.05, y + 0.95, 2.85, faces='X' if sx > 0 else 'x')
        sign(s, 'sg_elevators', xw + sx * 0.06, 3.75, 3.1, 'E' if sx > 0 else 'W', w=1.6)
    # info screens on two pillars + directory
    for x in (-9.0, 9.0):
        s.box('marble_black', x - 0.6, -10.4, 0, x + 0.6, -10.0, 2.6); s.cbox(x - 0.6, -10.4, 0, x + 0.6, -10.0, 2.6, 81)
        s.surf('info_screen', (x - 0.55, -10.41, 0.9), X, Z, 1.1, 1.5, step=0, fit=True)
    # waiting lounges (both sides of the entrance) + plants + benches
    for sx in (-1, 1):
        cx = sx * 15.0
        F(s, 'apa_mp_h_acc_rugwoolm_03', cx, -19.0, 0.0); F(s, 'apa_mp_h_stn_sofacorn_05', cx, -21.5, 0.0 + 180.0 if False else 180.0)
        F(s, 'apa_mp_h_stn_chairarm_12', cx - 2.6, -18.5, 90.0); F(s, 'apa_mp_h_stn_chairarm_12', cx + 2.6, -18.5, 270.0)
        F(s, 'apa_mp_h_tab_coffee_07', cx, -19.0, 0.0); F(s, 'apa_mp_h_floorlamp_c', cx + 3.6, -21.8, 0.0)
        for y in (-8.0, -4.0): F(s, 'v_ilev_ph_bench', sx * 22.0, y, 90.0 * -sx % 360)
        s.box('oak_panel', cx - 5.0, -24.3, 0, cx + 5.0, -24.1, 4.5, faces='Y', step=1.2); s.box('led_white', cx - 5.0, -24.1, 4.5, cx + 5.0, -24.06, 4.56)
    for p in ((-26, -20), (26, -20), (-8, -20), (8, -20), (-26, 2), (26, 2), (-7.5, -1.0), (7.5, -1.0), (-14, -14.5), (14, -14.5)): F(s, 'apa_mp_h_acc_plant_tall_01', p[0], p[1], 0.0)
    F(s, 'prop_flag_us', -6.5, -1.0, 0.0); F(s, 'prop_flag_lsservices', 6.5, -1.0, 0.0)
    sign(s, 'sg_restrooms', -20.0, 5.89, 3.0, 'S', w=1.6); sign(s, 'sg_staff_only', 20.0, 5.89, 3.0, 'S', w=1.6)
    # multi-level ceiling: black drop ceiling band at 4.6 m around the hall with LED cove, open atrium in the middle
    ring = [(-27, -22, 27, -16), (-27, 14, 27, 22), (-27, -16, -20, 14), (20, -16, 27, 14)]
    for a, b, c, d in ring:
        s.box('paint_black', a, b, 4.6, c, d, 4.8, faces='zxXyY')
    for a, b, c, d in ((-20, -16, 20, -15.9), (-20, 13.9, 20, 14), (-20.1, -16, -20, 14), (20, -16, 20.1, 14)):
        s.box('led_white', a, b, 4.56, c, d, 4.6)
    for k in range(9): s.box('led_white', -16 + k * 4, -15.0, 13.2, -16 + k * 4 + 0.08, 13.0, 13.26)            # long LED blades in the atrium
    for x in (-18, -9, 0, 9, 18):
        for y in (-19, -8, 4, 17): s.light(x, y, 4.3 if abs(y) > 15 else 12.0, color=(255, 244, 226), intensity=8.0, falloff=14.0)
    s.bb = (-30, -25, -0.1, 30, 25, 14.3)
    s.meta = dict(kind='lobby')
    return s


# ------------------------------------------------------------------------------------------------ build + export
# mid floor k -> type (k = 0..13, z = 14.6 + k * 3.9)
MID_PLAN = ['svc', 'ops', 'adm', 'cnf', 'inv', 'adm', 'cmd', 'adm', 'cnf', 'adm', 'inv', 'adm', 'svc', 'cmd']
LABELS = {'svc': ('Security & Services', 'الأمن والخدمات'), 'ops': ('Operations Center', 'مركز العمليات'), 'adm': ('Administration', 'الإدارة والمكاتب'),
          'cnf': ('Conference', 'قاعات الاجتماعات'), 'inv': ('Investigations', 'التحقيقات'), 'cmd': ('Command / Chief', 'القيادة ومكتب المدير')}


def all_pieces():
    DOORS.clear(); FURN.clear()
    ps = [lobby()] + [mid_floor(k) for k in ('svc', 'ops', 'adm', 'cnf', 'inv', 'cmd')] + [twin_floor('L'), twin_floor('R')]
    export(ps)
    return ps


def export(ps):
    floors = [dict(model='rox_towers_lobby', z=0.0, label='Lobby', labelAr='اللوبي والاستقبال', ex=0.0, ey=-3.0)]
    for k, kind in enumerate(MID_PLAN):
        floors.append(dict(model=f'rox_towers_f_{kind}', z=round(T.Z0 + k * FH, 3), label=f'{k + 1} - {LABELS[kind][0]}', labelAr=f'{k + 1} - {LABELS[kind][1]}', ex=0.0, ey=-1.6))
    for side, pts, top in (('L', T.TL, T.TL_TOP), ('R', T.TR, T.TR_TOP)):
        nf = int((top - T.TOP_MID - 0.3) / FH)
        ox = -13.0 if side == 'L' else 13.0; oy = 0.0 if side == 'L' else 2.0
        last = nf - 1 if side == 'L' else nf           # the top floor of the tall tower is the sky lounge
        for k in range(last):
            floors.append(dict(model=f'rox_towers_t{side.lower()}', z=round(T.TOP_MID + 0.3 + k * FH, 3), label=f'{"West" if side == "L" else "East"} tower {k + 1}',
                               labelAr=f'البرج {"الغربي" if side == "L" else "الشرقي"} {k + 1}', ex=ox, ey=oy - 9.5))
    floors.append(dict(model=None, z=round(T.FLOORS['skylounge'][0], 3), label='Sky Lounge', labelAr='لاونج السطح', ex=-13.0, ey=-11.0))
    data = dict(floors=floors, doors=DOORS, furniture=FURN)
    out = os.environ.get('ROX_TOWERS_DATA', os.path.join(os.path.dirname(__file__), '..', '..', 'rox_towers', 'data', 'interior.json'))
    os.makedirs(os.path.dirname(out), exist_ok=True); json.dump(data, open(out, 'w'), indent=1, ensure_ascii=False)
