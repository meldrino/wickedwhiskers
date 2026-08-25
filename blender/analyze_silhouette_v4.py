import bpy
import bmesh
import sys

def main():
    glb_path = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    obj = None
    best = 0
    for o in bpy.data.objects:
        if o.type == "MESH" and len(o.data.vertices) > best:
            obj = o
            best = len(o.data.vertices)
    if obj is None:
        print("RESULT: no mesh")
        return
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    bm.from_object(obj, depsgraph)
    bm.transform(obj.matrix_world)
    verts = [v.co for v in bm.verts]

    def profile_x_z(vs, label, nb=80, w=4):
        x0 = min(v.x for v in vs); x1 = max(v.x for v in vs)
        if x1 - x0 < 1e-6:
            print("RESULT: %s empty" % label); return
        prof = []
        for i in range(nb):
            xa = x0 + (x1 - x0) * i / nb
            xb = x0 + (x1 - x0) * (i + 1) / nb
            slab = [v for v in vs if xa <= v.x < xb]
            prof.append(max(v.z for v in slab) if slab else None)
        vals = [p if p is not None else 0.0 for p in prof]
        smooth = []
        for i in range(len(vals)):
            lo = max(0, i - w); hi = min(len(vals), i + w + 1)
            smooth.append(sum(vals[lo:hi]) / (hi - lo))
        maxima = []
        for i in range(1, len(smooth) - 1):
            if smooth[i] > smooth[i-1] and smooth[i] > smooth[i+1]:
                maxima.append((round(x0 + (x1 - x0) * i / nb, 3), round(smooth[i], 3)))
        peak = max(smooth); trough = min(smooth)
        print("RESULT: %s peaks=%d peak=%.3f trough=%.3f range=%.3f" % (label, len(maxima), peak, trough, peak - trough))
        print("RESULT: %s maxima_x=%s" % (label, maxima))

    hand = [v for v in verts if abs(v.z) < 0.30]
    profile_x_z(hand, "back_digit_row")
    arm = [v for v in verts if v.z < -0.30]
    x0 = min(v.x for v in arm); x1 = max(v.x for v in arm)
    print("RESULT: arm_width=%.3f z0=%.3f z1=%.3f" % (x1 - x0, min(v.z for v in arm), max(v.z for v in arm)))
    bm.free()

if __name__ == "__main__":
    main()
