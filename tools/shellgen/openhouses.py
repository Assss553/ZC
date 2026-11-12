# ROX open houses: two-storey walk-in interiors that sit inside real map houses  (c) ROX Store
# No outer hull, real window openings (you see the street), an open front door and a staircase.
# Origin = centre of the footprint at ground level, front door on the -Y side.
import math
import numpy as np
from kit import Shell, X, Y, Z

T = 0.15          # inner wall thickness
SW = 1.6          # stairwell width
RISE, RUN, STEPS = 0.2, 0.25, 15
YB = 1.0          # bottom landing depth
YK = YB + STEPS * RUN   # 4.75: depth of the front rooms
UP = RISE * STEPS       # 3.0: upper floor level


class Plan:
    """Thin wrapper: plan coordinates 0..W / 0..D, optional mirror, centred on the origin."""
    def __init__(p, s, W, D, mirror):
        p.s, p.W, p.D, p.m = s, W, D, mirror

    def x(p, v): return (p.W - v if p.m else v) - p.W / 2
    def y(p, v): return v - p.D / 2
    def sd(p, side): return {'E': 'W', 'W': 'E'}.get(side, side) if p.m else side

    def rng(p, side, c0, c1):
        if side in 'NS': return tuple(sorted((p.x(c0), p.x(c1))))
        return p.y(c0), p.y(c1)

    def room(p, name, x0, y0, x1, y1, **kw):
        a, b = sorted((p.x(x0), p.x(x1)))
        p.s.room(name, a, p.y(y0), b, p.y(y1), **kw)

    def door(p, room, side, c0, c1, **kw):
        a, b = p.rng(side, c0, c1); p.s.door(room, p.sd(side), a, b, **kw)

    def window(p, room, side, c0, c1, **kw):
        a, b = p.rng(side, c0, c1); p.s.window(room, p.sd(side), a, b, glass=None, **kw)

    def kitchen(p, room, side, c0, c1, **kw):
        a, b = p.rng(side, c0, c1); p.s.kitchen(room, p.sd(side), a, b, **kw)

    def wardrobe(p, room, side, c0, c1, **kw):
        a, b = p.rng(side, c0, c1); p.s.wardrobe(room, p.sd(side), a, b, **kw)

    def box(p, mat, x0, y0, z0, x1, y1, z1, **kw):
        a, b = sorted((p.x(x0), p.x(x1)))
        p.s.box(mat, a, p.y(y0), z0, b, p.y(y1), z1, **kw)

    def lamp(p, x, y, H, big=False):
        p.s.led_panel(p.x(x), p.y(y), H, 0.6 if big else 0.45, intensity=5 if big else 3.5, falloff=8 if big else 6)

    def wins(p, room, side, c0, c1, n=None, w=1.4, sill=0.9, head=2.15, cols=2, **kw):
        """Evenly spaced see-through windows on an outside wall range."""
        L = c1 - c0
        n = n if n is not None else max(1, int(L / 3.2))
        if L < w + 0.6: return
        for k in range(n):
            c = c0 + L * (k + 0.5) / n
            p.window(room, side, c - w / 2, c + w / 2, sill=sill, head=head, cols=cols, **kw)

    def bath(p, x0, y0, x1, y1):
        """Tub along the back wall, basin + toilet."""
        p.box('tile_white', x0 + 0.05, y1 - 0.8, 0, x0 + 1.75, y1 - 0.05, 0.55, col=81, occ=True)
        p.box('appliance', x0 + 0.12, y1 - 0.73, 0.5, x0 + 1.68, y1 - 0.12, 0.56, faces='Z')
        p.box('steel', x0 + 0.1, y1 - 0.47, 0.56, x0 + 0.16, y1 - 0.41, 0.78)
        bx = x1 - 0.75
        p.box('wood_dark', bx, y1 - 0.5, 0, x1 - 0.05, y1 - 0.02, 0.8, col=70, occ=True)
        p.box('countertop', bx - 0.02, y1 - 0.52, 0.8, x1 - 0.03, y1 - 0.02, 0.84)
        p.box('appliance', bx + 0.14, y1 - 0.42, 0.84, x1 - 0.2, y1 - 0.12, 0.9)
        p.box('window_dark', bx + 0.05, y1 - 0.035, 1.15, x1 - 0.1, y1 - 0.02, 1.95)
        tx = x1 - 0.5
        p.box('appliance', tx, y0 + 0.05, 0, tx + 0.4, y0 + 0.25, 0.85, col=56)
        p.box('appliance', tx, y0 + 0.25, 0, tx + 0.4, y0 + 0.72, 0.42, col=56)
        p.box('trim', tx - 0.01, y0 + 0.25, 0.42, tx + 0.41, y0 + 0.73, 0.45)


def house(name, label, label_ar, W, D, fw, mirror, st, tag):
    H = 2.7
    g = Shell(name, label, label_ar, H=H); g.hull = False
    u = Shell(name + '_u', label, label_ar, H=H); u.hull = False
    P, Q = Plan(g, W, D, mirror), Plan(u, W, D, mirror)
    xl = W - SW - T - fw - T          # right edge of the big left side
    fx0, fx1 = xl + T, W - SW - T     # foyer x range
    sx0, sx1 = W - SW, W
    big = xl >= 8.0
    xm = round(xl * 0.56, 2)          # split of the left side in wide houses
    wall, wall2, trim = st['wall'], st['wall2'], st.get('trim', 'trim')

    # ------------------------------------------------ ground floor
    kw = dict(floor=st['floor'], wall=wall, crown=st.get('crown', False), wains=st.get('wains'))
    if big:
        P.room('living', 0, 0, xm, D, floor_rot=st.get('rot', 0.0), **kw)
        P.room('dining', xm + T, 0, xl, D, **kw)
        P.door('living', 'E', 1.0, D - 1.0, to='dining', kind='open')
    else:
        P.room('living', 0, 0, xl, D, floor_rot=st.get('rot', 0.0), **kw)
    left = 'dining' if big else 'living'
    P.room('foyer', fx0, 0, fx1, YK, floor=st['hall'], wall=wall2, crown=st.get('crown', False))
    P.room('stair', sx0, 0, sx1, YK, floor=st['hall'], wall=wall2, ceil=None, H=UP, base=None)
    P.room('kitchen', fx0, YK + T, W, D, floor=st['kfloor'], wall=wall2, wains=st.get('kwains'))
    P.door(left, 'E', 1.0, min(3.6, YK - 0.6), to='foyer', kind='open')
    P.door('foyer', 'E', 0.05, 0.95, to='stair', kind='open')
    P.door('foyer', 'N', fx0 + 0.35, fx0 + 1.25, to='kitchen', casing=trim)
    if D - YK - T >= 3.2:
        P.door(left, 'E', YK + T + 0.6, D - 0.6, to='kitchen', kind='open')
    # front door: real opening with its own leaf standing open
    dc = (fx0 + fx1) / 2
    dw = st.get('door_w', 1.0)
    a, b = P.rng('S', dc - dw / 2, dc + dw / 2)
    g.door('foyer', 'S', a, b, h=2.12, casing=trim)
    la, lb = g.local('foyer', 'S', a, b)
    g._reveal('foyer', 'S', la, lb, 0, 2.12, 0.2, trim, back=None)
    g.door_leaf('foyer', 'S', (a, P.y(0)), dw, 2.1, 'l', st['door'], 105)
    if st.get('sidelights'):
        for c in (dc - dw / 2 - 0.55, dc + dw / 2 + 0.55):
            if fx0 + 0.3 < c - 0.2 and c + 0.2 < fx1 - 0.1:
                P.window('foyer', 'S', c - 0.2, c + 0.2, sill=0.3, head=2.1, cols=1, sillboard=False)
    g.entry = (float(P.x(dc)), float(P.y(1.2)), 1.0, 0.0)
    # windows you can look out of
    P.wins('living', 'S', 0.4, (xm if big else xl) - 0.4, w=st.get('win_w', 1.5), sill=st.get('sill', 0.8), cols=st.get('cols', 2), rows=st.get('rows', 1))
    P.wins('living', 'W', 0.6, D - 0.6, sill=st.get('sill', 0.8), cols=st.get('cols', 2), rows=st.get('rows', 1))
    P.wins('living', 'N', 0.4, (xm if big else xl) - 0.4, w=st.get('win_w', 1.5), cols=st.get('cols', 2), rows=st.get('rows', 1))
    if big:
        P.wins('dining', 'S', xm + T + 0.4, xl - 0.4, n=1, w=1.6, sill=0.8, cols=3)
        P.wins('dining', 'N', xm + T + 0.4, xl - 0.4, n=1, w=1.6, cols=3)
    P.wins('kitchen', 'E', YK + T + 0.3, D - 0.3, n=1, w=1.2, sill=1.1, head=2.1)
    P.kitchen('kitchen', 'N', fx0 + 0.15, W - 0.15)
    # staircase: solid steps + smooth ramp collision
    a, b = sorted((P.x(sx0), P.x(sx1)))
    for i in range(STEPS):
        y0, zt = P.y(YB + i * RUN), (i + 1) * RISE
        g.box(st['step'], a, y0, 0, b, y0 + RUN + 0.02, zt, faces='Z')
        g.box(st.get('riser', 'trim'), a, y0, zt - RISE, b, y0 + 0.01, zt, faces='y')
        g.box(st['step'], a, y0 - 0.025, zt - 0.035, b, y0 + 0.01, zt, faces='yzZ')          # nosing
        g.occ.append((a, y0, 0, b, y0 + RUN, zt))
    p0, p1 = np.array([a, P.y(YB) - 0.02, 0.0]), np.array([b, P.y(YB) - 0.02, 0.0])
    p2, p3 = np.array([b, P.y(YK), UP]), np.array([a, P.y(YK), UP])
    g.ctris += [(p0, p1, p2, 72), (p0, p2, p3, 72)]
    for side_x, sg in ((a, 1), (b, -1)):                                                    # stringer + stepped handrail on both walls
        for i in range(STEPS):
            y0, zt = P.y(YB + i * RUN), (i + 1) * RISE
            g.box('trim', side_x, y0, zt, side_x + sg * 0.02, y0 + RUN, zt + 0.12)
            g.box(st.get('rail', 'wood_dark'), side_x + sg * 0.05, y0 - 0.01, zt + 0.86, side_x + sg * 0.1, y0 + RUN + 0.01, zt + 0.91)
            if i % 4 == 0:
                g.box('steel', side_x, y0 + 0.1, zt + 0.87, side_x + sg * 0.05, y0 + 0.13, zt + 0.9)
    # lights
    P.lamp((xm if big else xl) / 2, D * 0.3, H, True); P.lamp((xm if big else xl) / 2, D * 0.72, H, True)
    if big: P.lamp((xm + T + xl) / 2, D * 0.3, H, True); P.lamp((xm + T + xl) / 2, D * 0.72, H, True)
    P.lamp((fx0 + fx1) / 2, YK / 2, H); P.lamp((fx0 + W) / 2, (YK + T + D) / 2, H, True)
    for (r, sdn, c) in (('living', 'N', 1.0), ('living', 'S', 0.8), ('kitchen', 'E', YK + T + 0.3)):
        a_, b_ = P.rng(sdn, c, c + 0.1); g.outlet(r, P.sd(sdn), a_)
    g.build_rooms()

    # ------------------------------------------------ upper floor
    ukw = dict(floor=st['ufloor'], crown=st.get('crown', False))
    Q.room('stairU', sx0, 0, sx1, YK, floor=None, wall=wall2, base=None)
    Q.room('bed1', fx0, 0, fx1, YK, wall=st['bed'][0], **ukw)
    corridor = D >= 9.0
    beds = [('bed1', (fx0 + fx1) / 2, YK / 2)]
    if corridor:
        cy0, cy1 = YK + T, YK + T + 1.5
        by0 = cy1 + T
        Q.room('hallU', 0, cy0, W, cy1, floor=st['hall'], wall=wall2)
        Q.door('hallU', 'S', sx0 + 0.05, sx1 - 0.05, to='stairU', kind='open')
        Q.door('bed1', 'N', fx0 + 0.3, fx0 + 1.2, to='hallU', casing=trim, leaf='l', leaf_mat=st.get('idoor', 'door_wood'))
        fronts = [('master', 0, xm if big else xl)] + ([('bed2', xm + T, xl)] if big else [])
        for i, (nm, a0, a1) in enumerate(fronts):
            Q.room(nm, a0, 0, a1, YK, wall=st['bed'][(i + 1) % len(st['bed'])], **ukw)
            Q.door(nm, 'N', a1 - 1.4, a1 - 0.5, to='hallU', casing=trim, leaf='r', leaf_mat=st.get('idoor', 'door_wood'))
            Q.wins(nm, 'S', a0 + 0.4, a1 - 0.4, w=st.get('win_w', 1.5), cols=st.get('cols', 2), rows=st.get('rows', 1))
            beds.append((nm, (a0 + a1) / 2, YK / 2))
        Q.wins('master', 'W', 0.6, YK - 0.6, n=1)
        bx = W - 3.0
        backs = [('bed3', 0, (xm if big else bx - T))] + ([('bed4', xm + T, bx - T)] if big else [])
        for i, (nm, a0, a1) in enumerate(backs):
            Q.room(nm, a0, by0, a1, D, wall=st['bed'][(i + 2) % len(st['bed'])], **ukw)
            Q.door(nm, 'S', a0 + 0.5, a0 + 1.4, to='hallU', casing=trim, leaf='l', leaf_mat=st.get('idoor', 'door_wood'))
            Q.wins(nm, 'N', a0 + 0.4, a1 - 0.4, n=1, w=st.get('win_w', 1.5), cols=st.get('cols', 2), rows=st.get('rows', 1))
            beds.append((nm, (a0 + a1) / 2, (by0 + D) / 2))
        Q.wins('bed3', 'W', by0 + 0.3, D - 0.3, n=1, w=1.2)
        Q.room('bath', bx, by0, W, D, floor='tile_white', wall='paint_white', wains=(st.get('btile', 'tile_white'), 1.5), base=None)
        Q.door('bath', 'S', bx + 0.3, bx + 1.1, to='hallU', casing=trim, leaf='l', leaf_mat=st.get('idoor', 'door_wood'))
        Q.window('bath', 'E', by0 + 0.5, by0 + 1.2, sill=1.5, head=2.1, cols=1)
        Q.bath(bx, by0, W, D)
        Q.window('hallU', 'W', cy0 + 0.25, cy1 - 0.25, sill=0.9, head=2.15, cols=1)
        Q.lamp(W * 0.25, (cy0 + cy1) / 2, H); Q.lamp(W * 0.7, (cy0 + cy1) / 2, H); Q.lamp((bx + W) / 2, (by0 + D) / 2, H)
    else:
        Q.room('lounge', fx0, YK + T, W, D, floor=st['hall'], wall=wall2)
        Q.door('lounge', 'S', sx0 + 0.05, sx1 - 0.05, to='stairU', kind='open')
        Q.door('bed1', 'N', fx0 + 0.3, fx0 + 1.2, to='lounge', casing=trim, leaf='l', leaf_mat=st.get('idoor', 'door_wood'))
        Q.wins('lounge', 'N', fx0 + 0.3, W - 0.3, n=1, w=1.6, cols=3)
        Q.wins('lounge', 'E', YK + T + 0.3, D - 0.3, n=1, w=1.2)
        ys = YK + T + 1.2
        has_bath = D - ys - T >= 1.7
        Q.room('master', 0, 0, xl, ys if has_bath else D, wall=st['bed'][1 % len(st['bed'])], **ukw)
        Q.door('master', 'E', YK + T + 0.15, YK + T + 1.05, to='lounge', casing=trim, leaf='l', leaf_mat=st.get('idoor', 'door_wood'))
        Q.wins('master', 'S', 0.4, xl - 0.4, w=st.get('win_w', 1.5), cols=st.get('cols', 2), rows=st.get('rows', 1))
        Q.wins('master', 'W', 0.6, (ys if has_bath else D) - 0.6, n=1)
        beds.append(('master', xl / 2, YK / 2))
        if has_bath:
            Q.room('bath', 0, ys + T, xl, D, floor='tile_white', wall='paint_white', wains=(st.get('btile', 'tile_white'), 1.5), base=None)
            Q.door('bath', 'E', ys + T + 0.2, ys + T + 1.0, to='lounge', casing=trim, leaf='r', leaf_mat=st.get('idoor', 'door_wood'))
            Q.window('bath', 'W', ys + T + 0.5, ys + T + 1.2, sill=1.5, head=2.1, cols=1)
            Q.bath(0, ys + T, xl, D)
            Q.lamp(xl / 2, (ys + T + D) / 2, H)
        else:
            Q.wins('master', 'N', 0.4, xl - 0.4, n=1)
        Q.lamp((fx0 + W) / 2, (YK + T + D) / 2, H, True)
    Q.wins('bed1', 'S', fx0 + 0.3, fx1 - 0.3, n=1, w=min(1.4, fx1 - fx0 - 1.0))
    Q.wardrobe('bed1', 'W', 0.4, 2.4)
    Q.wardrobe('master', 'E', 0.3, min(2.6, YK - 1.8))
    for (nm, cx, cy) in beds: Q.lamp(cx, cy, H, True)
    Q.lamp((sx0 + sx1) / 2, YK * 0.55, H)
    u.build_rooms()

    g.merge(u, UP)
    g.name = name
    g.meta = dict(model=name, label=label, labelAr=label_ar, w=round(W + 0.4, 2), d=round(D + 0.4, 2), doorX=round(float(P.x(dc)), 2),
                  rooms=len(g.rooms) - 3, tag=tag, image='images/%s.png' % name)
    g.txd, g.lod = 'rox_open_txd', 250
    return g


STYLES = dict(
    craftsman=dict(floor='planks', ufloor='planks', hall='planks', kfloor='tile_terra', wall='paint_cream', wall2='paint_sand', bed=['paint_sage', 'paint_cream'],
                   wains=('wainscot', 0.95), door='door_green', step='wood_dark', crown=True, rows=2),
    townhouse=dict(floor='parquet', ufloor='carpet', hall='parquet', kfloor='tile_white', wall='paint_white', wall2='paint_grey', bed=['paint_grey', 'paint_dkblue', 'paint_white'],
                   door='door_black', step='planks', riser='paint_white', sidelights=True, cols=3, idoor='door_grey', trim='trim'),
    ranch=dict(floor='planks', ufloor='carpet', hall='tile_beige', kfloor='tile_beige', wall='paint_sand', wall2='paint_cream', bed=['paint_blush', 'paint_sand', 'paint_sky'],
               door='door_red', step='wood_door', win_w=1.8, cols=3, kwains=('tile_white', 1.2)),
    cottage=dict(floor='planks', ufloor='planks', hall='tile_terra', kfloor='tile_terra', wall='wallpaper', wall2='paint_cream', bed=['paint_sky', 'paint_blush'],
                 wains=('wainscot', 0.95), door='door_blue', step='wood_dark', rows=2, sill=0.9, rot=90.0),
    villa=dict(floor='parquet', ufloor='parquet', hall='tile_beige', kfloor='tile_beige', wall='paint_white', wall2='paint_white', bed=['paint_cream', 'paint_grey', 'paint_sage'],
               door='door_wood', step='tile_beige', riser='tile_beige', door_w=1.2, sidelights=True, win_w=2.0, cols=3, sill=0.4, crown=True),
    beach=dict(floor='planks', ufloor='planks', hall='planks', kfloor='tile_white', wall='paint_white', wall2='paint_sky', bed=['paint_sky', 'paint_white'],
               door='door_yellow', step='planks', riser='paint_white', win_w=1.9, cols=2, sill=0.5, rail='steel'),
    family=dict(floor='planks', ufloor='carpet', hall='planks', kfloor='tile_beige', wall='paint_sage', wall2='paint_cream', bed=['paint_blush', 'paint_sky', 'paint_cream'],
                door='door_maroon', step='wood_dark', crown=True, cols=2, kwains=('tile_beige', 1.2)),
    mansion=dict(floor='parquet', ufloor='carpet', hall='tile_white', kfloor='tile_white', wall='paint_cream', wall2='paint_white', bed=['paint_dkblue', 'paint_cream', 'paint_maroon', 'paint_grey'],
                 wains=('wainscot', 1.0), door='door_white', step='wood_dark', riser='paint_white', door_w=1.3, sidelights=True, win_w=2.0, cols=3, rows=2, sill=0.5, crown=True, idoor='door_white'),
)

SPECS = [
    ('rox_open_cottage',   'ROX Cottage',        'كوخ ROX',            7.6,  7.6, 2.3, True,  'cottage',   'small'),
    ('rox_open_craftsman', 'ROX Craftsman',      'بيت ROX كرافتسمان',  8.4,  8.2, 2.5, False, 'craftsman', 'small'),
    ('rox_open_townhouse', 'ROX Townhouse',      'تاون هاوس ROX',      7.2, 10.2, 2.4, True,  'townhouse', 'narrow'),
    ('rox_open_beach',     'ROX Beach House',    'بيت الشاطئ ROX',     9.2,  9.6, 2.6, True,  'beach',     'medium'),
    ('rox_open_family',    'ROX Family Home',    'بيت العائلة ROX',   10.6,  8.6, 2.8, False, 'family',    'medium'),
    ('rox_open_ranch',     'ROX Ranch House',    'بيت ROX رانش',      12.4,  8.2, 3.0, False, 'ranch',     'wide'),
    ('rox_open_villa',     'ROX Villa',          'فيلا ROX',          14.2, 10.2, 3.2, False, 'villa',     'large'),
    ('rox_open_mansion',   'ROX Mansion',        'قصر ROX',           16.4, 11.6, 3.4, True,  'mansion',   'large'),
]


def all_pieces():
    return [house(n, l, la, W, D, fw, m, STYLES[st], tag) for (n, l, la, W, D, fw, m, st, tag) in SPECS]
