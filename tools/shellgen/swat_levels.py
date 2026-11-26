# ROX SWAT TEAM HQ - two underground floors (replaces the single-level hq() of swat.py)  (c) ROX Store
#   Level 1 (street - 11 m): 20-bay garage (beams, pipes, speed bumps, arrows), armory, tactical gear room, medical, servers,
#        5 m corridor with faceted black panels, visitor lobby (perforated wood ceiling, floor emblem, turnstiles + detectors,
#        reception), booking, mugshot room (oak panels + height charts), 6 holding cells, men / women locker rooms,
#        records & HR (cubicles), canteen, 2 interview rooms.
#   Level 2 (street - 18 m): commander suite (nero marble, gold emblem wall, backlit slats, trophy shelves, marble desk),
#        two SECRET doors (bookcase / emblem panel) to a secret 120-seat war hall, a secret vault armory and a secret
#        comms room; commander reception + private meeting room, 2 deputy offices, cyber unit, 100-seat auditorium,
#        30-seat meeting hall, HR, 18 offices, firing range, kill house, gym.
import math
import numpy as np
import swat as S
from swat import shell, F, glass_wall, led_lines, lights, outer, office, ceiling_with_hole, inner_walls, HW, HD, DEPTH, PLAZA
from kit import X, Y, Z

L1Z, L2Z = -DEPTH, -DEPTH - 7.0
R = dict(base='metal_dark')
LV = {'l1': dict(furn=[], doors=[]), 'l2': dict(furn=[], doors=[])}
SECRETS = []


def use(lv):
    S.FURN = LV[lv]['furn']; S.DOORS = LV[lv]['doors']


def plate(s, room, side, c, to, name, z=2.5, w=1.1):
    """name plate above a door, on the corridor (`to`) side"""
    if not to: return
    q = s.rooms[to]; m = 'pl_' + name; h = w * 0.166
    if side == 'N': s.surf(m, (c + w / 2, q['y0'] + 0.012, z), -X, Z, w, h, step=0, fit=True)
    if side == 'S': s.surf(m, (c - w / 2, q['y1'] - 0.012, z), X, Z, w, h, step=0, fit=True)
    if side == 'E': s.surf(m, (q['x0'] + 0.012, c - w / 2, z), Y, Z, w, h, step=0, fit=True)
    if side == 'W': s.surf(m, (q['x1'] - 0.012, c + w / 2, z), -Y, Z, w, h, step=0, fit=True)


def dp(s, room, side, c, to=None, kind='std', name=None, **kw):
    S.door(s, room, side, c, to=to, kind=kind, **kw)
    if name: plate(s, room, side, c, to, name)


def downlights(s, rm, sp=2.4, I=3.5, fo=6.0, col=(255, 236, 205)):
    r = s.rooms[rm]; z = r['H']
    nx, ny = max(1, int((r['x1'] - r['x0']) / sp)), max(1, int((r['y1'] - r['y0']) / sp))
    for i in range(nx):
        for j in range(ny):
            x = r['x0'] + (i + 0.5) * (r['x1'] - r['x0']) / nx; y = r['y0'] + (j + 0.5) * (r['y1'] - r['y0']) / ny
            s.box('led_white', x - 0.16, y - 0.16, z - 0.012, x + 0.16, y + 0.16, z - 0.002)
            if (i + j) % 2 == 0: s.light(x, y, z - 0.3, color=col, intensity=I, falloff=fo)


def cove(s, rm, drop=0.35, inset=0.9):
    """dropped ceiling border with a hidden LED cove (two-level ceiling)"""
    r = s.rooms[rm]; z = r['H']; x0, y0, x1, y1 = r['x0'], r['y0'], r['x1'], r['y1']
    for a in ((x0, y0, x1, y0 + inset), (x0, y1 - inset, x1, y1), (x0, y0 + inset, x0 + inset, y1 - inset), (x1 - inset, y0 + inset, x1, y1 - inset)):
        s.box('paint_black', a[0], a[1], z - drop, a[2], a[3], z - 0.001, faces='zxXyY')
    for a in ((x0 + inset, y0 + inset - 0.04, x1 - inset, y0 + inset), (x0 + inset, y1 - inset, x1 - inset, y1 - inset + 0.04),
              (x0 + inset - 0.04, y0 + inset, x0 + inset, y1 - inset), (x1 - inset, y0 + inset, x1 - inset + 0.04, y1 - inset)):
        s.box('led_white', a[0], a[1], z - drop - 0.02, a[2], a[3], z - drop + 0.02)


def wall_panel(s, rm, side, mat, z1=None, step=1.2):
    """cladding on the inside of a wall (8 mm proud) - facet panels, oak, marble"""
    r = s.rooms[rm]; z1 = z1 or r['H']; e = 0.008
    if side == 'N': s.box(mat, r['x0'], r['y1'] - e, 0.09, r['x1'], r['y1'], z1, faces='y', step=step)
    if side == 'S': s.box(mat, r['x0'], r['y0'], 0.09, r['x1'], r['y0'] + e, z1, faces='Y', step=step)
    if side == 'W': s.box(mat, r['x0'], r['y0'], 0.09, r['x0'] + e, r['y1'], z1, faces='X', step=step)
    if side == 'E': s.box(mat, r['x1'] - e, r['y0'], 0.09, r['x1'], r['y1'], z1, faces='x', step=step)


def extinguisher(x, y, h): F('prop_fire_exting_1a', x, y, h, z=0.0)


def elevator_doors(s, x, y0, y1):
    """2 brushed steel elevator doors on the west end wall of a corridor (x = wall), facing +X"""
    for k, yc in enumerate((y0 + (y1 - y0) * 0.3, y0 + (y1 - y0) * 0.7)):
        s.box('steel', x, yc - 0.6, 0, x + 0.02, yc + 0.6, 2.3, faces='X'); s.box('metal_dark', x + 0.02, yc - 0.003, 0, x + 0.024, yc + 0.003, 2.3, faces='X')
        s.box('marble_nero', x, yc - 0.8, 0, x + 0.05, yc - 0.6, 2.5, faces='XyY'); s.box('marble_nero', x, yc + 0.6, 0, x + 0.05, yc + 0.8, 2.5, faces='XyY')
        s.box('marble_nero', x, yc - 0.8, 2.3, x + 0.05, yc + 0.8, 2.5, faces='XZ'); s.box('led_white', x + 0.05, yc - 0.15, 2.38, x + 0.06, yc + 0.15, 2.44, faces='X')
    s.surf('pl_elevator', (x + 0.012, (y0 + y1) / 2 - 0.55, 2.75), Y, Z, 1.1, 0.18, step=0, fit=True)


def garage_detail(s):
    g = s.rooms['garage']
    for x in range(-24, 26, 5):                                     # concrete ceiling beams
        s.box('concrete_wall', x - 0.25, g['y0'], 4.4, x + 0.25, g['y1'], 5.0, faces='xXz')
    for y in (2.0, 12.0, 20.5):                                    # red sprinkler pipes + cable tray
        s.cyl('paint_maroon', -25.5, y, 4.25, 0.06, 0.12, seg=8) if False else None
        s.box('paint_maroon', g['x0'] + 0.3, y - 0.05, 4.2, g['x1'] - 0.3, y + 0.05, 4.3)
    s.box('metal_dark', g['x0'] + 0.3, 7.0, 4.15, g['x1'] - 0.3, 7.4, 4.22); s.box('metal_dark', g['x0'] + 0.3, 7.0, 4.22, g['x1'] - 0.3, 7.02, 4.3)
    for x in (-18.0, -6.0, 6.0, 18.0):                             # speed bumps across the aisle (yellow / black)
        s.box('hazard', x - 0.25, 11.6, 0, x + 0.25, 13.2, 0.07); s.box('hazard', x - 0.25, 15.6, 0, x + 0.25, 17.2, 0.07)
    for x in (-20.0, -10.0, 0.0, 10.0, 20.0):                       # direction arrows painted on the floor
        s.box('paint_white', x - 0.9, 14.35, 0, x + 0.6, 14.45, 0.012, faces='Z')
        s.box('paint_white', x + 0.5, 14.0, 0, x + 0.6, 14.8, 0.012, faces='Z')
    for y in (8.0, 20.5):
        for k in range(10): s.box('concrete_wall', -24.6 + k * 5.0, y - 0.1, 0, -22.4 + k * 5.0, y + 0.1, 0.15)   # wheel stops
    for x in (-24.5, -14.5, -4.5, 5.5, 15.5, 25.5): extinguisher(x, 14.0, 90.0); F('prop_cctv_cam_04a', x, 14.4, 0.0, z=4.0)


# ------------------------------------------------------------------------------------------------ level 1
def level1():
    use('l1')
    s = shell('rox_swat_l1', 'ROX SWAT HQ level 1', lod=220)
    s.room('garage', -26.0, -5.8, 26.0, 22.0, floor='concrete_floor', wall='concrete_wall', ceil=None, H=5.0, **R)
    s.room('corr', -40.0, -11.2, 41.8, -6.2, floor='tile_white', wall='facet', ceil='paint_black', H=3.6, **R)
    s.room('armory', 26.2, -5.8, 41.8, 8.0, floor='concrete_floor', wall='facet', ceil='paint_black', H=3.6, **R)
    s.room('gear', 26.2, 8.2, 41.8, 22.0, floor='concrete_floor', wall='facet', ceil='paint_black', H=3.6, **R)
    s.room('medical', -40.0, -5.8, -26.2, 8.0, floor='tile_white', wall='paint_white', ceil='paint_white', H=3.6, **R)
    s.room('servers', -40.0, 8.2, -26.2, 22.0, floor='concrete_floor', wall='paint_charcoal', ceil='paint_black', H=3.6, **R)
    # row A
    s.room('lock_m', -40.0, -24.0, -26.2, -11.4, floor='tile_white', wall='tile_white', ceil='paint_black', H=3.4, **R)
    s.room('lock_f', -26.0, -24.0, -12.2, -11.4, floor='tile_white', wall='tile_white', ceil='paint_black', H=3.4, **R)
    s.room('lobby', -12.0, -26.0, 12.0, -11.4, floor='tile_beige', wall='paint_white', ceil='wood_perf', H=4.4, **R)
    s.room('booking', 12.2, -24.0, 24.0, -11.4, floor='concrete_floor', wall='paint_white', ceil='paint_black', H=3.4, **R)
    s.room('mugshot', 24.2, -24.0, 32.0, -11.4, floor='concrete_floor', wall='oak_panel', ceil='paint_black', H=3.4, **R)
    s.room('cellcorr', 32.2, -44.0, 35.8, -11.4, floor='tile_white', wall='facet', ceil='paint_black', H=3.4, **R)
    cells = []
    ch = (32.6 - 5 * 0.2) / 6
    for i in range(6):
        y0 = -44.0 + i * (ch + 0.2); s.room(f'cell{i}', 36.0, y0, 41.8, y0 + ch, floor='concrete_floor', wall='paint_grey', ceil='paint_grey', H=3.0, **R); cells.append(f'cell{i}')
    # corridor B + row B
    s.room('corrb', -40.0, -29.0, 32.0, -26.2, floor='tile_white', wall='facet', ceil='paint_black', H=3.4, **R)
    s.room('records', -40.0, -44.0, -12.2, -29.2, floor='carpet', wall='paint_white', ceil='paint_black', H=3.4, **R)
    s.room('canteen', -12.0, -44.0, 12.0, -29.2, floor='tile_beige', wall='paint_white', ceil='wood_perf', H=3.4, **R)
    s.room('int1', 12.2, -44.0, 21.9, -29.2, floor='carpet', wall='paint_grey', ceil='paint_black', H=3.4, **R)
    s.room('int2', 22.1, -44.0, 32.0, -29.2, floor='carpet', wall='paint_grey', ceil='paint_black', H=3.4, **R)

    dp(s, 'garage', 'S', -15.0, to='corr', kind='glass', w=2.4, h=2.6); dp(s, 'garage', 'S', 15.0, to='corr', kind='glass', w=2.4, h=2.6)
    dp(s, 'garage', 'E', 2.0, to='armory', kind='sec', w=1.4); dp(s, 'garage', 'E', 15.0, to='gear', kind='sec', w=1.4)
    dp(s, 'garage', 'W', 15.0, to='servers', kind='sec'); dp(s, 'medical', 'S', -33.0, to='corr', name='medical')
    plate(s, 'armory', 'W', 2.0, 'garage', 'armoury'); plate(s, 'gear', 'W', 15.0, 'garage', 'tactical_gear'); plate(s, 'servers', 'E', 15.0, 'garage', 'server_room')
    dp(s, 'lock_m', 'N', -33.0, to='corr', name='locker_room_men'); dp(s, 'lock_f', 'N', -19.0, to='corr', name='locker_room_women')
    dp(s, 'lobby', 'N', 0.0, to='corr', kind='glass', w=2.4, h=2.6, name='security')
    dp(s, 'booking', 'N', 18.0, to='corr', kind='sec', name='booking'); dp(s, 'booking', 'E', -16.0, to='mugshot', name=None)
    dp(s, 'mugshot', 'E', -20.0, to='cellcorr', kind='sec'); s.door('cellcorr', 'N', 32.2, 35.8, to='corr', kind='door', h=2.4, casing='steel')
    plate(s, 'cellcorr', 'N', 34.0, 'corr', 'holding_cells')
    for c in cells:
        r = s.rooms[c]; dp(s, c, 'W', (r['y0'] + r['y1']) / 2, to='cellcorr', kind='cell', w=1.2)
    s.door('corrb', 'E', -28.4, -26.8, to='cellcorr', kind='door', h=2.3, casing='steel')
    dp(s, 'lobby', 'S', 8.0, to='corrb', kind='sec', name='exit')
    dp(s, 'records', 'N', -30.0, to='corrb', kind='glass', w=2.4, h=2.6, name='records'); dp(s, 'records', 'N', -18.0, to='corrb', name='human_resources')
    dp(s, 'canteen', 'N', -4.0, to='corrb', kind='glass', w=2.4, h=2.6, name='canteen')
    dp(s, 'int1', 'N', 17.0, to='corrb', kind='sec', name='interview'); dp(s, 'int2', 'N', 27.0, to='corrb', kind='sec', name='interview')
    s.door('lock_m', 'S', -36.0, -34.6, to='corrb', kind='door', h=2.3, casing='metal_dark') if False else None
    glass_wall(s, 'armory', 'W', 'garage', [(-5.3, 1.1), (2.9, 7.5)], sill=0.9)
    glass_wall(s, 'servers', 'E', 'garage', [(8.7, 14.2), (15.8, 21.5)], sill=0.9)
    glass_wall(s, 'lobby', 'N', 'corr', [(-11.5, -1.5), (1.5, 11.5)], sill=0.1, head=3.0)
    glass_wall(s, 'records', 'N', 'corrb', [(-39.5, -31.4), (-28.6, -18.8), (-17.2, -12.6)], sill=0.1, head=2.8)
    glass_wall(s, 'canteen', 'N', 'corrb', [(-11.5, -5.4), (-2.6, 11.5)], sill=0.1, head=2.8)
    glass_wall(s, 'booking', 'N', 'corr', [(12.6, 17.2), (18.8, 23.6)], sill=0.9, head=2.7)
    s.build_rooms()
    outer(s)
    ceiling_with_hole(s, 'concrete_wall', -26.0, -5.8, 26.0, 22.0, 5.0, (-HW, -HD, HW, HD))
    inner_walls(s, 'concrete_wall', -HW, -HD, HW, HD, 5.0, DEPTH + PLAZA)
    for z in (5.4, 8.0, 10.6):
        s.box('hazard', -HW + 0.01, -HD, z, -HW + 0.03, HD, z + 0.3, faces='X'); s.box('hazard', HW - 0.03, -HD, z, HW - 0.01, HD, z + 0.3, faces='x')
    for a in ((-HW - 0.4, -HD - 0.4, HW + 0.4, -HD), (-HW - 0.4, HD, HW + 0.4, HD + 0.4), (-HW - 0.4, -HD, -HW, HD), (HW, -HD, HW + 0.4, HD)):
        s.box('hazard', a[0], a[1], 0.0, a[2], a[3], 0.012, faces='Z')
    # garage: bays, columns, beams, pipes, bumps, arrows, wheel stops, signs
    for i in range(10):
        x = -24.5 + i * 5.0 + 2.5
        for y in (19.2, 9.6):
            for dx in (-2.5, 2.5): s.box('paint_yellow', x + dx - 0.06, y - 2.6, 0.0, x + dx + 0.06, y + 2.6, 0.012, faces='Z')
    for i in range(11):
        x = -24.5 + 5 * i
        s.box('concrete_wall', x - 0.35, 14.05, 0, x + 0.35, 14.75, 5.0, faces='xXyY'); s.cbox(x - 0.35, 14.05, 0, x + 0.35, 14.75, 5.0, 1)
        s.box('hazard', x - 0.36, 14.04, 0, x + 0.36, 14.76, 1.2, faces='xXyY')
    garage_detail(s)
    for x in range(-22, 24, 6):
        for y in (0.5, 9.0, 19.0):
            s.box('light', x - 0.8, y - 0.15, 4.36, x + 0.8, y + 0.15, 4.4, faces='z'); s.light(x, y, 4.2, color=(240, 246, 255), intensity=6.0, falloff=11.0)
    s.surf('sign_swat', (-6.0, 21.98, 3.0), X, Z, 12.0, 2.0, step=0, fit=True); s.surf('swat_badge', (-22.4, 21.98, 1.2), X, Z, 2.4, 2.4, step=0, fit=True)
    F('prop_toolchest_05', -25.4, 2.0, 270.0); F('prop_toolchest_05', -25.4, 4.0, 270.0); F('imp_prop_tool_chest_01a', 25.4, 9.0, 90.0)
    # main corridor: faceted panels, ceiling light panels, elevator at the west end, details
    r = s.rooms['corr']
    for x in np.arange(-38.0, 41.0, 3.0):
        s.box('light', x - 0.9, -9.0, 3.585, x + 0.9, -8.4, 3.6, faces='z')
        if int(x) % 6 == 0: s.light(x, -8.7, 3.3, color=(255, 246, 232), intensity=4.0, falloff=7.0)
    elevator_doors(s, r['x0'], r['y0'], r['y1'])
    for x in (-30.0, -2.0, 26.0): extinguisher(x, -11.0, 0.0); F('prop_cctv_cam_04a', x + 1.0, -6.4, 180.0, z=3.1)
    for x in (-24.0, 6.0, 30.0): F('apa_mp_h_acc_plant_tall_01', x, -10.7, 0.0)
    # armory + gear
    r = s.rooms['armory']
    for k in range(8): F('gr_prop_gr_gunlocker_01a' if k % 2 else 'bkr_prop_gunlocker_01a', r['x0'] + 1.2 + k * 1.8, r['y1'] - 0.45, 180.0)
    for k in range(3): F('gr_prop_gr_bench_04a', r['x0'] + 3.0 + k * 4.5, 1.2, 0.0); F('prop_box_guncase_02a', r['x0'] + 3.0 + k * 4.5, 1.2, 0.0, z=0.95)
    for k in range(4): F('xm_prop_crates_rifles_01a', r['x0'] + 2.0 + k * 3.5, r['y0'] + 0.6, 0.0)
    s.box('hazard', r['x0'] + 0.5, r['y0'] + 1.6, 0.0, r['x1'] - 0.5, r['y0'] + 1.7, 0.012, faces='Z'); downlights(s, 'armory'); cove(s, 'armory')
    r = s.rooms['gear']
    for k in range(7):
        x = r['x0'] + 1.2 + k * 2.1
        F('p_cs_locker_01_s', x, r['y1'] - 0.35, 180.0); F('prop_bodyarmour_02', x, r['y1'] - 0.6, 180.0, z=1.1)
        F('prop_ballistic_shield', x, r['y0'] + 0.4, 0.0) if k % 2 else F('prop_riot_shield', x, r['y0'] + 0.4, 0.0)
    for k in range(3): F('gr_prop_gr_bench_04a', r['x0'] + 3.5 + k * 4.5, (r['y0'] + r['y1']) / 2, 0.0); F('prop_mask_ballistic', r['x0'] + 3.0 + k * 4.5, (r['y0'] + r['y1']) / 2, 0.0, z=0.93); F('prop_cs_walkie_talkie', r['x0'] + 4.0 + k * 4.5, (r['y0'] + r['y1']) / 2, 0.0, z=0.93)
    for k in range(4): F('p_ld_heist_bag_s', r['x0'] + 2.0 + k * 3.0, (r['y0'] + r['y1']) / 2 - 1.2, 0.0)
    downlights(s, 'gear'); cove(s, 'gear')
    # medical, servers
    r = s.rooms['medical']
    for k in range(4): F('v_med_bed1', r['x0'] + 1.8 + k * 3.2, r['y1'] - 1.4, 180.0); F('v_med_trolley', r['x0'] + 3.2 + k * 3.2, r['y1'] - 0.6, 180.0)
    F('h4_prop_office_desk_01', r['x1'] - 2.0, r['y0'] + 2.0, 180.0, name='med'); F('prop_monitor_01a', r['x1'] - 2.0, r['y0'] + 2.0, 180.0, on='med'); F('prop_off_chair_01', r['x1'] - 2.0, r['y0'] + 1.1, 180.0)
    downlights(s, 'medical', I=4.5)
    r = s.rooms['servers']
    for row in range(4):
        for k in range(8): F('xm_base_cia_server_01' if (row + k) % 3 else 'v_corp_servercln', r['x0'] + 1.6 + k * 1.4, r['y0'] + 2.0 + row * 3.0, 0.0 if row % 2 else 180.0)
    s.box('led_white', r['x0'] + 0.5, r['y0'] + 0.5, 3.56, r['x1'] - 0.5, r['y0'] + 0.56, 3.6); lights(s, 'servers', I=3.0, col=(160, 200, 255))
    # locker rooms: lockers on 2 walls, benches, shower stalls, mirrors
    for rm in ('lock_m', 'lock_f'):
        r = s.rooms[rm]
        for k in range(16): F('p_cs_locker_01_s', r['x0'] + 0.5 + k * 0.8, r['y1'] - 0.35, 180.0)
        for k in range(3): F('v_ilev_ph_bench', r['x0'] + 3.0 + k * 4.0, r['y1'] - 2.2, 0.0)
        for k in range(5):
            x = r['x0'] + 1.0 + k * 2.4
            s.box('marble_cal', x, r['y0'], 0.0, x + 0.06, r['y0'] + 2.0, 2.2); s.cbox(x, r['y0'], 0, x + 0.06, r['y0'] + 2.0, 2.2, 81)
            F('prop_shower_rack_01', x + 1.2, r['y0'] + 0.1, 0.0, z=1.7)
        s.box('black_glass', r['x1'] - 0.03, r['y0'] + 3.0, 1.0, r['x1'] - 0.01, r['y1'] - 2.0, 2.2, faces='x')
        downlights(s, rm, I=4.0); cove(s, rm, inset=0.6)
    # lobby: perforated wood ceiling + LED lines, floor emblem, turnstiles + detectors, reception, posters, portrait, benches
    r = s.rooms['lobby']
    s.surf('swat_badge', (-2.4, -23.4, 0.012), X, Y, 4.8, 4.8, step=0, fit=True)
    for y in (-24.0, -20.0, -15.0):
        s.box('led_white', r['x0'] + 1.0, y - 0.03, 4.35, r['x1'] - 1.0, y + 0.03, 4.39)
    cove(s, 'lobby', drop=0.4, inset=1.0)
    for x in (-4.5, -1.5, 1.5, 4.5):                                  # turnstiles (steel cabinets + blue screens + glass flaps)
        s.box('steel', x - 0.18, -18.6, 0, x + 0.18, -17.2, 1.05); s.cbox(x - 0.18, -18.6, 0, x + 0.18, -17.2, 1.05, 56)
        s.box('info_screen', x - 0.1, -18.62, 0.75, x + 0.1, -18.6, 0.95, faces='y')
    for a, b in ((-11.6, -5.5), (5.5, 11.6)):
        s.box('steel', a, -17.95, 0, b, -17.85, 1.05); s.cbox(a, -17.95, 0, b, -17.85, 1.05, 56)
        s.box('glass_clear', a, -17.92, 1.05, b, -17.88, 1.9, faces='yY'); s.cbox(a, -17.92, 1.05, b, -17.88, 1.9, 114)
    for x in (-3.0, 0.0, 3.0): F('ch_prop_ch_metal_detector_01a', x, -15.2, 0.0)
    F('ch_prop_baggage_scanner_01a', -7.5, -15.2, 90.0)
    s.box('oak_panel', 7.0, -24.5, 0, 11.0, -23.7, 1.1, faces='xXyYZ', step=1.2); s.cbox(7.0, -24.5, 0, 11.0, -23.7, 1.1, 70)
    s.box('marble_nero', 6.9, -24.6, 1.1, 11.1, -23.6, 1.15); F('prop_off_chair_01', 9.0, -25.2, 180.0); F('prop_monitor_01a', 9.0, -24.1, 180.0, z=1.15)
    for x in (6.0, 6.0):
        pass
    s.box('oak_panel', r['x1'] - 0.02, -25.6, 0.0, r['x1'], -18.5, 4.4, faces='x', step=1.2)
    s.surf('poster_protect', (r['x0'] + 0.012, -22.8, 1.2), Y, Z, 2.2, 2.2 * 0.66, step=0, fit=True)
    s.surf('portrait', (r['x1'] - 0.03, -16.4, 1.3), -Y, Z, 1.4, 1.7, step=0, fit=True)
    for y in (-24.5, -21.5): F('v_ilev_ph_bench', r['x0'] + 0.6, y, 90.0)
    for p in ((-11.3, -25.4), (11.3, -18.8), (-11.3, -19.6), (-6.0, -25.5)): F('apa_mp_h_acc_plant_tall_01', p[0], p[1], 0.0)
    F('prop_flag_us', -10.6, -12.2, 180.0); F('prop_flag_lsservices', 10.6, -12.2, 180.0); F('prop_cctv_cam_04a', 11.6, -11.8, 225.0, z=4.0)
    # booking: L counter with PCs, printers, file shelves, water cooler, mesh cage wall
    r = s.rooms['booking']
    s.box('paint_white', r['x0'] + 1.0, -20.0, 0, r['x1'] - 1.0, -19.2, 1.0, faces='xXyYZ'); s.cbox(r['x0'] + 1.0, -20.0, 0, r['x1'] - 1.0, -19.2, 1.0, 70)
    s.box('marble_cal', r['x0'] + 0.95, -20.05, 1.0, r['x1'] - 0.95, -19.15, 1.05)
    for k in range(3):
        x = r['x0'] + 2.5 + k * 3.2
        F('prop_monitor_01a', x, -19.6, 0.0, z=1.05); F('prop_keyboard_01b', x, -19.9, 0.0, z=1.05); F('prop_off_chair_01', x, -18.6, 180.0)
    F('prop_printer_01', r['x1'] - 1.6, -19.6, 0.0, z=1.05); F('prop_cd_paper_pile1', r['x0'] + 1.5, -19.6, 0.0, z=1.05)
    s.box('metal_dark', r['x0'] + 2.0, r['y0'] + 0.02, 0.0, r['x1'] - 2.0, r['y0'] + 0.08, 3.0, faces='Y')
    for k in range(int((r['x1'] - r['x0'] - 4.0) / 0.3)): s.box('steel', r['x0'] + 2.0 + k * 0.3, r['y0'] + 0.09, 0.0, r['x0'] + 2.02 + k * 0.3, r['y0'] + 0.11, 3.0)
    F('prop_watercooler', r['x0'] + 0.5, r['y1'] - 0.6, 180.0); F('v_med_cor_filingcab', r['x0'] + 1.5, r['y1'] - 0.4, 180.0)
    F('prop_copier_01', r['x1'] - 0.8, r['y1'] - 0.7, 180.0); downlights(s, 'booking')
    # mugshot room: oak panels with reveals, 2 height charts, camera, desk, boxes
    r = s.rooms['mugshot']
    for z in (1.15, 2.3):
        for side in 'NSEW': pass
        s.box('paint_black', r['x0'] + 0.01, r['y0'], z, r['x0'] + 0.02, r['y1'], z + 0.02, faces='X'); s.box('paint_black', r['x0'], r['y0'] + 0.01, z, r['x1'], r['y0'] + 0.02, z + 0.02, faces='Y')
    for k, x in enumerate((r['x0'] + 1.2, r['x0'] + 4.8)):
        s.box('paint_black', x - 0.05, r['y0'] + 0.01, 0.35, x + 2.25, r['y0'] + 0.05, 2.55, faces='Y')
        s.surf('height_chart', (x + 2.15, r['y0'] + 0.055, 0.45), -X, Z, 2.1, 2.0, step=0, fit=True)
        F('prop_cd_paper_pile1' if k else 'prop_paper_box_01', x + 2.6, r['y0'] + 0.3, 0.0)
    F('prop_tv_cam_02', r['x0'] + 3.6, r['y1'] - 2.5, 0.0); F('h4_prop_office_desk_01', r['x1'] - 1.0, r['y1'] - 1.6, 90.0, name='mg')
    F('prop_monitor_01a', r['x1'] - 1.0, r['y1'] - 1.6, 270.0, on='mg'); F('prop_off_chair_01', r['x1'] - 2.0, r['y1'] - 1.6, 270.0); downlights(s, 'mugshot', I=4.5)
    # cells: bed, toilet, CCTV, cell corridor
    for c in cells:
        r = s.rooms[c]; cy = (r['y0'] + r['y1']) / 2
        s.box('concrete_wall', r['x1'] - 0.8, r['y0'] + 0.2, 0.0, r['x1'] - 0.02, r['y1'] - 0.2, 0.45, faces='xyYZ'); s.cbox(r['x1'] - 0.8, r['y0'] + 0.2, 0, r['x1'] - 0.02, r['y1'] - 0.2, 0.45, 1)
        F('prop_toilet_01', r['x0'] + 1.6, r['y0'] + 0.4, 0.0); F('prop_cctv_cam_04a', r['x1'] - 0.2, r['y1'] - 0.2, 135.0, z=2.8)
        s.light(r['x0'] + 2.8, cy, 2.8, color=(220, 235, 255), intensity=3.0, falloff=5.0); s.box('light', r['x0'] + 2.4, cy - 0.3, 2.985, r['x0'] + 3.2, cy + 0.3, 3.0, faces='z')
    lights(s, 'cellcorr', I=3.5, fo=7.0); led_lines(s, 'cellcorr', 1.4, 'y')
    # corridor B
    for x in np.arange(-38.0, 31.0, 3.0): s.box('light', x - 0.9, -27.9, 3.385, x + 0.9, -27.3, 3.4, faces='z')
    lights(s, 'corrb', I=3.5, fo=7.0)
    for x in (-34.0, 0.0, 24.0): extinguisher(x, -28.8, 0.0)
    # records & HR: cubicles (fabric partitions), desks, shelves, copier, whiteboard
    r = s.rooms['records']
    for row in range(2):
        for k in range(5):
            x = r['x0'] + 3.0 + k * 4.8; y = r['y0'] + 3.5 + row * 5.5
            s.box('fabric_grey' if False else 'carpet', x - 1.8, y + 0.85, 0, x + 1.8, y + 0.9, 1.4); s.box('metal_dark', x - 1.8, y + 0.84, 1.4, x + 1.8, y + 0.91, 1.44)
            s.box('carpet', x - 0.03, y - 1.0, 0, x + 0.03, y + 0.85, 1.4); s.cbox(x - 1.8, y + 0.84, 0, x + 1.8, y + 0.91, 1.44, 70)
            for dx in (-0.9, 0.9):
                n = f'rc{row}{k}{int(dx > 0)}'
                F('h4_prop_office_desk_01', x + dx, y + 0.35, 180.0, name=n); F('prop_monitor_01a', x + dx, y + 0.45, 180.0, on=n)
                F('prop_keyboard_01b', x + dx, y + 0.15, 180.0, on=n); F('prop_off_chair_01', x + dx, y - 0.6, 180.0)
                F('prop_office_phone_tnt' if dx < 0 else 'prop_mug_01', x + dx + 0.5, y + 0.3, 0.0, on=n)
    for k in range(6): F('v_med_cor_filingcab', r['x0'] + 0.4, r['y0'] + 1.2 + k * 0.9, 90.0)
    F('prop_copier_01', r['x1'] - 0.8, r['y0'] + 1.0, 270.0); F('ch_prop_whiteboard', r['x1'] - 0.1, r['y0'] + 6.0, 270.0); F('prop_watercooler', r['x1'] - 0.5, r['y0'] + 3.0, 270.0)
    downlights(s, 'records'); cove(s, 'records')
    # canteen
    r = s.rooms['canteen']
    for i in range(3):
        for j in range(2):
            x, y = r['x0'] + 4.0 + i * 7.0, r['y0'] + 4.0 + j * 5.0
            F('apa_mp_h_din_table_04', x, y, 0.0)
            for a in range(4): F('apa_mp_h_din_chair_04', x + (0.75 if a % 2 else -0.75), y + (0.6 if a < 2 else -0.6), 0.0 if a < 2 else 180.0)
    s.box('marble_nero', r['x0'] + 2.0, r['y0'] + 0.02, 0.0, r['x1'] - 2.0, r['y0'] + 0.7, 0.95); s.cbox(r['x0'] + 2.0, r['y0'], 0, r['x1'] - 2.0, r['y0'] + 0.7, 0.95, 81)
    for k in range(4): F('prop_vend_coffe_01' if k % 2 else 'prop_vend_soda_01', r['x0'] + 2.8 + k * 5.5, r['y0'] + 1.2, 0.0) if False else None
    F('prop_vend_coffe_01', r['x1'] - 1.0, r['y1'] - 0.6, 180.0); F('prop_vend_soda_01', r['x1'] - 2.2, r['y1'] - 0.6, 180.0); F('v_ret_ml_fridge', r['x1'] - 3.4, r['y1'] - 0.5, 180.0)
    F('prop_tv_flat_01', r['x0'] + 0.12, (r['y0'] + r['y1']) / 2, 270.0, z=1.7); downlights(s, 'canteen')
    for rm in ('int1', 'int2'):
        r = s.rooms[rm]; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
        s.box('black_glass', r['x0'] + 0.01, r['y0'] + 3.0, 1.0, r['x0'] + 0.03, r['y1'] - 3.0, 2.4, faces='X')
        s.box('steel', cx - 0.9, cy - 0.5, 0.74, cx + 0.9, cy + 0.5, 0.78); s.box('steel', cx - 0.05, cy - 0.05, 0, cx + 0.05, cy + 0.05, 0.74); s.cbox(cx - 0.9, cy - 0.5, 0, cx + 0.9, cy + 0.5, 0.78, 56)
        F('prop_off_chair_04', cx, cy - 1.0, 180.0); F('prop_off_chair_04', cx, cy + 1.0, 0.0); F('prop_cctv_cam_04a', r['x1'] - 0.3, r['y1'] - 0.3, 135.0, z=3.0)
        s.light(cx, cy, 3.1, color=(255, 240, 220), intensity=7.0, falloff=5.0)
    s.bb = (-42, -46, -0.3, 44, 24, DEPTH + PLAZA)
    return s


# ------------------------------------------------------------------------------------------------ level 2
def level2():
    use('l2')
    s = shell('rox_swat_l2', 'ROX SWAT HQ level 2 (command)', lod=220)
    s.room('corr', -40.0, -11.2, 41.8, -6.2, floor='marble_nero', wall='facet', ceil='paint_black', H=3.6, **R)
    s.room('dep1', -40.0, -5.8, -30.2, 7.9, floor='planks', wall='paint_white', ceil='paint_black', H=3.6, **R)
    s.room('dep2', -40.0, 8.1, -30.2, 22.0, floor='planks', wall='paint_white', ceil='paint_black', H=3.6, **R)
    s.room('hall', -30.0, -5.8, -6.2, 22.0, floor='carpet', wall='facet', ceil='paint_black', H=5.0, **R)
    s.room('cmd', -6.0, -5.8, 14.0, 10.0, floor='planks', wall='marble_nero', ceil='paint_black', H=4.2, **R)
    s.room('vault', -6.0, 10.2, 4.0, 22.0, floor='concrete_floor', wall='facet', ceil='paint_black', H=3.6, **R)
    s.room('comms', 4.2, 10.2, 14.0, 22.0, floor='marble_black', wall='paint_black', ceil='paint_black', H=3.6, **R)
    s.room('cmd_rec', 14.2, -5.8, 26.0, 10.0, floor='planks', wall='paint_white', ceil='paint_black', H=3.8, **R)
    s.room('cmd_meet', 14.2, 10.2, 26.0, 22.0, floor='planks', wall='marble_nero', ceil='paint_black', H=3.6, **R)
    s.room('cyber', 26.2, -5.8, 41.8, 22.0, floor='marble_black', wall='paint_black', ceil='paint_black', H=3.6, **R)
    s.room('auditorium', -40.0, -38.0, -12.2, -11.4, floor='carpet', wall='paint_charcoal', ceil='paint_black', H=5.0, **R)
    s.room('meeting', -12.0, -24.0, 8.0, -11.4, floor='carpet', wall='paint_charcoal', ceil='paint_black', H=3.6, **R)
    s.room('hr', 8.2, -24.0, 17.8, -11.4, floor='carpet', wall='paint_white', ceil='paint_black', H=3.4, **R)
    s.room('link', 18.0, -24.0, 21.8, -11.4, floor='marble_nero', wall='facet', ceil='paint_black', H=3.4, **R)
    s.room('corr2', -12.0, -29.0, 21.8, -24.2, floor='marble_nero', wall='facet', ceil='paint_black', H=3.4, **R)
    s.room('corr_off', 29.5, -50.0, 34.5, -11.4, floor='marble_nero', wall='facet', ceil='paint_black', H=3.4, **R)
    n, y0, y1 = 8, -50.0, -11.4; hgt = (y1 - y0 - (n - 1) * 0.2) / n
    offs = []
    for i in range(n):
        a = y0 + i * (hgt + 0.2); b = a + hgt
        s.room(f'off_w{i}', 22.2, a, 29.3, b, floor='carpet', wall='paint_white', ceil='paint_black', H=3.4, **R); offs.append((f'off_w{i}', 'E', (a + b) / 2))
        s.room(f'off_e{i}', 34.7, a, 41.8, b, floor='carpet', wall='paint_white', ceil='paint_black', H=3.4, **R); offs.append((f'off_e{i}', 'W', (a + b) / 2))
    s.room('sup1', 22.2, -56.0, 31.9, -50.2, floor='planks', wall='paint_white', ceil='paint_black', H=3.4, **R)
    s.room('sup2', 32.1, -56.0, 41.8, -50.2, floor='planks', wall='paint_white', ceil='paint_black', H=3.4, **R)
    s.room('range', -12.0, -46.0, 21.8, -29.2, floor='concrete_floor', wall='concrete_wall', ceil='paint_black', H=4.0, **R)
    s.room('killhouse', -40.0, -60.0, -12.2, -38.2, floor='concrete_floor', wall='concrete_wall', ceil='paint_black', H=4.0, **R)
    s.room('gym', -12.0, -60.0, 21.8, -46.2, floor='carpet', wall='paint_charcoal', ceil='paint_black', H=4.0, **R)

    dp(s, 'dep1', 'S', -35.0, to='corr', kind='sec', name='office'); dp(s, 'dep2', 'S', -35.0, to='dep1', kind='std')
    dp(s, 'cmd_rec', 'S', 20.0, to='corr', kind='glass', w=2.4, h=2.6, name='reception')
    dp(s, 'cmd_rec', 'W', 2.0, to='cmd', kind='sec', w=1.6, h=2.6); plate(s, 'cmd', 'E', 2.0, 'cmd_rec', 'swat_commander')
    dp(s, 'cmd_rec', 'N', 20.0, to='cmd_meet', kind='glass', w=1.6)
    dp(s, 'cyber', 'S', 34.0, to='corr', kind='sec', w=1.4, name='cyber_unit')
    dp(s, 'vault', 'E', 16.0, to='comms', kind='sec')
    # secret openings (no door props: the bookcase / emblem panel close them)
    s.door('cmd', 'W', 0.8, 3.2, to='hall', kind='door', h=2.8, casing='marble_nero')
    s.door('cmd', 'N', -2.2, 0.2, to='vault', kind='door', h=2.8, casing='marble_nero')
    SECRETS.append(dict(id='bookcase', model='rox_swat_bookcase', x=-6.0 + 0.32, y=2.0, h=90.0, dx=0.0, dy=2.6, lvl='l2'))
    SECRETS.append(dict(id='emblem', model='rox_swat_emblemdoor', x=-1.0, y=10.0 - 0.22, h=0.0, dx=-2.6, dy=0.0, lvl='l2'))
    dp(s, 'auditorium', 'N', -32.0, to='corr', kind='glass', w=2.4, h=2.6, name='briefing'); dp(s, 'auditorium', 'N', -18.0, to='corr', kind='glass', w=2.4, h=2.6)
    dp(s, 'meeting', 'N', -2.0, to='corr', kind='glass', w=2.4, h=2.6, name='conference')
    dp(s, 'hr', 'N', 13.0, to='corr', name='human_resources')
    s.door('link', 'N', 18.0, 21.8, to='corr', kind='open'); s.door('link', 'S', 18.0, 21.8, to='corr2', kind='open')
    s.door('corr_off', 'N', 29.5, 34.5, to='corr', kind='open'); plate(s, 'corr_off', 'N', 32.0, 'corr', 'command')
    for rm, sd, c in offs: dp(s, rm, sd, c, to='corr_off', name='office')
    dp(s, 'corr_off', 'S', 30.9, to='sup1', kind='sec'); dp(s, 'corr_off', 'S', 33.1, to='sup2', kind='sec')
    dp(s, 'corr2', 'S', 0.0, to='range', w=2.4, h=2.6, name='firing_range'); dp(s, 'corr2', 'S', 15.0, to='range')
    dp(s, 'range', 'W', -42.0, to='killhouse', w=1.6); dp(s, 'range', 'S', 5.0, to='gym', w=2.4, h=2.6)
    dp(s, 'meeting', 'S', -6.0, to='corr2')
    glass_wall(s, 'meeting', 'N', 'corr', [(-11.4, -3.5), (-0.5, 7.4)])
    glass_wall(s, 'hr', 'N', 'corr', [(8.6, 12.0), (14.0, 17.4)])
    glass_wall(s, 'auditorium', 'N', 'corr', [(-39.4, -33.5), (-30.5, -19.5), (-16.5, -12.8)])
    glass_wall(s, 'cmd_rec', 'S', 'corr', [(14.6, 18.6), (21.4, 25.6)], sill=0.1, head=2.8)
    glass_wall(s, 'cyber', 'S', 'corr', [(26.6, 33.0), (35.0, 41.4)], sill=0.1, head=2.8)
    glass_wall(s, 'range', 'N', 'corr2', [(-11.5, -1.5), (1.5, 14.2), (15.8, 21.4)], sill=1.0)
    glass_wall(s, 'gym', 'N', 'range', [(-11.5, 3.6), (6.4, 21.4)], sill=0.9)
    for rm, sd, c in offs:
        r = s.rooms[rm]; glass_wall(s, rm, sd, 'corr_off', [(r['y0'] + 0.3, c - 0.8), (c + 0.8, r['y1'] - 0.3)], sill=0.1, head=2.8)
    s.build_rooms()
    outer(s)

    # corridor: marble floor, faceted walls, LED ceiling panels, elevator
    r = s.rooms['corr']
    for x in np.arange(-38.0, 41.0, 3.0):
        s.box('light', x - 0.9, -9.0, 3.585, x + 0.9, -8.4, 3.6, faces='z')
        if int(x) % 6 == 0: s.light(x, -8.7, 3.3, color=(255, 240, 220), intensity=4.0, falloff=7.0)
    s.box('led_white', r['x0'], r['y0'] + 0.01, 0.05, r['x1'], r['y0'] + 0.03, 0.08, faces='Y'); s.box('led_white', r['x0'], r['y1'] - 0.03, 0.05, r['x1'], r['y1'] - 0.01, 0.08, faces='y')
    elevator_doors(s, r['x0'], r['y0'], r['y1'])
    for x in (-26.0, 6.0, 28.0): extinguisher(x, -11.0, 0.0); F('prop_cctv_cam_04a', x + 1.0, -6.4, 180.0, z=3.1)
    for x in (-38.0, -12.0, 12.0, 39.0): F('apa_mp_h_acc_plant_tall_01', x, -10.7, 0.0)

    # ---- commander office (reference: nero marble, gold emblem wall, backlit slats, trophy shelves, marble desk, sofa)
    r = s.rooms['cmd']; H = r['H']
    s.surf('cmd_emblem', (-2.6, r['y1'] - 0.012, 0.2), X, Z, 3.2, 3.6, step=0, fit=True) if False else None
    for k in range(13):                                                  # backlit vertical slats (N wall, east of the emblem)
        x = 5.4 + k * 0.32
        s.box('oak_panel', x, r['y1'] - 0.16, 0.0, x + 0.16, r['y1'] - 0.02, H, faces='xXy', step=1.2)
    s.box('led_white', 5.3, r['y1'] - 0.02, 0.0, 5.4 + 13 * 0.32, r['y1'] - 0.01, H, faces='y')
    s.light(7.5, r['y1'] - 0.6, 2.0, color=(255, 190, 120), intensity=4.0, falloff=4.0)
    for z in (1.5, 2.25, 3.0):                                           # trophy shelves (W wall, south of the bookcase) with LED
        s.box('oak_panel', r['x0'] + 0.01, -5.2, z, r['x0'] + 0.42, -1.0, z + 0.05); s.box('led_white', r['x0'] + 0.01, -5.2, z - 0.015, r['x0'] + 0.42, -1.0, z)
    s.box('wood_dark', r['x0'] + 0.01, -5.6, 0.0, r['x0'] + 0.6, -0.8, 0.9, faces='XyYZ', step=1.2); s.cbox(r['x0'], -5.6, 0, r['x0'] + 0.6, -0.8, 0.9, 70)
    s.box('wood_dark', r['x0'] + 0.01, 4.2, 0.0, r['x0'] + 0.6, 9.6, 0.9, faces='XyYZ', step=1.2); s.cbox(r['x0'], 4.2, 0, r['x0'] + 0.6, 9.6, 0.9, 70)
    for k, (y, z, m) in enumerate(((-4.6, 1.55, 'ch_prop_ch_trophy_patriot_01a'), (-3.0, 1.55, 'ch_prop_ch_trophy_gunner_01a'), (-1.6, 2.3, 'ch_prop_ch_trophy_king_01a'),
                                   (-4.0, 2.3, 'ba_prop_battle_trophy_no1'), (-2.4, 3.05, 'ch_prop_ch_trophy_strife_01a'), (-4.4, 3.05, 'ch_prop_ch_trophy_brawler_01a'))):
        F(m, r['x0'] + 0.22, y, 90.0, z=z)
    s.surf('poster_grad', (r['x0'] + 0.012, 8.8, 1.3), -Y, Z, 3.2, 1.9, step=0, fit=True)
    s.surf('portrait', (r['x1'] - 0.012, -5.0, 1.2), Y, Z, 1.3, 1.6, step=0, fit=True)
    # marble desk with gold trim + exec chair + 2 guest chairs + rug + lamp + laptop + files + sofa + plants
    cx, cy = -1.0, 5.2
    s.box('marble_nero', cx - 1.7, cy - 0.65, 0.0, cx + 1.7, cy + 0.65, 0.76, faces='xXyYZ'); s.cbox(cx - 1.7, cy - 0.65, 0, cx + 1.7, cy + 0.65, 0.78, 81)
    for a in ((cx - 1.72, cy - 0.67, cx + 1.72, cy - 0.64), (cx - 1.72, cy + 0.64, cx + 1.72, cy + 0.67), (cx - 1.72, cy - 0.67, cx - 1.69, cy + 0.67), (cx + 1.69, cy - 0.67, cx + 1.72, cy + 0.67)):
        s.box('brass', a[0], a[1], 0.0, a[2], a[3], 0.78)
    s.box('brass', cx - 1.72, cy - 0.67, 0.76, cx + 1.72, cy + 0.67, 0.78, faces='Z') if False else s.box('marble_nero', cx - 1.75, cy - 0.7, 0.76, cx + 1.75, cy + 0.7, 0.8)
    F('ex_prop_offchair_exec_01', cx, cy + 1.0, 0.0); F('ex_prop_offchair_exec_01', cx - 0.8, cy - 1.35, 180.0); F('ex_prop_offchair_exec_01', cx + 0.8, cy - 1.35, 180.0)
    F('ex_prop_ex_laptop_01a', cx + 0.3, cy + 0.1, 0.0, z=0.8); F('prop_cd_folder_pile1', cx - 1.1, cy + 0.2, 0.0, z=0.8); F('prop_office_phone_tnt', cx + 1.2, cy + 0.25, 0.0, z=0.8)
    s.box('rug_cream', cx - 3.2, cy - 3.2, 0.0, cx + 3.2, cy + 1.8, 0.012, faces='Z') if False else s.box('carpet', cx - 3.2, cy - 3.4, 0.0, cx + 3.2, cy + 1.8, 0.015, faces='Z')
    F('ex_mp_h_off_sofa_01', r['x1'] - 0.7, 0.5, 270.0); F('apa_mp_h_tab_coffee_07', r['x1'] - 2.1, 0.5, 0.0); F('ex_mp_h_off_easychair_01', r['x1'] - 3.6, -2.5, 30.0)
    for p in ((r['x0'] + 0.6, 3.8), (4.8, r['y1'] - 0.5), (r['x1'] - 0.5, r['y1'] - 0.5), (r['x1'] - 0.5, -5.3), (-4.6, r['y1'] - 0.5)): F('apa_mp_h_acc_plant_tall_01', p[0], p[1], 0.0)
    F('prop_flag_us', -3.6, r['y1'] - 0.6, 0.0); F('prop_flag_lsservices', 1.6, r['y1'] - 0.6, 0.0)
    # ceiling: dropped black border with warm cove + square downlights
    cove(s, 'cmd', drop=0.45, inset=1.2)
    for x in (-3.0, 1.0, 5.0, 9.0):
        for y in (-2.5, 2.5, 7.0):
            s.box('led_white', x - 0.2, y - 0.2, H - 0.012, x + 0.2, y + 0.2, H - 0.002)
    for x, y in ((-1.0, 5.0), (8.0, 0.0), (-3.0, -3.0), (10.0, 6.5)): s.light(x, y, H - 0.4, color=(255, 214, 160), intensity=4.5, falloff=7.0)

    # ---- secret 120-seat war hall (behind the bookcase)
    r = s.rooms['hall']; cx = (r['x0'] + r['x1']) / 2
    s.box('wood_dark', r['x0'] + 2.0, r['y1'] - 4.0, 0, r['x1'] - 2.0, r['y1'], 0.6, faces='xXyYZ', step=1.2); s.cbox(r['x0'] + 2.0, r['y1'] - 4.0, 0, r['x1'] - 2.0, r['y1'], 0.6, 70)
    s.box('led_white', r['x0'] + 2.0, r['y1'] - 4.03, 0.5, r['x1'] - 2.0, r['y1'] - 4.0, 0.56, faces='y')
    s.surf('ops_map', (cx - 6.0, r['y1'] - 0.03, 1.4), X, Z, 12.0, 3.0, step=0, fit=True)
    s.surf('cmd_emblem', (r['x0'] + 2.4, r['y1'] - 0.03, 1.2), X, Z, 3.0, 3.4, step=0, fit=True); s.surf('cmd_emblem', (r['x1'] - 5.4, r['y1'] - 0.03, 1.2), X, Z, 3.0, 3.4, step=0, fit=True)
    F('v_ilev_cd_lampal', cx + 4.5, r['y1'] - 2.6, 0.0, z=0.6)
    for row in range(10):
        for k in range(12):
            x = cx - 7.6 + k * 1.3 + (0.8 if k >= 6 else 0.0) - 0.4
            F('prop_off_chair_04', x, r['y1'] - 6.4 - row * 1.15, 180.0)
    led_lines(s, 'hall', 2.4); lights(s, 'hall', I=4.5, fo=10.0)
    for p in ((r['x0'] + 0.6, r['y0'] + 0.6), (r['x1'] - 0.6, r['y0'] + 0.6)): F('apa_mp_h_acc_plant_tall_01', p[0], p[1], 0.0)
    # ---- secret vault armory + comms
    r = s.rooms['vault']
    for k in range(5): F('bkr_prop_gunlocker_01a', r['x0'] + 1.0 + k * 1.8, r['y1'] - 0.45, 180.0)
    for k in range(3): F('gr_prop_gr_rsply_crate01a', r['x0'] + 1.5 + k * 2.6, r['y0'] + 2.5, 0.0); F('xm_prop_crates_rifles_01a', r['x0'] + 1.5 + k * 2.6, r['y0'] + 4.5, 0.0)
    F('p_v_43_safe_s', r['x1'] - 0.6, r['y0'] + 0.6, 270.0); F('hei_prop_heist_cash_pile', r['x1'] - 1.6, r['y0'] + 6.5, 0.0, z=0.9)
    F('gr_prop_gr_bench_04a', r['x1'] - 1.6, r['y0'] + 6.5, 90.0); downlights(s, 'vault', I=3.0, col=(255, 200, 150))
    r = s.rooms['comms']
    s.surf('cctv_wall', (r['x0'] + 8.6, r['y1'] - 0.03, 0.9), -X, Z, 7.4, 2.2, step=0, fit=True) if False else s.surf('cctv_wall', (r['x0'] + 1.2, r['y1'] - 0.03, 0.9), X, Z, 7.4, 2.2, step=0, fit=True)
    for k in range(3):
        F('h4_prop_office_desk_01', r['x0'] + 2.0 + k * 3.0, r['y1'] - 2.0, 180.0, name=f'cm{k}')
        for m in (-0.45, 0.0, 0.45): F('prop_monitor_01a', r['x0'] + 2.0 + k * 3.0 + m, r['y1'] - 2.0, 180.0, on=f'cm{k}')
        F('ex_prop_offchair_exec_01', r['x0'] + 2.0 + k * 3.0, r['y1'] - 2.9, 180.0)
    for k in range(3): F('xm_base_cia_server_01', r['x1'] - 0.6, r['y0'] + 1.0 + k * 1.2, 270.0)
    s.box('led_white', r['x0'] + 0.3, r['y0'] + 0.3, 3.55, r['x1'] - 0.3, r['y0'] + 0.36, 3.6); lights(s, 'comms', I=3.0, col=(150, 190, 255))
    # ---- commander reception (assistant desk, waiting sofas, portrait) + private meeting
    r = s.rooms['cmd_rec']
    s.box('oak_panel', 16.0, 4.0, 0, 21.0, 4.8, 1.1, faces='xXyYZ', step=1.2); s.cbox(16.0, 4.0, 0, 21.0, 4.8, 1.1, 70); s.box('marble_nero', 15.9, 3.9, 1.1, 21.1, 4.9, 1.15)
    F('ex_prop_offchair_exec_01', 18.5, 5.8, 0.0); F('prop_monitor_01a', 18.5, 4.4, 0.0, z=1.15); F('prop_office_phone_tnt', 19.8, 4.4, 0.0, z=1.15)
    for y in (-4.0, -1.0): F('ex_mp_h_off_sofa_01', r['x1'] - 0.7, y, 270.0)
    F('apa_mp_h_tab_coffee_07', r['x1'] - 2.0, -2.5, 0.0); s.surf('portrait', (r['x1'] - 0.012, 3.0, 1.3), Y, Z, 1.3, 1.6, step=0, fit=True)
    s.surf('swat_badge', (15.0, r['y1'] - 0.012, 1.3), X, Z, 2.0, 2.0, step=0, fit=True)
    for p in ((14.7, -5.3), (25.5, 9.5), (25.5, -5.3)): F('apa_mp_h_acc_plant_tall_01', p[0], p[1], 0.0)
    cove(s, 'cmd_rec', drop=0.35, inset=0.9); downlights(s, 'cmd_rec')
    r = s.rooms['cmd_meet']; cxm, cym = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
    s.box('marble_nero', cxm - 3.2, cym - 0.8, 0.72, cxm + 3.2, cym + 0.8, 0.78); s.box('wood_dark', cxm - 2.6, cym - 0.35, 0, cxm + 2.6, cym + 0.35, 0.72); s.cbox(cxm - 3.2, cym - 0.8, 0, cxm + 3.2, cym + 0.8, 0.78, 81)
    for k in range(5): F('ex_prop_offchair_exec_01', cxm - 2.6 + k * 1.3, cym - 1.25, 180.0); F('ex_prop_offchair_exec_01', cxm - 2.6 + k * 1.3, cym + 1.25, 0.0)
    F('prop_tv_flat_michael', r['x1'] - 0.15, cym, 90.0, z=1.6); cove(s, 'cmd_meet'); downlights(s, 'cmd_meet')
    for rm in ('dep1', 'dep2'): office(rm, s, 'N', boss=True) if rm == 'dep1' else office(rm, s, 'N', boss=True)
    # ---- cyber unit (moved up here)
    r = s.rooms['cyber']; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2
    s.surf('cctv_wall', (r['x0'] + 1.5, r['y1'] - 0.03, 0.9), X, Z, 6.0, 2.3, step=0, fit=True); s.surf('ops_map', (r['x0'] + 8.0, r['y1'] - 0.03, 0.9), X, Z, 6.4, 2.3, step=0, fit=True)
    s.box('marble_black', cx - 1.6, cy - 1.0, 0.0, cx + 1.6, cy + 0.2, 0.78, faces='xXyYZ'); s.cbox(cx - 1.6, cy - 1.0, 0, cx + 1.6, cy + 0.2, 0.78, 81)
    s.box('led_white', cx - 1.6, cy - 1.02, 0.05, cx + 1.6, cy - 1.0, 0.09, faces='y')
    F('ba_prop_battle_hacker_screen', cx, cy - 0.6, 180.0, z=0.78); F('xm_prop_x17_laptop_mrsr', cx - 0.9, cy - 0.3, 180.0, z=0.78); F('hei_prop_hst_laptop', cx + 0.9, cy - 0.3, 180.0, z=0.78)
    F('xm_prop_x17_computer_01', cx - 0.4, cy - 0.15, 180.0, z=0.78); F('ex_prop_offchair_exec_01', cx, cy + 0.9, 0.0)
    for row in range(2):
        for k in range(4):
            x = r['x0'] + 2.0 + k * 3.6; y = r['y0'] + 3.0 + row * 3.5; n = f'cy{row}{k}'
            F('h4_prop_office_desk_01', x, y, 0.0, name=n)
            for m in (-0.45, 0.0, 0.45): F('prop_monitor_01a', x + m, y + 0.1, 0.0, on=n)
            F('prop_off_chair_01', x, y - 0.9, 180.0)
    for k in range(4): F('xm_base_cia_server_01', r['x1'] - 0.6, r['y1'] - 1.2 - k * 1.2, 90.0)
    s.box('led_white', r['x0'] + 0.3, r['y1'] - 0.36, 3.55, r['x1'] - 0.3, r['y1'] - 0.3, 3.6); lights(s, 'cyber', I=3.0, col=(150, 190, 255))
    # ---- auditorium 100, meeting 30, HR, offices, range, kill house, gym (as before, wider corridors)
    r = s.rooms['auditorium']; cx = (r['x0'] + r['x1']) / 2
    s.box('wood_dark', r['x0'] + 2.0, r['y0'], 0, r['x1'] - 2.0, r['y0'] + 4.0, 0.6, faces='xXyYZ', step=1.2); s.cbox(r['x0'] + 2.0, r['y0'], 0, r['x1'] - 2.0, r['y0'] + 4.0, 0.6, 70)
    s.box('led_white', r['x0'] + 2.0, r['y0'] + 4.0, 0.5, r['x1'] - 2.0, r['y0'] + 4.03, 0.56, faces='Y')
    s.surf('ops_map', (cx + 7.0, r['y0'] + 0.03, 1.4), -X, Z, 14.0, 3.2, step=0, fit=True)
    s.surf('swat_badge', (r['x0'] + 5.2, r['y0'] + 0.03, 1.6), -X, Z, 2.8, 2.8, step=0, fit=True); s.surf('swat_badge', (r['x1'] - 2.4, r['y0'] + 0.03, 1.6), -X, Z, 2.8, 2.8, step=0, fit=True)
    F('v_ilev_cd_lampal', cx + 4.0, r['y0'] + 2.6, 180.0, z=0.6); F('prop_flag_us', cx - 5.0, r['y0'] + 1.0, 180.0, z=0.6); F('prop_flag_lsservices', cx + 6.0, r['y0'] + 1.0, 180.0, z=0.6)
    for row in range(10):
        for k in range(10): F('prop_off_chair_04', cx - 6.6 + k * 1.2 + (0.6 if k >= 5 else 0.0) - 0.3, r['y0'] + 6.6 + row * 1.15, 180.0)
    led_lines(s, 'auditorium', 2.4); lights(s, 'auditorium', I=5.0, fo=10.0)
    r = s.rooms['meeting']; cx, cy = (r['x0'] + r['x1']) / 2, (r['y0'] + r['y1']) / 2; L = 16.5
    s.box('marble_nero', cx - L / 2, cy - 0.9, 0.72, cx + L / 2, cy + 0.9, 0.78); s.box('wood_dark', cx - L / 2 + 0.6, cy - 0.4, 0, cx + L / 2 - 0.6, cy + 0.4, 0.72)
    s.cbox(cx - L / 2, cy - 0.9, 0, cx + L / 2, cy + 0.9, 0.78, 70); s.box('led_white', cx - L / 2 + 0.6, cy - 0.41, 0.05, cx + L / 2 - 0.6, cy - 0.4, 0.1)
    for k in range(15):
        x = cx - L / 2 + 0.55 + k * 1.1
        F('ex_prop_offchair_exec_01', x, cy - 1.35, 180.0); F('ex_prop_offchair_exec_01', x, cy + 1.35, 0.0)
        if k % 3 == 1: F('prop_cs_tablet', x, cy - 0.5, 0.0, z=0.78); F('prop_cs_tablet', x, cy + 0.5, 180.0, z=0.78)
    F('prop_tv_flat_michael', r['x0'] + 0.15, cy, 270.0, z=1.6); F('prop_tv_flat_michael', r['x1'] - 0.15, cy, 90.0, z=1.6)
    s.box('oak_panel', r['x0'] + 2.0, r['y1'] - 0.06, 0, r['x1'] - 2.0, r['y1'] - 0.02, 3.6, faces='y', step=1.2) if False else s.box('oak_panel', r['x0'] + 2.0, r['y0'] + 0.02, 0, r['x1'] - 2.0, r['y0'] + 0.06, 3.6, faces='Y', step=1.2)
    s.surf('swat_badge', (cx + 1.2, r['y0'] + 0.07, 1.3), -X, Z, 2.4, 2.4, step=0, fit=True); cove(s, 'meeting'); downlights(s, 'meeting')
    r = s.rooms['hr']
    for k in range(2):
        for j in range(2):
            x, y = r['x0'] + 2.4 + k * 4.6, r['y0'] + 3.0 + j * 4.5; n = f'hr{k}{j}'
            F('h4_prop_office_desk_01', x, y, 0.0, name=n); F('prop_monitor_01a', x, y + 0.1, 0.0, on=n); F('prop_off_chair_01', x, y - 0.9, 180.0); F('prop_office_phone_tnt', x + 0.5, y, 0.0, on=n)
    for k in range(5): F('v_med_cor_filingcab', r['x1'] - 0.4, r['y0'] + 1.0 + k * 0.9, 270.0)
    F('ch_prop_whiteboard', r['x0'] + 0.1, r['y0'] + 6.0, 90.0); downlights(s, 'hr')
    for rm in ('link', 'corr2', 'corr_off'): led_lines(s, rm, 1.3, 'y' if rm != 'corr2' else 'x'); lights(s, rm, I=4.0, fo=8.0)
    for rm, sd, c in offs: office(rm, s, 'E' if sd == 'E' else 'W')
    office('sup1', s, 'N', boss=True); office('sup2', s, 'N', boss=True)
    r = s.rooms['range']
    s.box('wood_dark', r['x0'] + 3.0, r['y0'] + 0.5, 0.0, r['x0'] + 3.6, r['y1'] - 4.0, 1.1, faces='xXyYZ'); s.cbox(r['x0'] + 3.0, r['y0'] + 0.5, 0, r['x0'] + 3.6, r['y1'] - 4.0, 1.1, 70)
    for k in range(9):
        y = r['y0'] + 0.5 + k * ((r['y1'] - 4.0 - r['y0'] - 0.5) / 8)
        s.box('metal_dark', r['x0'] + 3.6, y - 0.03, 0.0, r['x0'] + 5.0, y + 0.03, 2.2); s.cbox(r['x0'] + 3.6, y - 0.03, 0, r['x0'] + 5.0, y + 0.03, 2.2, 56)
    for k in range(8):
        y = r['y0'] + 0.5 + (k + 0.5) * ((r['y1'] - 4.0 - r['y0'] - 0.5) / 8)
        F('gr_prop_gr_target_05a', r['x1'] - 4.0 - (k % 3) * 4.0, y, 90.0); s.box('led_white', r['x0'] + 3.0, y - 0.3, 2.6, r['x0'] + 30.0, y - 0.28, 2.64)
    s.box('concrete_wall', r['x1'] - 1.2, r['y0'] + 0.2, 0, r['x1'] - 0.2, r['y1'] - 4.0, 4.0, faces='x'); s.box('hazard', r['x0'] + 3.0, r['y1'] - 4.0, 0.0, r['x1'] - 1.2, r['y1'] - 3.85, 0.012, faces='Z')
    for k in range(3): F('gr_prop_gr_bench_04a', r['x0'] + 11.0 + k * 5.0, r['y1'] - 1.8, 0.0)
    lights(s, 'range', I=5.0, fo=10.0); led_lines(s, 'range', 3.0, 'y')
    walls = [(-36.0, -60.0, -36.0, -50.0), (-30.0, -54.0, -30.0, -42.0), (-24.0, -60.0, -24.0, -48.0), (-18.0, -52.0, -18.0, -40.0),
             (-40.0, -46.0, -33.0, -46.0), (-30.0, -50.0, -20.0, -50.0), (-24.0, -44.0, -14.0, -44.0)]
    for x0, y0, x1, y1 in walls:
        a, b = (min(x0, x1) - 0.06, min(y0, y1)) if x0 == x1 else (min(x0, x1), y0 - 0.06)
        c, d = (max(x0, x1) + 0.06, max(y0, y1)) if x0 == x1 else (max(x0, x1), y0 + 0.06)
        s.box('planks', a, b, 0, c, d, 2.6, faces='xXyYZ', step=1.2); s.cbox(a, b, 0, c, d, 2.6, 72)
    for x, y in ((-33, -56), (-27, -46), (-21, -55), (-15, -48), (-34, -42)): F('gr_prop_gr_target_1_01a', x, y, 0.0)
    lights(s, 'killhouse', I=4.0); led_lines(s, 'killhouse', 3.0)
    r = s.rooms['gym']
    for k in range(4): F('prop_weight_bench_02', r['x0'] + 3.0 + k * 3.0, r['y0'] + 3.0, 0.0)
    for k in range(3): F('prop_weight_squat', r['x0'] + 3.0 + k * 4.0, r['y0'] + 7.5, 0.0); F('prop_muscle_bench_03', r['x0'] + 16.0 + k * 3.0, r['y0'] + 3.0, 0.0)
    for k in range(4): F('prop_beach_punchbag', r['x1'] - 3.0 - k * 2.5, r['y1'] - 2.0, 0.0)
    for k in range(5): F('apa_p_apdlc_treadmill_s', r['x0'] + 16.0 + k * 2.4, r['y0'] + 8.0, 180.0)
    s.box('black_glass', r['x0'] + 0.01, r['y0'] + 1.0, 0.4, r['x0'] + 0.03, r['y1'] - 1.0, 3.0, faces='X')
    led_lines(s, 'gym', 2.4); lights(s, 'gym')
    s.bb = (-42, -62, -0.3, 44, 24, 6.0)
    return s


# ------------------------------------------------------------------------------------------------ secret door panels
def bookcase():
    s = shell('rox_swat_bookcase', 'ROX SWAT secret bookcase', lod=80)
    w, d, h = 1.25, 0.22, 2.85
    s.box('wood_dark', -w, -d, 0, w, d, h, faces='xXyYZ', step=1.2); s.cbox(-w, -d, 0, w, d, h, 70)
    cols = ['paint_maroon', 'paint_navy', 'paint_olive', 'paint_brown', 'paint_charcoal', 'paint_sand']
    for z in (0.5, 1.1, 1.7, 2.3):
        s.box('oak_panel', -w + 0.05, -d - 0.01, z, w - 0.05, -d + 0.2, z + 0.04)
        x = -w + 0.1; k = int(z * 10)
        while x < w - 0.15:
            bw = 0.04 + ((k * 7) % 5) * 0.012; bh = 0.32 + ((k * 3) % 4) * 0.04
            s.box(cols[k % len(cols)], x, -d - 0.005, z + 0.04, x + bw, -d + 0.18, z + 0.04 + bh, faces='xXyZ'); x += bw + 0.005; k += 1
    s.box('led_white', -w + 0.05, -d - 0.012, 2.83, w - 0.05, -d - 0.005, 2.85, faces='y')
    s.bb = (-w, -d, 0, w, d, h)
    return s


def emblemdoor():
    s = shell('rox_swat_emblemdoor', 'ROX SWAT secret emblem panel', lod=80)
    w, d, h = 1.3, 0.1, 3.4
    s.box('marble_nero', -w, -d, 0, w, d, h, faces='xXyYZ', step=1.2); s.cbox(-w, -d, 0, w, d, h, 81)
    s.surf('cmd_emblem', (-w + 0.08, -d - 0.006, 0.25), X, Z, 2 * w - 0.16, h - 0.4, step=0, fit=True)
    for a in ((-w, -d - 0.02, -w + 0.04, h), (w - 0.04, -d - 0.02, w, h)): s.box('brass', a[0], a[1], 0, a[2], -d, a[3])
    s.box('brass', -w, -d - 0.02, h - 0.04, w, -d, h); s.box('led_white', -w - 0.02, -d, 0.0, -w, d, h, faces='x'); s.box('led_white', w, -d, 0.0, w + 0.02, d, h, faces='X')
    s.light(0, -d - 0.6, h - 0.3, color=(255, 200, 130), intensity=3.0, falloff=4.0)
    s.bb = (-w, -d, 0, w, d, h)
    return s
