# ROX Tower - built step by step in Blender, a render after every step (time-lapse)  (c) ROX Store
#   blender -b -P tower.py -- <outdir> [samples]
import bpy, bmesh, math, sys, os
from mathutils import Vector
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else '/tmp/tower'; SAMPLES = int(argv[1]) if len(argv) > 1 else 24
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = False; sc.cycles.sample_clamp_indirect = 2.0; sc.cycles.max_bounces = 4
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
sc.view_settings.view_transform = 'Filmic' if 'Filmic' in [i.identifier for i in sc.view_settings.bl_rna.properties['view_transform'].enum_items] else 'AgX'
sc.view_settings.look = 'None'; sc.view_settings.exposure = 0.6
# night world
w = bpy.data.worlds.new('night'); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes['Background']; sky = w.node_tree.nodes.new('ShaderNodeTexGradient')
ramp = w.node_tree.nodes.new('ShaderNodeValToRGB'); mp = w.node_tree.nodes.new('ShaderNodeMapping'); tc = w.node_tree.nodes.new('ShaderNodeTexCoord')
w.node_tree.links.new(tc.outputs['Generated'], mp.inputs['Vector']); mp.inputs['Rotation'].default_value = (0, -math.pi / 2, 0)
w.node_tree.links.new(mp.outputs['Vector'], sky.inputs['Vector']); w.node_tree.links.new(sky.outputs['Fac'], ramp.inputs['Fac'])
ramp.color_ramp.elements[0].color = (0.012, 0.016, 0.035, 1); ramp.color_ramp.elements[1].color = (0.06, 0.07, 0.12, 1)
w.node_tree.links.new(ramp.outputs['Color'], bg.inputs['Color']); bg.inputs['Strength'].default_value = 1.0

def mat(name, base=(0.1, 0.1, 0.1), metal=0.0, rough=0.5, emit=None, strength=0.0, transm=0.0, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*base, 1); b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit:
        k = 'Emission Color' if 'Emission Color' in b.inputs else 'Emission'
        b.inputs[k].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = strength
    if coat and 'Coat Weight' in b.inputs: b.inputs['Coat Weight'].default_value = coat
    return m
M = dict(
    glass=mat('glass_dark', (0.03, 0.04, 0.055), metal=0.9, rough=0.08, coat=1.0),
    glass_lit=mat('glass_office', (0.02, 0.02, 0.02), rough=0.2, emit=(1.0, 0.86, 0.62), strength=1.2),
    fin=mat('fins', (0.32, 0.34, 0.37), metal=1.0, rough=0.28),
    slab=mat('slab', (0.16, 0.17, 0.18), metal=0.6, rough=0.35),
    led=mat('led_white', (1, 1, 1), emit=(0.85, 0.92, 1.0), strength=28.0),
    ledw=mat('led_warm', (1, 1, 1), emit=(1.0, 0.8, 0.55), strength=14.0),
    road=mat('asphalt', (0.03, 0.03, 0.032), rough=0.85),
    walk=mat('pavement', (0.13, 0.13, 0.125), rough=0.8),
    line=mat('road_line', (0.8, 0.78, 0.7), rough=0.6),
    yellow=mat('road_yellow', (0.8, 0.55, 0.05), rough=0.6),
    grass=mat('grass', (0.02, 0.05, 0.02), rough=0.9),
    city=mat('city_block', (0.03, 0.032, 0.036), rough=0.7),
    cwin=mat('city_windows', (0.02, 0.02, 0.02), emit=(1.0, 0.82, 0.55), strength=4.0),
    heli=mat('helipad', (0.06, 0.065, 0.07), rough=0.6),
    sign=mat('sign_rox', (1, 1, 1), emit=(1.0, 0.38, 0.12), strength=18.0),
)

def box(name, c, s, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c); o = bpy.context.object; o.name = name; o.scale = s
    bpy.ops.object.transform_apply(scale=True); o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new('bev', 'BEVEL'); mod.width = bevel; mod.segments = 2
    return o

def prism(name, pts, z0, z1, m):
    """Extrude a closed 2D outline (list of x,y) from z0 to z1."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    vb = [bm.verts.new((x, y, z0)) for x, y in pts]; vt = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(vb[::-1]); bm.faces.new(vt)
    n = len(pts)
    for i in range(n): bm.faces.new((vb[i], vb[(i + 1) % n], vt[(i + 1) % n], vt[i]))
    bm.to_mesh(me); bm.free(); o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); o.data.materials.append(m)
    return o

def chamfer(w, d, c):
    x, y = w / 2, d / 2
    return [(-x + c, -y), (x - c, -y), (x, -y + c), (x, y - c), (x - c, y), (-x + c, y), (-x, y - c), (-x, -y + c)]

def edge_strips(name, pts, z, m, t=0.12, h=0.12, out=0.05):
    """LED strip running along every edge of an outline at height z."""
    n = len(pts); objs = []
    for i in range(n):
        a, b = Vector((*pts[i], 0)), Vector((*pts[(i + 1) % n], 0))
        d = b - a; L = d.length; mid = (a + b) / 2; nrm = Vector((d.y, -d.x, 0)).normalized()
        bpy.ops.mesh.primitive_cube_add(size=1, location=(mid.x + nrm.x * out, mid.y + nrm.y * out, z))
        o = bpy.context.object; o.name = f'{name}_{i}'; o.scale = (L + t, t, h); o.rotation_euler = (0, 0, math.atan2(d.y, d.x))
        o.data.materials.append(m); objs.append(o)
    return objs

def vertical_strips(name, pts, z0, z1, m, t=0.12):
    for i, (x, y) in enumerate(pts):
        box(f'{name}_{i}', (x * 1.004, y * 1.004, (z0 + z1) / 2), (t, t, z1 - z0), m)

def fins(name, pts, z0, z1, spacing=1.6, depth=0.35, width=0.14):
    """Vertical mullion fins standing out of every face (curtain wall look)."""
    n = len(pts)
    for i in range(n):
        a, b = Vector((*pts[i], 0)), Vector((*pts[(i + 1) % n], 0)); d = b - a; L = d.length
        if L < 2: continue
        nrm = Vector((d.y, -d.x, 0)).normalized(); k = int(L / spacing)
        for j in range(1, k):
            p = a + d * (j / k) + nrm * depth / 2
            bpy.ops.mesh.primitive_cube_add(size=1, location=(p.x, p.y, (z0 + z1) / 2)); o = bpy.context.object
            o.scale = (width, depth, z1 - z0); o.rotation_euler = (0, 0, math.atan2(d.y, d.x)); o.name = f'{name}_{i}_{j}'
            o.data.materials.append(M['fin'])

def spandrels(name, pts, z0, z1, fh):
    """Thin horizontal floor bands on every face."""
    z = z0 + fh
    while z < z1 - 0.5:
        edge_strips(f'{name}_{int(z)}', pts, z, M['slab'], t=0.08, h=0.35, out=0.08); z += fh


def floors_lit(name, pts, z0, z1, fh, rate, seed):
    """Warm office floors glowing behind the dark glass (thin emissive bands, random per floor and face)."""
    import random; r = random.Random(seed); n = len(pts); z = z0 + 0.6
    while z < z1 - 1:
        for i in range(n):
            if r.random() > rate: continue
            a, b = Vector((*pts[i], 0)), Vector((*pts[(i + 1) % n], 0)); d = b - a; L = d.length
            if L < 3: continue
            nrm = Vector((d.y, -d.x, 0)).normalized(); t0 = r.uniform(0.0, 0.5); t1 = min(1.0, t0 + r.uniform(0.25, 0.6))
            p = a + d * ((t0 + t1) / 2) + nrm * 0.04
            bpy.ops.mesh.primitive_cube_add(size=1, location=(p.x, p.y, z + fh * 0.4)); o = bpy.context.object
            o.scale = (L * (t1 - t0), 0.02, fh * 0.55); o.rotation_euler = (0, 0, math.atan2(d.y, d.x)); o.data.materials.append(M['glass_lit'])
        z += fh

cam_data = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_data); bpy.context.collection.objects.link(cam); sc.camera = cam
cam_data.lens = 28; cam_data.clip_end = 3000
tgt = bpy.data.objects.new('target', None); bpy.context.collection.objects.link(tgt)
tr = cam.constraints.new('TRACK_TO'); tr.target = tgt; tr.track_axis = 'TRACK_NEGATIVE_Z'; tr.up_axis = 'UP_Y'
moon = bpy.data.lights.new('moon', 'SUN'); moon.energy = 0.25; moon.color = (0.6, 0.7, 1.0)
mo = bpy.data.objects.new('moon', moon); mo.rotation_euler = (math.radians(55), 0, math.radians(35)); bpy.context.collection.objects.link(mo)

step = [0]
def shot(title, cam_pos, look=(0, 0, 40)):
    step[0] += 1
    cam.location = cam_pos; tgt.location = look
    sc.render.filepath = os.path.join(OUT, f'step_{step[0]:02d}.png')
    bpy.ops.render.render(write_still=True)
    with open(os.path.join(OUT, 'steps.txt'), 'a') as f: f.write(f'{step[0]:02d}|{title}\n')
    print('STEP', step[0], title, flush=True)

open(os.path.join(OUT, 'steps.txt'), 'w').close()
A = (150, -170, 95)                         # main 3/4 aerial camera
# 1 ground: plaza, roads, crossing
box('ground', (0, 0, -0.5), (400, 400, 1), M['road'])
box('plaza', (0, 0, 0.08), (64, 54, 0.16), M['walk'])
for x in (-160, -120, -80, -40, 0, 40, 80, 120):
    box(f'lane_{x}', (x + 10, -40, 0.02), (12, 0.25, 0.02), M['line'])
box('centre_line', (0, -43, 0.02), (400, 0.3, 0.02), M['yellow'])
for k in range(10): box(f'zebra_{k}', (40 + k * 1.6, -40, 0.03), (0.8, 10, 0.02), M['line'])
shot('Ground: plaza, road, crossing', A, (0, 0, 10))
# 2 podium (chamfered, two floors) + glass
pod = chamfer(60, 50, 9); prism('podium', pod, 0.16, 14, M['glass']); prism('podium_roof', chamfer(62, 52, 9.4), 14, 15.2, M['slab'])
shot('Podium: chamfered glass base', A, (0, 0, 10))
# 3 podium fins + LED outline
fins('pod_fin', pod, 0.2, 14, spacing=2.2); edge_strips('pod_led_top', chamfer(62, 52, 9.4), 15.25, M['led']); edge_strips('pod_led_mid', pod, 7.1, M['led'], h=0.09)
vertical_strips('pod_led_v', pod, 0.2, 15.2, M['led'], t=0.1)
shot('Podium: fins + LED edges', A, (0, 0, 10))
# 4 lobby entrance canopy + ROX sign
box('canopy', (0, -27.5, 6.2), (22, 6, 0.5), M['slab']); edge_strips('canopy_led', [(-11, -30.5), (11, -30.5), (11, -24.5), (-11, -24.5)], 6.0, M['ledw'])
box('sign', (0, -25.4, 10.5), (14, 0.3, 2.2), M['sign'])
shot('Entrance canopy + ROX sign', (60, -95, 18), (0, -20, 8))
# 5 mid tower
mid = chamfer(48, 38, 8); prism('mid_tower', mid, 15.2, 70, M['glass'])
shot('Mid tower: dark glass', A)
# 6 mid fins + lit floors
fins('mid_fin', mid, 15.3, 70, spacing=1.6); spandrels('mid_sp', mid, 15.3, 70, 3.9); floors_lit('mid_lit', mid, 15.3, 70, 3.9, 0.18, 3)
shot('Curtain wall fins + lit offices', A)
# 7 setback slab + LED
prism('setback', chamfer(52, 42, 9), 70, 72.5, M['slab']); edge_strips('set_led', chamfer(52, 42, 9), 72.55, M['led'])
vertical_strips('mid_led_v', mid, 15.2, 70, M['led'])
shot('Setback + LED outline', A)
# 8 upper tower (offset, taller)
up = [(x - 4, y + 3) for x, y in chamfer(36, 30, 6)]; prism('upper_tower', up, 72.5, 128, M['glass'])
fins('up_fin', up, 72.6, 128, spacing=1.5); spandrels('up_sp', up, 72.6, 128, 3.9); floors_lit('up_lit', up, 72.6, 128, 3.9, 0.15, 9)
shot('Upper tower', (165, -150, 105), (0, 0, 70))
# 9 crown + LED
prism('crown', [(x * 1.06, y * 1.06) for x, y in up], 128, 131, M['slab'])
edge_strips('crown_led', [(x * 1.06, y * 1.06) for x, y in up], 131.05, M['led']); vertical_strips('up_led_v', up, 72.5, 128, M['led'])
for z in (100.0,): edge_strips(f'band_{z}', up, z, M['led'], h=0.08, out=0.25)
shot('Crown + LED bands', (165, -150, 105), (0, 0, 70))
# 10 rooftop: plant room, helipad, beacons
box('plant', (2, 6, 133), (14, 9, 4), M['slab']); edge_strips('plant_led', [(-5, 1.5), (9, 1.5), (9, 10.5), (-5, 10.5)], 135.05, M['ledw'], h=0.08)
bpy.ops.mesh.primitive_cylinder_add(radius=7, depth=0.4, location=(-6, -4, 131.2)); hp = bpy.context.object; hp.data.materials.append(M['heli'])
bpy.ops.mesh.primitive_torus_add(major_radius=6.4, minor_radius=0.12, location=(-6, -4, 131.45)); bpy.context.object.data.materials.append(M['ledw'])
for k in range(4):
    a = k * math.pi / 2 + 0.6; box(f'beacon_{k}', (-6 + math.cos(a) * 9, -4 + math.sin(a) * 9, 134), (0.3, 0.3, 6), M['slab'])
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, location=(-6 + math.cos(a) * 9, -4 + math.sin(a) * 9, 137.2)); bpy.context.object.data.materials.append(M['sign'])
shot('Rooftop: helipad + beacons', (75, -65, 160), (-2, 0, 128))
# 11 street lights + trees + parked cars (simple blocks)
for x in range(-120, 130, 24):
    box(f'pole_{x}', (x, -33, 4), (0.25, 0.25, 8), M['fin']); box(f'lamp_{x}', (x, -34.2, 8), (0.5, 2.4, 0.2), M['fin'])
    pl = bpy.data.lights.new(f'sl_{x}', 'POINT'); pl.energy = 1800; pl.color = (1.0, 0.82, 0.6); pl.shadow_soft_size = 0.4
    po = bpy.data.objects.new(f'sl_{x}', pl); po.location = (x, -35, 7.6); bpy.context.collection.objects.link(po)
for x in range(-26, 30, 8):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=2.2, location=(x, -29.5, 4.2)); t = bpy.context.object; t.scale = (1, 1, 1.2); t.data.materials.append(M['grass'])
    box(f'trunk_{x}', (x, -29.5, 1.5), (0.3, 0.3, 3), M['fin'])
shot('Street lights + trees', (60, -95, 18), (0, -20, 8))
# 12 city around (lit blocks)
import random; r = random.Random(4)
for i in range(70):
    x, y = r.uniform(-190, 190), r.uniform(-190, 190)
    if abs(x) < 45 and abs(y) < 40 or (-60 < y < -25): continue
    h = r.choice((12, 18, 24, 30, 40, 55)); wdt, dpt = r.uniform(12, 26), r.uniform(12, 26)
    box(f'city_{i}', (x, y, h / 2), (wdt, dpt, h), M['city'])
    for z in range(3, int(h) - 2, 4):
        if r.random() < 0.55: box(f'cw_{i}_{z}', (x, y - dpt / 2 - 0.05, z), (wdt * r.uniform(0.3, 0.9), 0.05, 1.2), M['cwin'])
shot('City around', (220, -260, 140), (0, 0, 60))
# 13-15 final hero shots
shot('Final - aerial', (165, -185, 115), (0, 0, 62))
shot('Final - street level', (38, -78, 2.2), (0, 0, 70))
shot('Final - top', (-115, -80, 175), (0, 0, 95))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'rox_tower.blend'))
print('DONE')
