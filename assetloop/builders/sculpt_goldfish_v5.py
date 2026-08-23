# goldfish_v5.1 - SCULPTED single-mesh fish. Loft superelliptic egg body,
# fin slabs with buried roots + eye bosses, boolean-union into ONE manifold,
# voxel-remesh -> subsurf -> PAINT materials geometrically -> decimate ->
# keep-largest-island cleanup. Usage:
#   blender --background --python sculpt_goldfish_v5.py -- <out.glb>
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
glb_out = argv[0]
bpy.ops.wm.read_homefile(use_empty=True)

def cr_sample(pts, n):
    pts = [pts[0]] + list(pts) + [pts[-1]]
    segs = len(pts) - 3
    out = []
    for s in range(n):
        u = s / (n - 1) * segs
        i = min(int(u), segs - 1)
        f = u - i
        p0, p1, p2, p3 = pts[i], pts[i+1], pts[i+2], pts[i+3]
        v = 0.5*((2*p1)+(-p0+p2)*f+(2*p0-5*p1+4*p2-p3)*f*f+(-p0+3*p1-3*p2+p3)*f**3)
        out.append(Vector(v))
    return out

def bm_to_obj(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob

# ---------------- body: loft of plump egg rings along spine -----------------
PROFILE = [
    (-0.265, 0.118, 0.010, 0.016, 0.016),
    (-0.230, 0.120, 0.042, 0.058, 0.062),
    (-0.170, 0.123, 0.060, 0.083, 0.093),
    (-0.085, 0.126, 0.067, 0.096, 0.108),
    (0.000, 0.125, 0.064, 0.092, 0.104),
    (0.080, 0.119, 0.053, 0.074, 0.082),
    (0.150, 0.113, 0.038, 0.053, 0.057),
    (0.205, 0.109, 0.022, 0.031, 0.033),
    (0.245, 0.106, 0.009, 0.013, 0.014),
]
SIDES = 36
bm = bmesh.new()
rings = []
NS = len(PROFILE)
for i in range(NS):
    x, cz, w, rt, rb = PROFILE[i]
    ring = []
    for k in range(SIDES):
        a = 2*math.pi*k/SIDES
        c, s = math.cos(a), math.sin(a)
        z = cz + (rt if s >= 0 else rb) * s
        y = w * c * (1.0 - 0.22*s*s)
        ring.append(bm.verts.new(Vector((x, y, z))))
    rings.append(ring)
for i in range(NS-1):
    for k in range(SIDES):
        k2 = (k+1) % SIDES
        try:
            bm.faces.new((rings[i][k], rings[i][k2], rings[i+1][k2], rings[i+1][k]))
        except ValueError:
            pass
for ring, flip in ((rings[0], True), (rings[-1], False)):
    pole = bm.verts.new(ring[0].co.copy())
    for k in range(SIDES):
        k2 = (k+1) % SIDES
        vs = (pole, ring[k2], ring[k]) if flip else (pole, ring[k], ring[k2])
        try:
            bm.faces.new(vs)
        except ValueError:
            pass
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
bm_to_obj(bm, 'Body')

# ---------------- fins: closed thin slabs, roots buried in body -------------
def membrane(name, outline_pts, plane_n, thick_root, thick_tip, root_pt):
    ctrl = [Vector(p) if len(p) == 3 else Vector((p[0], 0.0, p[1]))
            for p in outline_pts]
    loop = cr_sample(ctrl + [ctrl[0]], 48)[:-1]   # smooth closed loop
    M = len(loop)
    n = Vector(plane_n).normalized()
    rp = Vector(root_pt)
    span = max((p-rp).length for p in loop)
    bm = bmesh.new()
    A, B = [], []
    for p in loop:
        w = 1.0 - min((p-rp).length/span, 1.0)
        t = thick_tip + (thick_root-thick_tip)*w
        A.append(bm.verts.new(p + n*(t/2)))
        B.append(bm.verts.new(p - n*(t/2)))
    try:
        bm.faces.new(A)
        bm.faces.new(list(reversed(B)))
    except Exception as e:
        print('CAP_FAIL %s: %s' % (name, e))
    for k in range(M):
        k2 = (k+1) % M
        try:
            bm.faces.new((A[k], A[k2], B[k2], B[k]))
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    ob = bm_to_obj(bm, name)
    bmc = bmesh.new()
    bmc.from_mesh(ob.data)
    nm = sum(1 for e in bmc.edges if len(e.link_faces) != 2)
    print('MEMBRANE %s polys=%d nonmanifold_edges=%d' % (name, len(ob.data.polygons), nm))
    bmc.free()
    return ob

def membrane_local(name, origin, u_ax, v_ax, w_ax, outline2d,
                   thick_root, thick_tip):
    O, U, V, W = Vector(origin), Vector(u_ax), Vector(v_ax), Vector(w_ax)
    ctrl2 = list(outline2d) + [outline2d[0]]
    loop2 = [(p.x, p.y) for p in cr_sample([Vector((q[0], q[1], 0)) for q in ctrl2], 48)][:-1]
    M = len(loop2)
    span = max(p[0] for p in loop2)
    bm = bmesh.new()
    A, B = [], []
    for pu, pv in loop2:
        wgt = 1.0 - min(pu/span, 1.0)
        t = thick_tip + (thick_root-thick_tip)*wgt
        base = O + U*pu + V*pv
        A.append(bm.verts.new(base + W*(t/2)))
        B.append(bm.verts.new(base - W*(t/2)))
    try:
        bm.faces.new(A)
        bm.faces.new(list(reversed(B)))
    except Exception as e:
        print('CAP_FAIL %s: %s' % (name, e))
    for k in range(M):
        k2 = (k+1) % M
        try:
            bm.faces.new((A[k], A[k2], B[k2], B[k]))
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    return bm_to_obj(bm, name)

# caudal: solid veil-style fan (NO fork notch - read as a hole in renders)
membrane('Caudal', [
    (0.205, 0.118), (0.310, 0.134), (0.405, 0.154), (0.480, 0.178),
    (0.525, 0.202),
    (0.548, 0.155), (0.556, 0.107),
    (0.548, 0.059), (0.525, 0.012), (0.480, 0.036), (0.405, 0.060),
    (0.310, 0.080),
    (0.205, 0.096),
], (0, 1, 0), 0.026, 0.012, (0.20, 0, 0.107))

membrane('Dorsal', [
    (-0.110, 0.206), (-0.050, 0.236), (0.020, 0.252), (0.085, 0.240),
    (0.125, 0.210), (0.135, 0.185),
    (0.070, 0.180), (0.000, 0.186), (-0.070, 0.190),
], (0, 1, 0), 0.020, 0.010, (-0.105, 0, 0.205))

def pect(side):
    s = -1.0 if side == 'L' else 1.0
    S = (-0.112, 0.028*s, 0.075)
    u = Vector((-0.90, 0.34*s, -0.18)).normalized()
    w = Vector((0.28, 0.0, 0.92)).normalized()
    v = u.cross(w).normalized()
    membrane_local('Pectoral'+side, S, u, v, w, [
        (0.000, 0.000), (0.032, 0.014), (0.068, 0.010),
        (0.100, -0.002), (0.122, -0.016), (0.130, -0.032),
        (0.118, -0.046), (0.092, -0.044), (0.058, -0.030),
        (0.024, -0.012),
    ], 0.018, 0.011)

pect('L')
pect('R')

membrane('Pelvic', [
    (0.000, 0.000, 0.036), (0.038, 0.000, 0.012), (0.066, 0.000, -0.020),
    (0.090, 0.000, -0.002), (0.060, 0.000, 0.024), (0.018, 0.000, 0.042),
], (0, 1, 0), 0.016, 0.011, (0.0, 0, 0.038))

for side in ('L', 'R'):
    s = -1.0 if side == 'L' else 1.0
    bme = bmesh.new()
    bmesh.ops.create_uvsphere(bme, u_segments=32, v_segments=22, radius=0.015)
    bme.transform(Matrix.Translation(Vector((-0.225, 0.032*s, 0.148))))
    bm_to_obj(bme, 'Eye'+side)

# mouth: shallow notch + painted dark lip line
bmm = bmesh.new()
bmesh.ops.create_uvsphere(bmm, u_segments=20, v_segments=14, radius=0.0075)
bmm.transform(Matrix.Translation(Vector((-0.270, 0.000, 0.112))))
mouth_ob = bm_to_obj(bmm, 'MouthCutter')

# ---------------- fuse: JOIN all shells, then voxel remesh welds them -------
objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
mouth_ob = next(o for o in objs if o.name == 'MouthCutter')
fuse = [o for o in objs if o.name != 'MouthCutter']

bm = bmesh.new()
for ob in fuse:
    bm.from_mesh(ob.data)
joined_me = bpy.data.meshes.new('FishJoined')
bm.to_mesh(joined_me)
bm.free()
fish = bpy.data.objects.new('Fish', joined_me)
bpy.context.collection.objects.link(fish)
print('JOINED polys=%d' % len(joined_me.polygons))
for ob in fuse:
    bpy.data.objects.remove(ob, do_unlink=True)

bpy.context.view_layer.objects.active = fish
rm = fish.modifiers.new('rm', 'REMESH')
rm.mode = 'VOXEL'
rm.voxel_size = 0.0042
rm.adaptivity = 0.0
bpy.ops.object.modifier_apply(modifier=rm.name)
print('FUSED polys=%d' % len(fish.data.polygons))

# calm the voxel staircase before subsurf
bs = bmesh.new()
bs.from_mesh(fish.data)
for _ in range(1):
    bmesh.ops.smooth_vert(bs, verts=bs.verts[:], factor=0.3)
bs.to_mesh(fish.data)
bs.free()
print('SMOOTHED')

# mouth notch: one small boolean on the now-clean manifold
mod = fish.modifiers.new('mouth', 'BOOLEAN')
mod.operation = 'DIFFERENCE'
mod.solver = 'EXACT'
mod.object = mouth_ob
try:
    bpy.ops.object.modifier_apply(modifier='mouth')
    print('MOUTH ok')
except Exception as e:
    print('MOUTH skipped: %s' % e)
    fish.modifiers.remove(mod)
bpy.data.objects.remove(mouth_ob, do_unlink=True)

ss = fish.modifiers.new('ss', 'SUBSURF')
ss.levels = ss.render_levels = 1
bpy.ops.object.modifier_apply(modifier=ss.name)
print('SUBSURF polys=%d' % len(fish.data.polygons))

# ---------------- paint via VERTEX COLORS (single material -> no GLB split) --
mcol = bpy.data.materials.new('fish_skin')
mcol.use_nodes = True
nt = mcol.node_tree
bsdf = nt.nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value = 0.55
anode = nt.nodes.new('ShaderNodeAttribute')
anode.attribute_name = 'Col'
nt.links.new(anode.outputs['Color'], bsdf.inputs['Base Color'])
fish.data.materials.clear()
fish.data.materials.append(mcol)

REG_COL = {
    'orange': (0.93, 0.38, 0.07),
    'cream': (0.99, 0.94, 0.84),
    'black': (0.02, 0.02, 0.02),
    'dark': (0.30, 0.10, 0.07),
}

eyeL = Vector((-0.225, -0.032, 0.148))
eyeR = Vector((-0.225, 0.032, 0.148))
mouth_pt = Vector((-0.274, 0.000, 0.112))
caudal_spine = cr_sample([Vector(p) for p in
                          [(0.21, 0, 0.108), (0.33, 0, 0.138), (0.45, 0, 0.118)]], 12)
caudal_spine += cr_sample([Vector(p) for p in
                           [(0.21, 0, 0.108), (0.33, 0, 0.078), (0.44, 0, 0.055)]], 12)
dorsal_spine = cr_sample([Vector(p) for p in
                          [(-0.10, 0, 0.20), (0.02, 0, 0.252), (0.13, 0, 0.19)]], 12)
pectL_spine = cr_sample([Vector(p) for p in
                         [(-0.120, -0.032, 0.075), (-0.235, -0.088, 0.035)]], 8)
pectR_spine = cr_sample([Vector(p) for p in
                         [(-0.120, 0.032, 0.075), (-0.235, 0.088, 0.035)]], 8)
pelvic_spine = cr_sample([Vector(p) for p in
                          [(0.0, 0, 0.035), (0.08, 0, -0.012)]], 8)

def dmin(p, poly):
    best = 1e9
    for i in range(len(poly)-1):
        a, b = poly[i], poly[i+1]
        ab = b-a
        t = max(0.0, min(1.0, (p-a).dot(ab)/max(ab.length_squared, 1e-9)))
        best = min(best, (p-(a+ab*t)).length)
    return best

def rb_at(x):
    xs = [st[0] for st in PROFILE]
    for i in range(len(xs)-1):
        if xs[i] <= x <= xs[i+1]:
            f = (x-xs[i])/(xs[i+1]-xs[i])
            return PROFILE[i][4]*(1-f) + PROFILE[i+1][4]*f
    return 0.09

me = fish.data
npoly = len(me.polygons)
eye_f, fin_f, belly_f, mouth_f = set(), set(), set(), set()
for fi, p in enumerate(me.polygons):
    c = p.center
    if (c-eyeL).length < 0.0145 or (c-eyeR).length < 0.0145:
        eye_f.add(fi)
        continue
    if c.x < -0.252 and dmin(c, [mouth_pt, mouth_pt + Vector((0.001, 0, 0))]) < 0.016:
        mouth_f.add(fi)
        continue
    is_fin = False
    if c.x > 0.205 and dmin(c, caudal_spine) < 0.088:
        is_fin = True
    elif dmin(c, dorsal_spine) < 0.034 and c.z > 0.168:
        is_fin = True
    elif dmin(c, pectL_spine) < 0.026 or dmin(c, pectR_spine) < 0.026:
        is_fin = True
    elif dmin(c, pelvic_spine) < 0.020 and c.z < 0.04:
        is_fin = True
    if is_fin:
        fin_f.add(fi)
    elif c.z < 0.121 - 0.60*rb_at(c.x):
        belly_f.add(fi)

def dilate(seed, rings):
    vfaces = [[] for _ in range(len(me.vertices))]
    for p in me.polygons:
        for v in p.vertices:
            vfaces[v].append(p.index)
    cur = set(seed)
    frontier = set(seed)
    for _ in range(rings):
        nxt = set()
        for fi in frontier:
            for v in me.polygons[fi].vertices:
                for fj in vfaces[v]:
                    if fj not in cur:
                        nxt.add(fj)
        cur |= nxt
        frontier = nxt
    return cur

fin_f = dilate(fin_f, 1)
eye_f = dilate(eye_f, 1)
print('MASKS eye=%d fin=%d belly=%d mouth=%d of %d' % (
    len(eye_f), len(fin_f), len(belly_f), len(mouth_f), npoly))

face_rgb = []
for fi in range(npoly):
    if fi in eye_f:
        face_rgb.append(REG_COL['black'])
    elif fi in mouth_f:
        face_rgb.append(REG_COL['dark'])
    elif fi in fin_f or fi in belly_f:
        face_rgb.append(REG_COL['cream'])
    else:
        face_rgb.append(REG_COL['orange'])

# per-VERTEX colors (POINT domain): continuous attribute -> glTF cannot
# split primitives on it, and boundaries render as soft gradients.
import numpy as np
rgb = np.array(face_rgb, dtype=np.float32)
vert_faces = [[] for _ in range(len(me.vertices))]
for p in me.polygons:
    for v in p.vertices:
        vert_faces[v].append(p.index)
vavg = np.zeros((len(me.vertices), 3), dtype=np.float32)
for vi, fl in enumerate(vert_faces):
    vavg[vi] = rgb[fl].mean(axis=0)
me.color_attributes.new(name='Col', type='FLOAT_COLOR', domain='POINT')
ca = me.color_attributes['Col']
for vi in range(len(me.vertices)):
    c = vavg[vi]
    ca.data[vi].color = (*c, 1.0)
print('PAINTED vertex colors (%d verts)' % len(me.vertices))

dc = fish.modifiers.new('dc', 'DECIMATE')
dc.ratio = 0.30
bpy.ops.object.modifier_apply(modifier=dc.name)
print('DECIMATED polys=%d' % len(fish.data.polygons))

# ---------------- keep only the largest connected island ---------------------
bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table()
seen = set()
islands = []
for v in bm.verts:
    if v.index in seen or not v.link_faces:
        continue
    stack = [v]
    comp = set()
    seen.add(v.index)
    while stack:
        cur = stack.pop()
        comp.add(cur.index)
        for e in cur.link_edges:
            o = e.other_vert(cur)
            if o.index not in seen:
                seen.add(o.index)
                stack.append(o)
    islands.append(comp)
islands.sort(key=len, reverse=True)
removed = 0
if len(islands) > 1:
    keep = islands[0]
    doomed = [v for v in bm.verts if v.index not in keep]
    removed = len(doomed)
    bmesh.ops.delete(bm, geom=doomed, context='VERTS')
print('ISLANDS=%d removed_verts=%d' % (len(islands), removed))
bm.to_mesh(me)
bm.free()
chk = bmesh.new()
chk.from_mesh(me)
be = sum(1 for e in chk.edges if len(e.link_faces) == 1)
nmv = sum(1 for e in chk.edges if len(e.link_faces) > 2)
print('PREEXPORT boundary=%d nonmanifold=%d polys=%d' % (
    be, nmv, len(me.polygons)))
chk.free()
for p in me.polygons:
    p.use_smooth = True

bpy.ops.export_scene.gltf(filepath=glb_out, export_format='GLB')

mins = [1e9]*3
maxs = [-1e9]*3
for v in me.vertices:
    for k, val in enumerate(v.co):
        mins[k] = min(mins[k], val)
        maxs[k] = max(maxs[k], val)
dims = tuple(round(maxs[k]-mins[k], 3) for k in range(3))
print('DIMS (%s)' % ', '.join(str(d) for d in dims))
print('ASSET_BUILT')
