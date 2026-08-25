import bpy
import bmesh

# Objective silhouette analysis of the paw hand region.
# Q: does the BACK of the hand (+Y view) show digit bumps (toe knuckles)?
# In paw_hv space: hand = |z|<0.25, back faces +Y.
def main():
    glb_path = r"C:\crypto\wicked whiskers\assets\paw_hv.glb"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    obj = None
    for o in bpy.data.objects:
        if o.type == "MESH":
            obj = o
            break
    if obj is None:
        print("RESULT: no mesh")
        return
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    bm.from_object(obj, depsgraph)
    bm.transform(obj.matrix_world)
    verts = [v.co for v in bm.verts]

    def analyze(label, vs):
        if not vs:
            print("RESULT: %s: empty" % label)
            return
        x0 = min(v.x for v in vs); x1 = max(v.x for v in vs)
        nb = 80
        profile = []
        for i in range(nb):
            xa = x0 + (x1 - x0) * i / nb
            xb = x0 + (x1 - x0) * (i + 1) / nb
            slab = [v for v in vs if xa <= v.x < xb]
            if slab:
                profile.append(max(v.z for v in slab))
            else:
                profile.append(None)
        vals = [(p if p is not None else 0.0) for p in profile]
        smooth = []
        for i in range(len(vals)):
            lo = max(0, i - 3); hi = min(len(vals), i + 4)
            smooth.append(sum(vals[lo:hi]) / (hi - lo))
        maxima = []
        for i in range(1, len(smooth) - 1):
            if smooth[i] > smooth[i-1] and smooth[i] > smooth[i+1]:
                maxima.append((i, round(smooth[i], 3)))
        peak = max(smooth); trough = min(smooth)
        print("RESULT: %s profile_peaks=%d peak=%.3f trough=%.3f range=%.3f" % (label, len(maxima), peak, trough, peak - trough))
        print("RESULT: %s maxima_xbins=%s" % (label, maxima))

    # Hand region, viewed from the back (+Y). Digit row = max Z per X bin.
    hand = [v for v in verts if abs(v.z) < 0.25]
    analyze("hand_from_back", hand)
    # Same but viewed from the palm (-Y): still X-Z projection
    analyze("hand_from_palm", hand)
    # Side view: from +X, project onto Y-Z. Shows the -Y growth as a bump.
    vs = hand
    y0 = min(v.y for v in vs); y1 = max(v.y for v in vs)
    nb = 80
    profile = []
    for i in range(nb):
        ya = y0 + (y1 - y0) * i / nb
        yb = y0 + (y1 - y0) * (i + 1) / nb
        slab = [v for v in vs if ya <= v.y < yb]
        if slab:
            profile.append(max(v.z for v in slab))
        else:
            profile.append(None)
    vals = [(p if p is not None else 0.0) for p in profile]
    smooth = []
    for i in range(len(vals)):
        lo = max(0, i - 3); hi = min(len(vals), i + 4)
        smooth.append(sum(vals[lo:hi]) / (hi - lo))
    maxima = []
    for i in range(1, len(smooth) - 1):
        if smooth[i] > smooth[i-1] and smooth[i] > smooth[i+1]:
            maxima.append((i, round(smooth[i], 3)))
    print("RESULT: hand_side_via_y_z profile_peaks=%d" % len(maxima))
    print("RESULT: hand_side_via_y_z maxima_ybins=%s" % maxima)
    bm.free()

if __name__ == "__main__":
    main()
