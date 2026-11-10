# ROX shell generator - the house designs  (c) ROX Store
from kit import Shell

def apartment():
    """Modern apartment: living room, kitchen, two bedrooms, bathroom, hall."""
    s = Shell('rox_shell_apartment', 'ROX Modern Apartment', 'شقة ROX مودرن', H=2.7)
    t = 0.15
    s.room('living', -5.0, -4.0, 1.0, 1.5, floor='planks', wall='paint_white')
    s.room('kitchen', 1.0 + t, -4.0, 5.0, -0.6, floor='tile_beige', wall='paint_white')
    s.room('hall', 1.0 + t, -0.6 + t, 5.0, 1.5, floor='planks', wall='paint_white')
    s.room('bed1', -5.0, 1.5 + t, -0.6, 5.5, floor='carpet', wall='paint_grey')
    s.room('bath', -0.6 + t, 1.5 + t, 2.0, 5.5, floor='tile_beige', wall='paint_white', wains=('tile_white', 1.5), base=None)
    s.room('bed2', 2.0 + t, 1.5 + t, 5.0, 5.5, floor='carpet', wall='paint_cream')
    s.door('living', 'E', -3.4, -1.4, to='kitchen', kind='open')
    s.door('living', 'E', 0.0, 1.0, to='hall', h=2.1, casing='trim')
    s.door('living', 'N', -3.4, -2.5, to='bed1', leaf='l')
    s.door('hall', 'N', 1.3, 1.9 + 0.0, to='bath', leaf='r') if False else None
    s.door('bath', 'S', 0.9, 1.75, to='hall', leaf='l') if False else None
    s.door('hall', 'N', 2.4, 3.3, to='bed2', leaf='l')
    s.door('living', 'N', 0.0, 0.85, to='bath', leaf='r')
    s.entry_door('hall', 'E', 0.0, 0.95)
    s.window('living', 'W', -2.6, 0.2, sill=0.5, head=2.3, cols=3)
    s.window('living', 'S', -4.0, -1.0, sill=0.9, head=2.2, cols=3)
    s.window('kitchen', 'S', 2.2, 3.8, sill=1.1, head=2.1, cols=2)
    s.window('bed1', 'W', 2.6, 4.4, sill=0.9, head=2.2, cols=2, cover='blind')
    s.window('bed2', 'N', 2.9, 4.4, sill=0.9, head=2.2, cols=2, cover='shade')
    s.window('bath', 'N', 0.2, 1.0, sill=1.5, head=2.1, cols=1)
    s.kitchen('kitchen', 'E', -3.9, -0.8)
    s.wardrobe('bed1', 'E', 2.0, 5.4)
    s.build_rooms()
    for (x, y, ln, al) in ((-2.0, -1.25, 1.6, 'x'), (3.1, -2.3, 1.4, 'y'), (3.1, 0.5, 1.0, 'x'), (-2.8, 3.6, 1.4, 'x'), (3.6, 3.6, 1.2, 'x')):
        s.linear_light(x, y, 2.7, ln, al, drop=0.02)
    s.led_panel(0.75, 3.5, 2.7, 0.5, intensity=3)
    for (r, sd, c) in (('living', 'S', -0.5), ('living', 'N', -1.5), ('bed1', 'S', -1.2), ('bed2', 'S', 4.2), ('kitchen', 'W', -2.0)):
        s.outlet(r, sd, c)
    return s

ALL = [apartment]


def garage():
    """Industrial unit with three bays, steel windows, roller shutter (reference 1)."""
    s = Shell('rox_shell_garage', 'ROX Industrial Unit (3 bays)', 'ورشة ROX صناعية (3 أقسام)', H=4.2, wall_t=0.25)
    kw = dict(floor='concrete_floor', wall='concrete_wall', ceil='concrete_wall', wains=('paint_dkblue', 1.15), rail=False, base=None)
    s.room('bay1', -9.5, -4.5, -3.35, 4.5, **kw)
    s.room('bay2', -3.1, -4.5, 3.1, 4.5, **kw)
    s.room('bay3', 3.35, -4.5, 9.5, 4.5, **kw)
    s.door('bay1', 'E', -4.0, 1.2, to='bay2', h=3.5, casing=None, thresh='concrete_floor')
    s.door('bay2', 'E', -4.0, 1.2, to='bay3', h=3.5, casing=None, thresh='concrete_floor')
    for (r, x0, x1) in (('bay1', -8.7, -4.1), ('bay2', -2.3, 2.3), ('bay3', 4.1, 8.7)):
        s.window(r, 'N', x0, x1, sill=2.0, head=3.7, glass='window_dark', frame='metal_dark', cols=8, rows=3, sillboard=False, bar=0.035)
    s.entry_door('bay3', 'S', 6.6, 7.6, h=2.1, mat='door_grey', frame='metal_dark')
    s.build_rooms()
    s.shutter('bay1', 'W', -2.3, 2.3, 3.3)
    for cx in (-6.4, 0.0, 6.4):
        s.linear_light(cx, 1.6, 4.2, 2.2, 'y', drop=0.5, intensity=7.0, falloff=10.0)
        s.linear_light(cx, -2.4, 4.2, 2.2, 'y', drop=0.5, intensity=7.0, falloff=10.0)
    # steel beams under the roof + conduits
    for y in (-3.0, 0.0, 3.0):
        s.box('metal_dark', -9.5, y - 0.08, 3.95, 9.5, y + 0.08, 4.2, faces='xXyYz', tag='fix')
    s.box('steel', -9.5, 4.38, 3.3, 9.5, 4.44, 3.36, tag='fix')
    s.wbox('metal_dark', 'bay3', 'S', *s.local('bay3', 'S', 5.4, 6.0), 1.2, 1.9, 0, 0.14)     # electrical panel
    s.wbox('steel', 'bay3', 'S', *s.local('bay3', 'S', 5.5, 5.9), 1.3, 1.8, 0.14, 0.15)
    for x in (-9.3, -3.2, 3.2, 9.3):
        pass
    return s


def office():
    """L-shaped loft office: herringbone parquet, tall dark windows with shades, grid ceiling (reference 2)."""
    s = Shell('rox_shell_office', 'ROX Loft Office', 'مكتب ROX لوفت', H=3.0, wall_t=0.2)
    kw = dict(floor='parquet', wall='paint_cream', ceil='ceiling_tile', floor_rot=0.7854, base='wood_dark')
    s.room('main', -7.0, 0.0, 7.0, 5.5, **kw)
    s.room('wing', -7.0, -6.0, 0.0, 0.0, **kw)
    s.door('main', 'S', -7.0, 0.0, to='wing', kind='open')
    for x in (-5.6, -2.9, -0.2, 2.5, 5.2):
        s.window('main', 'N', x - 0.95, x + 0.95, sill=0.25, head=2.7, glass='window_dark', frame='wood_dark', cols=1, cover='shade', sillboard=False)
    for y in (1.6, 3.9):
        s.window('main', 'E', y - 0.95, y + 0.95, sill=0.25, head=2.7, glass='window_dark', frame='wood_dark', cols=1, cover='shade', sillboard=False)
    for y in (-4.4, -1.9):
        s.window('wing', 'W', y - 0.95, y + 0.95, sill=0.25, head=2.7, glass='window_dark', frame='wood_dark', cols=1, cover='shade', sillboard=False)
    s.entry_door('wing', 'S', -4.4, -2.9, h=2.25, mat='wood_dark', frame='wood_dark')
    s.build_rooms()
    for x in (-5.4, -1.8, 1.8, 5.4):
        for y in (1.5, 4.0):
            s.led_panel(x, y, 3.0, 0.6, intensity=3.5, falloff=6.5)
    for y in (-4.5, -1.8):
        for x in (-5.4, -1.8):
            s.led_panel(x, y, 3.0, 0.6, intensity=3.5, falloff=6.5)
    # dark timber feature wall + inner corner column
    s.panel('wood_dark', 'wing', 'E', -5.6, -0.4, 0.0, 2.6, th=0.05)
    s.panel('wood_dark', 'main', 'S', 0.4, 6.6, 0.0, 2.6, th=0.05)
    return s


def oldhouse():
    """Old family house: tiled floors, wallpaper + wainscot, ceiling fans, boarded windows (reference 3)."""
    s = Shell('rox_shell_oldhouse', 'ROX Old Family House', 'بيت ROX القديم', H=2.65, wall_t=0.18)
    t = 0.18
    wp = dict(wall='wallpaper', wains=('wainscot', 0.95), ceil='paint_white', crown=True)
    s.room('living', -5.5, -5.0, 1.0, 0.5, floor='tile_terra', **wp)
    s.room('dining', 1.0 + t, -5.0, 5.5, -1.2, floor='tile_terra', **wp)
    s.room('kitchen', 1.0 + t, -1.2 + t, 5.5, 2.4, floor='tile_beige', wall='paint_cream', ceil='paint_white')
    s.room('hall', -5.5, 0.5 + t, 1.0, 2.4, floor='tile_terra', **wp)
    s.room('bed1', -5.5, 2.4 + t, -1.4, 6.5, floor='planks', wall='wallpaper', ceil='paint_white', crown=True)
    s.room('bath', -1.4 + t, 2.4 + t, 1.4, 6.5, floor='tile_beige', wall='paint_cream', wains=('tile_white', 1.6), base=None, ceil='paint_white')
    s.room('bed2', 1.4 + t, 2.4 + t, 5.5, 6.5, floor='planks', wall='wallpaper', ceil='paint_white', crown=True)
    s.door('living', 'E', -4.2, -2.2, to='dining', h=2.15)
    s.door('living', 'N', -3.6, -1.9, to='hall', h=2.15)
    s.door('hall', 'E', 0.95, 1.85, to='kitchen', leaf='l')
    s.door('dining', 'N', 2.6, 4.2, to='kitchen', h=2.15)
    s.door('hall', 'N', -4.3, -3.4, to='bed1', leaf='r')
    s.door('hall', 'N', -0.6, 0.25, to='bath', leaf='l')
    s.door('kitchen', 'N', 2.4, 3.3, to='bed2', leaf='l')
    s.entry_door('living', 'S', -1.6, 0.0, h=2.1, mat='door_grey', frame='trim')
    s.window('living', 'W', -3.9, -1.3, sill=0.85, head=2.1, cols=3, cover='boards')
    s.window('living', 'S', -4.7, -2.9, sill=0.85, head=2.1, cols=2, cover='boards')
    s.window('dining', 'S', 2.3, 4.5, sill=0.85, head=2.1, cols=3, cover='boards')
    s.window('dining', 'E', -4.1, -2.3, sill=0.85, head=2.1, cols=2)
    s.window('kitchen', 'E', 0.0, 1.5, sill=1.1, head=2.1, cols=2)
    s.window('bed1', 'W', 3.6, 5.4, sill=0.9, head=2.1, cols=2, cover='boards')
    s.window('bed2', 'E', 3.6, 5.4, sill=0.9, head=2.1, cols=2, cover='shade')
    s.window('bath', 'N', -0.6, 0.4, sill=1.5, head=2.1, cols=1)
    s.kitchen('kitchen', 'E', -0.9, 0.0 - 0.05, fridge=False, upper=True) if False else None
    s.kitchen('kitchen', 'S', 2.0, 5.4, fridge=True)
    s.wardrobe('bed1', 'E', 2.9, 5.6)
    s.wardrobe('bed2', 'W', 4.4, 6.4, mat='wood_door')
    s.build_rooms()
    for (x, y) in ((-2.2, -2.3), (3.3, -3.1), (3.3, 0.7), (-3.4, 4.5), (3.5, 4.5)):
        s.fan(x, y, 2.65)
    s.led_panel(-2.2, 1.5, 2.65, 0.4, intensity=2.5, falloff=5)
    s.led_panel(0.0, 4.5, 2.65, 0.4, intensity=2.5, falloff=4.5)
    for (r, sd, c) in (('living', 'N', -0.5), ('dining', 'W', -3.0), ('bed1', 'S', -2.4), ('bed2', 'S', 4.6), ('hall', 'S', -4.8)):
        s.outlet(r, sd, c)
    return s


def showroom():
    """Large empty hall with an entrance lobby: blue epoxy floor, white walls, hanging lights (reference 5)."""
    s = Shell('rox_shell_showroom', 'ROX Showroom Hall', 'صالة عرض ROX', H=4.6, wall_t=0.25)
    kw = dict(floor='floor_blue', wall='paint_white', ceil='paint_white', wains=('paint_grey', 1.0), rail=False, base='metal_dark')
    s.room('hall', -8.0, -4.0, 8.0, 7.0, **kw)
    s.room('lobby', 4.6, -7.2, 8.0, -4.25, H=2.8, floor='floor_blue', wall='paint_white', ceil='paint_white', base='metal_dark')
    s.door('lobby', 'N', 5.4, 7.0, to='hall', h=2.3, casing='metal_dark', thresh='metal_dark')
    s.entry_door('lobby', 'E', -6.3, -5.3, h=2.1, mat='door_grey', frame='metal_dark')
    s.build_rooms()
    for x in (-5.3, 0.0, 5.3):
        for y in (-1.2, 3.8):
            s.linear_light(x, y, 4.6, 2.4, 'x', drop=0.6, intensity=8.0, falloff=11.0)
    s.linear_light(6.3, -5.7, 2.8, 1.4, 'x', drop=0.02, intensity=4.0, falloff=5.0)
    # pilasters along the long walls
    for x in (-8.0, 8.0):
        for y in (-0.3, 3.4):
            sx = 0.3 if x < 0 else -0.3
            s.pillar('paint_white', min(x, x + sx), y - 0.3, max(x, x + sx), y + 0.3, 0, 4.6)
    return s


ALL = [apartment, garage, office, oldhouse, showroom]
