# ROX Store | All rights reserved
# Turn a free (CC0) weapon model into a GTA V weapon drawable (CodeWalker XML) via Sollumz.
# python convert_weapon.py <sollumz_addons> <src model> <out_dir> <gta_model_name> <length_m> <rot_x,rot_y,rot_z deg> <grip_fx,grip_fz> <icon_name>
#   grip_fx / grip_fz: right-hand grip position as fraction of the length (from the muzzle) / height (from the bottom)
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix, Euler

ADD, SRC, OUT, NAME, LENGTH, ROT, GRIP, ICON = sys.argv[-8:]
LENGTH = float(LENGTH); ROT = [math.radians(float(v)) for v in ROT.split(',')]; GFX, GFZ = [float(v) for v in GRIP.split(',')]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.use_scripts_auto_execute = False
S = bpy.context.scene
ext = os.path.splitext(SRC)[1].lower()
if ext == '.fbx': bpy.ops.import_scene.fbx(filepath=SRC)
elif ext == '.obj': bpy.ops.wm.obj_import(filepath=SRC)
else:
    with bpy.data.libraries.load(SRC, link=False) as (a, b): b.objects = list(a.objects)
    for o in b.objects:
        if o and o.type == 'MESH': S.collection.objects.link(o)
for o in list(S.objects):
    if o.type != 'MESH': bpy.data.objects.remove(o)
meshes = [o for o in S.objects if o.type == 'MESH']

# join, apply transforms
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
gun = bpy.context.object; gun.name = NAME + '_body'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# drop small loose parts that float away from the gun (speed-loaders, stray bullets)
bm = bmesh.new(); bm.from_mesh(gun.data)
islands, seen = [], set()
for f in bm.faces:
    if f.index in seen: continue
    stack, isl = [f], []
    while stack:
        g = stack.pop()
        if g.index in seen: continue
        seen.add(g.index); isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen: stack.append(h)
    islands.append(isl)
def bbox(isl):
    vs = [v.co for f in isl for v in f.verts]
    return Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))), Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
big = max(islands, key=lambda i: (bbox(i)[1] - bbox(i)[0]).length)
blo, bhi = bbox(big); pad = (bhi - blo) * 0.15
from mathutils.kdtree import KDTree
bigv = {v.index for f in big for v in f.verts}
kd = KDTree(len(bigv))
for i in bigv: kd.insert(bm.verts[i].co, i) if False else None
bm.verts.ensure_lookup_table()
kd = KDTree(len(bigv))
for i in bigv: kd.insert(bm.verts[i].co, i)
kd.balance()
diag = (bhi - blo).length
kill = []
for isl in islands:
    if isl is big: continue
    lo, hi = bbox(isl); c = (lo + hi) / 2
    outside = not all(blo[k] - pad[k] <= c[k] <= bhi[k] + pad[k] for k in range(3))
    small = (hi - lo).length < diag * 0.08
    near = min(kd.find(v.co)[2] for f in isl for v in f.verts)
    if outside or (small and near > diag * 0.01): kill += isl
bmesh.ops.delete(bm, geom=list(set(kill)), context='FACES')
bm.to_mesh(gun.data); bm.free()
print('removed faces', len(set(kill)))

# orient (barrel +X, up +Z), scale to real length, grip at origin
gun.rotation_euler = Euler(ROT, 'XYZ'); bpy.ops.object.transform_apply(rotation=True)
vs = [gun.matrix_world @ v.co for v in gun.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))); hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
s = LENGTH / (hi.x - lo.x); gun.scale = (s, s, s); bpy.ops.object.transform_apply(scale=True)
lo, hi = lo * s, hi * s
cy = (lo.y + hi.y) / 2
grip = Vector((hi.x - GFX * (hi.x - lo.x), cy, lo.z + GFZ * (hi.z - lo.z)))
gun.location = -grip; bpy.ops.object.transform_apply(location=True)
lo, hi = lo - grip, hi - grip
muzzle = Vector((hi.x, 0, lo.z + 0.72 * (hi.z - lo.z)))
print('SIZE', tuple(round(v, 3) for v in (hi - lo)), 'muzzle', tuple(round(v, 3) for v in muzzle))

if not gun.data.uv_layers: bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.smart_project(); bpy.ops.object.mode_set(mode='OBJECT')
gun.data.uv_layers[0].name = 'UVMap 0'
if 'Color 1' not in gun.data.color_attributes:
    ca = gun.data.color_attributes.new('Color 1', 'BYTE_COLOR', 'CORNER')
    for d in ca.data: d.color = (1, 1, 1, 1)
for m in gun.data.materials:                # make sure an image texture drives base colour (Sollumz needs it)
    if m and m.use_nodes and not any(n.type == 'TEX_IMAGE' for n in m.node_tree.nodes):
        print('WARN material without texture', m.name)

# icon render (side, transparent)
S.render.engine = 'CYCLES'; S.cycles.samples = 64; S.render.film_transparent = True
S.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new('w'); S.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
c = (lo + hi) / 2; L = (hi - lo)
for loc, e in [((c.x, -2, c.z + 1), 3.0), ((c.x - 1, -1, c.z), 1.2)]:
    bpy.ops.object.light_add(type='SUN', location=loc); l = bpy.context.object; l.data.energy = e
    l.rotation_euler = (c - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(c.x, -3, c.z)); cam = bpy.context.object; cam.rotation_euler = (math.radians(90), 0, 0)
cam.data.type = 'ORTHO'; cam.data.ortho_scale = L.x * 1.08; S.camera = cam
S.render.resolution_x, S.render.resolution_y = 960, int(960 * max(0.3, (L.z + 0.04) / L.x))
S.render.filepath = os.path.join(OUT, ICON + '.png'); bpy.ops.render.render(write_still=True)

# skeleton + Sollumz export
sys.path.insert(0, ADD)
import addon_utils
addon_utils.enable('sollumz', default_set=True)
from sollumz.sollumz_properties import SollumType, LODLevel
BONES = [('gun_root', None, (0, 0, 0)), ('Gun_GripR', 'gun_root', (0, 0, 0)), ('Gun_GripL', 'gun_root', (0.55 * hi.x, 0, 0.02)),
         ('Gun_Nuzzle', 'gun_root', tuple(muzzle)), ('WAPClip', 'gun_root', (0.08 * hi.x, 0, -0.02)), ('WAPScop', 'gun_root', (0.1 * hi.x, 0, hi.z)),
         ('WAPSupp', 'gun_root', tuple(muzzle)), ('WAPFlshLasr', 'gun_root', (0.5 * hi.x, 0.03, 0.02)), ('gun_vfx_eject', 'gun_root', (0.08 * hi.x, -0.02, 0.03))]
arm = bpy.data.armatures.new(NAME); ao = bpy.data.objects.new(NAME, arm); S.collection.objects.link(ao)
bpy.context.view_layer.objects.active = ao; bpy.ops.object.mode_set(mode='EDIT')
for n, p, pos in BONES:
    b = arm.edit_bones.new(n); b.head = pos; b.tail = (pos[0], pos[1] + 0.03, pos[2])
    if p: b.parent = arm.edit_bones[p]
bpy.ops.object.mode_set(mode='OBJECT')
ao.sollum_type = SollumType.DRAWABLE
bpy.ops.object.select_all(action='DESELECT'); gun.select_set(True); bpy.context.view_layer.objects.active = gun
bpy.ops.sollumz.autoconvertmaterials()
gun.sollum_type = SollumType.DRAWABLE_MODEL
gun.sz_lods.get_lod(LODLevel.HIGH).mesh = gun.data; gun.sz_lods.active_lod_level = LODLevel.HIGH
gun.parent = ao
xml = os.path.join(OUT, 'stream'); os.makedirs(xml, exist_ok=True)
bpy.ops.object.select_all(action='DESELECT'); ao.select_set(True); gun.select_set(True)
bpy.ops.sollumz.export_assets(directory=xml, direct_export=True, use_custom_settings=True,
                              target_formats={'CWXML'}, target_versions={'GEN8'}, limit_to_selected=True)
print('EXPORT', sorted(os.listdir(xml)))
