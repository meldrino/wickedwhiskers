import bpy
import bmesh
import math
import os
import sys

# Load paw_hv.glb, analyze hand-region asymmetry + locate the palm growth.
# Hand center is at origin in paw_hv.glb space (arm extends -Z).
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
    me = obj.data
    me.calc_loop_triangles()
    # Ensure object transforms applied
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    obj_eval = obj.evaluated_get(depsgraph)
    bm = bmesh.new()
    bm.from_object(obj_eval, depsgraph)
    bm.transform(obj.matrix_world)
    verts = [v.co for v in bm.verts]
    xs = [v.x for v in verts]
    ys = [v.y for v in verts]
    zs = [v.z for v in verts]
    print("RESULT: total_verts=%d bbox x[%.4f..%.4f] y[%.4f..%.4f] z[%.4f..%.4f]" % (
        len(verts), min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    # Hand region: |z| < 0.25 (hand radius ~0.18, excludes the long arm going -Z)
    hand = [v for v in verts if abs(v.z) < 0.25]
    if hand:
        hx = [v.x for v in hand]; hy = [v.y for v in hand]
        print("RESULT: hand_region(z|z|<0.25) n=%d x[%.4f..%.4f] y[%.4f..%.4f] wx=%.4f wy=%.4f" % (
            len(hand), min(hx), max(hx), min(hy), max(hy), max(hx)-min(hx), max(hy)-min(hy)))
    # Y-profile of the hand region in slabs to find where a growth pokes out (asymmetry).
    # Growth likely on palm = one side of Y. Print per-Z-slab Y extents.
    print("RESULT: z_slab profiles (z_low..z_high: y_min y_max y_mid, x_min x_max x_mid)")
    z0, z1 = -0.25, 0.25
    for i in range(10):
        za = z0 + (z1-z0) * i / 10.0
        zb = z0 + (z1-z0) * (i+1) / 10.0
        slab = [v for v in hand if za <= v.z < zb]
        if slab:
            sx = [v.x for v in slab]; sy = [v.y for v in slab]
            print("RESULT: slab z[%.4f..%.4f] n=%d y[%.4f..%.4f] ymid=%.4f x[%.4f..%.4f] xmid=%.4f" % (
                za, zb, len(slab), min(sy), max(sy), (min(sy)+max(sy))/2.0, min(sx), max(sx), (min(sx)+max(sx))/2.0))
    bm.free()

if __name__ == "__main__":
    main()
