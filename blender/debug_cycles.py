import bpy, sys, math

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
GLB = args[args.index('--glb') + 1]
OUT = args[args.index('--out') + 1]

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.render.resolution_x = 600
scene.render.resolution_y = 600
scene.cycles.device = 'GPU'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.view_settings.view_transform = 'Standard'

world = bpy.data.worlds.new('W')
scene.world = world
world.node_tree.nodes['Background'].inputs[0].default_value = (0.2, 0.2, 0.24, 1)

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, -4, 1.6)
cam.rotation_euler = (math.radians(12), 0, 0)

key = bpy.data.objects.new('Key', bpy.data.lights.new('Key', 'AREA'))
scene.collection.objects.link(key)
key.location = (1.5, -1.5, 2.5)
key.data.energy = 300

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
cube = bpy.context.active_object
mat = bpy.data.materials.new('Orange')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.976, 0.678, 0.349, 1.0)
cube.data.materials.append(mat)

scene.render.filepath = OUT.replace('.png', '_cube_cyc.png')
bpy.ops.render.render(write_still=True)
print('CUBE_CYC_DONE')
