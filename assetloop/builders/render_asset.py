# Self-rendering for the asset loop: opens a GLB and renders 4 studio-style
# views (Workbench engine = solid-viewport look) so the judge sees what a
# human sees in Blender. Usage:
#   blender --background --python render_asset.py -- <glb> <outdir>
import bpy
import bmesh
import math
import sys
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
glb, outdir = argv[0], argv[1]

bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
mins = [1e9] * 3
maxs = [-1e9] * 3
for o in meshes:
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        for k, val in enumerate((w.x, w.y, w.z)):
            mins[k] = min(mins[k], val)
            maxs[k] = max(maxs[k], val)
ctr = Vector(((mins[0] + maxs[0]) / 2, (mins[1] + maxs[1]) / 2, (mins[2] + maxs[2]) / 2))
ext = Vector((maxs[0] - mins[0], maxs[1] - mins[1], maxs[2] - mins[2]))
diag = ext.length

cam_data = bpy.data.cameras.new('cam')
cam = bpy.data.objects.new('cam', cam_data)
bpy.context.collection.objects.link(cam)
scene = bpy.context.scene
scene.camera = cam
cam_data.lens = 60

scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_cavity = True
scene.display.shading.show_shadows = True
scene.display.shading.shadow_intensity = 0.3
scene.render.resolution_x = 1024
scene.render.resolution_y = 768

world = bpy.data.worlds.new('bg')
world.color = (0.18, 0.18, 0.20)
scene.world = world

_bm = bmesh.new()
bmesh.ops.create_circle(_bm, cap_ends=True, segments=64, radius=1.0)
floor_data = bpy.data.meshes.new('floor')
_bm.to_mesh(floor_data)
_bm.free()
fw = diag * 3.0
floor_data.transform(Matrix.Diagonal((fw, fw, 1.0, 1.0)))
floor_data.transform(Matrix.Translation(Vector((ctr.x, ctr.y, mins[2] - 0.0004))))
floor_mat = bpy.data.materials.new('floor_mat')
floor_mat.diffuse_color = (0.32, 0.32, 0.34, 1.0)
floor_data.materials.append(floor_mat)
floor = bpy.data.objects.new('Floor', floor_data)
bpy.context.collection.objects.link(floor)

for i, (yaw, hf) in enumerate(((30, 0.5), (120, 0.5), (215, 0.08), (300, 0.3))):
    a = math.radians(yaw)
    d = diag * 1.05 + 0.12
    cam.location = ctr + Vector((math.cos(a) * d, math.sin(a) * d, diag * hf))
    direc = (ctr - cam.location).normalized()
    cam.rotation_euler = direc.to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = "%s\\view%d.png" % (outdir, i + 1)
    bpy.ops.render.render(write_still=True)

print("RENDERS_DONE")
