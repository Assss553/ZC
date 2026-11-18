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
    "herringbone": mat("herringbone", "herringbone", 0.35, tile=7.0), "plant": mat("plant", "plant", 0.6, tile=0.6),
    "epoxy": mat("epoxy", "epoxy", 0.12, tile=4.0),
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

def finish(o, m, col):
    o.data.materials.clear(); o.data.materials.append(M[m])
    box_uv(o, TILE[M[m].name])
    if col: col.objects.link(o); bpy.context.scene.collection.objects.unlink(o)
    return o

def box(name, loc, size, m, col=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object; o.name = name; o.scale = (size[0]/2, size[1]/2, size[2]/2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, col)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import furniture as F
F.CTX.update(M=M, finish=finish)

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
box("floor", (0, 0, 0.02), (W - 0.4, D - 0.4, 0.04), "herringbone", INT)
F.skirting("skirting", -W/2, 4, -D/2, D/2, 0.04, INT)
for x in range(-8, 4, 3):                                   # exposed ceiling beams
    box(f"beam_{x}", (x, 0, H - 0.25), (0.25, D - 0.4, 0.35), "wood", INT)
box("ceiling", (0, 0, H - 0.05), (W - 0.4, D - 0.4, 0.1), "plaster", INT)
box("bar_counter", (-5, 4.5, 0.55), (7, 1, 1.1), "wood", INT)
box("bar_top", (-5, 4.5, 1.12), (7.2, 1.2, 0.06), "marble", INT)
for i in range(6):
    F.bar_stool(f"stool_{i}", -8 + i * 1.2, 3.6, 0.04, INT)
box("bar_footrail", (-5, 3.95, 0.25), (7, 0.05, 0.05), "steel", INT)
for i in range(4):
    F.pendant(f"bar_pendant_{i}", -7.6 + i * 1.75, 4.5, H - 0.1, INT, drop=1.5)
for z in (1.6, 2.2, 2.8):
    box(f"bottle_shelf_{z}", (-5, 6.7, z), (6, 0.35, 0.05), "wood", INT)
box("back_bar_mirror", (-5, 6.75, 2.2), (6, 0.03, 1.6), "glass", INT)
box("kitchen_floor", (7, 3, 0.05), (5.6, 7.6, 0.02), "tiles", INT)
box("kitchen_counter", (8.5, 1, 0.5), (2.4, 4, 1.0), "steel", INT)
box("kitchen_hood", (8.5, 1, 3.6), (2.4, 4, 0.8), "steel", INT)
mb = box("menu_board", (0, 0, 0), (3, 0.05, 1.2), "sign", INT)
mb.rotation_euler[2] = math.radians(90); mb.location = (-9.72, -2, 2.9)
box("wainscot_l", (-9.75, 0, 0.6), (0.1, D - 0.6, 1.2), "wood", INT)
box("pass_window", (4, 4.5, 1.4), (0.35, 2, 0.6), "steel", INT)
box("kitchen_wall", (4, 3, H/2), (0.3, 8, H), "plaster", INT)
# booths along the left wall: table + two facing benches
for i, yc in enumerate((-4.8, -2.0, 0.8)):
    F.booth(f"booth_a_{i}", -9.0, yc - 0.78, 0.04, 90, INT, length=1.2)
    F.booth(f"booth_b_{i}", -9.0, yc + 0.78, 0.04, -90, INT, length=1.2)
    F.rect_table(f"booth_table_{i}", -9.0, yc, 0.04, INT, w=1.1, d=0.7, top="marble")
    F.pendant(f"booth_pendant_{i}", -9.0, yc, H - 0.1, INT, drop=1.7)
# round tables with 4 chairs
for i, (x, y) in enumerate([(-5.5, -3.8), (-2.5, -3.8), (0.5, -3.8), (-5.5, -0.8), (-2.5, -0.8), (0.5, -0.8)]):
    F.round_table(f"table_{i}", x, y, 0.04, INT)
    for k, (dx, dy, rz) in enumerate([(0, 0.7, 0), (0, -0.7, 180), (0.7, 0, -90), (-0.7, 0, 90)]):
        F.chair(f"chair_{i}_{k}", x + dx, y + dy, 0.04, rz, INT)
    F.pendant(f"pendant_{i}", x, y, H - 0.1, INT, drop=1.3)
for k, y in enumerate((-5, -1.5, 2)):
    F.sconce(f"sconce_r_{k}", 3.82, y, 2.4, -1, INT)
F.plant("plant_entry_l", -8.8, -6.2, 0.04, INT)
F.plant("plant_entry_r", 2.8, -6.2, 0.04, INT)
F.plant("plant_bar", -9.2, 5.8, 0.04, INT, h=1.6)

# ---- secret wall door (back-right storage) -> stairs ----
box("SECRET_DOOR", (7.5, D/2 - 0.25, 1.25), (1.6, 0.15, 2.5), "brick", INT)   # rotates via script
for i in range(14):                                       # staircase down
    box(f"stair_{i}", (7.5, D/2 + 0.6 + i * 0.3, -i * 0.25), (1.6, 0.3, 0.1), "concrete", HQ)

# ---- underground HQ (-6m) ----
HZ = -6.0
box("hq_floor", (0, 12, HZ), (18, 12, 0.2), "epoxy", HQ)
box("hq_ceiling", (0, 12, HZ + 3.6), (18, 12, 0.2), "concrete", HQ)
for n, l, s in [("hq_wall_n", (0, 18, HZ + 1.8), (18, 0.3, 3.6)), ("hq_wall_s", (0, 6, HZ + 1.8), (18, 0.3, 3.6)),
                ("hq_wall_w", (-9, 12, HZ + 1.8), (0.3, 12, 3.6)), ("hq_wall_e", (9, 12, HZ + 1.8), (0.3, 12, 3.6))]:
    box(n, l, s, "hqwall", HQ)
box("hq_meeting_table", (-3, 12, HZ + 0.86), (5, 2, 0.08), "marble", HQ)
for i in range(6):
    F.office_chair(f"hq_chair_{i}", -5 + (i % 3) * 2, 12 + (1.4 if i < 3 else -1.4), HZ + 0.1, 0 if i < 3 else 180, HQ)
F.office_chair("hq_boss_chair", -6.3, 12, HZ + 0.1, -90, HQ)
F.strip_light("hq_light_a", -3, 12, HZ + 3.45, 6, HQ, color=(1.0, 0.9, 0.8), axis="x")
F.strip_light("hq_light_b", 4.5, 9.5, HZ + 3.45, 4, HQ, color=(0.8, 0.3, 1.0), axis="x")
F.rect_table("hq_coffee", 4, 10.2, HZ + 0.1, HQ, w=1.4, d=0.7, top="wood", h=0.42)
F.plant("hq_plant", 8, 6.8, HZ + 0.1, HQ)
box("hq_rug", (4, 10, HZ + 0.11), (5, 3.5, 0.02), "fabric", HQ)
box("hq_tv", (4, 6.25, HZ + 1.8), (3, 0.1, 1.6), "neon_hq", HQ)
for i in range(4):
    box(f"hq_crate_{i}", (7 + (i % 2) * 1.1, 8 + (i // 2) * 1.1, HZ + 0.45), (1, 1, 0.9), "wood", HQ)
for x in (-6, 0, 6):
    box(f"hq_pipe_{x}", (x, 12, HZ + 3.35), (0.2, 12, 0.2), "steel", HQ)
for dx in (-1.8, 1.8):
    box(f"hq_table_leg_{dx}", (-3 + dx, 12, HZ + 0.48), (0.25, 1.4, 0.76), "steel", HQ)
box("hq_weapon_rack", (-8.6, 12, HZ + 1.5), (0.3, 4, 2), "steel", HQ)
box("hq_stash", (6, 16.5, HZ + 0.6), (3, 1, 1.2), "steel", HQ)
F.sofa("hq_sofa", 4, 8.6, HZ + 0.1, HQ, length=3.2)
box("hq_neon_strip", (0, 17.8, HZ + 3.2), (16, 0.05, 0.1), "neon_hq", HQ)

# ---- lights / camera / render ----
for c_, loc, col_, e, r in F.LIGHTS:
    bpy.ops.object.light_add(type="POINT", location=loc); L = bpy.context.object
    L.data.energy = e; L.data.color = col_; L.data.shadow_soft_size = 0.1
for loc, e, c in [((0, -20, 15), 4, (1, .95, .9)), ((0, 0, 4), 120, (1, .8, .6)), ((0, 12, HZ + 3), 150, (.6, .8, 1))]:
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
shot("render_interior_eye.png", (2.5, -5.8, 1.7), (-6, 0, 0.9))
shot("render_booths.png", (-5.6, -6.2, 2.2), (-9, -1, 0.6))
bpy.data.objects["hq_ceiling"].hide_render = True
shot("render_hq_eye.png", (7.5, 7, HZ + 1.8), (-3, 12.5, HZ + 0.8), hide=(EXT, INT))
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
        nv = len(col.data.vertices)
        if nv > 28000:   # GTA bound limit 32767 verts -> simplify collision only (visual mesh untouched)
            dm = col.modifiers.new("dec", "DECIMATE"); dm.ratio = 26000 / nv
            bpy.ops.object.select_all(action="DESELECT"); col.select_set(True); bpy.context.view_layer.objects.active = col
            bpy.ops.object.modifier_apply(modifier=dm.name)
            print("collision", name, nv, "->", len(col.data.vertices))
        with bpy.context.temp_override(collection=c):
            d = convert_objs_to_single_drawable([body]); d.name = name
            comp = convert_objs_to_single_composite([col], SollumType.BOUND_GEOMETRYBVH)
        comp.parent = d; comp.name = name + ".col"
        from sollumz.sollumz_properties import LightType
        for c_, loc, col_, e, r in F.LIGHTS:
            if c_ is not c: continue
            ld = bpy.data.lights.new(name + "_light", "POINT"); ld.sollum_type = LightType.POINT
            ld.color = col_; ld.energy = e * 4; ld.cutoff_distance = r
            lo = bpy.data.objects.new(name + "_light", ld); lo.sollum_type = SollumType.LIGHT
            lo.location = loc; c.objects.link(lo); lo.parent = d
        bpy.ops.object.select_all(action="DESELECT"); d.select_set(True)
        for ch in d.children_recursive: ch.select_set(True)
        bpy.ops.sollumz.export_assets(directory=xml, direct_export=True, use_custom_settings=True,
                                      target_formats={"CWXML"}, target_versions={"GEN8"}, limit_to_selected=True)
    print("SOLLUMZ EXPORT ->", sorted(os.listdir(xml)))
except Exception as e:
    import traceback; traceback.print_exc()
print("ROX maps build done ->", OUT)
