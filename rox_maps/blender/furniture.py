# ROX Store | All rights reserved
# Detailed furniture / lighting generators for ROX maps (original geometry).
import bpy, math

CTX = {}          # filled by build script: M (materials), finish(o, m, col)
LIGHTS = []       # (collection, location, color, energy, radius) -> render lights + Sollumz lights


def _new(op, loc, rot, **kw):
    op(location=loc, rotation=rot, **kw)
    return bpy.context.object


def part(kind, loc, size, m, bevel=0.0, rot=(0, 0, 0), verts=24, seg=3):
    """kind: cube | cyl | cone | sphere | torus. size = full dimensions (x, y, z)."""
    if kind == "cube":
        o = _new(bpy.ops.mesh.primitive_cube_add, loc, rot)
    elif kind == "cyl":
        o = _new(bpy.ops.mesh.primitive_cylinder_add, loc, rot, vertices=verts)
    elif kind == "cone":
        o = _new(bpy.ops.mesh.primitive_cone_add, loc, rot, vertices=verts, radius1=1, radius2=0.35)
    elif kind == "sphere":
        o = _new(bpy.ops.mesh.primitive_uv_sphere_add, loc, rot, segments=verts, ring_count=verts // 2)
    elif kind == "torus":
        o = _new(bpy.ops.mesh.primitive_torus_add, loc, rot, major_segments=verts, minor_segments=8,
                 major_radius=1, minor_radius=0.08)
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        md = o.modifiers.new("bev", "BEVEL"); md.width = bevel; md.segments = seg; md.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=md.name)
    if kind in ("cyl", "sphere", "torus", "cone"):
        bpy.ops.object.shade_smooth()
    o["rox_mat"] = m
    return o


def group(name, parts, col, origin=(0, 0, 0), rotz=0.0):
    """Finish (material + UV) every part, then join into one object rotated around origin."""
    for p in parts:
        CTX["finish"](p, p["rox_mat"], None)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    if rotz:
        bpy.context.scene.cursor.location = origin
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        o.rotation_euler[2] = math.radians(rotz)
        bpy.ops.object.transform_apply(rotation=True)
    if col:
        col.objects.link(o)
        bpy.context.scene.collection.objects.unlink(o)
    return o


# ------------------------------------------------------------------ chairs / seating
def chair(name, x, y, z, rotz, col, wood="wood", seat="fabric"):
    """Dining chair: tapered legs, stretchers, padded seat, curved slat back."""
    p = []
    for dx in (-0.2, 0.2):
        for dy in (-0.2, 0.2):
            p.append(part("cyl", (x + dx, y + dy, z + 0.22), (0.045, 0.045, 0.44), wood, verts=10))
    p.append(part("cube", (x, y - 0.2, z + 0.12), (0.4, 0.025, 0.03), wood))
    p.append(part("cube", (x, y + 0.2, z + 0.12), (0.4, 0.025, 0.03), wood))
    p.append(part("cube", (x, y, z + 0.46), (0.48, 0.48, 0.04), wood, bevel=0.01))
    p.append(part("cube", (x, y, z + 0.5), (0.46, 0.46, 0.06), seat, bevel=0.025, seg=4))       # cushion
    for dx in (-0.21, 0.21):                                                                    # back posts
        p.append(part("cube", (x + dx, y + 0.22, z + 0.72), (0.04, 0.04, 0.5), wood, bevel=0.008, rot=(math.radians(-6), 0, 0)))
    for i, h in enumerate((0.62, 0.74, 0.86)):                                                  # slats
        p.append(part("cube", (x, y + 0.235 + i * 0.012, z + h), (0.42, 0.03, 0.06 if i < 2 else 0.1), wood, bevel=0.01))
    return group(name, p, col, (x, y, z), rotz)


def bar_stool(name, x, y, z, col):
    p = [part("cyl", (x, y, z + 0.76), (0.42, 0.42, 0.08), "fabric", bevel=0.02, verts=28),
         part("cyl", (x, y, z + 0.71), (0.3, 0.3, 0.03), "steel", verts=24),
         part("cyl", (x, y, z + 0.37), (0.06, 0.06, 0.68), "steel", verts=12),
         part("torus", (x, y, z + 0.28), (0.36, 0.36, 0.36), "steel", verts=28),
         part("cyl", (x, y, z + 0.015), (0.4, 0.4, 0.03), "steel", bevel=0.008, verts=28)]
    return group(name, p, col)


def booth(name, x, y, z, rotz, col, length=1.4):
    """Diner booth: wood base, seat cushion, tilted tufted back, wood top cap."""
    p = [part("cube", (x, y, z + 0.22), (0.55, length, 0.44), "wood", bevel=0.015),
         part("cube", (x, y - 0.02, z + 0.5), (0.55, length - 0.04, 0.12), "fabric", bevel=0.045, seg=5),
         part("cube", (x - 0.24, y, z + 0.95), (0.16, length - 0.04, 0.75), "fabric", bevel=0.05, seg=5,
              rot=(0, math.radians(-8), 0)),
         part("cube", (x - 0.32, y, z + 1.38), (0.14, length + 0.02, 0.05), "wood", bevel=0.015)]
    for i in range(int(length / 0.35)):                       # vertical tuft channels
        yy = y - length / 2 + 0.2 + i * 0.35
        p.append(part("cube", (x - 0.15, yy, z + 0.95), (0.02, 0.02, 0.62), "leather", rot=(0, math.radians(-8), 0)))
    return group(name, p, col, (x, y, z), rotz)


def sofa(name, x, y, z, col, length=3.0):
    """Chesterfield-style sofa (HQ)."""
    p = [part("cube", (x, y, z + 0.22), (length, 0.95, 0.3), "leather", bevel=0.05, seg=4),
         part("cube", (x, y + 0.4, z + 0.6), (length, 0.22, 0.65), "leather", bevel=0.08, seg=5)]
    for sx in (-1, 1):
        p.append(part("cube", (x + sx * (length / 2 - 0.12), y, z + 0.48), (0.26, 0.95, 0.55), "leather", bevel=0.1, seg=5))
    n = 3
    for i in range(n):
        cw = (length - 0.5) / n
        p.append(part("cube", (x - (length - 0.5) / 2 + cw * (i + 0.5), y - 0.05, z + 0.42),
                      (cw - 0.03, 0.8, 0.16), "leather", bevel=0.06, seg=5))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(part("cyl", (x + sx * (length / 2 - 0.1), y + sy * 0.38, z + 0.04), (0.07, 0.07, 0.08), "wood", verts=10))
    return group(name, p, col)


def office_chair(name, x, y, z, rotz, col):
    p = [part("cube", (x, y, z + 0.5), (0.52, 0.5, 0.1), "leather", bevel=0.04, seg=4),
         part("cube", (x, y + 0.24, z + 0.9), (0.5, 0.1, 0.7), "leather", bevel=0.05, seg=4, rot=(math.radians(-8), 0, 0)),
         part("cyl", (x, y, z + 0.27), (0.06, 0.06, 0.4), "steel", verts=12)]
    for i in range(5):
        a = i * 2 * math.pi / 5
        p.append(part("cube", (x + math.cos(a) * 0.17, y + math.sin(a) * 0.17, z + 0.06), (0.34, 0.04, 0.03), "steel",
                      rot=(0, 0, a)))
        p.append(part("sphere", (x + math.cos(a) * 0.33, y + math.sin(a) * 0.33, z + 0.03), (0.05, 0.05, 0.05), "steel", verts=8))
    for sx in (-1, 1):
        p.append(part("cube", (x + sx * 0.28, y + 0.02, z + 0.68), (0.05, 0.36, 0.04), "steel", bevel=0.01))
    return group(name, p, col, (x, y, z), rotz)


# ------------------------------------------------------------------ tables
def round_table(name, x, y, z, col, r=0.45, top="marble"):
    p = [part("cyl", (x, y, z + 0.75), (r * 2, r * 2, 0.04), top, bevel=0.012, verts=36),
         part("torus", (x, y, z + 0.75), (r * 2, r * 2, 0.5), "steel", verts=36),     # chrome edge band
         part("cyl", (x, y, z + 0.38), (0.08, 0.08, 0.72), "steel", verts=14),
         part("cone", (x, y, z + 0.06), (0.55, 0.55, 0.12), "steel", verts=28)]
    return group(name, p, col)


def rect_table(name, x, y, z, col, w=1.2, d=0.8, top="wood", h=0.75):
    p = [part("cube", (x, y, z + h), (w, d, 0.045), top, bevel=0.01),
         part("cube", (x, y, z + h - 0.06), (w - 0.12, d - 0.12, 0.08), top)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(part("cyl", (x + sx * (w / 2 - 0.08), y + sy * (d / 2 - 0.08), z + (h - 0.05) / 2),
                          (0.05, 0.05, h - 0.05), "steel", verts=10))
    return group(name, p, col)


# ------------------------------------------------------------------ lighting
def pendant(name, x, y, ceil_z, col, drop=1.2, color=(1.0, 0.78, 0.5), energy=60):
    z = ceil_z - drop
    p = [part("cyl", (x, y, ceil_z - 0.02), (0.14, 0.14, 0.04), "steel", verts=16),
         part("cyl", (x, y, z + drop / 2), (0.008, 0.008, drop), "leather", verts=6),
         part("cone", (x, y, z), (0.42, 0.42, 0.3), "steel", verts=28),
         part("sphere", (x, y, z - 0.1), (0.12, 0.12, 0.12), "neon", verts=12)]
    LIGHTS.append((col, (x, y, z - 0.18), color, energy, 6.0))
    return group(name, p, col)


def sconce(name, x, y, z, nx, col, color=(1.0, 0.75, 0.45)):
    """Wall light; nx = wall normal sign on X (+1 left wall, -1 right wall)."""
    p = [part("cube", (x, y, z), (0.04, 0.16, 0.24), "steel", bevel=0.01),
         part("cyl", (x + nx * 0.1, y, z + 0.05), (0.14, 0.14, 0.2), "glass", verts=16),
         part("sphere", (x + nx * 0.1, y, z + 0.05), (0.07, 0.07, 0.07), "neon", verts=10)]
    LIGHTS.append((col, (x + nx * 0.15, y, z), color, 20, 4.0))
    return group(name, p, col)


def strip_light(name, x, y, z, length, col, color=(0.2, 0.7, 1.0), axis="x"):
    size = (length, 0.06, 0.04) if axis == "x" else (0.06, length, 0.04)
    p = [part("cube", (x, y, z), size, "neon_hq", bevel=0.01)]
    n = max(1, int(length / 4))
    for i in range(n):
        off = -length / 2 + length * (i + 0.5) / n
        LIGHTS.append((col, (x + off, y, z - 0.2) if axis == "x" else (x, y + off, z - 0.2), color, 80, 8.0))
    return group(name, p, col)


# ------------------------------------------------------------------ decor
def plant(name, x, y, z, col, h=1.2):
    p = [part("cyl", (x, y, z + 0.25), (0.5, 0.5, 0.5), "concrete", bevel=0.02, verts=20),
         part("cyl", (x, y, z + 0.48), (0.44, 0.44, 0.04), "asphalt", verts=20),
         part("cyl", (x, y, z + 0.5 + h * 0.3), (0.05, 0.05, h * 0.6), "wood", verts=8)]
    for i in range(7):
        a = i * 2.4
        rr = 0.18 + (i % 3) * 0.06
        p.append(part("sphere", (x + math.cos(a) * rr, y + math.sin(a) * rr, z + 0.6 + h * (0.45 + 0.08 * (i % 4))),
                      (0.42, 0.32, 0.22), "plant", verts=10, rot=(0, 0, a)))
    return group(name, p, col)


def skirting(name, x0, x1, y0, y1, z, col, inset=0.22):
    p = [part("cube", ((x0 + x1) / 2, y0 + inset, z + 0.06), (x1 - x0 - 2 * inset, 0.02, 0.12), "wood"),
         part("cube", ((x0 + x1) / 2, y1 - inset, z + 0.06), (x1 - x0 - 2 * inset, 0.02, 0.12), "wood"),
         part("cube", (x0 + inset, (y0 + y1) / 2, z + 0.06), (0.02, y1 - y0 - 2 * inset, 0.12), "wood"),
         part("cube", (x1 - inset, (y0 + y1) / 2, z + 0.06), (0.02, y1 - y0 - 2 * inset, 0.12), "wood")]
    return group(name, p, col)
