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
bb_min = Vector((min(c[i] for c in corners) for i in range(3)))
bb_size = Vector((max(c[i] for c in corners) for i in range(3))) - bb_min

hand_verts = []
for o in meshes:
    for v in o.data.vertices:
        wz = (o.matrix_world @ v.co).z
        if wz > bb_min.z + 0.72 * bb_size.z:
            hand_verts.append(o.matrix_world @ v.co)

hand_center = Vector(tuple(sum(v[i] for v in hand_verts) / len(hand_verts) for i in range(3)))
r_max = max((v - hand_center).length for v in hand_verts)

fov = math.radians(50)
D = r_max * 3.0 / math.tan(fov / 2.0)

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.angle = fov
cam.location = hand_center + Vector((0, D, 0))
q = Vector((0, 0, -1)).rotation_difference(Vector((0, -1, 0)))
cam.rotation_euler = q.to_euler()

world = bpy.data.worlds.new('W')
scene.world = world
world.node_tree.nodes['Background'].inputs[0].default_value = (0.18, 0.18, 0.21, 1)

key = bpy.data.objects.new('Key', bpy.data.lights.new('Key', 'AREA'))
scene.collection.objects.link(key)
key.location = cam.location + Vector((0.9, 0.3, 1.4))
key.data.energy = 1800
key.rotation_euler = q.to_euler()
fill = bpy.data.objects.new('Fill', bpy.data.lights.new('Fill', 'AREA'))
scene.collection.objects.link(fill)
fill.location = cam.location + Vector((-0.9, 0.4, 0.7))
fill.data.energy = 700
rim = bpy.data.objects.new('Rim', bpy.data.lights.new('Rim', 'AREA'))
scene.collection.objects.link(rim)
rim.location = cam.location + Vector((0, -0.8, 1.6))
rim.data.energy = 800

scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('HAND_CENTER=%s R_MAX=%.3f' % (tuple(round(v, 3) for v in hand_center), r_max))
print('RENDERED:' + OUT)
