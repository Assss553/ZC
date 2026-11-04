"""Converts the VC2 caravan moving parts (slide-outs + stabiliser leg) to GTA props (.ydr.xml) + one .ytyp.xml.
Run:  bl/bin/python convert_props.py <addons_dir> <model_dir> <out_dir>
"""
import sys, os, re, math
import bpy, addon_utils
from mathutils import Matrix, Vector

ADDONS, MODEL_DIR, OUT = sys.argv[-3:]
sys.path.insert(0, ADDONS)
addon_utils.enable("io_scene_gltf2", default_set=True)
addon_utils.enable("Sollumz", default_set=True)

from Sollumz.sollumz_properties import SollumType
from Sollumz.ydr.shader_materials import create_shader
from Sollumz.ybn.collision_materials import create_collision_material_from_index, collisionmats
from Sollumz.tools.drawablehelper import convert_obj_to_model
from Sollumz.tools.blenderhelper import create_empty_object, create_blender_object
from Sollumz.sollumz_preferences import get_addon_preferences
from PIL import Image
import numpy as np

R = Matrix.Rotation(math.radians(90.0), 4, "Z")   # three.js part space -> GTA prop space (x right, y fwd, z up)
TEX_DIR = os.path.join(OUT, "_dds"); os.makedirs(TEX_DIR, exist_ok=True)
PARTS = [  # (glb, prop name, collision boxes in three.js part coords: centre, size)
    ("vc2caravan_slideout_side.glb", "vc2caravan_slideout_side", "side"),
    ("vc2caravan_slideout_rear.glb", "vc2caravan_slideout_rear", "rear"),
    ("vc2caravan_jack.glb", "vc2caravan_jack", "jack"),
]

def lin2srgb(c): return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
def pot(n):
    p = 4
    while p < n and p < 1024: p *= 2
    return p
cache = {}
def dds(name, arr, alpha):
    if name in cache: return cache[name]
    im = Image.fromarray(arr, "RGBA"); im = im.resize((pot(im.width), pot(im.height)), Image.LANCZOS)
    path = os.path.join(TEX_DIR, name + ".dds"); im.save(path, pixel_format="DXT5" if alpha else "DXT1")
    img = bpy.data.images.load(path, check_existing=True); img.name = name; cache[name] = img
    return img

def to_static_material(src):
    col, img = (0.8, 0.8, 0.8, 1.0), None
    n = (src.name if src else "").lower()
    if src and src.node_tree:
        bsdf = next((x for x in src.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            lin = bsdf.inputs["Base Color"].default_value
            col = (lin2srgb(lin[0]), lin2srgb(lin[1]), lin2srgb(lin[2]), 1.0)
            st = [l.from_node for l in bsdf.inputs["Base Color"].links]
            while st:
                x = st.pop()
                if x.type == "TEX_IMAGE" and x.image: img = x.image; break
                for i in x.inputs: st += [l.from_node for l in i.links]
    if "glass" in n: shader, alpha = "glass_pv.sps", True
    elif "livery" in n or "logo" in n: shader, alpha = "decal.sps", True
    elif "light" in n or "led" in n: shader, alpha = "emissive.sps", False
    else: shader, alpha = "default.sps", False
    if "glass" in n:
        arr = np.zeros((8, 8, 4), np.uint8); arr[:] = (230, 237, 242, 30); tex = dds("vc2p_glass", arr, True)
    elif img is not None:
        w, h = img.size; px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
        tex = dds("vc2p_" + re.sub(r"[^a-z0-9]+", "_", n)[:40], (np.clip(px, 0, 1) * 255).astype(np.uint8), alpha)
    else:
        r, g, b, a = [int(max(0, min(1, c)) * 255) for c in col]
        arr = np.zeros((8, 8, 4), np.uint8); arr[:] = (r, g, b, a); tex = dds(f"vc2p_{r:02x}{g:02x}{b:02x}", arr, False)
    key = (shader, tex.name)
    if key in cache: return cache[key]
    m = create_shader(shader); m.name = f"vc2p_{shader[:-4]}_{tex.name}"
    for node in m.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.name == "DiffuseSampler":
            node.image = tex; node.texture_properties.embedded = True
    cache[key] = m
    return m

car_metal = next(i for i, m in enumerate(collisionmats) if m.name == "CAR_METAL")

def gta(v):  # three.js part coords -> GTA prop coords
    return Vector((v[2], v[0], v[1]))

def boxes_for(kind):
    # three.js part-local coords. slide-out boxes: x = length, y = up (0 = floor), z = depth (0 = outer face, +D inside)
    if kind == "side":
        L, H, D = 2.6, 2.17, 0.72
    elif kind == "rear":
        L, H, D = 1.7, 2.1, 0.7
    else:
        return [((0, -0.25, 0), (0.08, 0.5, 0.08)), ((0, -0.51, 0), (0.26, 0.04, 0.26))]
    t = 0.05
    return [((0, t / 2, D / 2), (L, t, D)),            # floor
            ((0, H - t / 2, D / 2), (L, t, D)),        # roof
            ((0, H / 2, t / 2), (L, H, t)),            # outer wall
            ((-L / 2 + t / 2, H / 2, D / 2), (t, H, D)), ((L / 2 - t / 2, H / 2, D / 2), (t, H, D))]  # ends

ytyp_items = []
for glb, name, kind in PARTS:
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODEL_DIR, glb))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in meshes:
        mw = R @ o.matrix_world; o.data = o.data.copy(); o.data.transform(mw); o.parent = None; o.matrix_world = Matrix.Identity(4)
        for i, s in enumerate(o.material_slots): o.material_slots[i].material = to_static_material(s.material)
        me = o.data
        for ca in list(me.color_attributes): me.color_attributes.remove(ca)
        for cn in ("Color 0", "Color 1"):
            ca = me.color_attributes.new(cn, "BYTE_COLOR", "CORNER"); ca.data.foreach_set("color", [1.0] * (len(ca.data) * 4))
        if not me.uv_layers: me.uv_layers.new(name="UVMap 0")
        me.uv_layers[0].name = "UVMap 0"
    for o in list(bpy.data.objects):
        if o.type != "MESH": bpy.data.objects.remove(o, do_unlink=True)
    with bpy.context.temp_override(active_object=meshes[0], selected_editable_objects=meshes, selected_objects=meshes):
        bpy.ops.object.join()
    mesh = meshes[0]; mesh.name = name + "_model"
    drawable = create_empty_object(SollumType.DRAWABLE, name)
    convert_obj_to_model(mesh); mesh.parent = drawable
    comp = create_empty_object(SollumType.BOUND_COMPOSITE, name + ".col"); comp.parent = drawable
    cm = create_collision_material_from_index(car_metal)
    for k, (c3, s3) in enumerate(boxes_for(kind)):
        c, s = gta(c3), Vector((s3[2], s3[0], s3[1]))
        me = bpy.data.meshes.new(f"{name}_col{k}")
        hx, hy, hz = s / 2
        v = [(c.x + a * hx, c.y + b * hy, c.z + d * hz) for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)]
        me.from_pydata(v, [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]); me.update()
        ob = create_blender_object(SollumType.BOUND_BOX, me.name, me); ob.data.materials.append(cm); ob.parent = comp
    # bounds for the ytyp
    pts = [Vector(v.co) for v in mesh.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (mn + mx) / 2
    ytyp_items.append((name, mn, mx, ctr, (mx - ctr).length))
    prefs = get_addon_preferences(bpy.context); es = prefs.export_settings
    es.target_formats = {"CWXML"}; es.target_versions = {"GEN8"}; es.limit_to_selected = True
    for o in bpy.data.objects: o.select_set(False)
    drawable.select_set(True); bpy.context.view_layer.objects.active = drawable
    print(name, "verts", len(mesh.data.vertices), "export:", bpy.ops.sollumz.export_assets(directory=OUT + "/"))

# ytyp (archetypes for the three props)
def f3(v): return f'x="{v.x:.6f}" y="{v.y:.6f}" z="{v.z:.6f}"'
items = "".join(f"""
    <Item type="CBaseArchetypeDef">
      <lodDist value="100.00000000" />
      <flags value="32" />
      <specialAttribute value="0" />
      <bbMin {f3(mn)} />
      <bbMax {f3(mx)} />
      <bsCentre {f3(c)} />
      <bsRadius value="{r:.6f}" />
      <hdTextureDist value="20.00000000" />
      <name>{n}</name>
      <textureDictionary>{n}</textureDictionary>
      <clipDictionary />
      <drawableDictionary />
      <physicsDictionary />
      <assetType>ASSET_TYPE_DRAWABLE</assetType>
      <assetName>{n}</assetName>
      <extensions />
    </Item>""" for n, mn, mx, c, r in ytyp_items)
with open(os.path.join(OUT, "vc2caravan_props.ytyp.xml"), "w") as fp:
    fp.write(f"""<?xml version="1.0" encoding="UTF-8"?>
<CMapTypes>
  <extensions />
  <archetypes>{items}
  </archetypes>
  <name>vc2caravan_props</name>
  <dependencies />
  <compositeEntityTypes />
</CMapTypes>
""")
print("ytyp written")
