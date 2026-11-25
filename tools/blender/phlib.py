# Poly Haven (CC0) asset loader: import each glTF once, then place cheap instances.  (c) ROX Store
#   ph(name, (x, y, z), face, height)  ->  face = direction the front looks at, degrees: 0 = -Y, 90 = +X, 180 = +Y, 270 = -X
import bpy, os, math
from mathutils import Vector
PH = os.environ.get('PH', '')
FRONT = {}            # per-asset correction (degrees) if a model's front is not -Y
_cache = {}

def _load(name):
    if name in _cache: return _cache[name]
    d = os.path.join(PH, name); f = [x for x in os.listdir(d) if x.endswith('.gltf')][0]
    before = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=os.path.join(d, f))
    new = [o for o in bpy.data.objects if o not in before]
    col = bpy.data.collections.new('PH_' + name)
    for o in new:
        for c in list(o.users_collection): c.objects.unlink(o)
        col.objects.link(o)
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in new if o.type == 'MESH' for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))); hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    col.instance_offset = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)
    _cache[name] = (col, hi.z - lo.z, hi - lo); return _cache[name]

def ph(name, loc, face=0.0, height=None, scale=None):
    col, h, dims = _load(name)
    o = bpy.data.objects.new(name, None); o.instance_type = 'COLLECTION'; o.instance_collection = col
    bpy.context.scene.collection.objects.link(o)
    s = scale or (height / h if height else 1.0); o.scale = (s, s, s)
    o.rotation_euler.z = math.radians(face + FRONT.get(name, 0.0)); o.location = Vector(loc)
    return o
