# Deterministic asset builder: reads a JSON part-list, writes a GLB.
# Craft rules (contiguity, smoothness, taper, tip orientation) are guaranteed
# here BY CONSTRUCTION - gemini only chooses parameters.
# Usage: blender --background --python build_asset.py -- <params.json> <out.glb>
import bpy
import bmesh
import json
import math
import random
import sys
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
params_path, glb_out = argv[0], argv[1]
with open(params_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

bpy.ops.wm.read_homefile(use_empty=True)

mats = {}
for name, m in data.get('materials', {}).items():
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    c = m['color']
    bsdf.inputs["Base Color"].default_value = (float(c[0]), float(c[1]), float(c[2]), 1.0)
    bsdf.inputs["Roughness"].default_value = float(m.get('roughness', 0.8))
    mats[name] = mat


def add_mesh(name, bm, mat_name, smooth):
    sn = data.get('surface_noise')
    if sn and sn.get('amplitude', 0) > 0:
        apply_surface_noise(bm, float(sn.get('frequency', 20.0)),
                            float(sn['amplitude']), int(sn.get('seed', 1)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if mat_name and mat_name in mats:
        ob.data.materials.append(mats[mat_name])
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    return ob


def _cr(points):
    """Catmull-Rom through points (Vectors or floats); returns sampled list."""
    is_vec = hasattr(points[0], 'x')
    pts = [points[0]] + list(points) + [points[-1]]
    zero = Vector((0, 0, 0)) if is_vec else 0.0
    out = []
    n = len(points)
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        for s in range(SAMPLES_PER_SEG):
            t = s / SAMPLES_PER_SEG
            t2, t3 = t * t, t * t * t
            if is_vec:
                v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            else:
                v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append(max(v, 1e-4) if not is_vec else v)
    out.append(points[-1])
    return out


SAMPLES_PER_SEG = 16


def sweep_spline(waypoints, radii, sides):
    """One continuous tube swept along a Catmull-Rom spline through the
    waypoints; radius interpolated MONOTONICALLY (linear in curve parameter,
    so no overshoot necking/bulging between waypoints). No joints, no kinks."""
    centers = _cr([Vector(w) for w in waypoints])
    sweep_spline.failed = 0
    n_wp = len(radii)
    rs = []
    for idx in range(len(centers)):
        u = idx * (n_wp - 1) / max(len(centers) - 1, 1)
        i0 = min(int(u), n_wp - 2)
        f = u - i0
        rs.append(max(radii[i0] + (radii[i0 + 1] - radii[i0]) * f, 1e-4))
    if len(centers) != len(rs):
        m = min(len(centers), len(rs))
        centers, rs = centers[:m], rs[:m]
    bm = bmesh.new()
    rings = []
    nsides = len(centers)
    UP = Vector((0, 0, 1))
    for idx in range(nsides):
        c = centers[idx]
        t = centers[min(idx + 1, nsides - 1)] - centers[max(idx - 1, 0)]
        if t.length < 1e-9:
            t = Vector((1, 0, 0))
        t.normalize()
        # fixed-up frame: project world up onto the plane perpendicular to the
        # tangent -> zero roll/twist along the sweep, no shading seams
        n = UP - t * t.dot(UP)
        if n.length < 1e-6:
            n = Vector((1, 0, 0)) - t * t.x
            if n.length < 1e-6:
                n = Vector((0, 1, 0)) - t * t.y
        n.normalize()
        b = t.cross(n)
        r = max(rs[idx], 1e-4)
        ring = []
        for k in range(sides):
            a = 2.0 * math.pi * k / sides
            ring.append(bm.verts.new(c + n * (math.cos(a) * r) + b * (math.sin(a) * r)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            try:
                bm.faces.new((rings[j][k], rings[j][k2], rings[j + 1][k2], rings[j + 1][k]))
            except ValueError:
                sweep_spline.failed += 1
    for ring, c, flip in ((rings[0], centers[0], True), (rings[-1], centers[-1], False)):
        cv = bm.verts.new(c)
        for k in range(sides):
            k2 = (k + 1) % sides
            vs = (cv, ring[k2], ring[k]) if flip else (cv, ring[k], ring[k2])
            try:
                bm.faces.new(vs)
            except ValueError:
                sweep_spline.failed += 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    print("SWEEP_DEBUG rings=%d sides=%d faces=%d failed=%d" %
          (len(rings), sides, len(bm.faces), sweep_spline.failed))
    return bm


def apply_surface_noise(bm, frequency, amplitude, seed):
    """Gentle normal displacement so surfaces read organic, not extruded."""
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28318) for _ in range(6)]

    def sn(v):
        x, y, z = v.x * frequency, v.y * frequency, v.z * frequency
        return (math.sin(x + ph[0]) * math.sin(y * 1.31 + ph[1]) +
                math.sin(y * 0.93 + ph[2]) * math.sin(z * 1.13 + ph[3]) +
                math.sin(z * 1.21 + ph[4]) * math.sin(x * 0.83 + ph[5])) / 6.0

    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * (sn(v.co) * amplitude)


def build_bent_cylinder(p):
    wps = p['waypoints']
    if len(wps) < 2:
        raise ValueError("bent_cylinder needs >=2 waypoints")
    sides = int(p.get('sides', 24))
    n = len(wps)
    radii = p.get('radii')
    if not radii or len(radii) != n:
        r0 = p.get('radius_start', 0.01)
        r1 = p.get('radius_end', r0)
        radii = [r0 + (r1 - r0) * (i / (n - 1)) for i in range(n)]
    bm = sweep_spline(wps, radii, sides)
    collar = p.get('collar')
    if collar:
        add_collar(bm, Vector(wps[0]), radii[0] * float(collar),
                   (Vector(wps[1]) - Vector(wps[0])).normalized())
    return bm


def add_collar(bm, at, radius, axis):
    """Bark knuckle: squashed sphere where a branch leaves the shaft."""
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=16, v_segments=12, radius=max(radius, 1e-4))
    rot = axis.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    tmp.transform(rot @ Matrix.Diagonal((1.0, 1.0, 0.65, 1.0)))
    tmp.transform(Matrix.Translation(at))
    me = bpy.data.meshes.new("_collar")
    tmp.to_mesh(me)
    tmp.free()
    tmp_bm = bmesh.new()
    tmp_bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    offs = {v.index: bm.verts.new(v.co) for v in tmp_bm.verts}
    for f in tmp_bm.faces:
        try:
            bm.faces.new([offs[v.index] for v in f.verts])
        except ValueError:
            pass
    tmp_bm.free()


def seg_bms(pairs, sides):
    """pairs: list of (p0, p1, r0, r1). One welded bmesh of cylinders sharing endpoints."""
    bm = bmesh.new()
    for p0, p1, r0, r1 in pairs:
        p0v, p1v = Vector(p0), Vector(p1)
        d = p1v - p0v
        if d.length < 1e-6:
            raise ValueError("degenerate segment (zero length)")
        ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False,
                                    segments=sides, radius1=max(r0, 1e-4),
                                    radius2=max(r1, 1e-4), depth=d.length)
        q = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        mid = (p0v + p1v) / 2.0
        for v in ret['verts']:
            v.co = q @ v.co + mid
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    return bm


def build_cylinder(p):
    sides = int(p.get('sides', 24))
    r0 = p.get('radius_start', p.get('radius', 0.01))
    r1 = p.get('radius_end', p.get('radius', r0))
    bm = sweep_spline([p['from'], p['to']], [r0, r1], sides)
    collar = p.get('collar')
    if collar:
        add_collar(bm, Vector(p['from']), float(r0) * float(collar),
                   (Vector(p['to']) - Vector(p['from'])).normalized())
    return bm


def build_splintered_tip(p):
    """Jagged broken-wood end: a short core stub plus splayed splinter spikes."""
    base = Vector(p['base'])
    direction = Vector(p.get('direction', [1, 0, 0]))
    if direction.length < 1e-9:
        direction = Vector((1, 0, 0))
    direction.normalize()
    radius = max(float(p['radius']), 5e-4)
    seed = int(p.get('seed', 7))
    n_spikes = int(p.get('spikes', 7))
    rnd = random.Random(seed)
    q = direction.to_track_quat('Z', 'Y').to_matrix()
    bm = bmesh.new()
    # core stub so the break has body
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False,
                                segments=12, radius1=radius, radius2=radius * 0.55,
                                depth=radius * 1.4)
    for v in ret['verts']:
        v.co = q @ v.co + base + direction * (radius * 0.7)
    # splinter spikes: golden-angle spread around the break plane, seeded jitter
    ga = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n_spikes):
        a = ga * i + rnd.uniform(-0.35, 0.35)
        off = Vector((math.cos(a), math.sin(a), 0)) * radius * rnd.uniform(0.25, 0.8)
        splay = rnd.uniform(0.15, 0.6)
        d = (direction + Vector((math.cos(a) * splay, math.sin(a) * splay, 0))).normalized()
        ln = radius * rnd.uniform(1.6, 5.2)
        rr = radius * rnd.uniform(0.18, 0.34)
        tmp = bmesh.new()
        ret2 = bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False,
                                     segments=6, radius1=rr, radius2=rr * 0.12, depth=ln)
        qq = d.to_track_quat('Z', 'Y').to_matrix()
        start = base + off + direction * (radius * rnd.uniform(0.1, 0.5))
        for v in ret2['verts']:
            v.co = qq @ v.co + start + d * (ln / 2)
        me = bpy.data.meshes.new("_spike")
        tmp.to_mesh(me)
        tmp.free()
        tbm = bmesh.new()
        tbm.from_mesh(me)
        bpy.data.meshes.remove(me)
        mapping = {}
        for v in tbm.verts:
            mapping[v.index] = bm.verts.new(v.co)
        for f in tbm.faces:
            try:
                bm.faces.new([mapping[v.index] for v in f.verts])
            except ValueError:
                pass
        tbm.free()
    return bm


def build_cone_tip(p):
    base, tip = Vector(p['base']), Vector(p['tip'])
    d = tip - base
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False,
                          segments=int(p.get('sides', 16)),
                          radius1=float(p['radius']), radius2=1e-4,
                          depth=d.length)
    q = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    bm.transform(q)
    bm.transform(Matrix.Translation(base))
    return bm


def build_box(p):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    s = p['size']
    bm.transform(Matrix.Diagonal((s[0], s[1], s[2], 1.0)))
    rot = p.get('rot_deg', [0, 0, 0])
    if any(rot):
        rx, ry, rz = [math.radians(a) for a in rot]
        bm.transform(Matrix.Rotation(rz, 4, 'Z') @ Matrix.Rotation(ry, 4, 'Y') @ Matrix.Rotation(rx, 4, 'X'))
    bm.transform(Matrix.Translation(Vector(p['center'])))
    return bm


def build_sphere(p):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=int(p.get('u_segments', 24)),
                              v_segments=int(p.get('v_segments', 16)),
                              radius=float(p['radius']))
    bm.transform(Matrix.Translation(Vector(p['center'])))
    return bm


def build_rock(p):
    """Natural stone: uvsphere deformed by seeded low-frequency lumps, squashed,
    with a flattened resting face so it sits believably on the ground."""
    r = max(float(p.get('radius', 0.05)), 5e-4)
    seed = int(p.get('seed', 5))
    squash = p.get('squash', [1.0, 0.85, 0.72])
    amp = float(p.get('lumpiness', 0.2))
    facet = min(max(float(p.get('facet', 0.0)), 0.0), 1.0)
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28318) for _ in range(8)]
    bm = bmesh.new()
    default_subd = 2 if facet > 0.3 else 4
    ret = bmesh.ops.create_icosphere(bm, subdivisions=int(p.get('subdivisions', default_subd)), radius=r)
    for v in ret['verts']:
        n = v.co.normalized()
        d = 1.0 + amp * ((math.sin(n.x * 2.1 + ph[0]) * math.sin(n.y * 1.7 + ph[1]) +
                          math.sin(n.y * 2.3 + ph[2]) * math.sin(n.z * 1.9 + ph[3])) / 2.0 +
                         (math.sin(n.x * 4.3 + ph[4]) * math.sin(n.z * 3.7 + ph[5]) +
                          math.sin(n.y * 4.1 + ph[6]) * math.sin(n.x * 3.3 + ph[7])) / 8.0)
        d += facet * rnd.uniform(-amp, amp) * 0.9
        v.co = n * (r * d)
    bm.transform(Matrix.Diagonal((float(squash[0]), float(squash[1]), float(squash[2]), 1.0)))
    fl = min(max(float(p.get('flatten', 0.35)), 0.0), 0.8)
    for v in bm.verts:
        t = min(max(-v.co.z / (r * 0.8), 0.0), 1.0)
        v.co.z *= 1.0 - fl * t * t
    zmin = min(v.co.z for v in bm.verts)
    cut = zmin + (0.0 - zmin) * (0.15 + 0.25 * fl)
    for v in bm.verts:
        if v.co.z < cut:
            v.co.z = cut
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.transform(Matrix.Translation(Vector(p['center'])))
    return bm


BUILDERS = {
    'bent_cylinder': build_bent_cylinder,
    'cylinder': build_cylinder,
    'cone_tip': build_cone_tip,
    'splintered_tip': build_splintered_tip,
    'box': build_box,
    'sphere': build_sphere,
    'rock': build_rock,
}

try:
    parts = data['parts']
    if not isinstance(parts, list) or not parts:
        raise ValueError("parts must be a non-empty list")
    for idx, p in enumerate(parts):
        t = p.get('type')
        if t not in BUILDERS:
            raise ValueError("part %d has unknown type '%s' (valid: %s)" % (idx, t, ', '.join(sorted(BUILDERS))))
        bm = BUILDERS[t](p)
        add_mesh(p.get('name', 'part_%d' % idx), bm, p.get('material'), bool(p.get('smooth', True)))
    if data.get('auto_ground', True):
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        mz = min((v.co).z for o in meshes for v in o.data.vertices)
        for o in meshes:
            o.location.z -= mz
    bpy.ops.export_scene.gltf(filepath=glb_out, export_format='GLB')

    mins = [1e9] * 3
    maxs = [-1e9] * 3
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            for k, val in enumerate((w.x, w.y, w.z)):
                mins[k] = min(mins[k], val)
                maxs[k] = max(maxs[k], val)
    dims = tuple(round(maxs[k] - mins[k], 3) for k in range(3))
    print("DIMS (%s)" % ", ".join(str(d) for d in dims))
    print("ASSET_BUILT")
except Exception as e:
    print("BUILD_ERROR: %s" % e)
