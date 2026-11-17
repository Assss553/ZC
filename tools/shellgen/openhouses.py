# ROX open houses: EMPTY walk-in hulls that sit inside real map houses  (c) ROX Store
# One clear volume: no inner walls, no stairs, no slab between the storeys. Players build the inside
# themselves with the ROX build pieces (walls, floors, stairs ...) from the furniture shop.
# Origin = centre of the footprint at ground level, front door on the -Y side.
from kit import Shell

H1, H2 = 2.9, 5.8


def house(name, label, label_ar, W, D, floors, door_x, st, tag):
    H = H2 if floors == 2 else H1
    s = Shell(name, label, label_ar, H=H); s.hull = False
    x0, y0, x1, y1 = -W / 2, -D / 2, W / 2, D / 2
    s.room('main', x0, y0, x1, y1, floor=st['floor'], wall=st['wall'], crown=st.get('crown', False) and not st.get('lux'), floor_rot=st.get('rot', 0.0), wains=st.get('wains'))
    trim = 'trim'
    dw = st.get('door_w', 1.0)
    a, b = door_x - dw / 2, door_x + dw / 2
    s.door('main', 'S', a, b, h=2.12, casing=trim)
    la, lb = s.local('main', 'S', a, b)
    s._reveal('main', 'S', la, lb, 0, 2.12, 0.2, trim, back=None)
    s.door_leaf('main', 'S', (a, y0), dw, 2.1, 'l', st['door'], 105)
    s.entry = (float(door_x), float(y0 + 1.2), 1.0, 0.0)
    ww, cols, rows = st.get('win_w', 1.5), st.get('cols', 2), st.get('rows', 1)

    wins = {'S': [], 'N': [], 'W': [], 'E': []}

    def row(side, c0, c1, sill, head, skip=None):
        L = c1 - c0
        n = max(1, int(L / 3.4))
        for k in range(n):
            c = c0 + L * (k + 0.5) / n
            if skip and abs(c - skip) < ww / 2 + dw / 2 + 0.45: continue
            wins[side].append(c)
            s.window('main', side, c - ww / 2, c + ww / 2, sill=sill, head=head, glass=None, cols=cols, rows=rows)

    levels = [(st.get('sill', 0.85), 2.2)] + ([(3.75, 5.05)] if floors == 2 else [])
    for i, (sill, head) in enumerate(levels):
        row('S', x0 + 0.5, x1 - 0.5, sill, head, skip=door_x if i == 0 else None)
        row('N', x0 + 0.5, x1 - 0.5, sill, head)
        row('W', y0 + 0.5, y1 - 0.5, sill, head)
        row('E', y0 + 0.5, y1 - 0.5, sill, head)
    if st.get('lux'):
        luxury(s, st, W, D, H, floors, wins, door_x, dw, ww)
    nx, ny = max(1, int(W / 4.5)), max(1, int(D / 4.5))
    for i in range(nx if not st.get('lux') else 0):
        for j in range(ny):
            s.led_panel(x0 + W * (i + 0.5) / nx, y0 + D * (j + 0.5) / ny, H, 0.6, intensity=6 if floors == 2 else 4.5, falloff=11 if floors == 2 else 7)
    s.build_rooms()
    s.meta = dict(model=name, label=label, labelAr=label_ar, w=round(W + 0.4, 2), d=round(D + 0.4, 2), doorX=round(door_x, 2),
                  rooms=1, floors=floors, tag=tag, image='images/%s.png' % name)
    s.txd, s.lod = 'rox_open_txd', 250
    return s


def luxury(s, st, W, D, H, floors, wins, door_x, dw, ww):
    """Premium finish: still an empty room, but with pilasters, coffered ceiling, cove light,
    inlaid floor border + centre medallion, entry marble and a storey band on tall houses."""
    x0, y0, x1, y1 = -W / 2, -D / 2, W / 2, D / 2
    acc, band, inlay, med = st.get('acc', 'trim'), st.get('band', 'wood_dark'), st.get('inlay', 'wood_dark'), st.get('medallion', 'tile_white')
    # --- pilasters between the windows (base, shaft, capital) on every wall
    def pil(side, c):
        if side == 'S': a, b, n0, n1 = c - 0.2, c + 0.2, y0, y0 + 0.09; bx = lambda m, z0, z1, e=0: s.box(m, a - e, n0, z0, b + e, n1 + e, z1, faces='xXY', occ=True)
        elif side == 'N': a, b, n0, n1 = c - 0.2, c + 0.2, y1 - 0.09, y1; bx = lambda m, z0, z1, e=0: s.box(m, a - e, n0 - e, z0, b + e, n1, z1, faces='xXy', occ=True)
        elif side == 'W': a, b, n0, n1 = c - 0.2, c + 0.2, x0, x0 + 0.09; bx = lambda m, z0, z1, e=0: s.box(m, n0, a - e, z0, n1 + e, b + e, z1, faces='yYX', occ=True)
        else: a, b, n0, n1 = c - 0.2, c + 0.2, x1 - 0.09, x1; bx = lambda m, z0, z1, e=0: s.box(m, n0 - e, a - e, z0, n1, b + e, z1, faces='yYx', occ=True)
        top = H - (0.32 if st.get('coffer', True) else 0.12)
        bx(acc, 0, 0.32, 0.04); bx(acc, 0.32, top - 0.22); bx(acc, top - 0.22, top, 0.05)
        if floors == 2: bx(acc, 2.75, 3.0, 0.03)
    for side, (lo, hi) in (('S', (x0, x1)), ('N', (x0, x1)), ('W', (y0, y1)), ('E', (y0, y1))):
        cs = sorted(wins[side]); pts = []
        if side == 'S': cs = sorted(cs + [door_x])
        for i in range(len(cs) - 1): pts.append((cs[i] + cs[i + 1]) / 2)
        if cs: pts += [max(lo + 0.35, cs[0] - ww / 2 - 0.55), min(hi - 0.35, cs[-1] + ww / 2 + 0.55)]
        for c in pts:
            if lo + 0.3 < c < hi - 0.3 and all(abs(c - w) > ww / 2 + 0.3 for w in wins[side]) and not (side == 'S' and abs(c - door_x) < dw / 2 + 0.35):
                pil(side, c)
    # --- storey band on tall houses (shows where the upper floor sits)
    if floors == 2:
        for (a, b, c, d) in ((x0, y0, x1, y0 + 0.07), (x0, y1 - 0.07, x1, y1), (x0, y0, x0 + 0.07, y1), (x1 - 0.07, y0, x1, y1)):
            s.box(band, a, b, 2.86, c, d, 3.02, faces='xXyYzZ')
    # --- coffered ceiling + cove light
    if st.get('coffer', True):
        sp = st.get('coffer_sp', 2.4)
        nx, ny = max(2, round(W / sp)), max(2, round(D / sp))
        for i in range(1, nx):
            x = x0 + W * i / nx; s.box(acc, x - 0.09, y0, H - 0.3, x + 0.09, y1, H, faces='xXz')
        for j in range(1, ny):
            y = y0 + D * j / ny; s.box(acc, x0, y - 0.09, H - 0.3, x1, y + 0.09, H, faces='yYz')
        for (a, b, c, d) in ((x0, y0, x1, y0 + 0.3), (x0, y1 - 0.3, x1, y1), (x0, y0, x0 + 0.3, y1), (x1 - 0.3, y0, x1, y1)):
            s.box(acc, a, b, H - 0.3, c, d, H, faces='xXyYz')
        # hidden LED cove along the inner edge of the perimeter beam
        for (a, b, c, d, f) in ((x0 + 0.3, y0 + 0.3, x1 - 0.3, y0 + 0.32, 'Y'), (x0 + 0.3, y1 - 0.32, x1 - 0.3, y1 - 0.3, 'y'),
                                (x0 + 0.3, y0 + 0.3, x0 + 0.32, y1 - 0.3, 'X'), (x1 - 0.32, y0 + 0.3, x1 - 0.3, y1 - 0.3, 'x')):
            s.box('light', a, b, H - 0.33, c, d, H - 0.3, faces='z')
        # one downlight in the centre of every coffer
        for i in range(nx):
            for j in range(ny):
                cx, cy = x0 + W * (i + 0.5) / nx, y0 + D * (j + 0.5) / ny
                s.cyl('metal_dark', cx, cy, H - 0.02, 0.11, 0.02, seg=14); s.cyl('light', cx, cy, H - 0.025, 0.08, 0.005, seg=14)
                if (i + j) % 2 == 0 or nx * ny <= 6:
                    s.light(cx, cy, H - 0.4, color=(255, 232, 200), intensity=5.5 if floors == 2 else 4.0, falloff=11 if floors == 2 else 7)
    # --- inlaid floor: dark border band, centre medallion, marble entry
    bw = 0.32
    for (a, b, c, d) in ((x0 + 0.25, y0 + 0.25, x1 - 0.25, y0 + 0.25 + bw), (x0 + 0.25, y1 - 0.25 - bw, x1 - 0.25, y1 - 0.25),
                         (x0 + 0.25, y0 + 0.25 + bw, x0 + 0.25 + bw, y1 - 0.25 - bw), (x1 - 0.25 - bw, y0 + 0.25 + bw, x1 - 0.25, y1 - 0.25 - bw)):
        s.box(inlay, a, b, 0, c, d, 0.004, faces='Z')
    if st.get('medallion_on', True):
        r = min(W, D) * 0.16
        s.cyl(inlay, 0, 0, 0, r + 0.12, 0.005, seg=40, caps=True); s.cyl(med, 0, 0, 0.005, r, 0.002, seg=40); s.cyl(inlay, 0, 0, 0.007, r * 0.45, 0.002, seg=32)
    s.box(med, door_x - dw / 2 - 0.5, y0 + 0.02, 0, door_x + dw / 2 + 0.5, y0 + 1.7, 0.005, faces='Z')
    s.box(inlay, door_x - dw / 2 - 0.56, y0 + 0.02, 0, door_x + dw / 2 + 0.56, y0 + 1.76, 0.0045, faces='Z')
    # wall sconces beside the front door
    for c in (door_x - dw / 2 - 0.45, door_x + dw / 2 + 0.45):
        s.box('brass', c - 0.05, y0, 1.8, c + 0.05, y0 + 0.08, 2.0); s.box('light', c - 0.07, y0 + 0.08, 1.85, c + 0.07, y0 + 0.2, 2.05)
        s.light(c, y0 + 0.4, 1.95, color=(255, 214, 160), intensity=2.5, falloff=4)


STYLES = dict(
    craftsman=dict(floor='planks', wall='paint_cream', door='door_green', crown=True, rows=2),
    townhouse=dict(floor='parquet', wall='paint_white', door='door_black', cols=3),
    ranch=dict(floor='planks', wall='paint_sand', door='door_red', win_w=1.8, cols=3),
    cottage=dict(floor='planks', wall='paint_cream', door='door_blue', rows=2, rot=90.0),
    villa=dict(floor='parquet', wall='paint_white', door='door_wood', door_w=1.2, win_w=2.0, cols=3, sill=0.5, crown=True, lux=True, wains=('wainscot', 1.0), acc='trim', inlay='wood_dark', medallion='tile_white'),
    beach=dict(floor='planks', wall='paint_sky', door='door_yellow', win_w=1.9, sill=0.5, lux=True, acc='trim', band='planks', inlay='wood_door', medallion='tile_white', medallion_on=False),
    family=dict(floor='planks', wall='paint_sage', door='door_maroon', crown=True, lux=True, acc='trim', band='wood_door', inlay='wood_dark', medallion='tile_beige', coffer=False),
    mansion=dict(floor='parquet', wall='paint_cream', door='door_white', door_w=1.3, win_w=2.0, cols=3, rows=2, sill=0.5, crown=True, lux=True, acc='trim', band='wood_dark', inlay='wood_dark', medallion='countertop', coffer_sp=2.6),
    studio=dict(floor='concrete_floor', wall='paint_white', door='door_grey', win_w=1.4),
    bungalow=dict(floor='planks', wall='paint_blush', door='door_wood', rows=2),
    longhouse=dict(floor='tile_beige', wall='paint_sand', door='door_blue', win_w=1.6, cols=3),
    garden=dict(floor='parquet', wall='paint_sage', door='door_white', win_w=1.8, cols=3, sill=0.5),
    estate=dict(floor='tile_white', wall='paint_white', door='door_black', door_w=1.2, win_w=2.0, cols=3, sill=0.5, crown=True, lux=True, acc='trim', inlay='countertop', medallion='stone'),
)

SPECS = [
    # two storeys high (one open volume)
    ('rox_open_cottage',   'ROX Cottage (2 floors, empty)',     'كوخ ROX (دورين، فاضي)',          7.6,  7.6, 2, -0.9, 'cottage',   'small'),
    ('rox_open_craftsman', 'ROX Craftsman (2 floors, empty)',   'كرافتسمان ROX (دورين، فاضي)',     8.4,  8.2, 2,  1.2, 'craftsman', 'small'),
    ('rox_open_townhouse', 'ROX Townhouse (2 floors, empty)',   'تاون هاوس ROX (دورين، فاضي)',     7.2, 10.2, 2, -0.6, 'townhouse', 'narrow'),
    ('rox_open_beach',     'ROX Beach House PREMIUM (2 floors, empty)', 'بيت الشاطئ ROX بريميوم (دورين، فاضي)',    9.2,  9.6, 2, -1.5, 'beach',     'medium'),
    ('rox_open_family',    'ROX Family Home PREMIUM (2 floors, empty)', 'بيت العائلة ROX بريميوم (دورين، فاضي)',  10.6,  8.6, 2,  2.1, 'family',    'medium'),
    ('rox_open_ranch',     'ROX Ranch House (2 floors, empty)', 'رانش ROX (دورين، فاضي)',         12.4,  8.2, 2,  2.9, 'ranch',     'wide'),
    ('rox_open_villa',     'ROX Villa PREMIUM (2 floors, empty)',       'فيلا ROX بريميوم (دورين، فاضي)',         14.2, 10.2, 2,  0.0, 'villa',     'large'),
    ('rox_open_mansion',   'ROX Mansion PREMIUM (2 floors, empty)', 'قصر ROX بريميوم (دورين، فاضي)',          16.4, 11.6, 2,  0.0, 'mansion',   'large'),
    # single storey
    ('rox_open1_studio',   'ROX Studio (1 floor, empty)',       'ستوديو ROX (دور واحد، فاضي)',     6.0,  6.0, 1,  0.0, 'studio',    'small'),
    ('rox_open1_bungalow', 'ROX Bungalow (1 floor, empty)',     'بنغلو ROX (دور واحد، فاضي)',      8.0,  7.0, 1, -1.5, 'bungalow',  'small'),
    ('rox_open1_long',     'ROX Long House (1 floor, empty)',   'البيت الطويل ROX (دور واحد، فاضي)', 6.6, 11.0, 1,  0.0, 'longhouse', 'narrow'),
    ('rox_open1_garden',   'ROX Garden House (1 floor, empty)', 'بيت الحديقة ROX (دور واحد، فاضي)', 11.0,  8.0, 1,  2.0, 'garden',    'wide'),
    ('rox_open1_estate',   'ROX Estate PREMIUM (1 floor, empty)', 'عزبة ROX بريميوم (دور واحد، فاضي)',      14.0, 10.0, 1,  0.0, 'estate',    'large'),
]


def all_pieces():
    return [house(n, l, la, W, D, fl, dx, STYLES[st], tag) for (n, l, la, W, D, fl, dx, st, tag) in SPECS]
