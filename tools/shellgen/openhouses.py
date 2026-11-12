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
    s.room('main', x0, y0, x1, y1, floor=st['floor'], wall=st['wall'], crown=st.get('crown', False), floor_rot=st.get('rot', 0.0))
    trim = 'trim'
    dw = st.get('door_w', 1.0)
    a, b = door_x - dw / 2, door_x + dw / 2
    s.door('main', 'S', a, b, h=2.12, casing=trim)
    la, lb = s.local('main', 'S', a, b)
    s._reveal('main', 'S', la, lb, 0, 2.12, 0.2, trim, back=None)
    s.door_leaf('main', 'S', (a, y0), dw, 2.1, 'l', st['door'], 105)
    s.entry = (float(door_x), float(y0 + 1.2), 1.0, 0.0)
    ww, cols, rows = st.get('win_w', 1.5), st.get('cols', 2), st.get('rows', 1)

    def row(side, c0, c1, sill, head, skip=None):
        L = c1 - c0
        n = max(1, int(L / 3.4))
        for k in range(n):
            c = c0 + L * (k + 0.5) / n
            if skip and abs(c - skip) < ww / 2 + dw / 2 + 0.45: continue
            s.window('main', side, c - ww / 2, c + ww / 2, sill=sill, head=head, glass=None, cols=cols, rows=rows)

    levels = [(st.get('sill', 0.85), 2.2)] + ([(3.75, 5.05)] if floors == 2 else [])
    for i, (sill, head) in enumerate(levels):
        row('S', x0 + 0.5, x1 - 0.5, sill, head, skip=door_x if i == 0 else None)
        row('N', x0 + 0.5, x1 - 0.5, sill, head)
        row('W', y0 + 0.5, y1 - 0.5, sill, head)
        row('E', y0 + 0.5, y1 - 0.5, sill, head)
    nx, ny = max(1, int(W / 4.5)), max(1, int(D / 4.5))
    for i in range(nx):
        for j in range(ny):
            s.led_panel(x0 + W * (i + 0.5) / nx, y0 + D * (j + 0.5) / ny, H, 0.6, intensity=6 if floors == 2 else 4.5, falloff=11 if floors == 2 else 7)
    s.build_rooms()
    s.meta = dict(model=name, label=label, labelAr=label_ar, w=round(W + 0.4, 2), d=round(D + 0.4, 2), doorX=round(door_x, 2),
                  rooms=1, floors=floors, tag=tag, image='images/%s.png' % name)
    s.txd, s.lod = 'rox_open_txd', 250
    return s


STYLES = dict(
    craftsman=dict(floor='planks', wall='paint_cream', door='door_green', crown=True, rows=2),
    townhouse=dict(floor='parquet', wall='paint_white', door='door_black', cols=3),
    ranch=dict(floor='planks', wall='paint_sand', door='door_red', win_w=1.8, cols=3),
    cottage=dict(floor='planks', wall='paint_cream', door='door_blue', rows=2, rot=90.0),
    villa=dict(floor='parquet', wall='paint_white', door='door_wood', door_w=1.2, win_w=2.0, cols=3, sill=0.5, crown=True),
    beach=dict(floor='planks', wall='paint_sky', door='door_yellow', win_w=1.9, sill=0.5),
    family=dict(floor='planks', wall='paint_sage', door='door_maroon', crown=True),
    mansion=dict(floor='parquet', wall='paint_cream', door='door_white', door_w=1.3, win_w=2.0, cols=3, rows=2, sill=0.5, crown=True),
    studio=dict(floor='concrete_floor', wall='paint_white', door='door_grey', win_w=1.4),
    bungalow=dict(floor='planks', wall='paint_blush', door='door_wood', rows=2),
    longhouse=dict(floor='tile_beige', wall='paint_sand', door='door_blue', win_w=1.6, cols=3),
    garden=dict(floor='parquet', wall='paint_sage', door='door_white', win_w=1.8, cols=3, sill=0.5),
    estate=dict(floor='tile_white', wall='paint_white', door='door_black', door_w=1.2, win_w=2.0, cols=3, sill=0.5, crown=True),
)

SPECS = [
    # two storeys high (one open volume)
    ('rox_open_cottage',   'ROX Cottage (2 floors, empty)',     'كوخ ROX (دورين، فاضي)',          7.6,  7.6, 2, -0.9, 'cottage',   'small'),
    ('rox_open_craftsman', 'ROX Craftsman (2 floors, empty)',   'كرافتسمان ROX (دورين، فاضي)',     8.4,  8.2, 2,  1.2, 'craftsman', 'small'),
    ('rox_open_townhouse', 'ROX Townhouse (2 floors, empty)',   'تاون هاوس ROX (دورين، فاضي)',     7.2, 10.2, 2, -0.6, 'townhouse', 'narrow'),
    ('rox_open_beach',     'ROX Beach House (2 floors, empty)', 'بيت الشاطئ ROX (دورين، فاضي)',    9.2,  9.6, 2, -1.5, 'beach',     'medium'),
    ('rox_open_family',    'ROX Family Home (2 floors, empty)', 'بيت العائلة ROX (دورين، فاضي)',  10.6,  8.6, 2,  2.1, 'family',    'medium'),
    ('rox_open_ranch',     'ROX Ranch House (2 floors, empty)', 'رانش ROX (دورين، فاضي)',         12.4,  8.2, 2,  2.9, 'ranch',     'wide'),
    ('rox_open_villa',     'ROX Villa (2 floors, empty)',       'فيلا ROX (دورين، فاضي)',         14.2, 10.2, 2,  0.0, 'villa',     'large'),
    ('rox_open_mansion',   'ROX Mansion (2 floors, empty)',     'قصر ROX (دورين، فاضي)',          16.4, 11.6, 2,  0.0, 'mansion',   'large'),
    # single storey
    ('rox_open1_studio',   'ROX Studio (1 floor, empty)',       'ستوديو ROX (دور واحد، فاضي)',     6.0,  6.0, 1,  0.0, 'studio',    'small'),
    ('rox_open1_bungalow', 'ROX Bungalow (1 floor, empty)',     'بنغلو ROX (دور واحد، فاضي)',      8.0,  7.0, 1, -1.5, 'bungalow',  'small'),
    ('rox_open1_long',     'ROX Long House (1 floor, empty)',   'البيت الطويل ROX (دور واحد، فاضي)', 6.6, 11.0, 1,  0.0, 'longhouse', 'narrow'),
    ('rox_open1_garden',   'ROX Garden House (1 floor, empty)', 'بيت الحديقة ROX (دور واحد، فاضي)', 11.0,  8.0, 1,  2.0, 'garden',    'wide'),
    ('rox_open1_estate',   'ROX Estate (1 floor, empty)',       'عزبة ROX (دور واحد، فاضي)',      14.0, 10.0, 1,  0.0, 'estate',    'large'),
]


def all_pieces():
    return [house(n, l, la, W, D, fl, dx, STYLES[st], tag) for (n, l, la, W, D, fl, dx, st, tag) in SPECS]
