# ROX SWAT TEAM underground headquarters  (c) ROX Store
# Surface: raised plaza with a vehicle hatch (two sliding leaves), 4 pillars + "SWAT TEAM" gantry that rise from the ground,
#          a car lift platform (12 m shaft) and a pedestrian access booth.
# Underground (floor 11 m below street): 20-bay garage, armory, lockers, medical, server room, main corridor,
#          100-seat briefing auditorium, 30-seat meeting hall, cyber / hacking room, 18 command offices (chief + deputy),
#          firing range, kill house, gym.   Furniture = real GTA props spawned by the rox_swat resource.
# Local coordinates: origin = centre of the hatch at street level. HQ model is placed at z = -DEPTH.
import math, json, os
import numpy as np
from kit import Shell, MATS, X, Y, Z

TXD = 'rox_swat_txd'
DEPTH = 11.0                # street level -> underground floor
PLAZA = 1.0                 # plaza top above street
HW, HD = 3.6, 4.6           # half size of the hatch / shaft
DOORS, FURN = [], []


def shell(name, label, H=3.6, lod=250):
    s = Shell(name, label, label, H=H); s.hull = False; s.txd, s.lod = TXD, lod
    return s


def F(model, x, y, h=0.0, z=0.0, **kw):
    d = dict(m=model, x=round(x, 3), y=round(y, 3), h=h)
    if z: d['z'] = z
    d.update(kw); FURN.append(d)


def door(s, room, side, c, to=None, kind='std', w=1.2, h=2.3, casing='metal_dark'):
    c0, c1 = c - w / 2, c + w / 2
    s.door(room, side, c0, c1, to=to, h=h, casing=casing)
    if kind == 'open': return
    r = s.rooms[room]
    if side in 'NS':
        y = r['y1'] if side == 'N' else r['y0']
        if to: y = (y + (s.rooms[to]['y0'] if side == 'N' else s.rooms[to]['y1'])) / 2
        DOORS.append(dict(x=round(c0, 3), y=round(y, 3), h=0.0, w=w, kind=kind))
    else:
        x = r['x1'] if side == 'E' else r['x0']
        if to: x = (x + (s.rooms[to]['x0'] if side == 'E' else s.rooms[to]['x1'])) / 2
        DOORS.append(dict(x=round(x, 3), y=round(c0, 3), h=90.0, w=w, kind=kind))


def inner_walls(s, mat, x0, y0, x1, y1, z0, z1, step=1.5, col=1):
    """4 walls of a vertical box seen from inside (shaft)"""
    s.surf(mat, (x1, y0, z0), -X, Z, x1 - x0, z1 - z0, step=step)
    s.surf(mat, (x0, y1, z0), X, Z, x1 - x0, z1 - z0, step=step)
    s.surf(mat, (x0, y0, z0), Y, Z, y1 - y0, z1 - z0, step=step)
    s.surf(mat, (x1, y1, z0), -Y, Z, y1 - y0, z1 - z0, step=step)
    t = 0.3
    for a in ((x0 - t, y0 - t, x1 + t, y0), (x0 - t, y1, x1 + t, y1 + t), (x0 - t, y0, x0, y1), (x1, y0, x1 + t, y1)):
        s.cbox(a[0], a[1], z0, a[2], a[3], z1, col)


def ceiling_with_hole(s, mat, x0, y0, x1, y1, z, hole):
    hx0, hy0, hx1, hy1 = hole
    s.surf(mat, (x0, y1, z), X, -Y, x1 - x0, y1 - y0, holes=[(hx0 - x0, y1 - hy1, hx1 - x0, y1 - hy0)], step=2.0)
    for a in ((x0, y0, x1, hy0), (x0, hy1, x1, y1), (x0, hy0, hx0, hy1), (hx1, hy0, x1, hy1)):
        s.cbox(a[0], a[1], z, a[2], a[3], z + 0.3, 1)


def glass_wall(s, room, side, to, spans, sill=0.1, head=2.9):
    """replace parts of the wall between `room` and `to` by clear glass in black frames (you see into the room)"""
    o = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}[side]
    r, q = s.rooms[room], s.rooms[to]
    for c0, c1 in spans:
        s._cut(room, side, c0, c1, sill, head, 'window'); s._cut(to, o, c0, c1, sill, head, 'window')
        if side in 'NS':
            ya = r['y1'] if side == 'N' else r['y0']; yb = q['y0'] if side == 'N' else q['y1']
            lo, hi = min(ya, yb), max(ya, yb); m = (lo + hi) / 2
            s.surf('glass_clear', (c0, m, sill), X, Z, c1 - c0, head - sill, step=0, fit=True); s.surf('glass_clear', (c1, m + 0.002, sill), -X, Z, c1 - c0, head - sill, step=0, fit=True)
            for z0, z1 in ((sill - 0.05, sill), (head, head + 0.05)): s.box('metal_dark', c0, lo - 0.1, z0, c1, hi + 0.1, z1)
            n = max(1, round((c1 - c0) / 1.25))
            for k in range(n + 1):
                x = c0 + k * (c1 - c0) / n; s.box('metal_dark', x - 0.03, lo - 0.1, sill, x + 0.03, hi + 0.1, head)
            s.box('metal_dark', c0, lo - 0.1, sill, c0 + 0.001, hi + 0.1, head, faces='X'); s.box('metal_dark', c1 - 0.001, lo - 0.1, sill, c1, hi + 0.1, head, faces='x')
        else:
            xa = r['x1'] if side == 'E' else r['x0']; xb = q['x0'] if side == 'E' else q['x1']
            lo, hi = min(xa, xb), max(xa, xb); m = (lo + hi) / 2
            s.surf('glass_clear', (m, c1, sill), -Y, Z, c1 - c0, head - sill, step=0, fit=True); s.surf('glass_clear', (m + 0.002, c0, sill), Y, Z, c1 - c0, head - sill, step=0, fit=True)
            for z0, z1 in ((sill - 0.05, sill), (head, head + 0.05)): s.box('metal_dark', lo - 0.1, c0, z0, hi + 0.1, c1, z1)
            n = max(1, round((c1 - c0) / 1.25))
            for k in range(n + 1):
                y = c0 + k * (c1 - c0) / n; s.box('metal_dark', lo - 0.1, y - 0.03, sill, hi + 0.1, y + 0.03, head)


def led_lines(s, rm, sp=2.4, along='x'):
    r = s.rooms[rm]; z = r['H']
    if along == 'x':
        y = r['y0'] + sp / 2
        while y < r['y1'] - 0.3: s.box('led_white', r['x0'] + 0.6, y - 0.03, z - 0.04, r['x1'] - 0.6, y + 0.03, z - 0.002); y += sp
    else:
        x = r['x0'] + sp / 2
        while x < r['x1'] - 0.3: s.box('led_white', x - 0.03, r['y0'] + 0.6, z - 0.04, x + 0.03, r['y1'] - 0.6, z - 0.002); x += sp


def lights(s, rm, I=5.0, fo=9.0, col=(255, 246, 232)):
    r = s.rooms[rm]; w, d = r['x1'] - r['x0'], r['y1'] - r['y0']
    nx, ny = max(1, round(w / 7)), max(1, round(d / 7))
    for i in range(nx):
        for j in range(ny):
            s.light(r['x0'] + (i + 0.5) * w / nx, r['y0'] + (j + 0.5) * d / ny, r['H'] - 0.25, color=col, intensity=I, falloff=fo)


def outer(s, zt=None, mat='paint_charcoal'):
    for name, r in s.rooms.items():
        h = zt or r['H']
        for sd in 'NSEW':
            O, U, Nn, L = s.frame(name, sd)
            hl = [(L - q[2], q[1], L - q[0], q[3]) for q in s.holes[(name, sd)]]
            s.surf(mat, O + U * L - Nn * 0.09, -U, Z, L, h, holes=hl, step=2.0)


def office(rm, s, face, boss=False):
    """private command office: desk + 2 screens, exec chair, guest chairs, cabinet, shelf, plant, flag"""
    r = s.rooms[rm]; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
    if face in 'EW':
        sgn = 1 if face == 'E' else -1                       # door on E -> desk near the W wall looking east
        dx = (r['x0'] + 1.8) if face == 'E' else (r['x1'] - 1.8); hd = 270.0 if face == 'E' else 90.0
        F('h4_prop_office_desk_01', dx, cy, hd, name=rm); F('prop_monitor_01a', dx, cy - 0.35, hd, on=rm); F('prop_monitor_01a', dx, cy + 0.35, hd, on=rm)
        F('ex_prop_offchair_exec_01', dx - sgn * 0.9, cy, (hd + 180) % 360); F('ex_prop_offchair_exec_04', dx + sgn * 1.1, cy - 0.5, hd); F('ex_prop_offchair_exec_04', dx + sgn * 1.1, cy + 0.5, hd)
        F('v_med_cor_filingcab', (r['x0'] + 0.35) if face == 'E' else (r['x1'] - 0.35), r['y1'] - 0.45, 180.0)
        F('apa_mp_h_acc_plant_tall_01', (r['x0'] + 0.45) if face == 'E' else (r['x1'] - 0.45), r['y0'] + 0.45, 0.0)
        s.surf('swat_badge', ((r['x0'] + 0.03) if face == 'E' else (r['x1'] - 0.03), cy + (0.6 if face == 'E' else -0.6), 1.5), Y if face == 'E' else -Y, Z, 1.2, 1.2, step=0, fit=True)
    else:
        dy = r['y0'] + 2.2
        F('h4_prop_office_desk_01', cx, dy, 180.0, name=rm); F('prop_monitor_01a', cx - 0.35, dy, 180.0, on=rm); F('prop_monitor_01a', cx + 0.35, dy, 180.0, on=rm)
        F('ex_prop_offchair_exec_01', cx, dy - 0.9, 180.0); F('ex_prop_offchair_exec_04', cx - 0.5, dy + 1.1, 0.0); F('ex_prop_offchair_exec_04', cx + 0.5, dy + 1.1, 0.0)
        F('v_med_cor_filingcab', r['x0'] + 0.4, r['y0'] + 0.4, 0.0); F('apa_mp_h_acc_plant_tall_01', r['x1'] - 0.5, r['y0'] + 0.5, 0.0)
        s.surf('swat_badge', (cx + 1.0, r['y0'] + 0.03, 1.4), -X, Z, 2.0, 2.0, step=0, fit=True)
    if boss:
        F('ex_mp_h_off_sofa_01', cx, r['y1'] - 0.8, 180.0); F('apa_mp_h_tab_coffee_07', cx, r['y1'] - 2.0, 0.0)
        F('prop_flag_us', r['x0'] + 0.6, r['y0'] + 0.6, 0.0); F('prop_flag_lsservices', r['x1'] - 0.6, r['y0'] + 0.6, 0.0)
    led_lines(s, rm, 1.8); lights(s, rm, I=4.0, fo=7.0)


# ------------------------------------------------------------------------------------------------ underground HQ
def hq():
    s = shell('rox_swat_hq', 'ROX SWAT HQ', lod=220)
    D = dict(base='metal_dark')
    s.room('garage', -26.0, -5.8, 26.0, 22.0, floor='concrete_floor', wall='concrete_wall', ceil=None, H=5.0, **D)
    s.room('corr', -40.0, -10.0, 41.8, -6.2, floor='marble_black', wall='paint_charcoal', ceil='paint_black', H=3.4, **D)
    s.room('armory', 26.2, -5.8, 41.8, 8.0, floor='concrete_floor', wall='paint_charcoal', ceil='paint_black', H=3.6, **D)
    s.room('lockers', 26.2, 8.2, 41.8, 22.0, floor='tile_white', wall='paint_grey', ceil='paint_black', H=3.6, **D)
    s.room('medical', -40.0, -5.8, -26.2, 8.0, floor='tile_white', wall='paint_white', ceil='paint_white', H=3.6, **D)
    s.room('servers', -40.0, 8.2, -26.2, 22.0, floor='concrete_floor', wall='paint_charcoal', ceil='paint_black', H=3.6, **D)
    s.room('auditorium', -40.0, -38.0, -12.2, -10.2, floor='carpet', wall='paint_charcoal', ceil='paint_black', H=5.0, **D)
    s.room('meeting', -12.0, -24.0, 8.0, -10.2, floor='carpet', wall='paint_charcoal', ceil='paint_black', H=3.6, **D)
    s.room('cyber', 8.2, -24.0, 17.8, -10.2, floor='marble_black', wall='paint_black', ceil='paint_black', H=3.6, **D)
    s.room('link', 18.0, -24.0, 21.8, -10.2, floor='marble_black', wall='paint_charcoal', ceil='paint_black', H=3.4, **D)
    s.room('corr2', -12.0, -28.0, 21.8, -24.2, floor='marble_black', wall='paint_charcoal', ceil='paint_black', H=3.4, **D)
    s.room('corr_off', 30.0, -50.0, 33.8, -10.2, floor='marble_black', wall='paint_charcoal', ceil='paint_black', H=3.4, **D)
    n, y0, y1 = 8, -50.0, -10.2; hgt = (y1 - y0 - (n - 1) * 0.2) / n
    offs = []
    for i in range(n):
        a = y0 + i * (hgt + 0.2); b = a + hgt
        s.room(f'off_w{i}', 22.2, a, 29.8, b, floor='carpet', wall='paint_white', ceil='paint_black', H=3.4, **D); offs.append((f'off_w{i}', 'E', (a + b) / 2))
        s.room(f'off_e{i}', 34.0, a, 41.8, b, floor='carpet', wall='paint_white', ceil='paint_black', H=3.4, **D); offs.append((f'off_e{i}', 'W', (a + b) / 2))
    s.room('chief', 22.2, -56.0, 31.9, -50.2, floor='parquet', wall='paint_white', ceil='paint_black', H=3.4, **D)
    s.room('deputy', 32.1, -56.0, 41.8, -50.2, floor='parquet', wall='paint_white', ceil='paint_black', H=3.4, **D)
    s.room('range', -12.0, -46.0, 21.8, -28.2, floor='concrete_floor', wall='concrete_wall', ceil='paint_black', H=4.0, **D)
    s.room('killhouse', -40.0, -60.0, -12.2, -38.2, floor='concrete_floor', wall='concrete_wall', ceil='paint_black', H=4.0, **D)
    s.room('gym', -12.0, -60.0, 21.8, -46.2, floor='carpet', wall='paint_charcoal', ceil='paint_black', H=4.0, **D)

    # connections
    door(s, 'garage', 'S', -15.0, to='corr', kind='glass', w=2.4, h=2.6); door(s, 'garage', 'S', 15.0, to='corr', kind='glass', w=2.4, h=2.6)
    door(s, 'garage', 'E', 2.0, to='armory', kind='sec', w=1.4); door(s, 'garage', 'E', 15.0, to='lockers')
    door(s, 'garage', 'W', 15.0, to='servers', kind='sec'); door(s, 'medical', 'S', -33.0, to='corr')
    door(s, 'auditorium', 'N', -32.0, to='corr', kind='glass', w=2.4, h=2.6); door(s, 'auditorium', 'N', -18.0, to='corr', kind='glass', w=2.4, h=2.6)
    door(s, 'meeting', 'N', -2.0, to='corr', kind='glass', w=2.4, h=2.6)
    door(s, 'cyber', 'N', 13.0, to='corr', kind='sec', w=1.4)
    s.door('link', 'N', 18.0, 21.8, to='corr', kind='open'); s.door('link', 'S', 18.0, 21.8, to='corr2', kind='open')
    s.door('corr_off', 'N', 30.0, 33.8, to='corr', kind='open')
    for rm, sd, c in offs: door(s, rm, sd, c, to='corr_off')
    door(s, 'corr_off', 'S', 30.9, to='chief', kind='sec'); door(s, 'corr_off', 'S', 32.9, to='deputy', kind='sec')
    door(s, 'corr2', 'S', 0.0, to='range', w=2.4, h=2.6); door(s, 'corr2', 'S', 15.0, to='range')
    door(s, 'range', 'W', -42.0, to='killhouse', w=1.6); door(s, 'range', 'S', 5.0, to='gym', w=2.4, h=2.6)
    door(s, 'meeting', 'S', -6.0, to='corr2')
    # glass fronts: you see into the halls and offices from the corridors (each section stays a closed room)
    glass_wall(s, 'meeting', 'N', 'corr', [(-11.4, -3.5), (-0.5, 7.4)])
    glass_wall(s, 'cyber', 'N', 'corr', [(8.6, 12.0), (14.0, 17.4)])
    glass_wall(s, 'auditorium', 'N', 'corr', [(-39.4, -33.5), (-30.5, -19.5), (-16.5, -12.8)])
    glass_wall(s, 'medical', 'S', 'corr', [(-39.4, -34.0), (-32.0, -26.8)])
    glass_wall(s, 'armory', 'W', 'garage', [(-5.3, 1.1), (2.9, 7.5)], sill=0.9)
    glass_wall(s, 'servers', 'E', 'garage', [(8.7, 14.2), (15.8, 21.5)], sill=0.9)
    glass_wall(s, 'range', 'N', 'corr2', [(-11.5, -1.5), (1.5, 14.2), (15.8, 21.4)], sill=1.0)
    glass_wall(s, 'gym', 'N', 'range', [(-11.5, 3.6), (6.4, 21.4)], sill=0.9)
    for rm, sd, c in offs:
        r = s.rooms[rm]; glass_wall(s, rm, sd, 'corr_off', [(r['y0'] + 0.3, c - 0.8), (c + 0.8, r['y1'] - 0.3)], sill=0.1, head=2.8)
    s.build_rooms()
    outer(s)

    # garage: ceiling with the lift shaft, shaft up to the plaza, 20 bays, pillars, signage
    ceiling_with_hole(s, 'concrete_wall', -26.0, -5.8, 26.0, 22.0, 5.0, (-HW, -HD, HW, HD))
    inner_walls(s, 'concrete_wall', -HW, -HD, HW, HD, 5.0, DEPTH + PLAZA)
    for z in (5.4, 8.0, 10.6):
        s.box('hazard', -HW + 0.01, -HD, z, -HW + 0.03, HD, z + 0.3, faces='X'); s.box('hazard', HW - 0.03, -HD, z, HW - 0.01, HD, z + 0.3, faces='x')
    for x in (-HW + 0.05, HW - 0.1):
        for y in (-HD + 0.05, HD - 0.1): s.box('led_white', x, y, 5.0, x + 0.05, y + 0.05, DEPTH + PLAZA)
    s.box('hazard', -HW - 0.4, -HD - 0.4, 0.0, HW + 0.4, -HD, 0.012, faces='Z'); s.box('hazard', -HW - 0.4, HD, 0.0, HW + 0.4, HD + 0.4, 0.012, faces='Z')
    s.box('hazard', -HW - 0.4, -HD, 0.0, -HW, HD, 0.012, faces='Z'); s.box('hazard', HW, -HD, 0.0, HW + 0.4, HD, 0.012, faces='Z')
    bays = []
    for i in range(10):
        x = -24.5 + i * 5.0 + 2.5
        bays.append((x, 19.2, 180.0)); bays.append((x, 9.6, 0.0))
    for k, (x, y, h) in enumerate(bays):
        for dx in (-2.5, 2.5):
            s.box('paint_yellow', x + dx - 0.06, y - 2.6, 0.0, x + dx + 0.06, y + 2.6, 0.012, faces='Z')
        s.box('paint_white', x - 0.6, (y + 2.2) if h == 0 else (y - 2.4), 0.0, x + 0.6, (y + 2.4) if h == 0 else (y - 2.2), 0.012, faces='Z')
    for x in (-24.5 + 5 * i for i in range(11)):
        for y in (14.4,):
            s.box('concrete_wall', x - 0.35, y - 0.35, 0, x + 0.35, y + 0.35, 5.0, faces='xXyY'); s.cbox(x - 0.35, y - 0.35, 0, x + 0.35, y + 0.35, 5.0, 1)
            s.box('hazard', x - 0.36, y - 0.36, 0, x + 0.36, y + 0.36, 1.0, faces='xXyY')
    for y in (4.0, 14.4):
        s.box('led_white', -25.0, y - 0.04, 4.94, 25.0, y + 0.04, 5.0)
    for x in range(-22, 24, 7):
        for y in (0.5, 9.0, 19.0): s.light(x, y, 4.6, color=(240, 246, 255), intensity=6.0, falloff=11.0)
    s.surf('sign_swat', (-6.0, 21.98, 3.0), X, Z, 12.0, 2.0, step=0, fit=True)
    s.surf('sg_garage', (-14.0 - 1.5, -5.78, 2.9), X, Z, 3.0, 0.5, step=0, fit=True); s.surf('sg_garage', (15.0 - 1.5, -5.78, 2.9), X, Z, 3.0, 0.5, step=0, fit=True)
    s.surf('swat_badge', (-22.4, 21.98, 1.2), X, Z, 2.4, 2.4, step=0, fit=True)
    F('prop_toolchest_05', -25.4, 2.0, 270.0); F('prop_toolchest_05', -25.4, 4.0, 270.0); F('imp_prop_tool_chest_01a', 25.4, 9.0, 90.0)
    for x in (-8.0, 8.0): F('prop_cctv_cam_06a', x, -5.6, 0.0, z=4.4)

    # main corridor: oak wainscot, LED, badge wall at both ends
    r = s.rooms['corr']
    s.box('oak_panel', r['x0'] + 0.5, r['y0'] + 0.01, 0, r['x1'] - 0.5, r['y0'] + 0.05, 1.1, faces='Y', step=1.2)
    led_lines(s, 'corr', 1.3); lights(s, 'corr', I=4.0, fo=8.0)
    s.surf('swat_badge', (r['x0'] + 0.02, -9.4, 0.6), Y, Z, 2.6, 2.6, step=0, fit=True)
    for x in (-36.0, -22.0, -6.0, 10.0, 26.0, 38.0): F('apa_mp_h_acc_plant_tall_01', x, -9.5, 0.0)
    F('prop_vend_coffe_01', 4.0, -6.6, 180.0); F('prop_vend_soda_01', 5.2, -6.6, 180.0); F('prop_watercooler', 6.3, -6.6, 180.0)
    for rm in ('link', 'corr2', 'corr_off'): led_lines(s, rm, 1.3, 'y' if rm != 'corr2' else 'x'); lights(s, rm, I=4.0, fo=8.0)

    # armory: weapon lockers, benches, ammo
    r = s.rooms['armory']
    for k in range(8): F('gr_prop_gr_gunlocker_01a' if k % 2 else 'bkr_prop_gunlocker_01a', r['x0'] + 1.2 + k * 1.8, r['y1'] - 0.45, 180.0)
    for k in range(3): F('gr_prop_gr_bench_04a', r['x0'] + 3.0 + k * 4.5, (r['y0'] + r['y1']) / 2, 0.0); F('prop_box_ammo04a', r['x0'] + 3.0 + k * 4.5, (r['y0'] + r['y1']) / 2, 0.0, z=0.95)
    for k in range(4): F('prop_gun_case_01', r['x0'] + 2.0 + k * 3.5, r['y0'] + 0.5, 0.0)
    s.box('hazard', r['x0'] + 0.5, r['y0'] + 1.6, 0.0, r['x1'] - 0.5, r['y0'] + 1.7, 0.012, faces='Z')
    led_lines(s, 'armory', 1.8); lights(s, 'armory')
    # lockers
    r = s.rooms['lockers']
    for k in range(18): F('p_cs_locker_01_s', r['x0'] + 0.6 + k * 0.8, r['y1'] - 0.35, 180.0); F('p_cs_locker_01_s', r['x0'] + 0.6 + k * 0.8, r['y0'] + 0.35, 0.0)
    for k in range(3): F('v_ilev_ph_bench', r['x0'] + 3.0 + k * 4.5, (r['y0'] + r['y1']) / 2, 0.0)
    led_lines(s, 'lockers', 1.8); lights(s, 'lockers')
    # medical
    r = s.rooms['medical']
    for k in range(4): F('v_med_bed1', r['x0'] + 1.8 + k * 3.2, r['y1'] - 1.4, 180.0); F('v_med_trolley', r['x0'] + 3.2 + k * 3.2, r['y1'] - 0.6, 180.0)
    F('h4_prop_office_desk_01', r['x1'] - 2.0, r['y0'] + 2.0, 180.0, name='med'); F('prop_monitor_01a', r['x1'] - 2.0, r['y0'] + 2.0, 180.0, on='med'); F('ex_prop_offchair_exec_04', r['x1'] - 2.0, r['y0'] + 1.1, 180.0)
    led_lines(s, 'medical', 1.8); lights(s, 'medical', I=6.0)
    # server room
    r = s.rooms['servers']
    for row in range(4):
        for k in range(8): F('xm_base_cia_server_01' if (row + k) % 3 else 'v_corp_servercln', r['x0'] + 1.6 + k * 1.4, r['y0'] + 2.0 + row * 3.0, 0.0 if row % 2 else 180.0)
    s.box('led_white', r['x0'] + 0.5, r['y0'] + 0.5, 3.56, r['x1'] - 0.5, r['y0'] + 0.56, 3.6); lights(s, 'servers', I=3.0, col=(160, 200, 255))

    # auditorium: 100 seats (10 x 10), stage, lectern, big screen + badge, LED steps
    r = s.rooms['auditorium']; cx = (r['x0'] + r['x1']) / 2
    s.box('wood_dark', r['x0'] + 2.0, r['y0'] + 0.0, 0, r['x1'] - 2.0, r['y0'] + 4.0, 0.6, faces='xXyYZ', step=1.2); s.cbox(r['x0'] + 2.0, r['y0'], 0, r['x1'] - 2.0, r['y0'] + 4.0, 0.6, 70)
    s.box('led_white', r['x0'] + 2.0, r['y0'] + 4.0, 0.5, r['x1'] - 2.0, r['y0'] + 4.03, 0.56, faces='Y')
    s.surf('ops_map', (cx + 7.0, r['y0'] + 0.03, 1.4), -X, Z, 14.0, 3.2, step=0, fit=True)
    s.surf('swat_badge', (r['x0'] + 5.2, r['y0'] + 0.03, 1.6), -X, Z, 2.8, 2.8, step=0, fit=True)
    s.surf('swat_badge', (r['x1'] - 2.4, r['y0'] + 0.03, 1.6), -X, Z, 2.8, 2.8, step=0, fit=True)
    F('v_ilev_cd_lampal', cx + 4.0, r['y0'] + 2.6, 180.0, z=0.6); F('prop_flag_us', cx - 5.0, r['y0'] + 1.0, 180.0, z=0.6); F('prop_flag_lsservices', cx + 6.0, r['y0'] + 1.0, 180.0, z=0.6)
    for row in range(10):
        for k in range(10):
            x = cx - 6.6 + k * 1.2 + (0.6 if k >= 5 else 0.0) - 0.3
            F('prop_off_chair_04', x, r['y0'] + 6.6 + row * 1.9 * 0.0 + row * 1.15, 180.0)
    for row in range(10): s.box('led_white', cx - 7.2, r['y0'] + 6.0 + row * 1.15, 0.0, cx - 7.1, r['y0'] + 6.3 + row * 1.15, 0.05)
    led_lines(s, 'auditorium', 2.4); lights(s, 'auditorium', I=5.0, fo=10.0)
    for x in (r['x0'] + 0.8, r['x1'] - 0.8):
        for y in (r['y0'] + 8.0, r['y1'] - 3.0): F('apa_mp_h_acc_plant_tall_01', x, y, 0.0)

    # meeting hall: one 15 m table for 30 (15 per side), screens at both ends, oak wall
    r = s.rooms['meeting']; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
    L = 16.5
    s.box('marble_black', cx - L / 2, cy - 0.9, 0.72, cx + L / 2, cy + 0.9, 0.78); s.box('wood_dark', cx - L / 2 + 0.6, cy - 0.4, 0, cx + L / 2 - 0.6, cy + 0.4, 0.72)
    s.cbox(cx - L / 2, cy - 0.9, 0, cx + L / 2, cy + 0.9, 0.78, 70); s.box('led_white', cx - L / 2 + 0.6, cy - 0.41, 0.05, cx + L / 2 - 0.6, cy - 0.4, 0.1)
    for k in range(15):
        x = cx - L / 2 + 0.55 + k * 1.1
        F('ex_prop_offchair_exec_01', x, cy - 1.35, 180.0); F('ex_prop_offchair_exec_01', x, cy + 1.35, 0.0)
        if k % 3 == 1: F('prop_cs_tablet', x, cy - 0.5, 0.0, z=0.78); F('prop_cs_tablet', x, cy + 0.5, 180.0, z=0.78)
    F('prop_tv_flat_michael', r['x0'] + 0.15, cy, 270.0, z=1.6); F('prop_tv_flat_michael', r['x1'] - 0.15, cy, 90.0, z=1.6)
    s.box('oak_panel', r['x0'] + 2.0, r['y1'] - 0.06, 0, r['x1'] - 2.0, r['y1'] - 0.02, 3.6, faces='y', step=1.2)
    s.surf('swat_badge', (cx - 1.2, r['y1'] - 0.07, 1.3), X, Z, 2.4, 2.4, step=0, fit=True)
    for k in range(3): s.box('led_white', cx - 6.0 + k * 6.0 - 1.8, cy - 0.04, 3.1, cx - 6.0 + k * 6.0 + 1.8, cy + 0.04, 3.14)
    led_lines(s, 'meeting', 2.2); lights(s, 'meeting')

    # cyber / hacking room: hacker console in the middle (chair + device), operator desks, screen wall, servers
    r = s.rooms['cyber']; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
    s.surf('cctv_wall', (r['x0'] + 9.1, r['y0'] + 0.03, 0.9), -X, Z, 8.6, 2.3, step=0, fit=True)
    s.box('marble_black', cx - 1.6, cy - 1.0, 0.0, cx + 1.6, cy + 0.2, 0.78, faces='xXyYZ'); s.cbox(cx - 1.6, cy - 1.0, 0, cx + 1.6, cy + 0.2, 0.78, 81)
    s.box('led_white', cx - 1.6, cy - 1.02, 0.05, cx + 1.6, cy - 1.0, 0.09, faces='y')
    F('ba_prop_battle_hacker_screen', cx, cy - 0.6, 180.0, z=0.78); F('xm_prop_x17_laptop_mrsr', cx - 0.9, cy - 0.3, 180.0, z=0.78); F('hei_prop_hst_laptop', cx + 0.9, cy - 0.3, 180.0, z=0.78)
    F('xm_prop_x17_computer_01', cx - 0.4, cy - 0.15, 180.0, z=0.78); F('ex_prop_offchair_exec_01', cx, cy + 0.9, 0.0)
    for k in range(3):
        F('h4_prop_office_desk_01', r['x0'] + 1.6 + k * 3.2, r['y1'] - 1.6, 0.0, name=f'cy{k}')
        for m in (-0.45, 0.0, 0.45): F('prop_monitor_01a', r['x0'] + 1.6 + k * 3.2 + m, r['y1'] - 1.5, 0.0, on=f'cy{k}')
        F('ex_prop_offchair_exec_04', r['x0'] + 1.6 + k * 3.2, r['y1'] - 2.5, 180.0)
    for k in range(3): F('xm_base_cia_server_01', r['x1'] - 0.6, r['y0'] + 3.0 + k * 1.2, 90.0)
    s.box('led_white', r['x0'] + 0.3, r['y0'] + 0.3, 3.55, r['x1'] - 0.3, r['y0'] + 0.36, 3.6); lights(s, 'cyber', I=3.0, col=(150, 190, 255))

    # 18 command offices (8 + 8 + chief + deputy)
    for rm, sd, c in offs: office(rm, s, 'E' if sd == 'E' else 'W')
    office('chief', s, 'N', boss=True); office('deputy', s, 'N', boss=True)

    # firing range: 8 lanes along X (shoot to the east), booths, targets, backstop
    r = s.rooms['range']; cy0 = r['y0'] + 1.2
    s.box('wood_dark', r['x0'] + 3.0, r['y0'] + 0.5, 0.0, r['x0'] + 3.6, r['y1'] - 4.0, 1.1, faces='xXyYZ'); s.cbox(r['x0'] + 3.0, r['y0'] + 0.5, 0, r['x0'] + 3.6, r['y1'] - 4.0, 1.1, 70)
    for k in range(9):
        y = r['y0'] + 0.5 + k * ((r['y1'] - 4.0 - r['y0'] - 0.5) / 8)
        s.box('metal_dark', r['x0'] + 3.6, y - 0.03, 0.0, r['x0'] + 5.0, y + 0.03, 2.2); s.cbox(r['x0'] + 3.6, y - 0.03, 0, r['x0'] + 5.0, y + 0.03, 2.2, 56)
    for k in range(8):
        y = r['y0'] + 0.5 + (k + 0.5) * ((r['y1'] - 4.0 - r['y0'] - 0.5) / 8)
        F('gr_prop_gr_target_05a', r['x1'] - 4.0 - (k % 3) * 4.0, y, 90.0); s.box('led_white', r['x0'] + 3.0, y - 0.3, 2.6, r['x0'] + 30.0, y - 0.28, 2.64)
    s.box('concrete_wall', r['x1'] - 1.2, r['y0'] + 0.2, 0, r['x1'] - 0.2, r['y1'] - 4.0, 4.0, faces='x'); s.box('hazard', r['x0'] + 3.0, r['y1'] - 4.0, 0.0, r['x1'] - 1.2, r['y1'] - 3.85, 0.012, faces='Z')
    s.surf('sg_range', (r['x0'] + 0.03, r['y1'] - 3.2, 2.6), Y, Z, 2.4, 0.4, step=0, fit=True)
    for k in range(4): F('prop_gun_case_01', r['x0'] + 2.0, r['y1'] - 1.0 - k * 0.1 - k * 0.0, 0.0) if k == 0 else F('gr_prop_gr_bench_04a', r['x0'] + 6.0 + k * 5.0, r['y1'] - 1.8, 0.0)
    lights(s, 'range', I=5.0, fo=10.0); led_lines(s, 'range', 3.0, 'y')
    # kill house: plywood maze rooms with openings
    r = s.rooms['killhouse']
    walls = [(-36.0, -60.0, -36.0, -50.0), (-30.0, -54.0, -30.0, -42.0), (-24.0, -60.0, -24.0, -48.0), (-18.0, -52.0, -18.0, -40.0),
             (-40.0, -46.0, -33.0, -46.0), (-30.0, -50.0, -20.0, -50.0), (-24.0, -44.0, -14.0, -44.0)]
    for x0, y0, x1, y1 in walls:
        a, b = (min(x0, x1) - 0.06, min(y0, y1)) if x0 == x1 else (min(x0, x1), y0 - 0.06)
        c, d = (max(x0, x1) + 0.06, max(y0, y1)) if x0 == x1 else (max(x0, x1), y0 + 0.06)
        s.box('planks', a, b, 0, c, d, 2.6, faces='xXyYZ', step=1.2); s.cbox(a, b, 0, c, d, 2.6, 72)
    for x, y in ((-33, -56), (-27, -46), (-21, -55), (-15, -48), (-34, -42)): F('gr_prop_gr_target_1_01a', x, y, 0.0)
    lights(s, 'killhouse', I=4.0); led_lines(s, 'killhouse', 3.0)
    # gym
    r = s.rooms['gym']
    for k in range(4): F('prop_weight_bench_02', r['x0'] + 3.0 + k * 3.0, r['y0'] + 3.0, 0.0)
    for k in range(3): F('prop_weight_squat', r['x0'] + 3.0 + k * 4.0, r['y0'] + 7.5, 0.0); F('prop_muscle_bench_03', r['x0'] + 16.0 + k * 3.0, r['y0'] + 3.0, 0.0)
    for k in range(4): F('prop_beach_punchbag', r['x1'] - 3.0 - k * 2.5, r['y1'] - 2.0, 0.0)
    for k in range(5): F('apa_p_apdlc_treadmill_s', r['x0'] + 16.0 + k * 2.4, r['y0'] + 8.0, 180.0)
    s.box('black_glass', r['x0'] + 0.01, r['y0'] + 1.0, 0.4, r['x0'] + 0.03, r['y1'] - 1.0, 3.0, faces='X')
    s.surf('swat_badge', (r['x1'] - 0.03, -51.5, 1.2), -Y, Z, 2.4, 2.4, step=0, fit=True)
    led_lines(s, 'gym', 2.4); lights(s, 'gym')
    s.bb = (-42, -62, -0.3, 44, 24, DEPTH + PLAZA)
    return s


# ------------------------------------------------------------------------------------------------ surface + moving parts
PILLARS = [(-HW - 1.6, -HD - 1.6), (HW + 1.6, -HD - 1.6), (-HW - 1.6, HD + 1.6), (HW + 1.6, HD + 1.6)]
PH = 7.0                       # pillar height


def plaza():
    s = shell('rox_swat_plaza', 'ROX SWAT plaza', lod=400)
    PX, PY, RL = 10.0, 12.0, 7.0      # half size of the plaza, ramp length
    z = PLAZA
    holes = [(PX - HW, PY - HD, PX + HW, PY + HD)] + [(PX + x - 0.42, PY - y - 0.42, PX + x + 0.42, PY - y + 0.42) for x, y in PILLARS]
    s.surf('concrete_floor', (-PX, PY, z), X, -Y, 2 * PX, 2 * PY, holes=holes, step=2.0)
    for a in ((-PX, -PY, -HW, PY), (HW, -PY, PX, PY), (-HW, -PY, HW, -HD), (-HW, HD, HW, PY)): s.cbox(a[0], a[1], -1.0, a[2], a[3], z, 1)
    # side walls of the plaza (down into the ground a bit)
    s.box('concrete_wall', -PX, -PY, -0.6, PX, PY, z, faces='xX')
    for x0, x1 in ((-PX, -4.5), (4.5, PX)):
        s.box('concrete_wall', x0, -PY, -0.6, x1, -PY + 0.01, z, faces='y'); s.box('concrete_wall', x0, PY - 0.01, -0.6, x1, PY, z, faces='Y')
    # ramps front / back (4.5 m wide driving lane each side of the hatch axis)
    for sgn in (-1, 1):
        y0 = sgn * PY; y1 = sgn * (PY + RL)
        P = [(-4.5, y0, z), (4.5, y0, z), (4.5, y1, 0.0), (-4.5, y1, 0.0)]
        if sgn < 0: P = [P[1], P[0], P[3], P[2]]
        Pn = np.array(P, float); n = np.cross(Pn[1] - Pn[0], Pn[3] - Pn[0]); n /= np.linalg.norm(n)
        if n[2] < 0: P = P[::-1]; Pn = np.array(P, float); n = -n
        s._add('concrete_floor', '', Pn, np.tile(n, (4, 1)), [(p[0] / 3, p[1] / 3) for p in P], np.tile((1, 0, 0, 1), (4, 1)), [0, 1, 2, 0, 2, 3])
        s.ctris.append((Pn[0], Pn[1], Pn[2], 1)); s.ctris.append((Pn[0], Pn[2], Pn[3], 1))
        for x in (-4.5, 4.5):
            s.box('hazard', x - 0.15, min(y0, y1), 0.0, x + 0.15, max(y0, y1), 0.15)
    # hazard frame around the hatch, LED strip, SWAT badge painted next to it
    for a in ((-HW - 0.6, -HD - 0.6, HW + 0.6, -HD), (-HW - 0.6, HD, HW + 0.6, HD + 0.6), (-HW - 0.6, -HD, -HW, HD), (HW, -HD, HW + 0.6, HD)):
        s.box('hazard', a[0], a[1], z, a[2], a[3], z + 0.012, faces='Z')
    for a in ((-HW - 0.62, -HD - 0.66, HW + 0.62, -HD - 0.6), (-HW - 0.62, HD + 0.6, HW + 0.62, HD + 0.66)):
        s.box('led_white', a[0], a[1], z, a[2], a[3], z + 0.02, faces='Z')
    s.surf('swat_badge', (6.0, -9.0, z + 0.013), X, Y, 3.0, 3.0, step=0, fit=True)
    # leaf pockets: the two hatch leaves slide under the plaza top (dark slots)
    s.box('paint_black', -HW - 3.7, -HD, z - 0.45, -HW, HD, z - 0.44, faces='Z'); s.box('paint_black', HW, -HD, z - 0.45, HW + 3.7, HD, z - 0.44, faces='Z')
    # pedestrian access booth (stairs down): glass + steel kiosk at the corner
    bx, by = 7.5, 9.0
    s.box('metal_dark', bx - 1.3, by - 1.0, z, bx + 1.3, by + 1.0, z + 2.6, faces='xXyY'); s.box('metal_dark', bx - 1.5, by - 1.2, z + 2.6, bx + 1.5, by + 1.2, z + 2.8)
    s.box('black_glass', bx - 1.0, by - 1.01, z + 0.1, bx + 1.0, by - 1.0, z + 2.5, faces='y'); s.box('led_white', bx - 1.5, by - 1.22, z + 2.6, bx + 1.5, by - 1.2, z + 2.65, faces='y')
    s.cbox(bx - 1.3, by - 0.8, z, bx + 1.3, by + 1.0, z + 2.8, 56)
    s.surf('sign_swat', (bx - 1.2, by - 1.23, z + 2.9), X, Z, 2.4, 0.4, step=0, fit=True)
    for x, y in ((-PX + 0.5, -PY + 0.5), (PX - 0.5, -PY + 0.5), (-PX + 0.5, PY - 0.5), (PX - 0.5, PY - 0.5)):
        s.cyl('metal_dark', x, y, z, 0.12, 0.9, seg=10); s.cyl('led_white', x, y, z + 0.9, 0.13, 0.12, seg=10)
    for x, y in ((-6, -6), (6, -6), (-6, 6), (6, 6)): s.light(x, y, z + 3.0, color=(255, 240, 220), intensity=6.0, falloff=12.0)
    s.bb = (-PX - 1, -PY - RL - 1, -1.0, PX + 1, PY + RL + 1, z + 3.5)
    return s


def lift():
    s = shell('rox_swat_lift', 'ROX SWAT car lift', lod=300)
    w, d = HW - 0.05, HD - 0.05
    s.box('steel', -w, -d, -0.3, w, d, 0.0, faces='xXyYZz', step=1.0); s.cbox(-w, -d, -0.3, w, d, 0.0, 56)
    for k in range(int(2 * d / 0.6)): s.box('metal_dark', -w + 0.2, -d + 0.3 + k * 0.6, 0.0, w - 0.2, -d + 0.34 + k * 0.6, 0.01, faces='Z')
    for a in ((-w, -d, w, -d + 0.4), (-w, d - 0.4, w, d), (-w, -d, -w + 0.4, d), (w - 0.4, -d, w, d)): s.box('hazard', a[0], a[1], 0.0, a[2], a[3], 0.012, faces='Z')
    for a in ((-w, -d - 0.02, w, -d), (-w, d, w, d + 0.02)): s.box('led_white', a[0], a[1], -0.25, a[2], a[3], -0.05, faces='yY')
    s.bb = (-w, -d, -0.4, w, d, 0.2)
    return s


def leaf():
    s = shell('rox_swat_leaf', 'ROX SWAT hatch leaf', lod=300)
    w, d = HW / 2 * 2 / 2, HD          # each leaf covers half of the hatch width (origin = its centre)
    s.box('metal_dark', -w, -d, -0.3, w, d, 0.0, faces='xXyYZz', step=1.0); s.cbox(-w, -d, -0.3, w, d, 0.0, 56)
    for k in range(int(2 * d / 0.5)): s.box('steel', -w + 0.15, -d + 0.2 + k * 0.5, 0.0, w - 0.15, -d + 0.24 + k * 0.5, 0.01, faces='Z')
    s.box('hazard', -w, -d, 0.0, w, -d + 0.35, 0.012, faces='Z'); s.box('hazard', -w, d - 0.35, 0.0, w, d, 0.012, faces='Z')
    s.bb = (-w, -d, -0.4, w, d, 0.1)
    return s


def pillar():
    s = shell('rox_swat_pillar', 'ROX SWAT pillar', lod=400)
    a = 0.4
    s.box('metal_dark', -a, -a, 0, a, a, PH, faces='xXyYZ', step=1.0); s.cbox(-a, -a, 0, a, a, PH, 56)
    for x, y in ((-a, -a), (a, -a), (-a, a), (a, a)): s.box('led_white', x - 0.03, y - 0.03, 0.3, x + 0.03, y + 0.03, PH - 0.1)
    s.box('hazard', -a - 0.01, -a - 0.01, 0, a + 0.01, a + 0.01, 0.9, faces='xXyY')
    s.surf('swat_badge', (-a + 0.05, -a - 0.012, PH - 1.2), X, Z, 2 * a - 0.1, 2 * a - 0.1, step=0, fit=True)
    s.surf('swat_badge', (a - 0.05, a + 0.012, PH - 1.2), -X, Z, 2 * a - 0.1, 2 * a - 0.1, step=0, fit=True)
    s.box('led_white', -a, -a, PH, a, a, PH + 0.06, faces='Z')
    s.light(0, -a - 0.4, PH - 0.5, color=(255, 255, 255), intensity=6.0, falloff=10.0)
    s.bb = (-a, -a, 0, a, a, PH + 0.1)
    return s


def sign():
    s = shell('rox_swat_sign', 'ROX SWAT TEAM gantry', lod=500)
    L = (HW + 1.6) * 2 - 0.8; h = 1.4
    s.box('metal_dark', -L / 2, -0.3, 0, L / 2, 0.3, h, faces='xXyYZz'); s.cbox(-L / 2, -0.3, 0, L / 2, 0.3, h, 56)
    s.surf('sign_swat', (-L / 2 + 0.2, -0.31, 0.15), X, Z, L - 0.4, h - 0.3, step=0, fit=True)
    s.surf('sign_swat', (L / 2 - 0.2, 0.31, 0.15), -X, Z, L - 0.4, h - 0.3, step=0, fit=True)
    for z in (0.0, h): s.box('led_white', -L / 2, -0.32, z - 0.03, L / 2, 0.32, z + 0.03)
    s.light(0, -2.0, -0.5, color=(255, 240, 210), intensity=8.0, falloff=14.0)
    s.bb = (-L / 2, -0.4, 0, L / 2, 0.4, h)
    return s


def all_pieces():
    import swat_levels as L
    for v in L.LV.values(): v['furn'].clear(); v['doors'].clear()
    L.SECRETS.clear(); L.VEH.clear()
    ps = [L.level1(), L.level2(), L.bookcase(), L.emblemdoor(), plaza(), lift(), leaf(), pillar(), sign()]
    out = os.environ.get('ROX_SWAT_DATA', os.path.join(os.path.dirname(__file__), '..', '..', 'rox_swat', 'data', 'swat.json'))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    stops = [dict(label='Street (booth)', labelAr='الشارع', x=7.5, y=7.6 - 1.5, z=PLAZA),
             dict(label='L1 - Lobby / Security', labelAr='الدور الأول - اللوبي والتفتيش', x=0.0, y=-23.5, z=L.L1Z),
             dict(label='L1 - Garage', labelAr='الدور الأول - الكراج', x=-15.0, y=-3.0, z=L.L1Z),
             dict(label='L1 - Cells / Lockers', labelAr='الدور الأول - الزنازين والملابس', x=-37.6, y=-8.7, z=L.L1Z),
             dict(label='L2 - Command', labelAr='الدور الثاني - القيادة', x=-37.6, y=-8.7, z=L.L2Z)]
    json.dump(dict(depth=DEPTH, plaza=PLAZA, hatch=[HW, HD], pillars=PILLARS, pillarHeight=PH, levels=dict(l1=L.L1Z, l2=L.L2Z),
                   furniture={k: v['furn'] for k, v in L.LV.items()}, doors={k: v['doors'] for k, v in L.LV.items()},
                   secrets=L.SECRETS, stops=stops, vehicles=L.VEH), open(out, 'w'), indent=1)
    return ps
