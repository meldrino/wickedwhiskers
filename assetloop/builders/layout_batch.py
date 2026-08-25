# Lay out several GLBs side by side in one scene for human review.
#   blender --python layout_batch.py -- <glb1> <glb2> ...
import bpy
import sys

argv = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_homefile(use_empty=True)

spacing = 0.75
for i, glb in enumerate(argv):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb)
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None or o.parent not in new]
    for r in roots:
        r.location.x += i * spacing
    print("LAID_OUT", glb, "at x=%.2f" % (i * spacing))

print("LAYOUT_DONE")
