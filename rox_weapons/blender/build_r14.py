# ROX Store | All rights reserved
# ROX R-14 battle rifle (original design) -> Blender model + weapon skeleton -> Sollumz CodeWalker XML + renders
# Run: python build_r14.py <folder-containing-sollumz> <out_dir>
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

ADDONS, OUT = sys.argv[-2], sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, 'textures')
NAME = 'w_ar_roxr14'

bpy.ops.wm.read_factory_settings(use_empty=True)
S = bpy.context.scene


def mat(name, tex=None, color=(0.1, 0.1, 0.1), rough=0.5, metal=0.0, scale=1.0, tint=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if tex:
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(os.path.join(TEX, tex + '.png'))
        if tint:
            mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'; mx.inputs[0].default_value = 1.0
            nt.links.new(t.outputs['Color'], mx.inputs[6]); mx.inputs[7].default_value = (*tint, 1)
            nt.links.new(mx.outputs[2], b.inputs['Base Color'])
        else:
            nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
        n = os.path.join(TEX, tex + '_n.png')
        if os.path.exists(n):
            ti = nt.nodes.new('ShaderNodeTexImage'); ti.image = bpy.data.images.load(n); ti.image.colorspace_settings.name = 'Non-Color'
            nm = nt.nodes.new('ShaderNodeNormalMap'); nt.links.new(ti.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], b.inputs['Normal'])
    else:
        b.inputs['Base Color'].default_value = (*color, 1)
    return m


WOOD = mat('roxr14_wood', 'rox_r14_wood', rough=0.38)
STEEL = mat('roxr14_steel', 'rox_r14_steel', rough=0.42, metal=0.85)
BLACK = mat('roxr14_black', None, (0.025, 0.025, 0.028), 0.55, 0.6)

parts = []


def part(kind, loc, size, m, rot=(0, 0, 0), bevel=0.0, verts=24, group='body'):
    if kind == 'cube': bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    else: bpy.ops.mesh.primitive_cylinder_add(location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object; o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        md = o.modifiers.new('b', 'BEVEL'); md.width = bevel; md.segments = 3; md.limit_method = 'ANGLE'
        bpy.ops.object.modifier_apply(modifier=md.name)
    if kind != 'cube' or bevel: bpy.ops.object.shade_smooth()
    o.data.materials.append(m); o['grp'] = group
    parts.append(o); return o


Y90 = (0, math.radians(90), 0)
# --- origin (0,0,0) = right-hand grip. Barrel points to +X (metres). ---
part('cube', (0.10, 0, 0.055), (0.32, 0.034, 0.075), STEEL, bevel=0.006)                   # receiver
part('cube', (0.10, 0, 0.097), (0.30, 0.026, 0.012), BLACK, bevel=0.002)                   # top cover
part('cube', (0.075, -0.019, 0.06), (0.06, 0.004, 0.02), BLACK)                            # ejection port
part('cyl', (0.47, 0, 0.068), (0.016, 0.016, 0.44), STEEL, rot=Y90, verts=20)              # barrel
part('cyl', (0.42, 0, 0.09), (0.012, 0.012, 0.32), STEEL, rot=Y90, verts=16)               # gas tube
part('cyl', (0.705, 0, 0.068), (0.026, 0.026, 0.06), BLACK, rot=Y90, verts=20)             # muzzle brake
for i in range(3):
    part('cube', (0.69 + i * 0.016, 0, 0.068), (0.005, 0.03, 0.012), STEEL)                # brake slots
part('cube', (0.695, 0, 0.1), (0.012, 0.006, 0.03), BLACK)                                 # front sight
part('cube', (0.0, 0, 0.11), (0.03, 0.022, 0.02), BLACK, bevel=0.002)                      # rear sight
part('cube', (0.33, 0, 0.065), (0.28, 0.046, 0.06), WOOD, bevel=0.012, group='body')       # wood handguard
part('cube', (0.36, 0, 0.097), (0.2, 0.03, 0.012), WOOD, bevel=0.004)                      # upper handguard
part('cube', (-0.004, 0, 0.008), (0.05, 0.034, 0.03), WOOD, bevel=0.008)                   # wrist
part('cube', (0.0, 0, -0.045), (0.042, 0.032, 0.1), WOOD, rot=(0, math.radians(-18), 0), bevel=0.01)   # pistol grip
part('cube', (-0.19, 0, 0.032), (0.34, 0.04, 0.07), WOOD, bevel=0.014)                                # stock
part('cube', (-0.26, 0, 0.012), (0.24, 0.04, 0.085), WOOD, rot=(0, math.radians(-6), 0), bevel=0.018)  # stock heel
part('cube', (-0.378, 0, 0.012), (0.014, 0.044, 0.11), BLACK, bevel=0.004)                 # butt pad
part('cube', (0.055, 0, 0.004), (0.07, 0.012, 0.004), STEEL)                               # trigger guard bottom
part('cube', (0.04, 0, 0.012), (0.006, 0.006, 0.026), BLACK, rot=(0, math.radians(15), 0)) # trigger
# magazine (own bone so reload animations can move it)
mag = part('cube', (0.15, 0, -0.03), (0.06, 0.026, 0.13), BLACK, rot=(0, math.radians(8), 0), bevel=0.004, group='mag')
part('cube', (0.16, 0, -0.095), (0.064, 0.03, 0.012), STEEL, group='mag')
for o in parts:                                            # UVs for textures
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=0.9); bpy.ops.object.mode_set(mode='OBJECT'); o.select_set(False)


GROUPS = {}
for o in parts: GROUPS.setdefault(o['grp'], []).append(o)


def join(group, name):
    objs = GROUPS[group]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); o = bpy.context.object; o.name = name
    o.data.uv_layers[0].name = 'UVMap 0'
    ca = o.data.color_attributes.new('Color 1', 'BYTE_COLOR', 'CORNER')
    for d in ca.data: d.color = (1, 1, 1, 1)
    return o


body = join('body', NAME + '_body')
magobj = join('mag', NAME + '_mag')

# ---- renders (icon + showcase) ----
S.render.engine = 'CYCLES'; S.cycles.samples = 96; S.render.film_transparent = True
S.view_settings.view_transform = 'Standard'; S.view_settings.exposure = -0.2
w = bpy.data.worlds.new('w'); S.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.3, 0.32, 0.35, 1)
for loc, e in [((0.3, -1.2, 0.9), 150), ((-0.8, -0.6, 0.4), 50), ((0.2, 1.0, 0.8), 90)]:
    bpy.ops.object.light_add(type='AREA', location=loc); L = bpy.context.object; L.data.energy = e; L.data.size = 1.2
    L.rotation_euler = (Vector((0.15, 0, 0.03)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(0.16, -1.55, 0.03)); cam = bpy.context.object; S.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 1.18; cam.rotation_euler = (math.radians(90), 0, 0)
S.render.resolution_x, S.render.resolution_y = 1024, 360
S.render.filepath = os.path.join(OUT, 'WEAPON_ROXR14_side.png'); bpy.ops.render.render(write_still=True)
cam.data.type = 'PERSP'; cam.data.lens = 50; cam.location = (0.75, -1.1, 0.42)
cam.rotation_euler = (Vector((0.16, 0, 0.02)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
S.render.resolution_x, S.render.resolution_y = 1280, 720
S.render.filepath = os.path.join(OUT, 'WEAPON_ROXR14_showcase.png'); bpy.ops.render.render(write_still=True)

# ---- skeleton + Sollumz export ----
sys.path.insert(0, ADDONS)
import addon_utils
addon_utils.enable('sollumz', default_set=True)
from sollumz.sollumz_properties import SollumType

BONES = [  # name, parent, position (m) -- standard GTA weapon bone names
    ('gun_root', None, (0, 0, 0)), ('Gun_GripR', 'gun_root', (0.0, 0, -0.03)), ('Gun_GripL', 'gun_root', (0.33, 0, 0.04)),
    ('Gun_Nuzzle', 'gun_root', (0.74, 0, 0.068)), ('WAPClip', 'gun_root', (0.15, 0, -0.03)), ('WAPScop', 'gun_root', (0.1, 0, 0.105)),
    ('WAPSupp', 'gun_root', (0.74, 0, 0.068)), ('WAPFlshLasr', 'gun_root', (0.38, 0.03, 0.06)), ('gun_vfx_eject', 'gun_root', (0.075, -0.02, 0.06)),
]
arm = bpy.data.armatures.new(NAME); ao = bpy.data.objects.new(NAME + '_drawable', arm); S.collection.objects.link(ao)
bpy.context.view_layer.objects.active = ao; bpy.ops.object.mode_set(mode='EDIT')
for n, p, pos in BONES:
    b = arm.edit_bones.new(n); b.head = pos; b.tail = (pos[0], pos[1] + 0.03, pos[2])
    if p: b.parent = arm.edit_bones[p]
bpy.ops.object.mode_set(mode='OBJECT')
ao.sollum_type = SollumType.DRAWABLE; ao.name = NAME
for o in (body, magobj):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.sollumz.autoconvertmaterials()
    o.sollum_type = SollumType.DRAWABLE_MODEL
    from sollumz.sollumz_properties import LODLevel
    o.sz_lods.get_lod(LODLevel.HIGH).mesh = o.data; o.sz_lods.active_lod_level = LODLevel.HIGH
    o.parent = ao
c = magobj.constraints.new('CHILD_OF'); c.target = ao; c.subtarget = 'WAPClip'; c.inverse_matrix = Matrix.Identity(4)
xml = os.path.join(OUT, 'stream'); os.makedirs(xml, exist_ok=True)
bpy.ops.object.select_all(action='DESELECT'); ao.select_set(True)
for ch in ao.children_recursive: ch.select_set(True)
bpy.ops.sollumz.export_assets(directory=xml, direct_export=True, use_custom_settings=True,
                              target_formats={'CWXML'}, target_versions={'GEN8'}, limit_to_selected=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'roxr14.blend'))
print('EXPORT', sorted(os.listdir(xml)))
