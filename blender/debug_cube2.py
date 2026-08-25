import bpy, sys, math

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.render.resolution_x = 400
scene.render.resolution_y = 400
scene.cycles.device = 'GPU'
scene.cycles.samples = 64
scene.view_settings.view_transform = 'Standard'

world = bpy.data.worlds.new('W')
scene.world = world
world.node_tree.nodes['Background'].inputs[0].default_value = (0.2, 0.2, 0.24, 1)

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, -1.6, 0.5)
cam.rotation_euler = (0, 0, 0)

key = bpy.data.objects.new('Key', bpy.data.lights.new('Key', 'AREA'))
scene.collection.objects.link(key)
key.location = (0.6, -0.8, 1.4)
key.data.energy = 5000

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
cube = bpy.context.active_object
mat = bpy.data.materials.new('Orange')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.976, 0.678, 0.349, 1.0)
cube.data.materials.append(mat)

scene.render.filepath = r'C:\crypto\wicked whiskers\screenshots\dbg_cube_close.png'
bpy.ops.render.render(write_still=True)

for img in bpy.data.images:
    if img.name == 'Render Result':
        px = img.pixels
        # center pixel
        w = img.size[0]
        ci = ((400 // 2) * w + (400 // 2)) * 4
        print('CENTER_PX %.3f %.3f %.3f' % (px[ci], px[ci + 1], px[ci + 2]))
        print('IMG_SIZE %d x %d' % (img.size[0], img.size[1]))
print('DONE')
