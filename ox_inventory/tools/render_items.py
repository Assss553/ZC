# ROX Store | All rights reserved
# Realistic item images for the ROX ox_inventory theme (original 3D models, rendered in Blender).
# Run: python render_items.py <out_dir>        (pip install bpy)
import bpy, math, os, sys
from mathutils import Vector

OUT = sys.argv[-1] if len(sys.argv) > 1 else "items"
os.makedirs(OUT, exist_ok=True)
SIZE = 256


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"; s.cycles.samples = 64; s.cycles.device = "CPU"
    s.render.film_transparent = True
    s.render.resolution_x = s.render.resolution_y = SIZE
    s.view_settings.view_transform = "Standard"; s.view_settings.look = "None"; s.view_settings.exposure = -0.45
    w = bpy.data.worlds.new("w"); s.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.37, 0.4, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    for loc, e, sz in [((3, -4, 5), 900, 4), ((-4, -2, 3), 300, 5), ((0, 5, 4), 500, 3)]:
        bpy.ops.object.light_add(type="AREA", location=loc); L = bpy.context.object
        L.data.energy = e; L.data.size = sz
        L.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


def mat(name, color, rough=0.5, metal=0.0, alpha=1.0, trans=0.0, emit=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if trans: b.inputs["Transmission Weight"].default_value = trans
    if alpha < 1: b.inputs["Alpha"].default_value = alpha
    if emit: b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = 2
    # fine fabric / surface noise via bump
    nt = m.node_tree; tex = nt.nodes.new("ShaderNodeTexNoise"); tex.inputs["Scale"].default_value = 180
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.08 if rough > 0.6 else 0.02
    nt.links.new(tex.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def add(kind, loc=(0, 0, 0), size=(1, 1, 1), m=None, rot=(0, 0, 0), bevel=0.0, verts=32, seg=3):
    if kind == "cube": bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    elif kind == "cyl": bpy.ops.mesh.primitive_cylinder_add(location=loc, rotation=rot, vertices=verts)
    elif kind == "sphere": bpy.ops.mesh.primitive_uv_sphere_add(location=loc, rotation=rot, segments=verts, ring_count=verts // 2)
    elif kind == "torus": bpy.ops.mesh.primitive_torus_add(location=loc, rotation=rot, major_radius=1, minor_radius=0.12, major_segments=verts, minor_segments=12)
    elif kind == "cone": bpy.ops.mesh.primitive_cone_add(location=loc, rotation=rot, vertices=verts, radius1=1, radius2=0.5)
    o = bpy.context.object; o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = seg; md.limit_method = "ANGLE"
    if kind != "cube" or bevel: bpy.ops.object.shade_smooth()
    if m: o.data.materials.append(m)
    return o


def shoot(name, dist=3.2, elev=32, azim=-35, target=(0, 0, 0), lens=60):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = Vector((min(v[i] for o in objs for v in [o.matrix_world @ Vector(c) for c in o.bound_box]) for i in range(3)))
    hi = Vector((max(v[i] for o in objs for v in [o.matrix_world @ Vector(c) for c in o.bound_box]) for i in range(3)))
    c = (lo + hi) / 2; r = (hi - lo).length / 2
    d = r * dist * 1.45
    e, a = math.radians(elev), math.radians(azim)
    pos = c + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * d
    bpy.ops.object.camera_add(location=pos); cam = bpy.context.object; cam.data.lens = lens
    cam.rotation_euler = (c - pos).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name)


# ---------------------------------------------------------------- items
def vest():
    reset()
    fab = mat("fab", (0.11, 0.11, 0.1), 0.9); strap = mat("strap", (0.06, 0.06, 0.06), 0.8); buckle = mat("buckle", (0.02, 0.02, 0.02), 0.4)
    add("cube", (0, 0, 0), (1.5, 0.28, 1.7), fab, bevel=0.12, seg=5)                          # front plate
    for x in (-0.48, 0, 0.48):                                                              # mag pouches
        add("cube", (x, -0.24, -0.38), (0.42, 0.22, 0.62), fab, bevel=0.06, seg=4)
        add("cube", (x, -0.36, -0.12), (0.36, 0.04, 0.16), strap, bevel=0.02)
    for x in (-0.5, 0.5):                                                                   # shoulder straps
        add("cube", (x, 0.05, 1.05), (0.34, 0.24, 0.6), fab, bevel=0.08)
    for z in (0.35, 0.55, 0.75):                                                            # MOLLE webbing
        add("cube", (0, -0.15, z - 0.2), (1.35, 0.02, 0.06), strap)
    add("cube", (0.62, -0.18, 0.55), (0.2, 0.06, 0.14), buckle, bevel=0.02)
    add("cube", (0, -0.16, 0.42), (0.55, 0.03, 0.22), mat("patch", (0.16, 0.16, 0.15), 0.9), bevel=0.02)   # name patch
    shoot("rox_vest", elev=12, azim=-22)


def tank():
    reset()
    steel = mat("steel", (0.55, 0.56, 0.58), 0.25, 1.0); black = mat("blk", (0.03, 0.03, 0.03), 0.5)
    add("cyl", (0, 0, 0), (0.55, 0.55, 2.0), steel, verts=48)
    add("sphere", (0, 0, 1.0), (0.55, 0.55, 0.4), steel)
    add("sphere", (0, 0, -1.0), (0.55, 0.55, 0.3), steel)
    add("cyl", (0, 0, 1.3), (0.16, 0.16, 0.3), black)
    add("cyl", (0.12, 0, 1.42), (0.08, 0.08, 0.3), black, rot=(0, math.pi / 2, 0))
    add("sphere", (0.3, 0, 1.42), (0.14, 0.14, 0.14), black)
    for z in (0.4, -0.4):
        add("torus", (0, 0, z), (0.6, 0.6, 0.9), black)
    add("cube", (0, 0.32, 0), (0.42, 0.08, 1.4), black, bevel=0.04)                          # backplate strap
    shoot("rox_oxygen", elev=18, azim=-30)


def transparency(name, col):
    reset()
    sheet = mat("sheet", tuple(0.35 + 0.6 * c for c in col), 0.25, trans=0.15)
    tint = mat("tint", tuple(c * 0.35 for c in col), 0.3)
    add("cube", (0, 0, 0), (1.6, 1.6, 0.02), sheet, bevel=0.03)
    add("cube", (0, 0, -0.012), (1.66, 1.66, 0.012), mat("edge", (0.95, 0.95, 0.95), 0.4), bevel=0.04)
    for sx in (-1, 1):                                                                      # corner register marks
        for sy in (-1, 1):
            add("cube", (sx * 0.62, sy * 0.62, 0.015), (0.16, 0.03, 0.01), tint)
            add("cube", (sx * 0.68, sy * 0.56, 0.015), (0.03, 0.16, 0.01), tint)
    # bracket symbol in the middle
    add("cube", (-0.22, 0.0, 0.015), (0.05, 0.6, 0.01), tint); add("cube", (-0.1, 0.27, 0.015), (0.25, 0.05, 0.01), tint)
    add("cube", (0.22, 0.0, 0.015), (0.05, 0.6, 0.01), tint); add("cube", (0.1, -0.27, 0.015), (0.25, 0.05, 0.01), tint)
    add("cube", (0, 0, -0.03), (1.3, 1.3, 0.005), mat("bgt", col, 0.5, alpha=1.0)).scale = (1, 1, 1)
    shoot(name, elev=70, azim=-15, dist=2.6)


def pills():
    reset()
    foil = mat("foil", (0.82, 0.83, 0.85), 0.22, 1.0); pill = mat("pill", (0.95, 0.95, 0.93), 0.35); blister = mat("bl", (0.9, 0.92, 0.95), 0.05, trans=0.9)
    add("cube", (0, 0, 0), (1.8, 0.9, 0.03), foil, bevel=0.03)
    for i in range(5):
        for j in range(2):
            x, y = -0.68 + i * 0.34, -0.2 + j * 0.4
            add("sphere", (x, y, 0.05), (0.26, 0.26, 0.16), blister)
            add("sphere", (x, y, 0.05), (0.2, 0.2, 0.1), pill)
    shoot("rox_pills", elev=50, azim=-25, dist=2.5)


def radio():
    reset()
    body = mat("body", (0.06, 0.06, 0.065), 0.55); rub = mat("rub", (0.02, 0.02, 0.02), 0.85); scr = mat("scr", (0.05, 0.12, 0.1), 0.2, emit=(0.15, 0.6, 0.35))
    add("cube", (0, 0, 0), (0.62, 0.3, 1.4), body, bevel=0.06, seg=4)
    add("cyl", (0.16, 0, 1.05), (0.12, 0.12, 0.8), rub, verts=24)                          # antenna
    add("cyl", (-0.16, 0, 0.78), (0.16, 0.16, 0.16), rub, verts=24)                        # knob
    add("cube", (0, -0.155, 0.38), (0.42, 0.01, 0.24), scr, bevel=0.01)
    for i in range(3):
        for j in range(4):
            add("cube", (-0.14 + i * 0.14, -0.16, 0.05 - j * 0.13), (0.1, 0.02, 0.08), rub, bevel=0.01)
    add("cube", (0, -0.16, -0.58), (0.44, 0.02, 0.12), mat("grill", (0.1, 0.1, 0.1), 0.7), bevel=0.01)
    shoot("rox_radio", elev=14, azim=-28)


def baton():
    reset()
    blk = mat("b", (0.02, 0.02, 0.022), 0.35, 0.3); grip = mat("g", (0.01, 0.01, 0.01), 0.9)
    add("cyl", (0, 0, 0), (0.12, 0.12, 2.4), blk, rot=(0, math.radians(90), math.radians(35)))
    o = add("cyl", (-0.7, -0.49, 0), (0.15, 0.15, 0.9), grip, rot=(0, math.radians(90), math.radians(35)))
    add("sphere", (1.0, 0.7, 0), (0.16, 0.16, 0.16), blk)
    shoot("rox_baton", elev=40, azim=0, dist=2.2)


def taser():
    reset()
    yel = mat("y", (0.95, 0.75, 0.05), 0.4); blk = mat("k", (0.03, 0.03, 0.035), 0.5)
    add("cube", (0, 0, 0), (1.3, 0.34, 0.52), yel, bevel=0.08, seg=4)
    add("cube", (-0.38, 0, -0.52), (0.36, 0.3, 0.75), blk, bevel=0.08, seg=4, rot=(0, math.radians(-14), 0))
    add("cube", (0.66, 0, 0.0), (0.18, 0.36, 0.42), blk, bevel=0.03)
    add("cube", (0.05, 0, -0.38), (0.06, 0.2, 0.3), blk, bevel=0.02)
    add("cube", (0.1, -0.175, 0.08), (0.4, 0.01, 0.12), mat("lbl", (0.05, 0.05, 0.05), 0.4))
    shoot("rox_taser", elev=10, azim=-12)


def cuffs():
    reset()
    st = mat("st", (0.7, 0.71, 0.73), 0.2, 1.0)
    add("torus", (-0.55, 0, 0), (1.0, 1.0, 1.4), st)
    add("torus", (0.55, 0, 0), (1.0, 1.0, 1.4), st)
    for i in range(3):
        add("torus", (-0.12 + i * 0.12, 0, 0), (0.14, 0.14, 0.5), st, rot=(math.pi / 2 if i % 2 else 0, 0, 0))
    shoot("rox_cuffs", elev=65, azim=-10, dist=2.4)


def bullet():
    reset()
    brass = mat("br", (0.78, 0.55, 0.2), 0.22, 1.0); lead = mat("ld", (0.6, 0.38, 0.22), 0.3, 1.0)
    for k, x in enumerate((-0.25, 0, 0.25)):
        add("cyl", (x, 0, 0), (0.22, 0.22, 0.8), brass, verts=32)
        add("cone", (x, 0, 0.55), (0.22, 0.22, 0.32), lead, verts=32)
    shoot("rox_ammo", elev=18, azim=-30, dist=2.6)


def idcard():
    reset()
    base = mat("c", (0.9, 0.88, 0.8), 0.35); blue = mat("bl", (0.12, 0.3, 0.6), 0.4); ph = mat("ph", (0.35, 0.3, 0.27), 0.5)
    add("cube", (0, 0, 0), (1.7, 1.08, 0.02), base, bevel=0.06)
    add("cube", (0, 0.42, 0.012), (1.7, 0.22, 0.004), blue)
    add("cube", (-0.5, -0.1, 0.012), (0.45, 0.55, 0.004), ph)
    for i in range(4):
        add("cube", (0.25, 0.12 - i * 0.14, 0.012), (0.75 - i * 0.1, 0.05, 0.004), mat("t%d" % i, (0.3, 0.3, 0.32), 0.5))
    shoot("rox_idcard", elev=58, azim=-15, dist=2.4)


def box():
    reset()
    cb = mat("cb", (0.42, 0.3, 0.17), 0.85); tape = mat("tp", (0.7, 0.6, 0.42), 0.3)
    add("cube", (0, 0, 0), (1.3, 1.0, 0.9), cb, bevel=0.015)
    add("cube", (0, 0, 0.452), (0.24, 1.02, 0.006), tape)
    add("cube", (0.652, 0, 0.3), (0.006, 0.24, 0.3), tape)
    shoot("rox_box", elev=28, azim=-35)


ITEMS = [vest, tank, pills, radio, baton, taser, cuffs, bullet, idcard, box]
for f in ITEMS:
    f()
for n, c in (("rox_transparency_red", (0.85, 0.15, 0.12)), ("rox_transparency_blue", (0.12, 0.3, 0.85)), ("rox_transparency_amber", (0.9, 0.55, 0.08))):
    transparency(n, c)
print("done ->", OUT)
