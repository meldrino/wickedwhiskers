import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\crypto\wicked whiskers\assetloop\runs\20260821_152113\stone_3.glb")
minz = 999.0
mins = [999.0]*3; maxs = [-999.0]*3
for o in bpy.context.scene.objects:
    if o.type != 'MESH': continue
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        p = (w.x, w.y, w.z)
        for k in range(3):
            if p[k] < mins[k]: mins[k] = p[k]
            if p[k] > maxs[k]: maxs[k] = p[k]
    zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
    if not zs: continue
    omin = min(zs)
    print("AUDITOBJ", o.name, round(omin, 4))
    minz = min(minz, omin)
print("AUDITMINZ", round(minz, 4))
print("AUDITBBOX", round(maxs[0]-mins[0],4), round(maxs[1]-mins[1],4), round(maxs[2]-mins[2],4))
