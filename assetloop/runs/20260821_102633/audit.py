import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\crypto\wicked whiskers\assetloop\runs\20260821_102633\stick_3.glb")
miny = 999.0
mins = [999.0]*3; maxs = [-999.0]*3
for o in bpy.context.scene.objects:
    if o.type != 'MESH': continue
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        p = (w.x, w.y, w.z)
        for k in range(3):
            if p[k] < mins[k]: mins[k] = p[k]
            if p[k] > maxs[k]: maxs[k] = p[k]
    ys = [(o.matrix_world @ v.co).y for v in o.data.vertices]
    if not ys: continue
    omin = min(ys)
    print("AUDITOBJ", o.name, round(omin, 4))
    miny = min(miny, omin)
print("AUDITMINY", round(miny, 4))
print("AUDITBBOX", round(maxs[0]-mins[0],4), round(maxs[1]-mins[1],4), round(maxs[2]-mins[2],4))
