# ROX Police HQ: walk-in MLO-style station (lobby, briefing, bullpen, offices, booking + mugshot, interrogation,
# cells, lockers, chief office) + roof helipad.  Furniture = real GTA props spawned by the rox_police resource.  (c) ROX Store
# Origin = centre of the building at street level, entrance on the -Y side.
import math
import numpy as np
from kit import Shell, X, Y, Z

H, G = 4.0, 0.2                  # room height, wall gap between rooms
XA, XB, YA, YB = -24.0, 24.0, -17.0, 17.0
CORR = (-5.0, -1.0)              # corridor y range


def build():
    s = Shell('rox_police_hq', 'ROX Police HQ', 'مركز شرطة ROX', H=H)
    s.hull = False; s.txd, s.lod = 'rox_police_txd', 500
    g = G / 2
    R = dict(ceil='paint_black', base='metal_dark', H=H)
    # south row
    s.room('briefing', XA, YA, -8 - g, CORR[0] - g, floor='carpet', wall='paint_white', **R)
    s.room('lobby', -8 + g, YA, 8 - g, CORR[0] - g, floor='tile_white', wall='paint_white', **R)
    s.room('bullpen', 8 + g, YA, XB, CORR[0] - g, floor='carpet', wall='paint_white', **R)
    s.room('corridor', XA, CORR[0] + g, XB, CORR[1] - g, floor='tile_white', wall='paint_white', **R)
    # north row
    s.room('office1', XA, CORR[1] + g, -12 - g, 8 - g, floor='carpet', wall='paint_white', **R)
    s.room('office2', XA, 8 + g, -12 - g, YB, floor='carpet', wall='paint_white', **R)
    s.room('booking', -12 + g, CORR[1] + g, -4 - g, 8 - g, floor='concrete_floor', wall='paint_grey', **R)
    s.room('interrog', -12 + g, 8 + g, -4 - g, YB, floor='concrete_floor', wall='paint_charcoal', **R)
    s.room('cells', -4 + g, CORR[1] + g, 10 - g, YB, floor='concrete_floor', wall='paint_grey', **R)
    s.room('lockers', 10 + g, CORR[1] + g, XB, 8 - g, floor='tile_white', wall='paint_white', **R)
    s.room('chief', 10 + g, 8 + g, XB, YB, floor='parquet', wall='paint_white', **R)

    # doors: lobby front (glass entrance), lobby <-> corridor, rooms <-> corridor
    s.door('lobby', 'S', -2.0, 2.0, h=3.2, casing='metal_dark')
    s.door('lobby', 'N', -2.0, 2.0, to='corridor', kind='door', h=3.0, casing='metal_dark')
    s.door('briefing', 'N', -12.0, -10.4, to='corridor', h=2.4, casing='metal_dark', leaf='l', leaf_mat='door_black', leaf_angle=95)
    s.door('bullpen', 'N', 10.4, 12.4, to='corridor', h=2.4, casing='metal_dark')
    s.door('bullpen', 'W', -14.0, -8.0, to='lobby', kind='open')
    s.door('corridor', 'N', -19.0, -17.6, to='office1', h=2.3, casing='metal_dark', leaf='l', leaf_mat='door_black', leaf_angle=90)
    s.door('corridor', 'N', -9.0, -7.6, to='booking', h=2.3, casing='metal_dark', leaf='l', leaf_mat='door_grey', leaf_angle=95)
    s.door('corridor', 'N', 2.0, 4.0, to='cells', h=2.4, casing='steel')
    s.door('corridor', 'N', 16.0, 17.4, to='lockers', h=2.3, casing='metal_dark', leaf='l', leaf_mat='door_grey', leaf_angle=95)
    s.door('office1', 'N', -19.0, -17.6, to='office2', h=2.3, casing='metal_dark', leaf='l', leaf_mat='door_black', leaf_angle=90)
    s.door('booking', 'N', -9.0, -7.6, to='interrog', h=2.3, casing='steel', leaf='l', leaf_mat='door_grey', leaf_angle=80)
    s.door('lockers', 'N', 16.0, 17.4, to='chief', h=2.3, casing='metal_dark', leaf='l', leaf_mat='door_wood', leaf_angle=95)
    # big windows (glass seen from outside = black glass, from inside = city view)
    for rm, sd, c0, c1 in [('briefing', 'S', -22, -10), ('bullpen', 'S', 10, 22), ('lobby', 'S', -7, -3), ('lobby', 'S', 3, 7),
                           ('office1', 'W', 0, 7), ('office2', 'W', 9, 16), ('chief', 'E', 9, 16), ('chief', 'N', 12, 22), ('bullpen', 'E', -16, -6)]:
        s.window(rm, sd, c0, c1, sill=0.6, head=3.3, glass='city_view', frame='metal_dark', cols=max(2, int((c1 - c0) / 1.6)), depth=0.3)
    s.entry = (0.0, YA - 1.5, 1.0, 0.0)
    s.build_rooms()
    dress(s)
    exterior(s)
    s.meta = dict(model='rox_police_hq')
    return s


def led_lines(s, x0, y0, x1, y1, sp=3.0, along='x'):
    if along == 'x':
        y = y0 + sp / 2
        while y < y1:
            s.box('led_white', x0 + 0.8, y - 0.035, H - 0.05, x1 - 0.8, y + 0.035, H - 0.002); y += sp
    else:
        x = x0 + sp / 2
        while x < x1:
            s.box('led_white', x - 0.035, y0 + 0.8, H - 0.05, x + 0.035, y1 - 0.8, H - 0.002); x += sp


def oak_wall(s, x0, y0, x1, y1, z1=H, face='y'):
    s.box('oak_panel', x0, y0, 0, x1, y1, z1, faces=face, step=1.2)


def dress(s):
    r = s.rooms
    for name, rm in r.items():
        led_lines(s, rm['x0'], rm['y0'], rm['x1'], rm['y1'], sp=3.0 if name != 'corridor' else 2.0,
                  along='y' if name == 'corridor' else 'x')
        cx, cy = (rm['x0'] + rm['x1']) / 2, (rm['y0'] + rm['y1']) / 2
        nx = max(1, int((rm['x1'] - rm['x0']) / 6)); ny = max(1, int((rm['y1'] - rm['y0']) / 6))
        for i in range(nx):
            for j in range(ny):
                x = rm['x0'] + (i + 0.5) * (rm['x1'] - rm['x0']) / nx; y = rm['y0'] + (j + 0.5) * (rm['y1'] - rm['y0']) / ny
                s.light(x, y, H - 0.3, color=(255, 246, 232), intensity=5.0, falloff=9.0)
    # lobby: oak badge wall behind reception, oak side columns, reception counter, ROX badge
    L = r['lobby']
    oak_wall(s, L['x0'] + 2, L['y1'] - 0.08, L['x1'] - 2, L['y1'], face='y')
    s.surf('police_badge', (-1.6, L['y1'] - 0.1, 1.9), X, Z, 3.2, 3.2 * 0.0 + 3.2 - 1.2, step=0, fit=True) if False else \
        s.surf('police_badge', (-1.3, L['y1'] - 0.1, 1.5), X, Z, 2.6, 2.3, step=0, fit=True)
    for x in (L['x0'] + 0.01, L['x1'] - 0.31):
        s.box('oak_panel', x, L['y0'] + 0.5, 0, x + 0.3, L['y1'] - 0.5, H, faces='xXyY', step=1.2)
    s.box('oak_panel', -3.5, -9.2, 0, 3.5, -8.4, 1.1, faces='xXyYZ', step=1.2); s.cbox(-3.5, -9.2, 0, 3.5, -8.4, 1.1, 70)
    s.box('marble_dark' if False else 'paint_charcoal', -3.6, -9.3, 1.1, 3.6, -8.3, 1.16)
    s.box('led_white', -3.5, -9.22, 0.05, 3.5, -9.2, 0.09)
    s.box('steel', -3.5, -8.0, 0, -3.3, -7.8, 1.05); s.box('steel', 3.3, -8.0, 0, 3.5, -7.8, 1.05)   # security gates
    # briefing: oak front wall with badge + screen panel
    B = r['briefing']
    oak_wall(s, B['x0'] + 0.01, B['y0'] + 2, B['x0'] + 0.09, B['y1'] - 2, face='X')
    s.surf('police_badge', (B['x0'] + 0.1, -9.6, 1.6), Y, Z, 2.2, 2.0, step=0, fit=True)
    s.box('podium' if False else 'wood_dark', B['x0'] + 2.0, -12.0, 0, B['x0'] + 2.6, -11.2, 1.15, faces='xXyYZ'); s.cbox(B['x0'] + 2.0, -12.0, 0, B['x0'] + 2.6, -11.2, 1.15, 70)
    # bullpen: oak back wall + glass partition to corridor (frames)
    P = r['bullpen']
    oak_wall(s, P['x0'] + 2, P['y1'] - 0.08, P['x1'] - 0.5, P['y1'], face='y')
    # corridor: oak wainscot strips + LED
    C = r['corridor']
    for yy, f in ((C['y0'] + 0.04, 'Y'), (C['y1'] - 0.04, 'y')):
        s.box('oak_panel', C['x0'] + 0.5, yy - 0.04, 0, C['x1'] - 0.5, yy + 0.04, 1.1, faces=f, step=1.2)
    # booking: mugshot height chart + bench
    K = r['booking']
    s.surf('height_chart', (K['x0'] + 0.03, 4.6, 0.0), -Y, Z, 2.4, 2.4, step=0, fit=True) if False else \
        s.surf('height_chart', (K['x0'] + 0.03, 2.4, 0.0), Y, Z, 2.4, 2.4, step=0, fit=True)
    s.box('steel', K['x1'] - 0.6, K['y0'] + 1, 0.45, K['x1'] - 0.02, K['y1'] - 1, 0.5); s.cbox(K['x1'] - 0.6, K['y0'] + 1, 0, K['x1'] - 0.02, K['y1'] - 1, 0.5, 56)
    # interrogation: one-way mirror band (black glass) + table base
    I = r['interrog']
    s.box('black_glass', I['x0'] + 1.0, I['y0'] + 0.01, 1.0, I['x1'] - 1.0, I['y0'] + 0.04, 2.4, faces='Y')
    # cells: 4 cells along the east wall with steel bars, sliding gate gap, bunk + toilet blocks
    Cl = r['cells']; cw = (Cl['y1'] - Cl['y0']) / 4; xb = Cl['x1'] - 4.0
    for k in range(5):
        y = Cl['y0'] + k * cw
        s.box('paint_grey', xb, y - 0.1, 0, Cl['x1'], y + 0.1, H, faces='xXyY'); s.cbox(xb, y - 0.1, 0, Cl['x1'], y + 0.1, H, 101)
    for k in range(4):
        y0 = Cl['y0'] + k * cw + 0.1; y1 = y0 + cw - 0.2
        for yy in np.arange(y0 + 0.12, y1, 0.14):
            if y0 + 0.6 < yy < y0 + 1.6: continue        # open gate
            s.box('steel', xb - 0.025, yy - 0.02, 0, xb + 0.025, yy + 0.02, 2.6)
        s.box('steel', xb - 0.05, y0, 2.6, xb + 0.05, y1, 2.7); s.box('steel', xb - 0.05, y0, 1.0, xb + 0.05, y1, 1.05)
        s.cbox(xb - 0.03, y0, 0, xb + 0.03, y0 + 0.6, 2.7, 56); s.cbox(xb - 0.03, y0 + 1.6, 0, xb + 0.03, y1, 2.7, 56)
        s.box('steel', Cl['x1'] - 0.8, y0 + 0.1, 0.45, Cl['x1'] - 0.02, y1 - 0.1, 0.55); s.cbox(Cl['x1'] - 0.8, y0 + 0.1, 0, Cl['x1'] - 0.02, y1 - 0.1, 0.55, 56)
        s.box('steel', xb + 0.3, y1 - 0.6, 0, xb + 0.8, y1 - 0.1, 0.45)
    # chief: oak walls + badge
    Q = r['chief']
    oak_wall(s, Q['x0'] + 0.01, Q['y0'] + 0.5, Q['x0'] + 0.09, Q['y1'] - 0.5, face='X')
    s.surf('police_badge', (Q['x0'] + 0.1, 11.0, 1.4), Y, Z, 1.6, 1.6, step=0, fit=True)
    # offices: oak accent wall
    for nm in ('office1', 'office2'):
        O = r[nm]; oak_wall(s, O['x1'] - 0.09, O['y0'] + 0.5, O['x1'] - 0.01, O['y1'] - 0.5, face='x')


def exterior(s):
    t = 0.35; x0, y0, x1, y1 = XA - G, YA - G, XB + G, YB + G
    zt = H + 0.6
    # outer walls: dark stone + oak band, holes for the windows/door come from room cuts -> build a facade shell with matching holes
    sides = [((x1, y0, 0), -X, x1 - x0, 'S'), ((x0, y1, 0), X, x1 - x0, 'N'), ((x0, y0, 0), Y, y1 - y0, 'W'), ((x1, y1, 0), -Y, y1 - y0, 'E')]
    rooms_on = {'S': ['briefing', 'lobby', 'bullpen'], 'N': ['office2', 'interrog', 'cells', 'chief'], 'W': ['briefing', 'corridor', 'office1', 'office2'],
                'E': ['bullpen', 'corridor', 'lockers', 'chief']}
    for O, U, Lw, sd in sides:
        O = np.array(O, float); holes = []
        for rm in rooms_on[sd]:
            Ro, Ru, Rn, RL = s.frame(rm, sd)
            for a0, z0, a1, z1, kind in s.holes[(rm, sd)]:
                p0 = Ro + Ru * a0; p1 = Ro + Ru * a1
                u0 = float(np.dot(p0 - O, U)); u1 = float(np.dot(p1 - O, U))
                holes.append((min(u0, u1), z0, max(u0, u1), z1))
        Nout = np.cross(Z, U); E = O + U * Lw          # outward normal; draw from the far end so the face looks out
        hl = [(Lw - u1, z0, Lw - u0, z1) for (u0, z0, u1, z1) in holes]
        s.surf('concrete_wall', E + Nout * t, -U, Z, Lw, zt, holes=hl, step=2.0)
        for (u0, z0, u1, z1) in hl:
            if z0 > 0.1: s.surf('black_glass', E + Nout * (t - 0.06) - U * u0 + Z * z0, -U, Z, u1 - u0, z1 - z0, step=0, fit=True)
        s.box('led_white', *(lambda a, b: (min(a[0], b[0]) - 0.02, min(a[1], b[1]) - 0.02, zt - 0.08, max(a[0], b[0]) + 0.02, max(a[1], b[1]) + 0.02, zt - 0.02))(O + Nout * (t + 0.02), O + U * Lw + Nout * (t + 0.02)), faces='xXyYz')
    # wall tops + roof slab with the helipad
    s.box('concrete_wall', x0 - t, y0 - t, H, x1 + t, y1 + t, zt, faces='Z'); s.cbox(x0 - t, y0 - t, H, x1 + t, y1 + t, zt, 1)
    for a, b, c, d in [(x0 - t, y0 - t, x1 + t, y0), (x0 - t, y1, x1 + t, y1 + t), (x0 - t, y0, x0, y1), (x1, y0, x1 + t, y1)]:
        s.cbox(a, b, 0, c, d, zt, 1)
    s.box('concrete_wall', x0 - t, y0 - t, zt, x1 + t, y1 + t, zt + 1.0, faces='xXyY')         # parapet outside
    s.cyl('floor_blue', 8.0, 4.0, zt, 7.0, 0.08, seg=40); s.cyl('led_white', 8.0, 4.0, zt + 0.08, 6.7, 0.03, seg=40, caps=False)
    for bx in ((6.4, 1.0, 6.9, 7.0), (9.1, 1.0, 9.6, 7.0), (6.9, 3.75, 9.1, 4.25)):       # the H
        s.box('paint_white', bx[0], bx[1], zt + 0.08, bx[2], bx[3], zt + 0.1, faces='Z')
    s.cbox(1.0, -3.0, zt, 15.0, 11.0, zt + 0.08, 1)
    # entrance canopy + sign
    s.box('metal_dark', -5.0, y0 - t - 3.0, 3.6, 5.0, y0 - t, 3.9); s.box('led_white', -5.0, y0 - t - 3.02, 3.55, 5.0, y0 - t - 2.98, 3.6)
    s.surf('sign_police', (-4.0, y0 - t - 0.02, 4.0), X, Z, 8.0, 1.0, step=0, fit=True)
    s.surf('police_badge', (-11.5, y0 - t - 0.02, 1.0), X, Z, 2.6, 2.6, step=0, fit=True)
    s.bb = (x0 - 16, y0 - 16, -0.3, x1 + 16, y1 + 16, zt + 2)


def all_pieces():
    return [build()]
