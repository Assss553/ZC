# ROX Store | All rights reserved
# ROX maps - Restaurant + secret underground gang HQ (Blender, procedural textures)
# Run: python build_restaurant.py <out_dir>
import bpy, math, sys, os

OUT = sys.argv[-1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
S = bpy.context.scene

def mat(name, color, rough=0.5, metal=0.0, noise=0.0, emit=None, scale=8.0, brick=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if brick:
        t = nt.nodes.new("ShaderNodeTexBrick"); t.inputs["Scale"].default_value = scale
        t.inputs["Color1"].default_value = color
        t.inputs["Color2"].default_value = tuple(c * 0.8 for c in color[:3]) + (1,)
        t.inputs["Mortar"].default_value = (0.75, 0.73, 0.7, 1)
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    elif noise:
        t = nt.nodes.new("ShaderNodeTexNoise"); t.inputs["Scale"].default_value = scale
        r = nt.nodes.new("ShaderNodeValToRGB")
        r.color_ramp.elements[0].color = tuple(c * (1 - noise) for c in color[:3]) + (1,)
        r.color_ramp.elements[1].color = color
        nt.links.new(t.outputs["Fac"], r.inputs["Fac"]); nt.links.new(r.outputs["Color"], b.inputs["Base Color"])
    else:
        b.inputs["Base Color"].default_value = color
    if emit:
        b.inputs["Emission Color"].default_value = emit
        b.inputs["Emission Strength"].default_value = 6.0
    return m

M = {
    "brick": mat("rox_brick", (0.45, 0.16, 0.10, 1), 0.8, brick=True, scale=6),
    "plaster": mat("rox_plaster", (0.85, 0.82, 0.76, 1), 0.7, noise=0.15, scale=20),
    "wood": mat("rox_wood_floor", (0.35, 0.2, 0.1, 1), 0.4, noise=0.4, scale=40),
    "glass": mat("rox_glass", (0.6, 0.75, 0.8, 1), 0.05, 0.3),
    "steel": mat("rox_steel", (0.6, 0.6, 0.62, 1), 0.3, 1.0),
    "concrete": mat("rox_concrete", (0.32, 0.32, 0.33, 1), 0.9, noise=0.3, scale=15),
    "neon": mat("rox_neon", (1, 0.2, 0.5, 1), emit=(1, 0.1, 0.5, 1)),
    "neon_hq": mat("rox_neon_hq", (0.2, 0.8, 1, 1), emit=(0.1, 0.7, 1, 1)),
    "leather": mat("rox_leather", (0.08, 0.05, 0.04, 1), 0.35),
    "asphalt": mat("rox_asphalt", (0.07, 0.07, 0.08, 1), 0.95, noise=0.5, scale=60),
}

def box(name, loc, size, m, col=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object; o.name = name; o.scale = (size[0]/2, size[1]/2, size[2]/2)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(M[m])
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
box("sign_ROX", (0, -D/2 - 0.35, 4.6), (7, 0.1, 0.6), "neon", EXT)

# ---- interior ----
box("floor", (0, 0, 0.02), (W - 0.4, D - 0.4, 0.04), "wood", INT)
box("ceiling", (0, 0, H - 0.05), (W - 0.4, D - 0.4, 0.1), "plaster", INT)
box("bar_counter", (-5, 4.5, 0.55), (7, 1, 1.1), "wood", INT)
box("bar_top", (-5, 4.5, 1.12), (7.2, 1.2, 0.06), "steel", INT)
box("kitchen_wall", (4, 3, H/2), (0.3, 8, H), "plaster", INT)
for i, (x, y) in enumerate([(-7, -3), (-3, -3), (1, -3), (-7, 0), (-3, 0), (1, 0)]):
    box(f"table_{i}", (x, y, 0.75), (1.2, 1.2, 0.05), "wood", INT)
    box(f"table_leg_{i}", (x, y, 0.37), (0.1, 0.1, 0.74), "steel", INT)
    for dx in (-0.9, 0.9):
        box(f"booth_{i}_{dx}", (x + dx, y, 0.45), (0.5, 1.4, 0.9), "leather", INT)
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
    box(n, l, s, "brick", HQ)
box("hq_meeting_table", (-3, 12, HZ + 0.8), (5, 2, 0.08), "wood", HQ)
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
shot("render_hq.png", (0, 12, 10), (0, 12, HZ), hide=(EXT, INT))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "rox_restaurant.blend"))
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "rox_restaurant.fbx"))
print("ROX maps build done ->", OUT)
