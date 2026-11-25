# ROX executive office: walls, wooden door, glass city wall, real scanned CC0 furniture (Poly Haven)  (c) ROX Store
#   PH=<poly haven dir> OUT=<dir> SAMPLES=64 DENOISE=1 python office.py
import bpy, math, os
from mathutils import Vector
PH = os.environ['PH']; OUT = os.environ.get('OUT', '/tmp/office'); os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = int(os.environ.get('SAMPLES', '64')); sc.cycles.use_denoising = bool(int(os.environ.get('DENOISE', '1')))
sc.cycles.max_bounces = 8; sc.cycles.sample_clamp_indirect = 4.0
sc.render.resolution_x, sc.render.resolution_y = int(os.environ.get('W', '1920')), int(os.environ.get('H', '1080'))
names = [i.identifier for i in sc.view_settings.bl_rna.properties['view_transform'].enum_items]
sc.view_settings.view_transform = 'AgX' if 'AgX' in names else 'Filmic'; sc.view_settings.exposure = 0.6

# night city HDRI seen through the glass wall
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True; nt = w.node_tree
env = nt.nodes.new('ShaderNodeTexEnvironment'); env.image = bpy.data.images.load(os.path.join(PH, 'rooftop_night', 'rooftop_night.hdr'))
nt.links.new(env.outputs['Color'], nt.nodes['Background'].inputs['Color']); nt.nodes['Background'].inputs['Strength'].default_value = 1.2

def mat(name, base=(0.5, 0.5, 0.5), metal=0.0, rough=0.5, emit=None, strength=0.0, glass=False):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*base, 1); b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit:
        b.inputs['Emission Color' if 'Emission Color' in b.inputs else 'Emission'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = strength
    if glass:
        b.inputs['Transmission Weight' if 'Transmission Weight' in b.inputs else 'Transmission'].default_value = 1.0; b.inputs['Roughness'].default_value = 0.0
    return m

def texmat(name, folder, scale=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; t = m.node_tree; b = t.nodes['Principled BSDF']
    co = t.nodes.new('ShaderNodeTexCoord'); mp = t.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (scale, scale, scale)
    t.links.new(co.outputs['Object'], mp.inputs['Vector'])
    d = os.path.join(PH, folder, 'textures')
    def img(kind, col):
        f = [x for x in os.listdir(d) if kind in x][0]; n = t.nodes.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(os.path.join(d, f))
        if not col: n.image.colorspace_settings.name = 'Non-Color'
        t.links.new(mp.outputs['Vector'], n.inputs['Vector']); return n
    t.links.new(img('diff', True).outputs['Color'], b.inputs['Base Color'])
    t.links.new(img('rough', False).outputs['Color'], b.inputs['Roughness'])
    nm = t.nodes.new('ShaderNodeNormalMap'); t.links.new(img('nor_gl', False).outputs['Color'], nm.inputs['Color']); t.links.new(nm.outputs['Normal'], b.inputs['Normal'])
    return m

M = dict(floor=texmat('oak_floor', 'laminate_floor_02', 0.5), wall=mat('plaster', (0.82, 0.8, 0.76), rough=0.85),
         panel=mat('walnut_panel', (0.17, 0.09, 0.05), rough=0.38), ceil=mat('ceiling', (0.9, 0.9, 0.88), rough=0.9),
         glass=mat('glass', (0.9, 0.95, 1.0), glass=True), frame=mat('black_frame', (0.02, 0.02, 0.022), metal=0.9, rough=0.3),
         door=mat('door_walnut', (0.2, 0.1, 0.05), rough=0.3), brass=mat('brass', (0.85, 0.62, 0.32), metal=1.0, rough=0.2),
         marble=mat('nero_marble', (0.03, 0.03, 0.035), rough=0.08), led=mat('led', (1, 1, 1), emit=(1.0, 0.82, 0.6), strength=18.0),
         logo=mat('rox', (1, 1, 1), emit=(1.0, 0.36, 0.1), strength=16.0), rug=mat('rug', (0.32, 0.3, 0.28), rough=1.0),
         screen=mat('screen', (0.01, 0.01, 0.01), emit=(0.3, 0.5, 1.0), strength=0.8))

def box(name, c, s, m, bev=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c); o = bpy.context.object; o.name = name; o.scale = s
    bpy.ops.object.transform_apply(scale=True); o.data.materials.append(m)
    if bev: md = o.modifiers.new('b', 'BEVEL'); md.width = bev; md.segments = 3
    return o

def asset(name, loc, rot=0.0, target=None):
    """import a Poly Haven glTF, drop it on the floor at loc, optional fit to a height"""
    d = os.path.join(PH, name); f = [x for x in os.listdir(d) if x.endswith('.gltf')][0]
    before = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=os.path.join(d, f))
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(name + '_root', None); bpy.context.collection.objects.link(root)
    for o in new:
        if o.parent is None: o.parent = root
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in new if o.type == 'MESH' for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))); hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = target / (hi.z - lo.z) if target else 1.0
    root.scale = (s, s, s); root.rotation_euler.z = math.radians(rot)
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    for o in new:
        if o.parent is root: o.location -= Vector((cx, cy, lo.z))
    root.location = Vector(loc); return root

cam_d = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_d); bpy.context.collection.objects.link(cam); sc.camera = cam
tgt = bpy.data.objects.new('t', None); bpy.context.collection.objects.link(tgt)
tr = cam.constraints.new('TRACK_TO'); tr.target = tgt; tr.track_axis = 'TRACK_NEGATIVE_Z'; tr.up_axis = 'UP_Y'
step = [0]; open(os.path.join(OUT, 'steps.txt'), 'w').close()
def shot(title, pos, look, lens=20):
    step[0] += 1; cam.location = pos; tgt.location = look; cam_d.lens = lens
    sc.render.filepath = os.path.join(OUT, f'step_{step[0]:02d}.png'); bpy.ops.render.render(write_still=True)
    open(os.path.join(OUT, 'steps.txt'), 'a').write(f'{step[0]:02d}|{title}\n'); print('STEP', step[0], title, flush=True)

# room 9 x 7 x 3.3, glass wall at y=+3.5, door on x=-4.5 wall
W2, D2, H = 4.5, 3.5, 3.3
ROOF = []
CAM_IN = ((3.9, -3.0, 1.65), (-1.0, 1.5, 1.0))
CAM_UP = ((7.5, -8.0, 7.5), (0, 0, 0.6))
# step 1: floor
box('floor', (0, 0, -0.05), (2 * W2, 2 * D2, 0.1), M['floor'])
shot('Floor: oak', *CAM_UP, lens=24)
# step 2: walls + door opening + walnut feature wall
box('wall_back', (0, -D2 - 0.1, H / 2), (2 * W2 + 0.4, 0.2, H), M['wall'])
box('wall_r', (W2 + 0.1, 0, H / 2), (0.2, 2 * D2, H), M['wall'])
DY, DW, DH = -1.2, 1.1, 2.4          # door centre y, width, height on the left wall
box('wall_l_a', (-W2 - 0.1, (-D2 + DY - DW / 2) / 2, H / 2), (0.2, (DY - DW / 2) + D2, H), M['wall'])
box('wall_l_b', (-W2 - 0.1, (DY + DW / 2 + D2) / 2, H / 2), (0.2, D2 - (DY + DW / 2), H), M['wall'])
box('wall_l_top', (-W2 - 0.1, DY, (DH + H) / 2), (0.2, DW, H - DH), M['wall'])
for i in range(9):                     # vertical walnut slats behind the desk
    box(f'slat{i}', (-2.0 + i * 0.5, -D2 + 0.03, H / 2), (0.36, 0.06, H - 0.02), M['panel'], 0.006)
shot('Walls + door', *CAM_UP, lens=24)
# step 3: the door (frame, leaf slightly open, brass handle)
for s in (-1, 1): box(f'jamb{s}', (-W2 - 0.1, DY + s * (DW / 2 + 0.03), DH / 2), (0.26, 0.06, DH), M['frame'])
box('head', (-W2 - 0.1, DY, DH + 0.03), (0.26, DW + 0.12, 0.06), M['frame'])
leaf = box('door_leaf', (0, DW / 2, DH / 2), (0.05, DW - 0.02, DH - 0.02), M['door'], 0.004)
for k in range(3): box(f'groove{k}', (0.03, DW / 2, 0.5 + k * 0.7), (0.012, DW - 0.25, 0.012), M['brass']).parent = leaf
h1 = box('handle', (0.08, DW - 0.12, 1.05), (0.03, 0.03, 0.55), M['brass'], 0.008); h1.parent = leaf
hinge = bpy.data.objects.new('hinge', None); bpy.context.collection.objects.link(hinge); hinge.location = (-W2 - 0.08, DY - DW / 2, 0)
leaf.parent = hinge; hinge.rotation_euler.z = math.radians(-35)
shot('Door: walnut', (1.5, -1.8, 1.6), (-W2, DY, 1.2), lens=26)
# step 4: glass city wall + ceiling + lights
for i in range(7): box(f'mull{i}', (-W2 + i * 1.5, D2, H / 2), (0.05, 0.08, H), M['frame'])
box('glass', (0, D2, H / 2), (2 * W2, 0.02, H), M['glass'])
box('sill', (0, D2 - 0.1, 0.05), (2 * W2, 0.2, 0.1), M['frame'])
box('ceiling', (0, 0, H + 0.05), (2 * W2 + 0.4, 2 * D2, 0.1), M['ceil'])
box('cove_back', (0, -D2 + 0.1, H - 0.04), (2 * W2 - 0.2, 0.03, 0.03), M['led'])
for x in (-3, -1, 1, 3):
    for y in (-1.8, 0.6):
        box(f'spot{x}{y}', (x, y, H - 0.005), (0.12, 0.12, 0.01), M['led'])
        L = bpy.data.lights.new('spot', 'SPOT'); L.energy = 120; L.spot_size = math.radians(75); L.spot_blend = 0.6; L.color = (1, 0.88, 0.72)
        o = bpy.data.objects.new('spot', L); bpy.context.collection.objects.link(o); o.location = (x, y, H - 0.03)
A = bpy.data.lights.new('fill', 'AREA'); A.energy = 250; A.size = 6; A.color = (1, 0.92, 0.85)
o = bpy.data.objects.new('fill', A); bpy.context.collection.objects.link(o); o.location = (0, 0, H - 0.1)
shot('Glass wall + ceiling', *CAM_IN)
# step 5: executive desk (nero marble top, walnut legs) + chair + screen
box('desk_top', (0, -1.6, 0.74), (2.4, 1.0, 0.05), M['marble'], 0.01)
box('desk_l', (-1.05, -1.6, 0.36), (0.08, 0.9, 0.72), M['panel'], 0.01)
box('desk_r', (0.6, -1.6, 0.36), (0.9, 0.9, 0.72), M['panel'], 0.01)
box('mon', (0, -1.85, 1.05), (0.75, 0.03, 0.42), M['screen']); box('mon_st', (0, -1.88, 0.83), (0.06, 0.06, 0.16), M['frame'])
asset('modern_arm_chair_01', (0, -2.55, 0), 0, 1.05)
asset('desk_lamp_arm_01', (0.95, -1.75, 0.765), 200, 0.55)
asset('book_encyclopedia_set_01', (-0.85, -1.85, 0.765), 0, 0.25)
for s in (-1, 1): asset('dining_chair_02' if os.path.isdir(os.path.join(PH, 'dining_chair_02')) else 'mid_century_lounge_chair', (s * 0.6, -0.55, 0), 180, 0.85)
shot('Desk: marble + chair', (2.2, 0.8, 1.55), (0, -1.8, 0.8), lens=26)
# step 6: lounge by the window
box('rug', (2.2, 1.6, 0.005), (3.2, 2.2, 0.01), M['rug'])
asset('sofa_03', (2.2, 0.55, 0), 0, 0.85)
asset('mid_century_lounge_chair', (3.6, 2.4, 0), 220, 0.85)
asset('modern_coffee_table_01', (2.2, 1.6, 0), 0, 0.42)
asset('ceramic_vase_01', (2.2, 1.6, 0.42), 0, 0.3)
asset('side_table_01', (3.9, 0.6, 0), 0, 0.55)
shot('Lounge by the glass', (-1.5, -2.8, 1.7), (2.4, 1.6, 0.4), lens=24)
# step 7: storage, art, plants, logo
asset('modern_wooden_cabinet', (W2 - 0.3, -1.6, 0), 270, 0.8)
asset('marble_bust_01', (W2 - 0.3, -1.9, 0.8), 270, 0.4)
asset('steel_frame_shelves_03', (-3.6, -D2 + 0.35, 0), 0, 2.0)
asset('hanging_picture_frame_01', (W2 - 0.02, -1.6, 1.4), 270, 0.9)
asset('wall_clock', (-W2 + 0.03, 1.8, 2.2), 90, 0.4)
asset('potted_plant_01', (-W2 + 0.5, D2 - 0.5, 0), 0, 1.5)
asset('potted_plant_02', (W2 - 0.5, D2 - 0.5, 0), 0, 1.2)
asset('potted_plant_02', (-2.2, -D2 + 0.4, 0), 0, 1.0)
asset('CoffeeCart_01', (-3.6, 1.2, 0), 90, 0.9)
for i, (x, wd) in enumerate([(-0.55, 0.32), (-0.12, 0.08), (0.12, 0.08), (0.42, 0.28)]):   # ROX letters glow on the slats
    box(f'rox{i}', (x, -D2 + 0.08, 2.35), (wd, 0.02, 0.4), M['logo'])
shot('Storage, art + plants', *CAM_IN)
# finals
asset('modern_ceiling_lamp_01', (2.2, 1.6, H - 0.9), 0, 0.9)
shot('Final - office', *CAM_IN, lens=18)
shot('Final - from the door', (-W2 + 0.4, DY, 1.6), (2.5, 0.5, 0.9), lens=18)
sc.view_settings.exposure = 0.2
shot('Final - city view', (-2.5, -2.6, 1.3), (1.5, D2 + 4, 1.6), lens=22)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'rox_office.blend'))
print('DONE')
