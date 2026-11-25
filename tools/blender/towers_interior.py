# ROX Twin Towers with real interiors (lobby, offices, sky lounge) - building only, nothing around  (c) ROX Store
#   OUT=<dir> SAMPLES=48 DENOISE=1 python towers_interior.py      (pip bpy)   or   blender -b -P towers_interior.py
import bpy, bmesh, math, os, random
from mathutils import Vector
OUT = os.environ.get('OUT', '/tmp/towers'); SAMPLES = int(os.environ.get('SAMPLES', '32')); os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = bool(int(os.environ.get('DENOISE', '1')))
sc.cycles.max_bounces = 6; sc.cycles.transmission_bounces = 6; sc.cycles.sample_clamp_indirect = 3.0
sc.render.resolution_x, sc.render.resolution_y = int(os.environ.get('W', '1600')), int(os.environ.get('H', '900'))
names = [i.identifier for i in sc.view_settings.bl_rna.properties['view_transform'].enum_items]
sc.view_settings.view_transform = 'AgX' if 'AgX' in names else 'Filmic'; sc.view_settings.exposure = 0.0
w = bpy.data.worlds.new('studio'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.025, 0.04, 1); w.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0

def mat(name, base=(0.5, 0.5, 0.5), metal=0.0, rough=0.5, emit=None, strength=0.0, glass=False, alpha=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*base, 1); b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit:
        k = 'Emission Color' if 'Emission Color' in b.inputs else 'Emission'
        b.inputs[k].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = strength
    if glass:
        k = 'Transmission Weight' if 'Transmission Weight' in b.inputs else 'Transmission'
        b.inputs[k].default_value = 1.0; b.inputs['IOR'].default_value = 1.45; b.inputs['Roughness'].default_value = 0.02
    return m
M = dict(
    glass=mat('curtain_glass', (0.55, 0.65, 0.75), glass=True),
    mullion=mat('mullion', (0.08, 0.085, 0.09), metal=1.0, rough=0.3),
    slab=mat('slab_edge', (0.2, 0.21, 0.22), metal=0.5, rough=0.4),
    led=mat('led_white', (1, 1, 1), emit=(0.85, 0.92, 1.0), strength=22.0),
    marble=mat('marble_floor', (0.86, 0.84, 0.8), rough=0.12),
    darkmarble=mat('dark_marble', (0.05, 0.05, 0.055), rough=0.1),
    wood=mat('walnut', (0.25, 0.13, 0.07), rough=0.35),
    oak=mat('oak', (0.55, 0.38, 0.22), rough=0.4),
    carpet=mat('office_carpet', (0.18, 0.19, 0.21), rough=0.95),
    concrete=mat('core_concrete', (0.42, 0.41, 0.4), rough=0.8),
    ceiling=mat('ceiling', (0.88, 0.88, 0.86), rough=0.9),
    white=mat('desk_white', (0.92, 0.92, 0.9), rough=0.35),
    black=mat('black_metal', (0.03, 0.03, 0.035), metal=0.8, rough=0.3),
    brass=mat('brass', (0.8, 0.6, 0.3), metal=1.0, rough=0.22),
    fabric=mat('sofa_fabric', (0.12, 0.14, 0.18), rough=0.9),
    leather=mat('leather', (0.35, 0.18, 0.1), rough=0.5),
    plant=mat('plant', (0.05, 0.2, 0.06), rough=0.7),
    pot=mat('pot', (0.15, 0.15, 0.15), rough=0.6),
    screen=mat('screen', (0.02, 0.02, 0.02), emit=(0.35, 0.55, 1.0), strength=3.0),
    panel=mat('light_panel', (1, 1, 1), emit=(1.0, 0.95, 0.88), strength=9.0),
    warm=mat('warm_light', (1, 1, 1), emit=(1.0, 0.75, 0.45), strength=12.0),
    logo=mat('rox_logo', (1, 1, 1), emit=(1.0, 0.36, 0.1), strength=14.0),
    elev=mat('elevator_door', (0.7, 0.7, 0.72), metal=1.0, rough=0.15),
    water=mat('water', (0.2, 0.35, 0.45), glass=True),
)

SOFT = [False]
def box(name, c, s, m, bev=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c); o = bpy.context.object; o.name = name; o.scale = s
    bpy.ops.object.transform_apply(scale=True); o.data.materials.append(m)
    bev = bev if bev is not None else (0.025 if SOFT[0] else 0.0)
    if bev and min(s) > bev * 2.2:          # rounded furniture edges (catch the light like real furniture)
        md = o.modifiers.new('bevel', 'BEVEL'); md.width = bev; md.segments = 3; md.limit_method = 'ANGLE'
    return o

def cyl(name, c, r, h, m, v=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=c); o = bpy.context.object; o.name = name; o.data.materials.append(m); return o

def prism(name, pts, z0, z1, m):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    vb = [bm.verts.new((x, y, z0)) for x, y in pts]; vt = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(vb[::-1]); bm.faces.new(vt)
    for i in range(len(pts)): bm.faces.new((vb[i], vb[(i + 1) % len(pts)], vt[(i + 1) % len(pts)], vt[i]))
    bm.to_mesh(me); bm.free(); o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); o.data.materials.append(m); return o

def chamfer(w, d, c, ox=0.0, oy=0.0):
    x, y = w / 2, d / 2
    return [(ox + a, oy + b) for a, b in [(-x + c, -y), (x - c, -y), (x, -y + c), (x, y - c), (x - c, y), (-x + c, y), (-x, y - c), (-x, -y + c)]]

def seg_box(name, a, b, z, h, t, m, out=0.0):
    a, b = Vector((*a, 0)), Vector((*b, 0)); d = b - a; L = d.length; nrm = Vector((d.y, -d.x, 0)).normalized(); mid = (a + b) / 2 + nrm * out
    bpy.ops.mesh.primitive_cube_add(size=1, location=(mid.x, mid.y, z + h / 2)); o = bpy.context.object; o.name = name
    o.scale = (L, t, h); o.rotation_euler = (0, 0, math.atan2(d.y, d.x)); o.data.materials.append(m); return o

def curtain(name, pts, z0, z1, fh=3.9, mull=1.5):
    """Real glass curtain wall: glass panes, vertical mullions, floor slab edges - you can see inside."""
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        seg_box(f'{name}_glass_{i}', a, b, z0, z1 - z0, 0.03, M['glass'])
        A, B = Vector((*a, 0)), Vector((*b, 0)); L = (B - A).length; k = max(1, int(L / mull))
        for j in range(k + 1):
            p = A + (B - A) * (j / k); nrm = Vector(((B - A).y, -(B - A).x, 0)).normalized() * 0.06
            box(f'{name}_mul_{i}_{j}', (p.x + nrm.x, p.y + nrm.y, (z0 + z1) / 2), (0.07, 0.07, z1 - z0), M['mullion'])
    z = z0
    while z <= z1 + 0.01:
        for i in range(n): seg_box(f'{name}_edge_{i}_{int(z * 10)}', pts[i], pts[(i + 1) % n], z - 0.25, 0.5, 0.18, M['slab'], out=0.05)
        z += fh

def led_outline(name, pts, z):
    for i in range(len(pts)): seg_box(f'{name}_{i}', pts[i], pts[(i + 1) % len(pts)], z - 0.06, 0.12, 0.12, M['led'], out=0.12)
    for i, (x, y) in enumerate(pts): box(f'{name}_v{i}', (x, y, z), (0.12, 0.12, 0.12), M['led'])

def vled(name, pts, z0, z1):
    for i, (x, y) in enumerate(pts): box(f'{name}_{i}', (x * 1.003, y * 1.003, (z0 + z1) / 2), (0.1, 0.1, z1 - z0), M['led'])

def slab(name, pts, z, ceiling=True, floor_mat=None):
    prism(f'{name}_slab', pts, z - 0.25, z, M['concrete'])
    if floor_mat: prism(f'{name}_floor', [(x * 0.995, y * 0.995) for x, y in pts], z, z + 0.02, floor_mat)
    if ceiling: prism(f'{name}_ceil', [(x * 0.995, y * 0.995) for x, y in pts], z - 0.3, z - 0.25, M['ceiling'])

def ceiling_lights(name, x0, y0, x1, y1, z, sp=3.0, strength=1.0):
    x = x0 + sp / 2
    while x < x1:
        y = y0 + sp / 2
        while y < y1:
            box(f'{name}_{int(x)}_{int(y)}', (x, y, z - 0.32), (1.2, 0.3, 0.02), M['panel']); y += sp
        x += sp
    l = bpy.data.lights.new(name, 'AREA'); l.shape = 'RECTANGLE'; l.size = x1 - x0; l.size_y = y1 - y0; l.energy = 600 * strength * (x1 - x0) * (y1 - y0) / 100
    l.color = (1.0, 0.95, 0.88); o = bpy.data.objects.new(name, l); o.location = ((x0 + x1) / 2, (y0 + y1) / 2, z - 0.35); bpy.context.collection.objects.link(o)

import sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from phlib import ph          # real scanned CC0 furniture (Poly Haven), instanced
PLANTS = ['potted_plant_01', 'potted_plant_02', 'potted_plant_04', 'pachira_aquatica_01', 'calathea_orbifolia_01']
def plant(name, x, y, z, h=1.6):
    rr = random.Random(hash(name) & 0xffff); ph(rr.choice(PLANTS), (x, y, z), rr.uniform(0, 360), h)

_desk = [None]
def _desk_coll():
    if _desk[0]: return _desk[0]
    col = bpy.data.collections.new('DESK'); objs = []
    objs.append(box('d_top', (0, 0, 0.74), (1.6, 0.8, 0.04), M['white'], bev=0.01))
    for dx in (-0.75, 0.75): objs.append(box(f'd_leg{dx}', (dx, 0, 0.37), (0.04, 0.7, 0.74), M['black'], bev=0))
    objs.append(box('d_scr', (0, 0.25, 1.02), (0.6, 0.03, 0.36), M['screen'], bev=0)); objs.append(box('d_st', (0, 0.28, 0.8), (0.05, 0.05, 0.12), M['black'], bev=0))
    objs.append(box('d_kb', (0, -0.05, 0.765), (0.45, 0.15, 0.015), M['black'], bev=0))
    for o in objs:
        for c in list(o.users_collection): c.objects.unlink(o)
        col.objects.link(o)
    _desk[0] = col; return col

def desk(name, x, y, z, rot=0.0, chair=True):
    o = bpy.data.objects.new(name, None); o.instance_type = 'COLLECTION'; o.instance_collection = _desk_coll()
    bpy.context.scene.collection.objects.link(o); o.location = (x, y, z); o.rotation_euler.z = math.radians(rot)
    if chair:
        c, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        ph('modern_arm_chair_01', (x + 0.75 * sn, y - 0.75 * c, z), 180 + rot, 1.0)
    rr = random.Random(hash(name) & 0xffff)
    if rr.random() < 0.4: ph('office_notepads', (x + 0.5, y - 0.1, z + 0.76), rr.uniform(0, 360), 0.05)
    if rr.random() < 0.3: ph('stationery_supplies', (x - 0.55, y + 0.1, z + 0.76), rr.uniform(0, 360), 0.15)

def sofa(name, x, y, z, L=2.4, rot=0.0, m=None):
    ph('sofa_02' if (hash(name) & 1) else 'sofa_03', (x, y, z), rot, 0.85)

def lounge(name, x, y, z, face=0.0, table=True):
    """sofa facing `face`, two lounge chairs opposite, round table + rug between (all real models)"""
    f = math.radians(face); fx, fy = math.sin(f), -math.cos(f)        # direction the sofa looks at
    sofa(name, x, y, z, rot=face)
    cx, cy = x + fx * 1.6, y + fy * 1.6
    if table: ph('modern_coffee_table_01', (cx, cy, z), face, 0.42); ph('ceramic_vase_01', (cx, cy, z + 0.42), 0, 0.3)
    px, py = fy, -fx
    for sd in (-1, 1):
        ph('mid_century_lounge_chair', (cx + fx * 1.4 + px * sd * 0.9, cy + fy * 1.4 + py * sd * 0.9, z), face + 180 + sd * 20, 0.85)
    box(f'{name}_rug', (cx, cy, z + 0.012), (4.2, 3.6, 0.02), M['fabric'], bev=0)

cam_data = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_data); bpy.context.collection.objects.link(cam); sc.camera = cam
cam_data.lens = 24; cam_data.clip_end = 2000
tgt = bpy.data.objects.new('target', None); bpy.context.collection.objects.link(tgt)
tr = cam.constraints.new('TRACK_TO'); tr.target = tgt; tr.track_axis = 'TRACK_NEGATIVE_Z'; tr.up_axis = 'UP_Y'
step = [0]; open(os.path.join(OUT, 'steps.txt'), 'w').close()
def shot(title, pos, look, lens=24):
    step[0] += 1; cam.location = pos; tgt.location = look; cam_data.lens = lens
    sc.render.filepath = os.path.join(OUT, f'step_{step[0]:02d}.png'); bpy.ops.render.render(write_still=True)
    open(os.path.join(OUT, 'steps.txt'), 'a').write(f'{step[0]:02d}|{title}\n'); print('STEP', step[0], title, flush=True)

# ------------------------------------------------------------------ geometry
POD = chamfer(60, 50, 9); MID = chamfer(48, 38, 8)
TL = chamfer(18, 30, 4, -13, 0); TR = chamfer(18, 28, 4, 13, 2)
EXT = (130, -150, 95)
# 1 podium: lobby slab, glass curtain wall, roof
slab('lobby', POD, 0.0, ceiling=False, floor_mat=M['marble'])
curtain('pod', POD, 0.0, 14.0, fh=14.0, mull=2.2)
slab('pod_roof', chamfer(62, 52, 9.4), 14.6); led_outline('pod_led', chamfer(62, 52, 9.4), 14.65); vled('pod_v', POD, 0, 14.6)
shot('Podium: glass lobby box', EXT, (0, 0, 20), 28)
# 2 core + elevators through the whole building
box('core', (0, 4, 70), (10, 8, 140), M['concrete'])
for k, x in enumerate((-3.6, -1.2, 1.2, 3.6)):
    box(f'elev_{k}', (x, -0.02, 1.4), (1.6, 0.06, 2.8), M['elev']); box(f'elev_frame_{k}', (x, -0.04, 2.95), (1.9, 0.08, 0.2), M['brass'])
shot('Core + elevator bank', EXT, (0, 0, 40), 28)
SOFT[0] = True
# 3 lobby interior: reception, logo wall, seating, plants, water feature, double-height lights
box('logo_wall', (0, -0.3, 7.5), (14, 0.4, 9), M['darkmarble']); box('logo', (0, -0.55, 9.5), (6, 0.08, 1.6), M['logo'])
box('reception', (0, -6.5, 0.55), (8, 1.4, 1.1), M['wood']); box('reception_top', (0, -6.5, 1.12), (8.3, 1.6, 0.06), M['darkmarble'])
box('reception_led', (0, -7.22, 0.15), (8, 0.04, 0.06), M['warm'])
for k, x in enumerate((-18, -10, 10, 18)):
    lounge(f'lob_sofa_{k}', x, -11.0, 0.02, face=0)
for k, (x, y) in enumerate(((-24, -18), (24, -18), (-24, 14), (24, 14), (-6, -18), (6, -18), (-26, -4), (26, -4), (-12, -18), (12, -18), (-20, -14), (20, -14))): plant(f'lob_plant_{k}', x, y, 0.02, 3.0)
for k, x in enumerate((-18, 18)): lounge(f'lob_b_{k}', x, -17.5, 0.02, face=180)
box('water_basin', (-16, 8, 0.2), (8, 4, 0.4), M['darkmarble']); box('water', (-16, 8, 0.42), (7.6, 3.6, 0.04), M['water'])
for k in range(5): box(f'chand_{k}', (-12 + k * 6, -6, 11.5), (0.08, 3.5, 0.08), M['warm'])
for k in range(8): cyl(f'pend_{k}', (-14 + k * 4, -14, 9.0), 0.35, 0.5, M['warm'])
ceiling_lights('lobby_l', -26, -22, 26, 20, 14.3, sp=4.0, strength=0.35)
for k, (x, y) in enumerate(((-20, -6), (20, -6), (-20, 6), (20, 6), (-10, 12), (10, 12))):     # round columns with brass rings
    cyl(f'col_{k}', (x, y, 7.0), 0.55, 14.0, M['marble']); cyl(f'col_ring_{k}', (x, y, 0.3), 0.6, 0.6, M['brass']); cyl(f'col_top_{k}', (x, y, 13.7), 0.62, 0.6, M['brass'])
box('lobby_rug', (0, -12.5, 0.04), (14, 6, 0.03), M['fabric'], bev=0)
for k, x in enumerate((-2.4, 2.4)): ph('modern_arm_chair_01', (x, -5.4, 0.02), 0, 1.0); ph('classic_laptop', (x, -6.3, 1.15), 0, 0.25)
ph('desk_lamp_arm_01', (3.6, -6.4, 1.15), 200, 0.55); ph('stationery_supplies', (-3.6, -6.5, 1.15), 0, 0.15)
for k, x in enumerate((-5.5, 5.5)): ph('modern_wooden_cabinet', (x, -1.0, 0.02), 0, 0.8); ph('marble_bust_01', (x, -1.0, 0.82), 0, 0.45)
for k, (x, y) in enumerate(((-14, 2), (14, 2))): ph('coffee_table_round_01', (x, y, 0.02), 0, 0.75)
for cx in (-14, 14):
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4; ph('dining_chair_02', (cx + 1.1 * math.cos(a), 2 + 1.1 * math.sin(a), 0.02), math.degrees(math.atan2(-math.cos(a), math.sin(a))), 0.95)
box('mezz', (0, 14, 7.0), (40, 8, 0.4), M['concrete'], bev=0); box('mezz_rail', (0, 10.05, 7.6), (40, 0.05, 1.0), M['glass'], bev=0); box('mezz_led', (0, 10.0, 6.78), (40, 0.05, 0.05), M['warm'], bev=0)
for k in range(12): box(f'stair_{k}', (22, 9.5 - k * 0.0 - 0.0, 0.3 + k * 0.58) if False else (22 - 0.0, 2.0 + k * 0.6, 0.29 + k * 0.58), (2.2, 0.6, 0.12), M['darkmarble'], bev=0)
shot('Lobby: reception, ROX wall, lounge', (-4, -22.5, 1.8), (1, -4, 3.5), 22)
shot('Lobby: double height + water', (20, -18, 6), (-10, 4, 4), 20)
# 4 mid block: 14 office floors behind real glass
FH = 3.9; Z0 = 14.6; NMID = 14
for k in range(NMID):
    z = Z0 + k * FH
    slab(f'mid_{k}', MID, z, floor_mat=M['carpet'])
curtain('mid', MID, Z0, Z0 + NMID * FH, fh=FH, mull=1.5); vled('mid_v', MID, Z0, Z0 + NMID * FH)
TOP_MID = Z0 + NMID * FH
slab('mid_roof', chamfer(52, 42, 9), TOP_MID + 0.3); led_outline('mid_led', chamfer(52, 42, 9), TOP_MID + 0.35)
shot('Mid block: 14 office floors (glass)', EXT, (0, 0, 40), 28)
# 5 furnish two office floors (open plan + executive) and light every floor
r = random.Random(3)
for k in range(NMID):
    z = Z0 + k * FH
    if k in (3, 8): continue
    if r.random() < 0.55:
        ceiling_lights(f'mid_lt_{k}', -20, -15, 20, 15, z + FH, sp=4.0, strength=0.35)
        for i in range(6):
            for j in (-12, 10): desk(f'fd_{k}_{i}_{j}', -16 + i * 6.4, j, z, rot=0 if j < 0 else 180)
        for i in range(3): plant(f'fp_{k}_{i}', -20 + i * 20, -15, z, 1.4)
z = Z0 + 3 * FH
for i in range(6):
    for j in range(3): desk(f'desk_{i}_{j}', -17 + i * 3.4, -13 + j * 3.2, z)
for i in range(4): plant(f'off_plant_{i}', -21 + i * 14, 12, z, 1.4)
box('meeting_glass', (14, -10, z + 1.4), (8, 0.05, 2.8), M['glass']); box('meeting_table', (14, -13, z + 0.75), (5, 1.6, 0.06), M['oak'])
for i in range(6): ph('dining_chair_02', (12 + (i % 3) * 2, -14.3 + (i // 3) * 2.6, z), 180 if i < 3 else 0, 0.95)
ph('projector_screen', (14, -16.5, z), 0, 2.2); lounge('off_lounge', 14, 6, z, face=0)
ph('wall_clock', (-22.5, 0, z + 2.4), 90, 0.4)
ceiling_lights('off_a', -22, -17, 22, 17, z + FH, sp=3.0, strength=0.35)
z8 = Z0 + 8 * FH
box('exec_desk', (0, -11, z8 + 0.75), (3.0, 1.2, 0.08), M['darkmarble']); box('exec_desk_b', (0.6, -11, z8 + 0.36), (1.6, 1.1, 0.72), M['wood'])
ph('modern_arm_chair_01', (0, -10.0, z8), 0, 1.05); ph('classic_laptop', (0, -11.1, z8 + 0.79), 180, 0.25); ph('desk_lamp_arm_01', (1.1, -11.2, z8 + 0.79), 20, 0.55)
for dx in (-0.7, 0.7): ph('dining_chair_02', (dx, -12.4, z8), 180, 0.95)
ph('book_encyclopedia_set_01', (14, -2.1, z8 + 1.2), 180, 0.3); ph('marble_bust_01', (12, -2.1, z8 + 1.2), 180, 0.4); lounge('exec_l2', 10, 8, z8, face=0)
lounge('exec_sofa', -12, -9.5, z8, face=0)
box('conf_table', (10, -11, z8 + 0.75), (6.0, 1.8, 0.07), M['oak'], bev=0.02); box('conf_base', (10, -11, z8 + 0.37), (4.0, 0.6, 0.72), M['black'], bev=0)
for i in range(5):
    for sd in (-1, 1): ph('dining_chair_02', (7.6 + i * 1.2, -11 + sd * 1.25, z8), 180 if sd < 0 else 0, 0.95)
ph('projector_screen', (14.2, -11, z8), 270, 2.2)
for i in range(6): plant(f'exec_p2_{i}', -20 + i * 8, 14, z8, 1.9)
for i in range(4): desk(f'exec_d_{i}', -16 + i * 4.5, 8, z8, rot=180)
for i in range(3): plant(f'exec_plant_{i}', -20 + i * 20, -14, z8, 1.8)
box('exec_shelf', (14, -2, z8 + 1.4), (8, 0.5, 2.8), M['wood'])
ceiling_lights('off_b', -22, -17, 22, 17, z8 + FH, sp=3.0, strength=0.3)
shot('Office floor: open plan', (-16, -18, z + 1.7), (6, 0, z + 1.0), 20)
shot('Executive floor', (17, -16, z8 + 1.7), (4, -6, z8 + 0.8), 20)
# 6 the tower splits: twin towers, all glass, lit floors
for pts, top, nm in ((TL, 138.0, 'L'), (TR, 118.0, 'R')):
    nf = int((top - TOP_MID - 0.3) / FH)
    for k in range(nf):
        zz = TOP_MID + 0.3 + k * FH; slab(f'{nm}_{k}', pts, zz, floor_mat=M['carpet'])
        if r.random() < 0.4: ceiling_lights(f'{nm}_lt_{k}', pts[0][0] - 4, -13, pts[1][0] + 4, 13, zz + FH, sp=4.0, strength=0.3)
    curtain(f'tw_{nm}', pts, TOP_MID + 0.3, top, fh=FH, mull=1.35); vled(f'tw_v_{nm}', pts, TOP_MID + 0.3, top)
    led_outline(f'tw_led_{nm}', pts, top + 0.05); slab(f'{nm}_roof', pts, top + 0.3)
BR = [(-4.2, -1.5), (4.2, -1.5), (4.2, 3.5), (-4.2, 3.5)]
curtain('bridge', BR, 98, 102, fh=4, mull=1.0); slab('bridge_floor', BR, 98.02); led_outline('bridge_led', BR, 102.1)
shot('Split: twin glass towers + sky bridge', (150, -140, 130), (0, 0, 95), 28)
# 7 sky lounge on top of the tall tower: bar, sofas, view
nfl = int((138.0 - TOP_MID - 0.3) / FH); zt = TOP_MID + 0.3 + (nfl - 1) * FH + 0.02
box('bar', (-13, 8, zt + 0.55), (8, 1.0, 1.1), M['darkmarble']); box('bar_led', (-13, 7.48, zt + 0.12), (8, 0.04, 0.05), M['warm'])
box('bar_shelf', (-13, 10.5, zt + 1.6), (8, 0.4, 2.4), M['wood'])
lounge('sky_l1', -16, -2, zt, face=0); lounge('sky_l2', -10, -2, zt, face=0)
for i in range(5): ph('bar_chair_round_01', (-15 + i * 1.0, 7.0, zt), 180, 0.95)
ph('side_table_tall_01', (-19, -12, zt), 0, 0.9)
for i in range(3): cyl(f'sky_pend_{i}', (-17 + i * 4, -3, zt + 2.6), 0.4, 0.4, M['warm'])
for i in range(2): plant(f'sky_plant_{i}', -20 + i * 14, -13, zt, 1.6)
ceiling_lights('sky', -21, -14, -5, 14, 138.0, sp=4.0, strength=0.25)
shot('Sky lounge (top of the tall tower)', (-6, -12, zt + 1.7), (-16, 4, zt + 1.2), 20)
# 8 final exterior night shots
shot('Final - night, inside visible', (120, -140, 60), (0, 0, 55), 30)
shot('Final - full height', (150, -170, 120), (0, 0, 70), 28)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'rox_twin_towers_interior.blend'))
print('DONE', flush=True)
