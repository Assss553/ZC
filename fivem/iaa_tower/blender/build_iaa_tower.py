"""IAA Tower - Blender model builder.

Run inside Blender:  Scripting tab > Open > Run Script
or headless:         blender -b -P build_iaa_tower.py
Outputs (next to this script): iaa_tower.blend, iaa_tower.fbx, iaa_tower.obj, iaa_tower.glb
Units: meters. Origin = ground center. Height to spire tip = 280 m.
"""
import bpy, bmesh, math, os

OUT = os.path.dirname(os.path.abspath(__file__))

# ---------- reset ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
col = bpy.data.collections.new("IAA_Tower")
scene.collection.children.link(col)

# ---------- materials ----------
def mat(name, color, metal=0.0, rough=0.5, emit=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

M_GLASS = mat("IAA_Glass", (0.06, 0.20, 0.32), metal=0.7, rough=0.08)
M_STEEL = mat("IAA_Steel", (0.62, 0.68, 0.72), metal=0.9, rough=0.3)
M_DARK  = mat("IAA_Dark",  (0.03, 0.06, 0.09), metal=0.5, rough=0.4)
M_GOLD  = mat("IAA_Gold",  (0.85, 0.65, 0.25), metal=1.0, rough=0.25,
              emit=(1.0, 0.85, 0.5), strength=0.6)
M_LOGO  = mat("IAA_Logo",  (1.0, 0.78, 0.3), emit=(1.0, 0.78, 0.3), strength=12.0)
M_RED   = mat("IAA_Beacon", (1, 0.1, 0.1), emit=(1, 0.1, 0.1), strength=20.0)
M_LOBBY = mat("IAA_Lobby", (0.25, 0.53, 0.69), metal=0.3, rough=0.05,
              emit=(1.0, 0.85, 0.55), strength=1.5)

# ---------- helpers ----------
def frustum(name, z0, z1, w0, d0, w1, d1, m, cx=0.0, cy=0.0):
    """Box whose bottom is w0 x d0 and top is w1 x d1 (tapered)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    v = []
    for z, w, d in ((z0, w0, d0), (z1, w1, d1)):
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            v.append(bm.verts.new((cx + sx * w / 2, cy + sy * d / 2, z)))
    bm.faces.new(v[3::-1])            # bottom
    bm.faces.new(v[4:8])              # top
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((v[i], v[j], v[4 + j], v[4 + i]))
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(m)
    col.objects.link(ob)
    return ob

def lerp(a, b, t): return a + (b - a) * t

# ---------- dimensions ----------
PODIUM_H = 12
SHAFT_Z0, SHAFT_Z1 = PODIUM_H, 230
W0, W1 = 40.0, 30.0            # shaft width bottom / top (square plan)
CROWN_Z1 = 255
SPIRE_TIP = 280

def width_at(z):
    return lerp(W0, W1, (z - SHAFT_Z0) / (SHAFT_Z1 - SHAFT_Z0))

# ---------- podium ----------
frustum("Podium", 0, PODIUM_H, 70, 50, 70, 50, M_DARK)
frustum("Podium_Trim", PODIUM_H - 0.8, PODIUM_H, 70.6, 50.6, 70.6, 50.6, M_GOLD)
frustum("Entrance", 0, 9, 18, 50.4, 18, 50.4, M_LOBBY)

# ---------- shaft ----------
frustum("Shaft", SHAFT_Z0, SHAFT_Z1, W0, W0, W1, W1, M_GLASS)

# sky-lobby gold bands (F20, F40)
for name, z in (("SkyLobby_F20", 95), ("SkyLobby_F40", 165)):
    w = width_at(z) + 1.2
    frustum(name, z, z + 4, w, w, w - 0.1, w - 0.1, M_GOLD)

# vertical fins: 3 per face, follow the taper
FIN_T, FIN_D = 0.6, 1.4
for face in range(4):
    ang = face * math.pi / 2
    for k in (-0.5, 0.0, 0.5):
        me = bpy.data.meshes.new("Fin")
        bm = bmesh.new()
        pts = []
        for z in (SHAFT_Z0, SHAFT_Z1):
            half = width_at(z) / 2
            for off_out, off_side in ((0, -FIN_T/2), (FIN_D, -FIN_T/2),
                                      (FIN_D, FIN_T/2), (0, FIN_T/2)):
                lx = k * half + off_side
                ly = half + off_out
                x = lx * math.cos(ang) - ly * math.sin(ang)
                y = lx * math.sin(ang) + ly * math.cos(ang)
                pts.append(bm.verts.new((x, y, z)))
        bm.faces.new(pts[3::-1]); bm.faces.new(pts[4:8])
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((pts[i], pts[j], pts[4 + j], pts[4 + i]))
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(f"Fin_{face}_{k}", me)
        ob.data.materials.append(M_STEEL); col.objects.link(ob)

# ---------- crown ----------
frustum("Crown", SHAFT_Z1, CROWN_Z1, W1, W1, 26, 26, M_DARK)
frustum("Crown_Ring", CROWN_Z1, CROWN_Z1 + 1.5, 27.5, 27.5, 27.5, 27.5, M_GOLD)
frustum("Roof", CROWN_Z1 + 1.5, CROWN_Z1 + 3, 22, 22, 18, 18, M_STEEL)

# ---------- IAA logo on 4 sides of the crown ----------
LOGO_Z = (SHAFT_Z1 + CROWN_Z1) / 2
for face in range(4):
    ang = face * math.pi / 2
    zc = LOGO_Z
    half = lerp(W1, 26, (zc - SHAFT_Z1) / (CROWN_Z1 - SHAFT_Z1)) / 2 + 0.15
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.object
    t.name = f"Logo_IAA_{face}"
    t.data.body = "IAA"
    t.data.align_x = 'CENTER'; t.data.align_y = 'CENTER'
    t.data.size = 11
    t.data.extrude = 0.25
    t.data.space_character = 1.15
    bpy.ops.object.convert(target='MESH')
    t.data.materials.clear(); t.data.materials.append(M_LOGO)
    # stand text up, face outward (face normal = (-sin, cos))
    nx, ny = -math.sin(ang), math.cos(ang)
    t.rotation_euler = (math.pi / 2, 0, ang + math.pi)
    t.location = (nx * half, ny * half, zc)
    for c in t.users_collection: c.objects.unlink(t)
    col.objects.link(t)

# ---------- spire + beacon ----------
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=1.6, radius2=0.15,
                                depth=SPIRE_TIP - (CROWN_Z1 + 3),
                                location=(0, 0, (CROWN_Z1 + 3 + SPIRE_TIP) / 2))
sp = bpy.context.object; sp.name = "Spire"; sp.data.materials.append(M_STEEL)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.6,
                                     location=(0, 0, SPIRE_TIP))
bc = bpy.context.object; bc.name = "Beacon"; bc.data.materials.append(M_RED)
for o in (sp, bc):
    for c in o.users_collection: c.objects.unlink(o)
    col.objects.link(o)

# ---------- simple collision mesh (for Sollumz bound) ----------
c1 = frustum("COL_Podium", 0, PODIUM_H, 70, 50, 70, 50, M_DARK)
c2 = frustum("COL_Shaft", SHAFT_Z0, CROWN_Z1 + 3, W0, W0, 26, 26, M_DARK)
colc = bpy.data.collections.new("IAA_Collision")
scene.collection.children.link(colc)
for o in (c1, c2):
    col.objects.unlink(o); colc.objects.link(o); o.hide_render = True
    o.display_type = 'WIRE'

# ---------- save + export ----------
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "iaa_tower.blend"))

bpy.ops.object.select_all(action='DESELECT')
for o in col.objects: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "iaa_tower.fbx"), use_selection=True)
bpy.ops.wm.obj_export(filepath=os.path.join(OUT, "iaa_tower.obj"), export_selected_objects=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "iaa_tower.glb"), use_selection=True)
print("IAA tower built:", OUT)
