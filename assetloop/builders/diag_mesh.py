import bpy
import sys
import math
from collections import defaultdict

argv = sys.argv[sys.argv.index('--') + 1:]
glb = argv[0]
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

for ob in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    me = ob.data
    print("OBJ", ob.name, "polys", len(me.polygons),
          "smooth", sum(1 for p in me.polygons if p.use_smooth))
    edge_faces = defaultdict(list)
    for pi, p in enumerate(me.polygons):
        for ek in p.edge_keys:
            edge_faces[ek].append(pi)
    worst = []
    for ek, fs in edge_faces.items():
        if len(fs) == 2:
            n1 = me.polygons[fs[0]].normal
            n2 = me.polygons[fs[1]].normal
            ang = math.degrees(n1.angle(n2))
            if ang > 4.0:
                worst.append((ang, ek))
    worst.sort(reverse=True)
    b90 = sum(1 for a, _ in worst if a > 90)
    b45 = sum(1 for a, _ in worst if 45 < a <= 90)
    b25 = sum(1 for a, _ in worst if 25 < a <= 45)
    b15 = sum(1 for a, _ in worst if 15 < a <= 25)
    print("BUCKETS >90:%d 45-90:%d 25-45:%d 15-25:%d 4-15:%d" %
          (b90, b45, b25, b15, len(worst) - b90 - b45 - b25 - b15))
    print("CREASES_OVER_4DEG", len(worst))
    for ang, ek in worst[:12]:
        v0 = me.vertices[ek[0]]
        v1 = me.vertices[ek[1]]
        mid = (v0.co + v1.co) / 2
        print("CREASE %.1fdeg at (%.3f, %.3f, %.3f)" % (ang, mid.x, mid.y, mid.z))

ob = [o for o in bpy.context.scene.objects if o.type == 'MESH' and 'Shaft' in o.name]
if ob:
    me = ob[0].data
    prof = defaultdict(list)
    for v in me.vertices:
        prof[round(v.co.x, 2)].append(math.hypot(v.co.y, v.co.z))
    xs = sorted(prof)
    print("RADIUS_PROFILE (x: rmin-rmax)")
    line = []
    for x in xs[::3]:
        rs = prof[x]
        line.append("%.2f:%.4f-%.4f" % (x, min(rs), max(rs)))
    print(" | ".join(line))
