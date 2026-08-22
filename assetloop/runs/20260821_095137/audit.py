import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\crypto\wicked whiskers\assetloop\runs\20260821_095137\stick_3.glb")
miny = 999.0
for o in bpy.context.scene.objects:
    if o.type != 'MESH': continue
    ys = [(o.matrix_world @ v.co).y for v in o.data.vertices]
    if not ys: continue
    omin = min(ys)
    print("AUDITOBJ", o.name, round(omin, 4))
    miny = min(miny, omin)
print("AUDITMINY", round(miny, 4))
