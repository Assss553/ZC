# ROX Store | All rights reserved
# ROX maps - Restaurant + secret underground gang HQ (Blender, procedural textures)
# Run: python build_restaurant.py <out_dir>
import bpy, math, sys, os

OUT = sys.argv[-1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
S = bpy.context.scene

TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")
TILE = {}
def mat(name, tex, rough=0.5, metal=0.0, tile=2.0, emit=None, alpha=1.0):
    m = bpy.data.materials.new("rox_" + name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if tex:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(os.path.join(TEX, f"rox_{tex}.png"))
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        npath = os.path.join(TEX, f"rox_{tex}_n.png")
        if os.path.exists(npath):
            ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = bpy.data.images.load(npath); ti.image.colorspace_settings.name = "Non-Color"
            nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(ti.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    if emit:
        b.inputs["Emission Color"].default_value = emit; b.inputs["Emission Strength"].default_value = 8.0
        b.inputs["Base Color"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha; b.inputs["Transmission Weight"].default_value = 1.0
        b.inputs["Base Color"].default_value = (0.7, 0.85, 0.9, 1)
    TILE[m.name] = tile
    return m

M = {
    "brick": mat("brick", "brick", 0.85, tile=3.0), "plaster": mat("plaster", "plaster", 0.7, tile=3.0),
    "wood": mat("wood_floor", "wood", 0.4, tile=4.0), "glass": mat("glass", None, 0.02, alpha=0.25),
    "steel": mat("steel", "metal", 0.3, 1.0, tile=2.0), "concrete": mat("concrete", "concrete", 0.9, tile=4.0),
    "neon": mat("neon", None, emit=(1, 0.15, 0.55, 1)), "neon_hq": mat("neon_hq", None, emit=(0.1, 0.7, 1, 1)),
    "leather": mat("leather", "leather", 0.35, tile=1.0), "asphalt": mat("asphalt", "asphalt", 0.95, tile=6.0),
    "marble": mat("marble", "marble", 0.15, tile=2.0), "tiles": mat("tiles", "tiles", 0.25, tile=4.0),
    "fabric": mat("fabric", "fabric", 0.9, tile=1.0), "hqwall": mat("hqwall", "hqwall", 0.8, tile=5.0),
    "sign": mat("sign", "sign", 0.3, emit=None, tile=0),
}
sb = M["sign"].node_tree.nodes["Principled BSDF"]
sb.inputs["Emission Strength"].default_value = 5.0
M["sign"].node_tree.links.new(M["sign"].node_tree.nodes["Image Texture"].outputs["Color"], sb.inputs["Emission Color"])

import bmesh
def box_uv(o, tile):
    bm = bmesh.new(); bm.from_mesh(o.data); uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap 0")
    for f in bm.faces:
        n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            w = o.matrix_world @ l.vert.co
            if tile == 0:   # stretch whole image on one face (sign)
                d = o.dimensions
                u = (l.vert.co.x / d.x + 0.5) if ax != 0 else (l.vert.co.y / d.y + 0.5); v = l.vert.co.z / d.z + 0.5
                l[uv].uv = (u, v)
            else:
                a, b = [(1, 2), (0, 2), (0, 1)][ax]
                l[uv].uv = (w[a] / tile, w[b] / tile)
    bm.to_mesh(o.data); bm.free()
    o.data.uv_layers[0].name = "UVMap 0"
    ca = o.data.color_attributes.new("Color 1", "BYTE_COLOR", "CORNER")
    for d in ca.data: d.color = (1, 1, 1, 1)

def box(name, loc, size, m, col=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object; o.name = name; o.scale = (size[0]/2, size[1]/2, size[2]/2)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(M[m])
    o.matrix_world = o.matrix_world  # noqa
    box_uv(o, TILE[M[m].name])
    if col: col.objects.link(o); bpy.context.scene.collection.objects.unlink(o)
    return o

def coll(n):
    c = bpy.data.collections.new(n); S.collection.children.link(c); return c

EXT, INT, HQ = coll("ROX_Exterior"), coll("ROX_Interior"), coll("ROX_GangHQ")
W, D, H = 20, 14, 5   # restaurant footprint (m)

# ---- exterior shell ----
box("ground", (0, 0, -0.05), (60, 40, 0.1), "asphalt", EXT)
box("wall_back", (0, D/2, H/2), (W, 0.4, H), "brick", EXT)
box("wall_left", (-W/2, 0, H/2), (0.4, D, H), "brick", EXT)
box("wall_right", (W/2, 0, H/2), (0.4, D, H), "brick", EXT)
for x in (-8, -3, 3, 8):                                   # front pillars
    box(f"pillar_{x}", (x, -D/2, H/2), (0.8, 0.5, H), "brick", EXT)
box("front_glass", (0, -D/2, 2), (W, 0.1, 4), "glass", EXT)
box("front_header", (0, -D/2, 4.6), (W, 0.6, 0.8), "steel", EXT)
box("roof", (0, 0, H + 0.15), (W + 0.6, D + 0.6, 0.3), "concrete", EXT)
box("awning", (0, -D/2 - 1.2, 3.6), (W, 2.4, 0.12), "steel", EXT)
box("sign_ROX", (0, -D/2 - 0.35, 4.6), (7, 0.1, 1.75), "sign", EXT)
# sidewalk, curb, parking lines, planters, front door, window frames
box("sidewalk", (0, -D/2 - 3, 0.08), (W + 10, 6, 0.16), "concrete", EXT)
box("curb", (0, -D/2 - 6, 0.1), (W + 10, 0.3, 0.2), "steel", EXT)
for i in range(-4, 5):
    box(f"park_line_{i}", (i * 3, -D/2 - 10, 0.01), (0.15, 5, 0.02), "plaster", EXT)
for x in (-9.5, 9.5):
    box(f"planter_{x}", (x, -D/2 - 1.2, 0.5), (1.2, 1.2, 1.0), "concrete", EXT)
    box(f"bush_{x}", (x, -D/2 - 1.2, 1.2), (1.0, 1.0, 0.5), "leather", EXT)
box("door_frame", (0, -D/2 - 0.05, 1.3), (2.4, 0.2, 2.6), "steel", EXT)
box("door_glass", (0, -D/2 - 0.1, 1.25), (2.0, 0.05, 2.4), "glass", EXT)
for x in (-6, -1.5, 1.5, 6):
    box(f"mullion_{x}", (x, -D/2 - 0.06, 2), (0.12, 0.12, 4), "steel", EXT)
box("transom", (0, -D/2 - 0.06, 3.0), (W, 0.12, 0.12), "steel", EXT)
# roof details
for i, x in enumerate((-6, 0, 6)):
    box(f"ac_unit_{i}", (x, 3, H + 0.9), (1.8, 1.4, 1.2), "steel", EXT)
box("chimney", (6, 5, H + 1.5), (0.8, 0.8, 3), "brick", EXT)
box("parapet_f", (0, -D/2, H + 0.6), (W + 0.6, 0.3, 0.9), "brick", EXT)

# ---- interior ----
box("floor", (0, 0, 0.02), (W - 0.4, D - 0.4, 0.04), "wood", INT)
box("ceiling", (0, 0, H - 0.05), (W - 0.4, D - 0.4, 0.1), "plaster", INT)
box("bar_counter", (-5, 4.5, 0.55), (7, 1, 1.1), "wood", INT)
box("bar_top", (-5, 4.5, 1.12), (7.2, 1.2, 0.06), "marble", INT)
for i in range(6):
    box(f"stool_{i}", (-8 + i * 1.2, 3.5, 0.4), (0.45, 0.45, 0.08), "fabric", INT)
    box(f"stool_leg_{i}", (-8 + i * 1.2, 3.5, 0.2), (0.08, 0.08, 0.4), "steel", INT)
for z in (1.6, 2.2, 2.8):
    box(f"bottle_shelf_{z}", (-5, 6.7, z), (6, 0.35, 0.05), "wood", INT)
box("back_bar_mirror", (-5, 6.75, 2.2), (6, 0.03, 1.6), "glass", INT)
box("kitchen_floor", (7, 3, 0.05), (5.6, 7.6, 0.02), "tiles", INT)
box("kitchen_counter", (8.5, 1, 0.5), (2.4, 4, 1.0), "steel", INT)
box("kitchen_hood", (8.5, 1, 3.6), (2.4, 4, 0.8), "steel", INT)
box("menu_board", (-9.7, -2, 2.6), (0.05, 3, 1.2), "sign", INT)
box("wainscot_l", (-9.75, 0, 0.6), (0.1, D - 0.6, 1.2), "wood", INT)
box("pass_window", (4, 4.5, 1.4), (0.35, 2, 0.6), "steel", INT)
box("kitchen_wall", (4, 3, H/2), (0.3, 8, H), "plaster", INT)
for i, (x, y) in enumerate([(-7, -3), (-3, -3), (1, -3), (-7, 0), (-3, 0), (1, 0)]):
    box(f"table_{i}", (x, y, 0.75), (1.2, 1.2, 0.05), "wood", INT)
    box(f"table_leg_{i}", (x, y, 0.37), (0.1, 0.1, 0.74), "steel", INT)
    for dx in (-0.9, 0.9):
        box(f"booth_{i}_{dx}", (x + dx, y, 0.45), (0.5, 1.4, 0.9), "fabric", INT)
for x in (-6, -2, 2):
    box(f"lamp_{x}", (x, -1.5, H - 0.5), (0.4, 0.4, 0.15), "neon", INT)

# ---- secret wall door (back-right storage) -> stairs ----
box("SECRET_DOOR", (7.5, D/2 - 0.25, 1.25), (1.6, 0.15, 2.5), "brick", INT)   # rotates via script
for i in range(14):                                       # staircase down
    box(f"stair_{i}", (7.5, D/2 + 0.6 + i * 0.3, -i * 0.25), (1.6, 0.3, 0.1), "concrete", HQ)

# ---- underground HQ (-6m) ----
HZ = -6.0
box("hq_floor", (0, 12, HZ), (18, 12, 0.2), "concrete", HQ)
box("hq_ceiling", (0, 12, HZ + 3.6), (18, 12, 0.2), "concrete", HQ)
for n, l, s in [("hq_wall_n", (0, 18, HZ + 1.8), (18, 0.3, 3.6)), ("hq_wall_s", (0, 6, HZ + 1.8), (18, 0.3, 3.6)),
                ("hq_wall_w", (-9, 12, HZ + 1.8), (0.3, 12, 3.6)), ("hq_wall_e", (9, 12, HZ + 1.8), (0.3, 12, 3.6))]:
    box(n, l, s, "hqwall", HQ)
box("hq_meeting_table", (-3, 12, HZ + 0.8), (5, 2, 0.08), "marble", HQ)
for i in range(6):
    box(f"hq_chair_{i}", (-5 + (i % 3) * 2, 12 + (1.6 if i < 3 else -1.6), HZ + 0.5), (0.6, 0.6, 1.0), "leather", HQ)
box("hq_rug", (4, 10, HZ + 0.11), (5, 3.5, 0.02), "fabric", HQ)
box("hq_tv", (4, 6.25, HZ + 1.8), (3, 0.1, 1.6), "neon_hq", HQ)
for i in range(4):
    box(f"hq_crate_{i}", (7 + (i % 2) * 1.1, 8 + (i // 2) * 1.1, HZ + 0.45), (1, 1, 0.9), "wood", HQ)
for x in (-6, 0, 6):
    box(f"hq_pipe_{x}", (x, 12, HZ + 3.35), (0.2, 12, 0.2), "steel", HQ)
box("hq_table_leg", (-3, 12, HZ + 0.4), (0.4, 0.4, 0.8), "steel", HQ)
box("hq_weapon_rack", (-8.6, 12, HZ + 1.5), (0.3, 4, 2), "steel", HQ)
box("hq_stash", (6, 16.5, HZ + 0.6), (3, 1, 1.2), "steel", HQ)
box("hq_sofa", (4, 9, HZ + 0.45), (4, 1, 0.9), "leather", HQ)
box("hq_neon_strip", (0, 17.8, HZ + 3.2), (16, 0.05, 0.1), "neon_hq", HQ)

# ---- lights / camera / render ----
for loc, e, c in [((0, -20, 15), 4, (1, .95, .9)), ((0, 0, 4), 300, (1, .8, .6)), ((0, 12, HZ + 3), 400, (.6, .8, 1))]:
    if e < 10:
        bpy.ops.object.light_add(type="SUN", location=loc); bpy.context.object.data.energy = e
        bpy.context.object.rotation_euler = (math.radians(55), 0, math.radians(20))
    else:
        bpy.ops.object.light_add(type="POINT", location=loc); bpy.context.object.data.energy = e
    bpy.context.object.data.color = c
S.world = bpy.data.worlds.new("w"); S.world.use_nodes = True
S.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.25, 0.32, 0.45, 1)
S.render.engine = "CYCLES"; S.cycles.samples = 48; S.cycles.device = "CPU"
S.render.resolution_x, S.render.resolution_y = 1280, 720

def shot(name, loc, target, hide=()):
    bpy.ops.object.camera_add(location=loc); cam = bpy.context.object
    d = [target[i] - loc[i] for i in range(3)]
    cam.rotation_euler = (math.atan2(math.hypot(d[0], d[1]), -d[2]), 0, math.atan2(d[1], d[0]) - math.pi/2)
    S.camera = cam
    for c in hide: c.hide_render = True
    S.render.filepath = os.path.join(OUT, name); bpy.ops.render.render(write_still=True)
    for c in hide: c.hide_render = False

shot("render_exterior.png", (14, -26, 8), (0, 0, 2))
roof = bpy.data.objects["roof"]; ceil = bpy.data.objects["ceiling"]
roof.hide_render = ceil.hide_render = True
shot("render_interior.png", (-2, -5, 14), (0, 2, 0))
bpy.data.objects["hq_ceiling"].hide_render = True
shot("render_hq.png", (-6, 2, HZ + 9), (1, 13, HZ), hide=(EXT, INT))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "rox_restaurant.blend"))
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "rox_restaurant.fbx"))

# ---- Sollumz: CodeWalker XML export (one drawable per collection) ----
try:
    import addon_utils
    if len(sys.argv) > 2: sys.path.insert(0, sys.argv[-2])
    addon_utils.enable("sollumz", default_set=True)
    xml = os.path.join(OUT, "stream"); os.makedirs(xml, exist_ok=True)
    roof.hide_render = ceil.hide_render = bpy.data.objects["hq_ceiling"].hide_render = False
    from sollumz.tools.drawablehelper import convert_objs_to_single_drawable
    from sollumz.tools.boundhelper import convert_objs_to_single_composite
    from sollumz.ybn.collision_materials import create_collision_material_from_index
    from sollumz.sollumz_properties import SollumType
    for c, name in ((EXT, "rox_diner_ext"), (INT, "rox_diner_int"), (HQ, "rox_diner_hq")):
        bpy.ops.object.select_all(action="DESELECT")
        meshes = [o for o in c.objects if o.type == "MESH"]
        for o in meshes: o.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        body = bpy.context.view_layer.objects.active; body.name = name
        bpy.ops.object.select_all(action="DESELECT"); body.select_set(True)
        bpy.ops.sollumz.autoconvertmaterials()
        col = body.copy(); col.data = body.data.copy(); c.objects.link(col)
        col.data.materials.clear(); col.data.materials.append(create_collision_material_from_index(1))  # concrete
        with bpy.context.temp_override(collection=c):
            d = convert_objs_to_single_drawable([body]); d.name = name
            comp = convert_objs_to_single_composite([col], SollumType.BOUND_GEOMETRYBVH)
        comp.parent = d; comp.name = name + ".col"
        bpy.ops.object.select_all(action="DESELECT"); d.select_set(True)
        for ch in d.children_recursive: ch.select_set(True)
        bpy.ops.sollumz.export_assets(directory=xml, direct_export=True, use_custom_settings=True,
                                      target_formats={"CWXML"}, target_versions={"GEN8"}, limit_to_selected=True)
    print("SOLLUMZ EXPORT ->", sorted(os.listdir(xml)))
except Exception as e:
    import traceback; traceback.print_exc()
print("ROX maps build done ->", OUT)
