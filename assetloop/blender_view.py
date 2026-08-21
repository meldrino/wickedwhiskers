import bpy
import sys

glb = sys.argv[sys.argv.index('--') + 1]
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
print('IMPORTED', glb)
