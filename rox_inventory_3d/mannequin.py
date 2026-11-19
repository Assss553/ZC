# ROX Store | mannequin render for the inventory (original)
import bpy, math, sys, os
from mathutils import Vector
OUT = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
s = bpy.context.scene
s.render.engine = "CYCLES"; s.cycles.samples = 96; s.render.film_transparent = True
s.render.resolution_x, s.render.resolution_y = 600, 1000
s.view_settings.view_transform = "Standard"; s.view_settings.exposure = -0.1
w = bpy.data.worlds.new("w"); s.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.1, 0.11, 0.13, 1)

def mat(c, r=0.45, m=0.2):
    x = bpy.data.materials.new("m"); x.use_nodes = True; b = x.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = r; b.inputs["Metallic"].default_value = m
    return x
BODY = mat((0.07, 0.075, 0.085), 0.55, 0.15); JOINT = mat((0.05, 0.05, 0.06), 0.5, 0.6)

def cap(a, b, r, m=BODY):
    a, b = Vector(a), Vector(b); d = b - a
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(a + b) / 2, vertices=32)
    o = bpy.context.object; o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler(); o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    for p in (a, b):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=p, segments=32, ring_count=16)
        bpy.context.object.data.materials.append(m); bpy.ops.object.shade_smooth()

def ball(p, sc, m=BODY):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=p, segments=48, ring_count=24)
    o = bpy.context.object; o.scale = sc; o.data.materials.append(m); bpy.ops.object.shade_smooth()

ball((0, 0, 1.68), (0.095, 0.11, 0.125))               # head
cap((0, 0, 1.5), (0, 0, 1.58), 0.05, JOINT)            # neck
ball((0, 0, 1.31), (0.175, 0.105, 0.2))                  # chest
ball((0, 0, 1.08), (0.13, 0.085, 0.14))                  # abdomen
ball((0, 0, 0.9), (0.155, 0.095, 0.1))                  # pelvis
for sx in (-1, 1):
    ball((0.22 * sx, 0, 1.42), (0.075, 0.075, 0.075), JOINT)          # shoulder
    cap((0.24 * sx, 0, 1.4), (0.3 * sx, 0.02, 1.13), 0.048)           # upper arm
    ball((0.3 * sx, 0.02, 1.12), (0.04, 0.04, 0.04), JOINT)           # elbow
    cap((0.3 * sx, 0.02, 1.11), (0.33 * sx, -0.04, 0.88), 0.04)       # forearm
    ball((0.335 * sx, -0.05, 0.84), (0.04, 0.03, 0.055))              # hand
    ball((0.1 * sx, 0, 0.86), (0.07, 0.07, 0.07), JOINT)              # hip
    cap((0.1 * sx, 0, 0.84), (0.11 * sx, 0.01, 0.48), 0.07)           # thigh
    ball((0.11 * sx, 0, 0.47), (0.055, 0.055, 0.055), JOINT)          # knee
    cap((0.11 * sx, 0, 0.45), (0.115 * sx, 0.03, 0.1), 0.055)         # shin
    ball((0.115 * sx, -0.04, 0.05), (0.05, 0.11, 0.04))              # foot

for loc, e, col in [((2.2, -2.5, 3), 600, (1, .92, .85)), ((-2.5, -1.2, 2), 220, (.7, .8, 1)), ((0.4, 2.5, 2.2), 1600, (1, .45, .15)), ((-0.6, 2.5, 1.0), 900, (1, .45, .15))]:
    bpy.ops.object.light_add(type="AREA", location=loc); L = bpy.context.object
    L.data.energy = e; L.data.size = 2; L.data.color = col
    L.rotation_euler = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(0.9, -4.2, 1.2)); c = bpy.context.object; c.data.lens = 58
c.rotation_euler = (Vector((0, 0, 0.9)) - c.location).to_track_quat('-Z', 'Y').to_euler(); s.camera = c
s.render.filepath = os.path.join(OUT, "mannequin.png"); bpy.ops.render.render(write_still=True)
print("ok")
