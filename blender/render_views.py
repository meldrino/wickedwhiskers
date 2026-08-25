import bpy, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
GLB = args[args.index('--glb') + 1]
OUT = args[args.index('--out') + 1]

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=GLB)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
bpy.context.view_layer.update()

meshes = [o for o in scene.objects if o.type == 'MESH']
corners = []
for o in meshes:
    corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
bb_max = Vector((max(c[i] for c in corners) for i in range(3)))
bb_min = Vector((min(c[i] for c in corners) for i in range(3)))
bb_center = (bb_max + bb_min) * 0.5
bb_size = bb_max - bb_min

z_steps = 40
z_hist = {}
for o in meshes:
    for v in o.data.vertices:
        wz = (o.matrix_world @ v.co).z
        zidx = min(z_steps - 1, max(0, int((wz - bb_min.z) / bb_size.z * z_steps)))
        z_hist[zidx] = z_hist.get(zidx, 0) + 1
zmax = max(z_hist.values())
bars = []
for i in range(z_steps):
    bars.append('#' if z_hist.get(i, 0) > zmax * 0.25 else '.')
print('ZPROFILE low->high: %s' % ''.join(bars))

world = bpy.data.worlds.new('W')
scene.world = world
world.node_tree.nodes['Background'].inputs[0].default_value = (0.13, 0.13, 0.15, 1)

key = bpy.data.objects.new('Key', bpy.data.lights.new('Key', 'AREA'))
scene.collection.objects.link(key)
key.data.energy = 800
fill = bpy.data.objects.new('Fill', bpy.data.lights.new('Fill', 'AREA'))
scene.collection.objects.link(fill)
fill.data.energy = 350

fov = math.radians(45)
margin = 2.0
D = (max(bb_size.x, bb_size.y, bb_size.z) * margin) / (2.0 * math.tan(fov / 2.0))

views = {
    'top': (bb_center + Vector((0, 0, D)), (0, 0, -1), 'TOP'),
    'front': (bb_center + Vector((0, -D, 0)), (0, 1, 0), 'FRONT'),
    'back': (bb_center + Vector((0, D, 0)), (0, -1, 0), 'BACK'),
    'right': (bb_center + Vector((D, 0, 0)), (-1, 0, 0), 'RIGHT'),
    'left': (bb_center + Vector((-D, 0, 0)), (1, 0, 0), 'LEFT'),
    'bottom': (bb_center + Vector((0, 0, -D)), (0, 0, 1), 'BOTTOM'),
    'qtr': (bb_center + Vector((D * 0.6, -D * 0.6, D * 0.6)), Vector((-1, 1, -1)).normalized(), '3-4'),
}

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.angle = fov

scene.render.resolution_x = 800
scene.render.resolution_y = 533

import os
os.makedirs(os.path.dirname(OUT), exist_ok=True)
base = os.path.splitext(OUT)[0]
for name, (loc, fwd, label) in views.items():
    cam.location = loc
    q = Vector((0, 0, -1)).rotation_difference(fwd)
    cam.rotation_euler = q.to_euler()
    cam.rotation_euler.x += math.radians(20)
    key.location = cam.location + Vector((0.6, 0.6, 0.8))
    fill.location = cam.location + Vector((-0.6, 0.7, 0.5))
    scene.render.filepath = '%s_%s.png' % (base, name)
    bpy.ops.render.render(write_still=True)
    print('VIEW %s done' % label)
print('SHEET_DONE')
