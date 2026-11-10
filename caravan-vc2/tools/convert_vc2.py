"""Builds the VC2 caravan as a GTA V vehicle fragment with Sollumz and exports it as CodeWalker XML.
Run:  bl/bin/python convert_vc2.py <addons_dir> <glb> <out_dir>
"""
import sys, os, re, math
import bpy, addon_utils
from mathutils import Matrix, Vector

ADDONS, GLB, OUT = sys.argv[-3:]
sys.path.insert(0, ADDONS)
addon_utils.enable("io_scene_gltf2", default_set=True)
addon_utils.enable("Sollumz", default_set=True)

from Sollumz.sollumz_properties import SollumType, LODLevel
from Sollumz.ydr.shader_materials import create_shader
from Sollumz.ybn.collision_materials import create_collision_material_from_index, collisionmats
from Sollumz.ydr.properties import BoneProperties
from Sollumz.tools.drawablehelper import convert_obj_to_model
from Sollumz.tools.blenderhelper import create_empty_object, create_blender_object
from PIL import Image
import numpy as np

MODEL = "vc2caravan"
TEX_DIR = os.path.join(OUT, "_dds")
os.makedirs(TEX_DIR, exist_ok=True)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.import_scene.gltf(filepath=GLB)

# ------------------------------------------------------------------ 1. bake everything into GTA space
# three.js (x fwd, y up, z right) -> glTF import (x fwd, -z, y up) -> rotate +90 about Z -> GTA (x right, y fwd, z up)
R = Matrix.Rotation(math.radians(90.0), 4, "Z")
BASE = lambda n: re.sub(r"\.\d+$", "", n)

def ancestors(o):
    out, p = [], o.parent
    while p:
        out.append(BASE(p.name)); p = p.parent
    return out

LIGHTS = {
    "headlight_l": "headlight_l", "headlight_r": "headlight_r",
    "headlight_projector_l": "headlight_l", "headlight_projector_r": "headlight_r",
    "taillight_l": "taillight_l", "taillight_r": "taillight_r",
    "indicator_lf": "indicator_lf", "indicator_rf": "indicator_rf",
    "headlight_turn_l": "indicator_lf", "headlight_turn_r": "indicator_rf",
    "reverse_light_l": "reversinglight_l", "reverse_light_r": "reversinglight_r",
}
WHEELS = ("wheel_lf", "wheel_rf", "wheel_lr", "wheel_rr")
DOORS = ("door_dside_f", "door_pside_f", "door_pside_r")

def bone_for(o):
    base, anc = BASE(o.name), ancestors(o)
    for w in WHEELS:
        if w in anc: return w
    if base in ("window_lf", "window_rf"): return base
    for d in DOORS:
        if d in anc: return d
    if "steeringw" in anc: return "steeringw"
    if base == "windscreen": return "windscreen"
    if base in LIGHTS: return LIGHTS[base]
    return "chassis"

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
assign = {}
for o in meshes:
    assign[o.name] = bone_for(o)
for o in meshes:
    mw = R @ o.matrix_world
    o.data = o.data.copy()
    o.data.transform(mw)
    o.parent = None
    o.matrix_world = Matrix.Identity(4)
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)

# ------------------------------------------------------------------ 2. bone positions (GTA space)
def gta(x, y, z):  # three.js builder coords -> GTA coords (model origin at x = 3.95)
    return Vector((z, x - 3.95, y))

CAB, WB = 2.24, 2.45
BONES = {
    "chassis": (None, gta(3.95, 0.0, 0.0)),
    "wheel_lf": ("chassis", gta(6.95, 0.42, -1.0)), "wheel_rf": ("chassis", gta(6.95, 0.42, 1.0)),
    "wheel_lr": ("chassis", gta(1.95, 0.42, -0.97)), "wheel_rr": ("chassis", gta(1.95, 0.42, 0.97)),
    "door_dside_f": ("chassis", gta(6.9, 1.0, -CAB / 2)), "door_pside_f": ("chassis", gta(6.9, 1.0, CAB / 2)),
    "door_pside_r": ("chassis", gta(3.65 + 0.36, 1.6, WB / 2)),
    "window_lf": ("door_dside_f", gta(6.3, 1.75, -CAB / 2)), "window_rf": ("door_pside_f", gta(6.3, 1.75, CAB / 2)),
    "windscreen": ("chassis", gta(6.69, 1.735, 0.0)),
    "steeringw": ("chassis", gta(6.3, 1.32, -0.5)),
    "seat_dside_f": ("chassis", gta(5.75, 1.0, -0.5)), "seat_pside_f": ("chassis", gta(5.75, 1.0, 0.5)),
    "headlight_l": ("chassis", gta(7.965, 0.95, -0.66)), "headlight_r": ("chassis", gta(7.965, 0.95, 0.66)),
    "indicator_lf": ("chassis", gta(7.965, 0.815, -0.66)), "indicator_rf": ("chassis", gta(7.965, 0.815, 0.66)),
    "taillight_l": ("chassis", gta(0.0, 1.35, -1.05)), "taillight_r": ("chassis", gta(0.0, 1.35, 1.05)),
    "brakelight_l": ("chassis", gta(0.0, 1.35, -1.05)), "brakelight_r": ("chassis", gta(0.0, 1.35, 1.05)),
    "indicator_lr": ("chassis", gta(0.0, 1.2, -1.05)), "indicator_rr": ("chassis", gta(0.0, 1.2, 1.05)),
    "reversinglight_l": ("chassis", gta(0.0, 0.88, -1.05)), "reversinglight_r": ("chassis", gta(0.0, 0.88, 1.05)),
    "bodyshell": ("chassis", gta(3.95, 1.5, 0.0)),
}
# the model origin is the chassis bone, so move every vertex so that chassis = (0,0,0)
ORIGIN = BONES["chassis"][1].copy()
for name, (parent, head) in BONES.items():
    BONES[name] = (parent, head - ORIGIN)
for o in meshes:
    o.data.transform(Matrix.Translation(-ORIGIN))

arm_data = bpy.data.armatures.new(MODEL + ".skel")
arm = bpy.data.objects.new(MODEL, arm_data)
bpy.context.scene.collection.objects.link(arm)
arm.sollum_type = SollumType.FRAGMENT
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name, (parent, head) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head = head
    b.tail = head + Vector((0.0, 0.08, 0.0))   # +Y, roll 0 -> identity bone orientation
    b.roll = 0.0
    eb[name] = b
for name, (parent, _) in BONES.items():
    if parent: eb[name].parent = eb[parent]
bpy.ops.object.mode_set(mode="OBJECT")
for b in arm_data.bones:
    b.bone_properties.tag = 0 if b.name == "chassis" else BoneProperties.calc_tag_hash(b.name)
# door hinges (joint limits), physics groups on bones that carry collision
JOINTS = {"door_dside_f": (-1.25, 0.0), "door_pside_f": (0.0, 1.25), "door_pside_r": (0.0, 1.3)}
for pb in arm.pose.bones:
    if pb.name in JOINTS:
        c = pb.constraints.new("LIMIT_ROTATION")
        c.use_limit_x = c.use_limit_y = c.use_limit_z = True
        c.min_z, c.max_z = JOINTS[pb.name]
        c.owner_space = "LOCAL"
for name in ("chassis", "door_dside_f", "door_pside_f", "door_pside_r"):
    arm_data.bones[name].sollumz_use_physics = True

# ------------------------------------------------------------------ 3. materials -> GTA vehicle shaders (+ DDS textures)
def pot(n):
    p = 4
    while p < n and p < 1024: p *= 2
    return p

dds_cache = {}
def dds_from_pixels(name, arr, alpha):
    key = name
    if key in dds_cache: return dds_cache[key]
    im = Image.fromarray(arr, "RGBA")
    w, h = pot(im.width), pot(im.height)
    im = im.resize((w, h), Image.LANCZOS)
    path = os.path.join(TEX_DIR, name + ".dds")
    im.save(path, pixel_format="DXT5" if alpha else "DXT1")
    img = bpy.data.images.load(path, check_existing=True)
    img.name = name
    dds_cache[key] = img
    return img

def dds_from_image(bimg, name, alpha):
    w, h = bimg.size
    px = np.array(bimg.pixels[:], dtype=np.float32).reshape(h, w, 4)
    # Blender pixels already match the UV convention Sollumz exports with (no flip)
    if bimg.colorspace_settings.name != "Non-Color":  # glTF images are sRGB already stored as sRGB bytes
        pass
    arr = (np.clip(px, 0, 1) * 255).astype(np.uint8)
    return dds_from_pixels(name, arr, alpha)

def dds_solid(rgba):
    r, g, b, a = [int(max(0, min(1, c)) * 255) for c in rgba]
    name = f"vc2c_{r:02x}{g:02x}{b:02x}{a:02x}"
    arr = np.zeros((8, 8, 4), np.uint8); arr[:] = (r, g, b, a)
    return dds_from_pixels(name, arr, a < 255)

def lin2srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055

def read_gltf_material(mat):
    """(srgb colour rgba, image or None, emissive?)"""
    col, img, emis = (0.8, 0.8, 0.8, 1.0), None, False
    if not mat or not mat.node_tree: return col, img, emis
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None: return col, img, emis
    bc = bsdf.inputs["Base Color"]
    lin = list(bc.default_value)
    col = (lin2srgb(lin[0]), lin2srgb(lin[1]), lin2srgb(lin[2]), bsdf.inputs["Alpha"].default_value)
    stack = [l.from_node for l in bc.links]
    while stack:
        n = stack.pop()
        if n.type == "TEX_IMAGE" and n.image: img = n.image; break
        for i in n.inputs:
            stack += [l.from_node for l in i.links]
    es = bsdf.inputs.get("Emission Strength")
    ec = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if es is not None and ec is not None and es.default_value > 0 and (sum(ec.default_value[:3]) > 0.05 or ec.is_linked):
        emis = True
    return col, img, emis

LIGHT_BONES = set(LIGHTS.values())
def shader_for(mat_name, bone, emis):
    n = mat_name.lower()
    if bone == "chassis" and any(k in n for k in ("vc2_paint",)) : return "vehicle_paint1.sps"
    if bone in DOORS and "vc2_paint" in n: return "vehicle_paint1.sps"
    if "glass" in n and "mirror" not in n: return "vehicle_vehglass.sps"
    if "livery" in n or "logo" in n or "swoosh" in n and "_2" not in n: return "vehicle_decal.sps"
    if "tyre" in n: return "vehicle_tire.sps"
    if bone in LIGHT_BONES: return "vehicle_lightsemissive.sps"
    if emis or any(k in n for k in ("led", "marker", "ceiling_light", "gauges", "prndl", "wall_screen", "projector")): return "vehicle_emissive_opaque.sps"
    if any(k in n for k in ("leather", "floor", "interior", "seat", "dash", "cab_floor", "cup", "button", "stitch", "cluster")): return "vehicle_interior.sps"
    return "vehicle_mesh.sps"

SHARED_TEX = {  # vehshare textures referenced by name (not embedded)
    "DamageSampler": "vehicle_genericmud_car", "DirtSampler": "vehicle_genericmud_car",
    "SpecSampler": "vehicle_generic_smallspecmap", "BumpSampler": "vehicle_generic_smallspecmap",
}
placeholder = {}
def shared_image(name):
    if name not in placeholder:
        img = bpy.data.images.new(name, 4, 4); placeholder[name] = img
    return placeholder[name]

sz_cache = {}
def sollumz_material(src, bone):
    col, img, emis = read_gltf_material(src)
    shader = shader_for(src.name if src else "", bone, emis)
    alpha = shader in ("vehicle_decal.sps", "vehicle_vehglass.sps")
    if shader == "vehicle_vehglass.sps":
        tex = dds_solid((0.9, 0.93, 0.95, 0.12))           # clear, untinted glass
    elif shader == "vehicle_paint1.sps":
        tex = dds_solid((1, 1, 1, 1))                      # colour comes from the vehicle paint
    elif img is not None:
        tex = dds_from_image(img, "vc2c_" + re.sub(r"[^a-z0-9]+", "_", (src.name or img.name).lower())[:40], alpha)
    else:
        tex = dds_solid(col)
    key = (shader, tex.name)
    if key in sz_cache: return sz_cache[key]
    m = create_shader(shader)
    m.name = f"{MODEL}_{shader.replace('.sps', '')}_{tex.name}"
    for node in m.node_tree.nodes:
        if node.type != "TEX_IMAGE": continue
        if node.name == "DiffuseSampler":
            node.image = tex
            node.texture_properties.embedded = True
        elif node.name in SHARED_TEX:
            node.image = shared_image(SHARED_TEX[node.name])
            node.texture_properties.embedded = False
    sz_cache[key] = m
    return m

for o in meshes:
    bone = assign[o.name]
    for i, slot in enumerate(o.material_slots):
        o.material_slots[i].material = sollumz_material(slot.material, bone)

# GTA vehicle shaders read vertex colours (dirt / damage / glass shattering): give every mesh a white Colour0
for o in meshes:
    me = o.data
    for ca in list(me.color_attributes): me.color_attributes.remove(ca)
    for cn in ("Color 0", "Color 1"):
        ca = me.color_attributes.new(cn, "BYTE_COLOR", "CORNER")
        ca.data.foreach_set("color", [1.0] * (len(ca.data) * 4))
    me.color_attributes.active_color_index = 0
    me.color_attributes.render_color_index = 0
    # UV channels the vehicle shaders use (copies of the first one)
    if not me.uv_layers: me.uv_layers.new(name="UVMap 0")
    me.uv_layers[0].name = "UVMap 0"
    while len(me.uv_layers) > 1 and me.uv_layers[1].name not in ("UVMap 1",): me.uv_layers.remove(me.uv_layers[1])
    src = [0.0] * (len(me.loops) * 2); me.uv_layers[0].data.foreach_get("uv", src)
    for un in ("UVMap 1", "UVMap 2"):
        if un not in me.uv_layers: me.uv_layers.new(name=un)
        me.uv_layers[un].data.foreach_set("uv", src)

# ------------------------------------------------------------------ 4. drawable: ONE skinned model, every vertex weighted 100% to its bone
drawable = create_empty_object(SollumType.DRAWABLE, MODEL + ".mesh")
drawable.parent = arm
for o in meshes:
    vg = o.vertex_groups.new(name=assign[o.name])
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
with bpy.context.temp_override(active_object=meshes[0], selected_editable_objects=meshes, selected_objects=meshes):
    bpy.ops.object.join()
body = meshes[0]
body.name = MODEL
convert_obj_to_model(body)
body.parent = drawable
mod = body.modifiers.new("Armature", "ARMATURE"); mod.object = arm
counts = {}
for v in body.data.vertices:
    g = body.vertex_groups[v.groups[0].group].name if v.groups else "?"
    counts[g] = counts.get(g, 0) + 1
print("model verts:", len(body.data.vertices), "materials:", len(body.data.materials))
print("per bone:", counts)

# ------------------------------------------------------------------ 5. collision: hollow shell so you can walk inside
composite = create_empty_object(SollumType.BOUND_COMPOSITE, MODEL + ".col")
composite.parent = arm
car_metal = next(i for i, m in enumerate(collisionmats) if m.name == "CAR_METAL")
col_mat = create_collision_material_from_index(car_metal)

def box(name, bone, c3, s3, mass):
    """c3/s3 in builder coords (x fwd, y up, z right); converted to bone space."""
    c = gta(*c3) - ORIGIN - BONES[bone][1]
    size = Vector((s3[2], s3[0], s3[1]))
    me = bpy.data.meshes.new(name)
    hx, hy, hz = size / 2
    v = [(c.x + sx * hx, c.y + sy * hy, c.z + sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    me.from_pydata(v, [], f); me.update()
    ob = create_blender_object(SollumType.BOUND_BOX, name, me)
    ob.data.materials.append(col_mat)
    ob.parent = composite
    k = ob.constraints.new("COPY_TRANSFORMS"); k.target = arm; k.subtarget = bone
    ob.child_properties.mass = mass
    ob.child_properties.shattermap_mode = "NO"
    return ob

S = []
# living box
S += [box("floor", "chassis", (2.85, 0.64, 0), (5.5, 0.12, WB - 0.06), 900),
      box("roof", "chassis", (2.85, 3.3, 0), (5.6, 0.1, WB), 400),
      box("underbody", "chassis", (3.9, 0.47, 0), (7.4, 0.24, 1.5), 1500)]
# left wall (slide-out opening 2.65..5.25 x 0.78..2.95 stays open)
S += [box("wall_l_rear", "chassis", (1.35, 1.95, -1.19), (2.6, 2.5, 0.07), 120),
      box("wall_l_front", "chassis", (5.42, 1.95, -1.19), (0.34, 2.5, 0.07), 20),
      box("wall_l_top", "chassis", (3.95, 3.12, -1.19), (2.6, 0.34, 0.07), 20)]
# right wall with the entry door gap (3.29..4.01, up to 2.49)
S += [box("wall_r_rear", "chassis", (1.66, 1.95, 1.19), (3.22, 2.5, 0.07), 140),
      box("wall_r_front", "chassis", (4.8, 1.95, 1.19), (1.58, 2.5, 0.07), 70),
      box("wall_r_door_top", "chassis", (3.65, 2.9, 1.19), (0.74, 0.8, 0.07), 10)]
# rear wall around the rear slide-out opening (|z| < 0.85, 0.8..2.9)
S += [box("rear_l", "chassis", (0.03, 1.95, -1.04), (0.07, 2.5, 0.37), 15), box("rear_r", "chassis", (0.03, 1.95, 1.04), (0.07, 2.5, 0.37), 15),
      box("rear_low", "chassis", (0.03, 0.7, 0), (0.07, 0.2, 1.7), 10), box("rear_top", "chassis", (0.03, 3.1, 0), (0.07, 0.4, 1.7), 10)]
# cab-over bunk + nose
S += [box("bunk_floor", "chassis", (6.4, 2.24, 0), (2.0, 0.1, WB - 0.1), 120), box("cabover_top", "chassis", (6.3, 3.25, 0), (1.9, 0.18, 2.3), 80),
      box("nose", "chassis", (7.3, 2.7, 0), (0.55, 0.45, 1.9), 40)]
# cab: hood/engine, cab floor, windscreen, rear posts, bumpers
S += [box("hood", "chassis", (7.42, 0.92, 0), (1.05, 0.7, 2.0), 600), box("cab_floor", "chassis", (6.1, 0.64, 0), (1.5, 0.12, CAB - 0.1), 150),
      box("windscreen_col", "chassis", (6.72, 1.72, 0), (0.12, 0.75, CAB - 0.2), 15),
      box("cab_roof", "chassis", (6.0, 2.18, 0), (1.1, 0.06, CAB), 30),
      box("bumper_f", "chassis", (8.02, 0.56, 0), (0.24, 0.22, CAB), 40), box("bumper_r", "chassis", (-0.02, 0.6, 0), (0.2, 0.2, WB), 30)]
# doors (move with their bones)
S += [box("door_dside_f_col", "door_dside_f", (6.25, 1.38, -CAB / 2 + 0.03), (1.3, 1.45, 0.06), 25),
      box("door_pside_f_col", "door_pside_f", (6.25, 1.38, CAB / 2 - 0.03), (1.3, 1.45, 0.06), 25),
      box("door_pside_r_col", "door_pside_r", (3.65, 1.6, WB / 2 - 0.03), (0.7, 1.76, 0.05), 20)]
print("collision boxes:", len(S))

# ------------------------------------------------------------------ 6. export (CodeWalker XML, gen8 = FiveM)
from Sollumz.sollumz_preferences import get_addon_preferences
prefs = get_addon_preferences(bpy.context)
es = prefs.export_settings
es.target_formats = {"CWXML"}
es.target_versions = {"GEN8"}
es.limit_to_selected = True
for o in bpy.data.objects: o.select_set(False)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, MODEL + ".blend"))
res = bpy.ops.sollumz.export_assets(directory=OUT + "/")
print("export:", res)
