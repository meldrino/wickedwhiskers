import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\crypto\wicked whiskers\assetloop\runs\20260821_150737\stone_4.glb")
junk = [o for o in list(bpy.context.scene.objects) if o.name.split('.')[0] in ('Cube', 'Plane', 'Circle', 'Sphere')]
if junk:
    for o in junk: bpy.data.objects.remove(o)
    bpy.ops.export_scene.gltf(filepath=r"C:\crypto\wicked whiskers\assetloop\runs\20260821_150737\stone_4.glb", export_format='GLB')
    print('JUNK_REMOVED')
else:
    print('JUNK_NONE')
