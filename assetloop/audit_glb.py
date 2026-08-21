import bpy
import sys

glb = sys.argv[sys.argv.index('--') + 1]
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

miny = 999.0
for o in bpy.context.scene.objects:
    if o.type != 'MESH':
        continue
    ys = [(o.matrix_world @ v.co).y for v in o.data.vertices]
    if not ys:
        continue
    omin = min(ys)
    print("AUDITOBJ", o.name, round(omin, 4))
    miny = min(miny, omin)
print("AUDITMINY", round(miny, 4))
