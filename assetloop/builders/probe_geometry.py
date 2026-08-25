# Geometry probe for the asset polish loop: opens a GLB headless and prints
# MEASURED per-part facts the judge cannot get from pictures:
#   - pairwise bbox overlaps (attachment)
#   - % of a part's surface points INSIDE the largest part (rooted / buried / detached)
#   - fully-enclosed parts (hidden geometry suspects)
# Usage: blender --background --python probe_geometry.py -- <glb>
# Output: lines starting with "PROBE" (parseable), human-readable after "->".
import bpy
import sys
import random
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
glb = argv[0]
random.seed(4242)

bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if not objs:
    print("PROBE ERROR no meshes")
    sys.exit(0)

def world_bbox(o):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        for k in range(3):
            mn[k] = min(mn[k], w[k])
            mx[k] = max(mx[k], w[k])
    return mn, mx

boxes = {}
for o in objs:
    boxes[o.name] = world_bbox(o)

touching = []

ext = [max(mx[k] for mn, mx in boxes.values()) - min(mn[k] for mn, mx in boxes.values()) for k in range(3)]
print("PROBE parts=%d bbox=(%.3f,%.3f,%.3f)" % (len(objs), ext[0], ext[1], ext[2]))

def overlap(a, b):
    (amn, amx), (bmn, bmx) = boxes[a], boxes[b]
    d = [min(amx[k], bmx[k]) - max(amn[k], bmn[k]) for k in range(3)]
    return d

# largest part = reference body
ref = max(objs, key=lambda o: (boxes[o.name][1] - boxes[o.name][0]).length)
ref_name = ref.name

for i, a in enumerate(objs):
    for b in objs[i + 1:]:
        d = overlap(a.name, b.name)
        if all(v > -1e-6 for v in d) and min(d) > 0.0005:
            touching.append((a.name, b.name))
            print("PROBE pair %s|%s overlap=(%.3f,%.3f,%.3f)" % (a.name, b.name, *d))

# connectivity: anything reachable from the reference body through bbox contacts
# counts as attached (chain rooting is legitimate: blade -> bridge -> body)
adj = {o.name: set() for o in objs}
for a, b in touching:
    adj[a].add(b)
    adj[b].add(a)
reach = {}
frontier = [(ref_name, [ref_name])]
seen = {ref_name}
while frontier:
    nxt = []
    for node, path in frontier:
        for nb in adj[node]:
            if nb not in seen:
                seen.add(nb)
                reach[nb] = path + [nb]
                nxt.append((nb, path + [nb]))
    frontier = nxt

# surface sampling of every non-reference part against the reference body
# NOTE: closest_point_on_mesh expects LOCAL coordinates of the evaluated object
dg = bpy.context.evaluated_depsgraph_get()
ref_eval = ref.evaluated_get(dg)
ref_inv = ref_eval.matrix_world.inverted()
for o in objs:
    if o is ref:
        continue
    n_total = len(o.data.vertices)
    idxs = range(n_total) if n_total <= 300 else sorted(random.sample(range(n_total), 300))
    inside = 0
    depths = []
    for vi in idxs:
        p_local = ref_inv @ (o.matrix_world @ o.data.vertices[vi].co)
        hit, loc, norm, _ = ref_eval.closest_point_on_mesh(p_local)
        if hit:
            signed = (p_local - loc).dot(norm)
            if signed < 0.0:
                inside += 1
                depths.append(-signed)
    pct = int(100.0 * inside / max(len(idxs), 1))
    if o.name in reach and reach[o.name] != [o.name] and len(reach[o.name]) > 2:
        chain = " -> ".join(reach[o.name][1:])
        verdict = "CHAIN_ROOTED via %s" % chain
    elif o.name in reach:
        touches_ref = min(overlap(o.name, ref_name)) > 0.0005
        if pct == 0 and not touches_ref:
            verdict = "DETACHED_CANDIDATE"
        elif pct == 0:
            verdict = "SURFACE_ONLY_NO_ROOT (warn)"
        elif pct < 8:
            verdict = "BARELY_ROOTED (warn)"
        elif pct >= 97:
            verdict = "BURIED_SUSPECT"
        else:
            mean_d = sum(depths) / len(depths) if depths else 0.0
            verdict = "ROOTED_VISIBLE (mean root depth %.3fm)" % mean_d
    else:
        verdict = "DETACHED_CANDIDATE"
    line = "PROBE inside %s in %s pct=%d -> %s" % (o.name, ref_name, pct, verdict)
    print(line)

# hidden-geometry suspects: bbox fully enclosed by another part's bbox AND
# mesh-confirmed mostly inside it (bbox alone false-positives on elongated bodies)
for a in objs:
    for b in objs:
        if a is b:
            continue
        (amn, amx), (bmn, bmx) = boxes[a.name], boxes[b.name]
        if all(amn[k] >= bmn[k] - 1e-4 and amx[k] <= bmx[k] + 1e-4 for k in range(3)):
            print("PROBE enclosed %s by %s -> check inside%% above" % (a.name, b.name))
            break

print("PROBE_DONE")
